(* JSON round trip with Yojson: parse, serialize exactly as Python's json.dumps(separators=(',', ':')) does
   (ASCII-only escapes, shortest round-trip floats), print the MD5. 1.ml prints Yojson's own float format. *)

(* The fewest significant digits (1..17) that read back as the same float. *)
let shortest x =
  let rec search low high =
    if low >= high then low
    else
      let mid = (low + high) / 2 in
      if float_of_string (Printf.sprintf "%.*e" (mid - 1) x) = x then search low mid else search (mid + 1) high
  in
  Printf.sprintf "%.*e" (search 1 17 - 1) x

(* Python's repr(float): positional for 1e-4 <= |x| < 1e16, scientific otherwise. *)
let add_float b x =
  let sci = shortest (Float.abs x) in
  let e = String.index sci 'e' in
  let mantissa = String.sub sci 0 e in
  let exponent = int_of_string (String.sub sci (e + 1) (String.length sci - e - 1)) in
  let digits = String.concat "" (String.split_on_char '.' mantissa) in
  let len = ref (String.length digits) in
  while !len > 1 && digits.[!len - 1] = '0' do decr len done;
  let digits = String.sub digits 0 !len in
  let n = String.length digits in
  if Float.sign_bit x then Buffer.add_char b '-';
  if exponent >= -4 && exponent < 16 then
    if exponent < 0 then (
      Buffer.add_string b "0.";
      Buffer.add_string b (String.make (-exponent - 1) '0');
      Buffer.add_string b digits)
    else if n > exponent + 1 then (
      Buffer.add_string b (String.sub digits 0 (exponent + 1));
      Buffer.add_char b '.';
      Buffer.add_string b (String.sub digits (exponent + 1) (n - exponent - 1)))
    else (
      Buffer.add_string b digits;
      Buffer.add_string b (String.make (exponent + 1 - n) '0');
      Buffer.add_string b ".0")
  else (
    Buffer.add_char b digits.[0];
    if n > 1 then (
      Buffer.add_char b '.';
      Buffer.add_string b (String.sub digits 1 (n - 1)));
    Printf.bprintf b "e%c%02d" (if exponent < 0 then '-' else '+') (abs exponent))

let add_string b s =
  Buffer.add_char b '"';
  let i = ref 0 in
  while !i < String.length s do
    let d = String.get_utf_8_uchar s !i in
    let cp = Uchar.to_int (Uchar.utf_decode_uchar d) in
    i := !i + Uchar.utf_decode_length d;
    match cp with
    | 0x22 -> Buffer.add_string b "\\\""
    | 0x5c -> Buffer.add_string b "\\\\"
    | 0x0a -> Buffer.add_string b "\\n"
    | 0x0d -> Buffer.add_string b "\\r"
    | 0x09 -> Buffer.add_string b "\\t"
    | 0x08 -> Buffer.add_string b "\\b"
    | 0x0c -> Buffer.add_string b "\\f"
    | c when c < 0x20 || (c >= 0x80 && c < 0x10000) -> Printf.bprintf b "\\u%04x" c
    | c when c >= 0x10000 ->
        let v = c - 0x10000 in
        Printf.bprintf b "\\u%04x\\u%04x" (0xd800 + (v lsr 10)) (0xdc00 + (v land 0x3ff))
    | c -> Buffer.add_char b (Char.chr c)
  done;
  Buffer.add_char b '"'

let rec dump b (v : Yojson.Safe.t) =
  match v with
  | `Null -> Buffer.add_string b "null"
  | `Bool x -> Buffer.add_string b (if x then "true" else "false")
  | `Int i -> Buffer.add_string b (string_of_int i)
  | `Intlit s -> Buffer.add_string b s
  | `Float f -> add_float b f
  | `String s -> add_string b s
  | `List items ->
      Buffer.add_char b '[';
      List.iteri
        (fun i item ->
          if i > 0 then Buffer.add_char b ',';
          dump b item)
        items;
      Buffer.add_char b ']'
  | `Assoc members ->
      Buffer.add_char b '{';
      List.iteri
        (fun i (key, item) ->
          if i > 0 then Buffer.add_char b ',';
          add_string b key;
          Buffer.add_char b ':';
          dump b item)
        members;
      Buffer.add_char b '}'

let print_hash v =
  let b = Buffer.create (1 lsl 20) in
  dump b v;
  print_endline (Digest.to_hex (Digest.string (Buffer.contents b)))

let () =
  let name = try Sys.argv.(1) with _ -> "sample" in
  let n = try int_of_string Sys.argv.(2) with _ -> 3 in
  let text = In_channel.with_open_bin (name ^ ".json") In_channel.input_all in
  let text = if String.starts_with ~prefix:"\xef\xbb\xbf" text then String.sub text 3 (String.length text - 3) else text in
  print_hash (Yojson.Safe.from_string text);
  print_hash (`List (List.init n (fun _ -> Yojson.Safe.from_string text)))
