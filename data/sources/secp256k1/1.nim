# secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on the bigints package.
import os, strutils, bigints

let
  P = initBigInt(2).pow(256) - initBigInt(2).pow(32) - 977.initBigInt
  N = initBigInt(2).pow(256) - initBigInt("432420386565659656852420866394968145599")
  GX = initBigInt("55066263022277343669578718895168534326250603453777594175500187360389116729240")
  GY = initBigInt("32670510020758816978083085130507043184471273380659243275938904335757337482424")
  BETA = initBigInt("7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee", 16)
  POW_2_128 = initBigInt(2).pow(128)
  A1 = initBigInt("3086d221a7d46bcde86c90e49284eb15", 16)
  B1 = -initBigInt("e4437ed6010e88286f547fa90abfe4c3", 16)
  A2 = initBigInt("114ca50f7a8e2f3f657c1108d9d44cfd8", 16)
  ZERO = 0.initBigInt
  ONE = 1.initBigInt
  TWO = 2.initBigInt
  THREE = 3.initBigInt
  EIGHT = 8.initBigInt

# Floor modulo: bigints' `mod` takes the sign of the divisor, so results are never negative here.
proc md(a: BigInt, m = P): BigInt = a mod m

type Jacobian = object
  x, y, z: BigInt

proc zeroPoint(): Jacobian = Jacobian(x: ZERO, y: ONE, z: ZERO)

proc dbl(p: Jacobian): Jacobian =
  let a = md(p.x * p.x)
  let b = md(p.y * p.y)
  let c = md(b * b)
  let xb = p.x + b
  let d = md(TWO * (md(xb * xb) - a - c))
  let e = md(THREE * a)
  let f = md(e * e)
  let x3 = md(f - TWO * d)
  let y3 = md(e * (d - x3) - EIGHT * c)
  let z3 = md(TWO * p.y * p.z)
  Jacobian(x: x3, y: y3, z: z3)

proc add(p, o: Jacobian): Jacobian =
  if o.x == ZERO or o.y == ZERO: return p
  if p.x == ZERO or p.y == ZERO: return o
  let z1z1 = md(p.z * p.z)
  let z2z2 = md(o.z * o.z)
  let u1 = md(p.x * z2z2)
  let u2 = md(o.x * z1z1)
  let s1 = md(p.y * o.z * z2z2)
  let s2 = md(md(o.y * p.z) * z1z1)
  let h = md(u2 - u1)
  let r = md(s2 - s1)
  if h == ZERO:
    return (if r == ZERO: p.dbl() else: zeroPoint())
  let hh = md(h * h)
  let hhh = md(h * hh)
  let v = md(u1 * hh)
  let x3 = md(r * r - hhh - TWO * v)
  let y3 = md(r * (v - x3) - s1 * hhh)
  let z3 = md(p.z * o.z * h)
  Jacobian(x: x3, y: y3, z: z3)

# (a + b div 2) div b, floor division; every caller passes non-negative values.
proc divNearest(a, b: BigInt): BigInt = (a + b div TWO) div b

proc multiply(p: Jacobian, k: BigInt): Jacobian =
  let b2 = A1
  let c1 = divNearest(b2 * k, N)
  let c2 = divNearest(-B1 * k, N)
  var k1 = md(k - c1 * A1 - c2 * A2, N)
  var k2 = md(-c1 * B1 - c2 * b2, N)
  let k1neg = k1 > POW_2_128
  let k2neg = k2 > POW_2_128
  if k1neg: k1 = N - k1
  if k2neg: k2 = N - k2
  var k1p = zeroPoint()
  var k2p = zeroPoint()
  var d = p
  while k1 > ZERO or k2 > ZERO:
    if (k1 and ONE) == ONE: k1p = k1p.add(d)
    if (k2 and ONE) == ONE: k2p = k2p.add(d)
    d = d.dbl()
    k1 = k1 shr 1
    k2 = k2 shr 1
  if k1neg: k1p.y = md(-k1p.y)
  if k2neg: k2p.y = md(-k2p.y)
  k2p.x = md(k2p.x * BETA)
  k1p.add(k2p)

let n = if paramCount() > 0: parseInt(paramStr(1)) else: 1
let key = initBigInt("2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693", 16)
var x = GX
var y = GY
for i in 0 ..< n:
  let j = Jacobian(x: x, y: y, z: ONE).multiply(key)
  let inv = invmod(j.z, P)
  let inv2 = md(inv * inv)
  x = md(j.x * inv2)
  y = md(j.y * inv * inv2)
echo toString(x, 16), ",", toString(y, 16)
