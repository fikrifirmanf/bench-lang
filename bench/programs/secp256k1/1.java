// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on BigInteger.
import java.math.BigInteger;

final class app {
  static final BigInteger TWO = BigInteger.TWO, THREE = BigInteger.valueOf(3), EIGHT = BigInteger.valueOf(8);
  static final BigInteger P = TWO.pow(256).subtract(TWO.pow(32)).subtract(BigInteger.valueOf(977));
  static final BigInteger N = TWO.pow(256).subtract(new BigInteger("432420386565659656852420866394968145599"));
  static final BigInteger GX = new BigInteger("55066263022277343669578718895168534326250603453777594175500187360389116729240");
  static final BigInteger GY = new BigInteger("32670510020758816978083085130507043184471273380659243275938904335757337482424");
  static final BigInteger BETA = new BigInteger("7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee", 16);
  static final BigInteger POW_2_128 = TWO.pow(128);
  static final BigInteger A1 = new BigInteger("3086d221a7d46bcde86c90e49284eb15", 16);
  static final BigInteger B1 = new BigInteger("-e4437ed6010e88286f547fa90abfe4c3", 16);
  static final BigInteger A2 = new BigInteger("114ca50f7a8e2f3f657c1108d9d44cfd8", 16);

  // BigInteger.mod always returns a non-negative result.
  static BigInteger mod(BigInteger a) {
    return a.mod(P);
  }

  record Jacobian(BigInteger x, BigInteger y, BigInteger z) {
    static Jacobian zero() {
      return new Jacobian(BigInteger.ZERO, BigInteger.ONE, BigInteger.ZERO);
    }

    Jacobian dbl() {
      var a = mod(x.multiply(x));
      var b = mod(y.multiply(y));
      var c = mod(b.multiply(b));
      var xb = x.add(b);
      var d = mod(TWO.multiply(mod(xb.multiply(xb)).subtract(a).subtract(c)));
      var e = mod(THREE.multiply(a));
      var f = mod(e.multiply(e));
      var x3 = mod(f.subtract(TWO.multiply(d)));
      var y3 = mod(e.multiply(d.subtract(x3)).subtract(EIGHT.multiply(c)));
      var z3 = mod(TWO.multiply(y).multiply(z));
      return new Jacobian(x3, y3, z3);
    }

    Jacobian add(Jacobian o) {
      if (o.x.signum() == 0 || o.y.signum() == 0) return this;
      if (x.signum() == 0 || y.signum() == 0) return o;
      var z1z1 = mod(z.multiply(z));
      var z2z2 = mod(o.z.multiply(o.z));
      var u1 = mod(x.multiply(z2z2));
      var u2 = mod(o.x.multiply(z1z1));
      var s1 = mod(y.multiply(o.z).multiply(z2z2));
      var s2 = mod(mod(o.y.multiply(z)).multiply(z1z1));
      var h = mod(u2.subtract(u1));
      var r = mod(s2.subtract(s1));
      if (h.signum() == 0) return r.signum() == 0 ? dbl() : zero();
      var hh = mod(h.multiply(h));
      var hhh = mod(h.multiply(hh));
      var v = mod(u1.multiply(hh));
      var x3 = mod(r.multiply(r).subtract(hhh).subtract(TWO.multiply(v)));
      var y3 = mod(r.multiply(v.subtract(x3)).subtract(s1.multiply(hhh)));
      var z3 = mod(z.multiply(o.z).multiply(h));
      return new Jacobian(x3, y3, z3);
    }

    Jacobian multiply(BigInteger k) {
      var b2 = A1;
      var c1 = divNearest(b2.multiply(k), N);
      var c2 = divNearest(B1.negate().multiply(k), N);
      var k1 = k.subtract(c1.multiply(A1)).subtract(c2.multiply(A2)).mod(N);
      var k2 = c1.negate().multiply(B1).subtract(c2.multiply(b2)).mod(N);
      boolean k1neg = k1.compareTo(POW_2_128) > 0, k2neg = k2.compareTo(POW_2_128) > 0;
      if (k1neg) k1 = N.subtract(k1);
      if (k2neg) k2 = N.subtract(k2);
      var k1p = zero();
      var k2p = zero();
      var d = this;
      while (k1.signum() > 0 || k2.signum() > 0) {
        if (k1.testBit(0)) k1p = k1p.add(d);
        if (k2.testBit(0)) k2p = k2p.add(d);
        d = d.dbl();
        k1 = k1.shiftRight(1);
        k2 = k2.shiftRight(1);
      }
      if (k1neg) k1p = new Jacobian(k1p.x, mod(k1p.y.negate()), k1p.z);
      if (k2neg) k2p = new Jacobian(k2p.x, mod(k2p.y.negate()), k2p.z);
      k2p = new Jacobian(mod(k2p.x.multiply(BETA)), k2p.y, k2p.z);
      return k1p.add(k2p);
    }
  }

  // (a + b / 2) floor-divided by b; every caller passes non-negative values.
  static BigInteger divNearest(BigInteger a, BigInteger b) {
    return a.add(b.shiftRight(1)).divide(b);
  }

  public static void main(String[] args) {
    int n = args.length > 0 ? Integer.parseInt(args[0]) : 1;
    var key = new BigInteger("2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693", 16);
    var x = GX;
    var y = GY;
    for (int i = 0; i < n; i++) {
      var j = new Jacobian(x, y, BigInteger.ONE).multiply(key);
      var inv = j.z.modInverse(P);
      var inv2 = mod(inv.multiply(inv));
      x = mod(j.x.multiply(inv2));
      y = mod(j.y.multiply(inv).multiply(inv2));
    }
    System.out.println(x.toString(16) + "," + y.toString(16));
  }
}
