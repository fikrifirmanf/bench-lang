# secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on Crystal's BigInt (GMP).
require "big"

P         = BigInt.new(2) ** 256 - BigInt.new(2) ** 32 - 977
N         = BigInt.new(2) ** 256 - BigInt.new("432420386565659656852420866394968145599")
GX        = BigInt.new("55066263022277343669578718895168534326250603453777594175500187360389116729240")
GY        = BigInt.new("32670510020758816978083085130507043184471273380659243275938904335757337482424")
BETA      = BigInt.new("7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee", 16)
POW_2_128 = BigInt.new(2) ** 128
A1        = BigInt.new("3086d221a7d46bcde86c90e49284eb15", 16)
B1        = -BigInt.new("e4437ed6010e88286f547fa90abfe4c3", 16)
A2        = BigInt.new("114ca50f7a8e2f3f657c1108d9d44cfd8", 16)

# Crystal's % on BigInt takes the sign of the divisor, so the result is never negative here.
def mod(a : BigInt, m : BigInt = P) : BigInt
  a % m
end

struct Jacobian
  getter x : BigInt, y : BigInt, z : BigInt

  def initialize(@x, @y, @z)
  end

  def self.zero
    new(BigInt.new(0), BigInt.new(1), BigInt.new(0))
  end

  def double : Jacobian
    a = mod(x * x)
    b = mod(y * y)
    c = mod(b * b)
    d = mod(2 * (mod((x + b) * (x + b)) - a - c))
    e = mod(3 * a)
    f = mod(e * e)
    x3 = mod(f - 2 * d)
    y3 = mod(e * (d - x3) - 8 * c)
    z3 = mod(2 * y * z)
    Jacobian.new(x3, y3, z3)
  end

  def add(o : Jacobian) : Jacobian
    return self if o.x.zero? || o.y.zero?
    return o if x.zero? || y.zero?
    z1z1 = mod(z * z)
    z2z2 = mod(o.z * o.z)
    u1 = mod(x * z2z2)
    u2 = mod(o.x * z1z1)
    s1 = mod(y * o.z * z2z2)
    s2 = mod(mod(o.y * z) * z1z1)
    h = mod(u2 - u1)
    r = mod(s2 - s1)
    return r.zero? ? double : Jacobian.zero if h.zero?
    hh = mod(h * h)
    hhh = mod(h * hh)
    v = mod(u1 * hh)
    x3 = mod(r * r - hhh - 2 * v)
    y3 = mod(r * (v - x3) - s1 * hhh)
    z3 = mod(z * o.z * h)
    Jacobian.new(x3, y3, z3)
  end

  def multiply(k : BigInt) : Jacobian
    b2 = A1
    c1 = div_nearest(b2 * k, N)
    c2 = div_nearest(-B1 * k, N)
    k1 = mod(k - c1 * A1 - c2 * A2, N)
    k2 = mod(-c1 * B1 - c2 * b2, N)
    k1neg = k1 > POW_2_128
    k2neg = k2 > POW_2_128
    k1 = N - k1 if k1neg
    k2 = N - k2 if k2neg
    k1p = Jacobian.zero
    k2p = Jacobian.zero
    d = self
    while k1 > 0 || k2 > 0
      k1p = k1p.add(d) if k1.odd?
      k2p = k2p.add(d) if k2.odd?
      d = d.double
      k1 >>= 1
      k2 >>= 1
    end
    k1p = Jacobian.new(k1p.x, mod(-k1p.y), k1p.z) if k1neg
    k2p = Jacobian.new(k2p.x, mod(-k2p.y), k2p.z) if k2neg
    k2p = Jacobian.new(mod(k2p.x * BETA), k2p.y, k2p.z)
    k1p.add(k2p)
  end
end

# (a + b // 2) // b, with floor division.
def div_nearest(a : BigInt, b : BigInt) : BigInt
  (a + b // 2) // b
end

# Inverse modulo m by the extended Euclidean algorithm.
def invert(number : BigInt, modulo : BigInt = P) : BigInt
  a = mod(number, modulo)
  b = modulo
  x, y, u, v = BigInt.new(0), BigInt.new(1), BigInt.new(1), BigInt.new(0)
  while !a.zero?
    q = b // a
    r = b % a
    m = x - u * q
    n = y - v * q
    b, a = a, r
    x, y = u, v
    u, v = m, n
  end
  mod(x, modulo)
end

n = ARGV.size > 0 ? ARGV[0].to_i : 1
key = BigInt.new("2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693", 16)
x, y = GX, GY
n.times do
  j = Jacobian.new(x, y, BigInt.new(1)).multiply(key)
  inv = invert(j.z)
  inv2 = mod(inv * inv)
  x = mod(j.x * inv2)
  y = mod(j.y * inv * inv2)
end
puts "#{x.to_s(16)},#{y.to_s(16)}"
