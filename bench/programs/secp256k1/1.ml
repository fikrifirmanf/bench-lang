(* secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on Zarith (GMP). *)
let z = Z.of_string
let hex s = Z.of_string_base 16 s
let p = Z.sub (Z.sub (Z.shift_left Z.one 256) (Z.shift_left Z.one 32)) (Z.of_int 977)
let n = Z.sub (Z.shift_left Z.one 256) (z "432420386565659656852420866394968145599")
let gx = z "55066263022277343669578718895168534326250603453777594175500187360389116729240"
let gy = z "32670510020758816978083085130507043184471273380659243275938904335757337482424"
let beta = hex "7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee"
let pow_2_128 = Z.shift_left Z.one 128
let a1 = hex "3086d221a7d46bcde86c90e49284eb15"
let b1 = Z.neg (hex "e4437ed6010e88286f547fa90abfe4c3")
let a2 = hex "114ca50f7a8e2f3f657c1108d9d44cfd8"

(* Z.erem is the non-negative remainder. *)
let md ?(m = p) a = Z.erem a m
let ( + ) = Z.add
let ( - ) = Z.sub
let ( * ) = Z.mul
let two = Z.of_int 2
let three = Z.of_int 3
let eight = Z.of_int 8

type point = { x : Z.t; y : Z.t; z : Z.t }

let zero = { x = Z.zero; y = Z.one; z = Z.zero }

let double pt =
  let a = md (pt.x * pt.x) in
  let b = md (pt.y * pt.y) in
  let c = md (b * b) in
  let xb = pt.x + b in
  let d = md (two * (md (xb * xb) - a - c)) in
  let e = md (three * a) in
  let f = md (e * e) in
  let x3 = md (f - (two * d)) in
  let y3 = md ((e * (d - x3)) - (eight * c)) in
  let z3 = md (two * pt.y * pt.z) in
  { x = x3; y = y3; z = z3 }

let add pt o =
  if Z.equal o.x Z.zero || Z.equal o.y Z.zero then pt
  else if Z.equal pt.x Z.zero || Z.equal pt.y Z.zero then o
  else
    let z1z1 = md (pt.z * pt.z) and z2z2 = md (o.z * o.z) in
    let u1 = md (pt.x * z2z2) and u2 = md (o.x * z1z1) in
    let s1 = md (pt.y * o.z * z2z2) and s2 = md (md (o.y * pt.z) * z1z1) in
    let h = md (u2 - u1) and r = md (s2 - s1) in
    if Z.equal h Z.zero then if Z.equal r Z.zero then double pt else zero
    else
      let hh = md (h * h) in
      let hhh = md (h * hh) in
      let v = md (u1 * hh) in
      let x3 = md ((r * r) - hhh - (two * v)) in
      let y3 = md ((r * (v - x3)) - (s1 * hhh)) in
      let z3 = md (pt.z * o.z * h) in
      { x = x3; y = y3; z = z3 }

(* (a + b / 2) floor-divided by b. *)
let div_nearest a b = Z.fdiv (a + Z.fdiv b two) b

let multiply pt k =
  let b2 = a1 in
  let c1 = div_nearest (b2 * k) n and c2 = div_nearest (Z.neg b1 * k) n in
  let k1 = md ~m:n (k - (c1 * a1) - (c2 * a2)) and k2 = md ~m:n (Z.neg (c1 * b1) - (c2 * b2)) in
  let k1neg = Z.gt k1 pow_2_128 and k2neg = Z.gt k2 pow_2_128 in
  let k1 = ref (if k1neg then n - k1 else k1) and k2 = ref (if k2neg then n - k2 else k2) in
  let k1p = ref zero and k2p = ref zero and d = ref pt in
  while Z.sign !k1 > 0 || Z.sign !k2 > 0 do
    if Z.is_odd !k1 then k1p := add !k1p !d;
    if Z.is_odd !k2 then k2p := add !k2p !d;
    d := double !d;
    k1 := Z.shift_right !k1 1;
    k2 := Z.shift_right !k2 1
  done;
  let k1p = if k1neg then { !k1p with y = md (Z.neg !k1p.y) } else !k1p in
  let k2p = if k2neg then { !k2p with y = md (Z.neg !k2p.y) } else !k2p in
  add k1p { k2p with x = md (k2p.x * beta) }

let () =
  let count = try int_of_string Sys.argv.(1) with _ -> 1 in
  let key = hex "2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693" in
  let x = ref gx and y = ref gy in
  for _ = 1 to count do
    let j = multiply { x = !x; y = !y; z = Z.one } key in
    let inv = Z.invert j.z p in
    let inv2 = md (inv * inv) in
    x := md (j.x * inv2);
    y := md (j.y * inv * inv2)
  done;
  Printf.printf "%s,%s\n" (Z.format "%x" !x) (Z.format "%x" !y)
