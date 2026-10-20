(* Digits of e by binary splitting of sum(1/k!), on Zarith (GMP) integers. *)
let rec sum_terms a b =
  if b = a + 1 then (Z.one, Z.of_int b)
  else
    let mid = (a + b) / 2 in
    let p_left, q_left = sum_terms a mid in
    let p_right, q_right = sum_terms mid b in
    (Z.add (Z.mul p_left q_right) p_right, Z.mul q_left q_right)

let test_k n k =
  k > 0
  &&
  let k = float_of_int k in
  let ln_k_factorial = (k *. (log k -. 1.)) +. (0.5 *. log (2. *. Float.pi)) in
  ln_k_factorial /. log 10. >= float_of_int (n + 50)

let binary_search n =
  let a = ref 0 and b = ref 1 in
  while not (test_k n !b) do
    a := !b;
    b := !b * 2
  done;
  while !b - !a > 1 do
    let m = (!a + !b) / 2 in
    if test_k n m then b := m else a := m
  done;
  !b

let () =
  let n = try int_of_string Sys.argv.(1) with _ -> 27 in
  let p, q = sum_terms 0 (binary_search n - 1) in
  let s = Z.to_string (Z.fdiv (Z.mul (Z.add p q) (Z.pow (Z.of_int 10) (n - 1))) q) in
  let out = Buffer.create (n * 2) in
  let i = ref 0 in
  while !i < n do
    if !i + 10 <= n then Printf.bprintf out "%s\t:%d\n" (String.sub s !i 10) (!i + 10)
    else Printf.bprintf out "%s%s\t:%d\n" (String.sub s !i (n - !i)) (String.make (10 - (n mod 10)) ' ') n;
    i := !i + 10
  done;
  print_string (Buffer.contents out)
