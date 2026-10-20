(* Unbounded spigot for the digits of pi, on Zarith (GMP) integers. *)
let () =
  let n = try int_of_string Sys.argv.(1) with _ -> 27 in
  let acc = ref Z.zero and den = ref Z.one and num = ref Z.one in
  let extract_digit nth = Z.to_int (Z.div (Z.add (Z.mul !num (Z.of_int nth)) !acc) !den) in
  let out = Buffer.create (n * 2) in
  let i = ref 0 and k = ref 0 in
  while !i < n do
    incr k;
    let k2 = Z.of_int ((!k * 2) + 1) in
    acc := Z.mul (Z.add !acc (Z.mul !num (Z.of_int 2))) k2;
    den := Z.mul !den k2;
    num := Z.mul !num (Z.of_int !k);
    if Z.leq !num !acc then begin
      let d = extract_digit 3 in
      if d = extract_digit 4 then begin
        Buffer.add_char out (Char.chr (48 + d));
        incr i;
        if !i mod 10 = 0 then Printf.bprintf out "\t:%d\n" !i;
        acc := Z.mul (Z.sub !acc (Z.mul !den (Z.of_int d))) (Z.of_int 10);
        num := Z.mul !num (Z.of_int 10)
      end
    end
  done;
  if !i mod 10 <> 0 then Printf.bprintf out "%s\t:%d\n" (String.make (10 - (!i mod 10)) ' ') !i;
  print_string (Buffer.contents out)
