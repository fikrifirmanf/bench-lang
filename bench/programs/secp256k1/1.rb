# secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on Ruby's Integer.
P = 2**256 - 2**32 - 977
N = 2**256 - 432420386565659656852420866394968145599
GX = 55066263022277343669578718895168534326250603453777594175500187360389116729240
GY = 32670510020758816978083085130507043184471273380659243275938904335757337482424
BETA = 0x7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee
POW_2_128 = 2**128

# Ruby's % takes the sign of the divisor, so the result is never negative here.
def mod(a, b = P)
  a % b
end

Jacobian = Struct.new(:x, :y, :z) do
  def self.zero
    new(0, 1, 0)
  end

  def double
    a = mod(x * x)
    b = mod(y * y)
    c = mod(b * b)
    d = mod(2 * (mod((x + b)**2) - a - c))
    e = mod(3 * a)
    f = mod(e * e)
    x3 = mod(f - 2 * d)
    y3 = mod(e * (d - x3) - 8 * c)
    z3 = mod(2 * y * z)
    Jacobian.new(x3, y3, z3)
  end

  def add(other)
    return self if other.x.zero? || other.y.zero?
    return other if x.zero? || y.zero?

    z1z1 = mod(z * z)
    z2z2 = mod(other.z * other.z)
    u1 = mod(x * z2z2)
    u2 = mod(other.x * z1z1)
    s1 = mod(y * other.z * z2z2)
    s2 = mod(mod(other.y * z) * z1z1)
    h = mod(u2 - u1)
    r = mod(s2 - s1)
    return r.zero? ? double : Jacobian.zero if h.zero?

    hh = mod(h * h)
    hhh = mod(h * hh)
    v = mod(u1 * hh)
    x3 = mod(r * r - hhh - 2 * v)
    y3 = mod(r * (v - x3) - s1 * hhh)
    z3 = mod(z * other.z * h)
    Jacobian.new(x3, y3, z3)
  end

  def multiply(k)
    k1neg, k1, k2neg, k2 = split_scalar_endo(k)
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

def invert(number, modulo = P)
  a = mod(number, modulo)
  b = modulo
  x, y, u, v = 0, 1, 1, 0
  until a.zero?
    q, r = b.divmod(a)
    m = x - u * q
    n = y - v * q
    b, a = a, r
    x, y = u, v
    u, v = m, n
  end
  mod(x, modulo)
end

def div_nearest(a, b)
  (a + b / 2) / b
end

def split_scalar_endo(k)
  n = N
  a1 = 0x3086d221a7d46bcde86c90e49284eb15
  b1 = -0xe4437ed6010e88286f547fa90abfe4c3
  a2 = 0x114ca50f7a8e2f3f657c1108d9d44cfd8
  b2 = a1
  c1 = div_nearest(b2 * k, n)
  c2 = div_nearest(-b1 * k, n)
  k1 = mod(k - c1 * a1 - c2 * a2, n)
  k2 = mod(-c1 * b1 - c2 * b2, n)
  k1neg = k1 > POW_2_128
  k2neg = k2 > POW_2_128
  k1 = n - k1 if k1neg
  k2 = n - k2 if k2neg
  [k1neg, k1, k2neg, k2]
end

n = (ARGV[0] || 1).to_i
private_key = 0x2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693
x = GX
y = GY
n.times do
  j = Jacobian.new(x, y, 1).multiply(private_key)
  inv = invert(j.z)
  inv2 = mod(inv * inv)
  x = mod(j.x * inv2)
  y = mod(j.y * inv * inv2)
end
puts "#{x.to_s(16)},#{y.to_s(16)}"
