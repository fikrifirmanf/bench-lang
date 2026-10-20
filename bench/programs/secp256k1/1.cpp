// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on GMP's C++ integers.
#include <gmpxx.h>

#include <cstdio>
#include <cstdlib>

static const mpz_class P("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f", 16);
static const mpz_class N("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141", 16);
static const mpz_class BETA("7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee", 16);
static const mpz_class POW_2_128 = mpz_class(1) << 128;

static mpz_class mod(const mpz_class &a, const mpz_class &m = P) {
    mpz_class r;
    mpz_mod(r.get_mpz_t(), a.get_mpz_t(), m.get_mpz_t());
    return r;
}

struct Jacobian {
    mpz_class x, y, z;

    static Jacobian zero() { return {0, 1, 0}; }

    Jacobian dbl() const {
        mpz_class a = mod(x * x), b = mod(y * y), c = mod(b * b);
        mpz_class d = mod(2 * (mod((x + b) * (x + b)) - a - c));
        mpz_class e = mod(3 * a), f = mod(e * e);
        mpz_class x3 = mod(f - 2 * d);
        mpz_class y3 = mod(e * (d - x3) - 8 * c);
        mpz_class z3 = mod(2 * y * z);
        return {x3, y3, z3};
    }

    Jacobian add(const Jacobian &o) const {
        if (o.x == 0 || o.y == 0) return *this;
        if (x == 0 || y == 0) return o;
        mpz_class z1z1 = mod(z * z), z2z2 = mod(o.z * o.z);
        mpz_class u1 = mod(x * z2z2), u2 = mod(o.x * z1z1);
        mpz_class s1 = mod(y * o.z * z2z2), s2 = mod(mod(o.y * z) * z1z1);
        mpz_class h = mod(u2 - u1), r = mod(s2 - s1);
        if (h == 0) return r == 0 ? dbl() : zero();
        mpz_class hh = mod(h * h), hhh = mod(h * hh), v = mod(u1 * hh);
        mpz_class x3 = mod(r * r - hhh - 2 * v);
        mpz_class y3 = mod(r * (v - x3) - s1 * hhh);
        mpz_class z3 = mod(z * o.z * h);
        return {x3, y3, z3};
    }
};

static mpz_class div_nearest(const mpz_class &a, const mpz_class &b) {
    mpz_class half = b / 2, r = a + half, q;
    mpz_fdiv_q(q.get_mpz_t(), r.get_mpz_t(), b.get_mpz_t());
    return q;
}

static Jacobian multiply(const Jacobian &point, const mpz_class &k) {
    static const mpz_class a1("3086d221a7d46bcde86c90e49284eb15", 16);
    static const mpz_class b1("-e4437ed6010e88286f547fa90abfe4c3", 16);
    static const mpz_class a2("114ca50f7a8e2f3f657c1108d9d44cfd8", 16);
    const mpz_class &b2 = a1;
    mpz_class c1 = div_nearest(b2 * k, N), c2 = div_nearest(-b1 * k, N);
    mpz_class k1 = mod(k - c1 * a1 - c2 * a2, N), k2 = mod(-c1 * b1 - c2 * b2, N);
    bool k1neg = k1 > POW_2_128, k2neg = k2 > POW_2_128;
    if (k1neg) k1 = N - k1;
    if (k2neg) k2 = N - k2;

    Jacobian k1p = Jacobian::zero(), k2p = Jacobian::zero(), d = point;
    while (k1 > 0 || k2 > 0) {
        if (mpz_odd_p(k1.get_mpz_t())) k1p = k1p.add(d);
        if (mpz_odd_p(k2.get_mpz_t())) k2p = k2p.add(d);
        d = d.dbl();
        k1 >>= 1;
        k2 >>= 1;
    }
    if (k1neg) k1p.y = mod(-k1p.y);
    if (k2neg) k2p.y = mod(-k2p.y);
    k2p.x = mod(k2p.x * BETA);
    return k1p.add(k2p);
}

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 1;
    const mpz_class key("2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693", 16);
    mpz_class x("55066263022277343669578718895168534326250603453777594175500187360389116729240");
    mpz_class y("32670510020758816978083085130507043184471273380659243275938904335757337482424");
    for (int i = 0; i < n; i++) {
        Jacobian j = multiply({x, y, 1}, key);
        mpz_class inv;
        mpz_invert(inv.get_mpz_t(), j.z.get_mpz_t(), P.get_mpz_t());
        mpz_class inv2 = mod(inv * inv);
        x = mod(j.x * inv2);
        y = mod(j.y * inv * inv2);
    }
    gmp_printf("%Zx,%Zx\n", x.get_mpz_t(), y.get_mpz_t());
}
