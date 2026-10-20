// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on Dart's BigInt.
final BigInt P = BigInt.two.pow(256) - BigInt.two.pow(32) - BigInt.from(977);
final BigInt N = BigInt.two.pow(256) - BigInt.parse('432420386565659656852420866394968145599');
final BigInt GX = BigInt.parse('55066263022277343669578718895168534326250603453777594175500187360389116729240');
final BigInt GY = BigInt.parse('32670510020758816978083085130507043184471273380659243275938904335757337482424');
final BigInt BETA = BigInt.parse('7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee', radix: 16);
final BigInt POW_2_128 = BigInt.two.pow(128);
final BigInt A1 = BigInt.parse('3086d221a7d46bcde86c90e49284eb15', radix: 16);
final BigInt B1 = -BigInt.parse('e4437ed6010e88286f547fa90abfe4c3', radix: 16);
final BigInt A2 = BigInt.parse('114ca50f7a8e2f3f657c1108d9d44cfd8', radix: 16);
final BigInt two = BigInt.two, three = BigInt.from(3), eight = BigInt.from(8);

// Dart's % on BigInt is already the non-negative Euclidean modulo.
BigInt mod(BigInt a, [BigInt? m]) => a % (m ?? P);

class Jacobian {
  final BigInt x, y, z;
  Jacobian(this.x, this.y, this.z);

  static Jacobian zero() => Jacobian(BigInt.zero, BigInt.one, BigInt.zero);

  Jacobian dbl() {
    final a = mod(x * x), b = mod(y * y), c = mod(b * b);
    final d = mod(two * (mod((x + b) * (x + b)) - a - c));
    final e = mod(three * a), f = mod(e * e);
    final x3 = mod(f - two * d);
    final y3 = mod(e * (d - x3) - eight * c);
    final z3 = mod(two * y * z);
    return Jacobian(x3, y3, z3);
  }

  Jacobian add(Jacobian o) {
    if (o.x == BigInt.zero || o.y == BigInt.zero) return this;
    if (x == BigInt.zero || y == BigInt.zero) return o;
    final z1z1 = mod(z * z), z2z2 = mod(o.z * o.z);
    final u1 = mod(x * z2z2), u2 = mod(o.x * z1z1);
    final s1 = mod(y * o.z * z2z2), s2 = mod(mod(o.y * z) * z1z1);
    final h = mod(u2 - u1), r = mod(s2 - s1);
    if (h == BigInt.zero) return r == BigInt.zero ? dbl() : zero();
    final hh = mod(h * h), hhh = mod(h * hh), v = mod(u1 * hh);
    final x3 = mod(r * r - hhh - two * v);
    final y3 = mod(r * (v - x3) - s1 * hhh);
    final z3 = mod(z * o.z * h);
    return Jacobian(x3, y3, z3);
  }

  Jacobian multiply(BigInt k) {
    final b2 = A1;
    final c1 = divNearest(b2 * k, N), c2 = divNearest(-B1 * k, N);
    var k1 = mod(k - c1 * A1 - c2 * A2, N), k2 = mod(-c1 * B1 - c2 * b2, N);
    final k1neg = k1 > POW_2_128, k2neg = k2 > POW_2_128;
    if (k1neg) k1 = N - k1;
    if (k2neg) k2 = N - k2;
    var k1p = zero(), k2p = zero(), d = this;
    while (k1 > BigInt.zero || k2 > BigInt.zero) {
      if (k1.isOdd) k1p = k1p.add(d);
      if (k2.isOdd) k2p = k2p.add(d);
      d = d.dbl();
      k1 >>= 1;
      k2 >>= 1;
    }
    if (k1neg) k1p = Jacobian(k1p.x, mod(-k1p.y), k1p.z);
    if (k2neg) k2p = Jacobian(k2p.x, mod(-k2p.y), k2p.z);
    k2p = Jacobian(mod(k2p.x * BETA), k2p.y, k2p.z);
    return k1p.add(k2p);
  }
}

// (a + b ~/ 2) floor-divided by b; every caller passes non-negative values.
BigInt divNearest(BigInt a, BigInt b) => (a + b ~/ two) ~/ b;

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 1;
  final key = BigInt.parse('2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693', radix: 16);
  var x = GX, y = GY;
  for (var i = 0; i < n; i++) {
    final j = Jacobian(x, y, BigInt.one).multiply(key);
    final inv = j.z.modInverse(P);
    final inv2 = mod(inv * inv);
    x = mod(j.x * inv2);
    y = mod(j.y * inv * inv2);
  }
  print('${x.toRadixString(16)},${y.toRadixString(16)}');
}
