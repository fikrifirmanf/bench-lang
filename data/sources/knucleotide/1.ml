(* k-nucleotide: counts every k-mer of the THREE sequence in a Hashtbl keyed by 2-bit packed codes.
   (3.ml rounds one percentage differently from the reference output.) *)
let code_of = function 'A' -> 0 | 'C' -> 1 | 'G' -> 2 | _ -> 3

let count_kmers seq k =
  let counts = Hashtbl.create 1024 in
  let mask = (1 lsl (2 * k)) - 1 in
  let key = ref 0 in
  Bytes.iteri
    (fun i c ->
      key := ((!key lsl 2) lor Char.code c) land mask;
      if i + 1 >= k then
        match Hashtbl.find_opt counts !key with
        | Some r -> incr r
        | None -> Hashtbl.add counts !key (ref 1))
    seq;
  counts

let unpack key k = String.init k (fun i -> "ACGT".[(key lsr (2 * (k - 1 - i))) land 3])

let read_sequence file_name =
  let ic = open_in_bin file_name in
  let rec skip () = if not (String.starts_with ~prefix:">THREE" (input_line ic)) then skip () in
  skip ();
  let b = Buffer.create (1 lsl 20) in
  (try
     while true do
       let line = input_line ic in
       if String.starts_with ~prefix:">" line then raise End_of_file;
       String.iter
         (fun c -> if c <> '\r' && c <> ' ' && c <> '\t' then Buffer.add_char b (Char.chr (code_of (Char.uppercase_ascii c))))
         line
     done
   with End_of_file -> ());
  close_in ic;
  Buffer.to_bytes b

let () =
  let seq = read_sequence (try Sys.argv.(1) with _ -> "25000_in") in
  let out = Buffer.create 4096 in
  List.iter
    (fun k ->
      let total = float_of_int (Bytes.length seq - k + 1) in
      Hashtbl.fold (fun key count acc -> (unpack key k, !count) :: acc) (count_kmers seq k) []
      |> List.sort (fun (a, ca) (b, cb) -> if ca <> cb then compare cb ca else compare a b)
      |> List.iter (fun (kmer, count) -> Printf.bprintf out "%s %.3f\n" kmer (float_of_int count *. 100. /. total));
      Buffer.add_char out '\n')
    [ 1; 2 ];
  List.iter
    (fun kmer ->
      let key = String.fold_left (fun acc c -> (acc lsl 2) lor code_of c) 0 kmer in
      let count = match Hashtbl.find_opt (count_kmers seq (String.length kmer)) key with Some r -> !r | None -> 0 in
      Printf.bprintf out "%d\t%s\n" count kmer)
    [ "GGT"; "GGTA"; "GGTATT"; "GGTATTTTAATT"; "GGTATTTTAATTTATAGT" ];
  print_string (Buffer.contents out)
