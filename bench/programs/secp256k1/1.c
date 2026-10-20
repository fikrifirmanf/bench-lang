// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on GMP integers.
#include <gmp.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    mpz_t x, y, z;
} Point;

static mpz_t P, N, BETA, POW_2_128, A1, B1, A2;
static mpz_t t1, t2, t3, t4, t5, t6, t7, t8, t9, t10;

static void point_init(Point *p) { mpz_inits(p->x, p->y, p->z, NULL); }
static void point_clear(Point *p) { mpz_clears(p->x, p->y, p->z, NULL); }
static void point_zero(Point *p) {
    mpz_set_ui(p->x, 0);
    mpz_set_ui(p->y, 1);
    mpz_set_ui(p->z, 0);
}
static void point_copy(Point *dst, const Point *src) {
    mpz_set(dst->x, src->x);
    mpz_set(dst->y, src->y);
    mpz_set(dst->z, src->z);
}

static void modp(mpz_t r) { mpz_mod(r, r, P); }

static void point_double(Point *r, const Point *p) {
    mpz_mul(t1, p->x, p->x), modp(t1);                         // a
    mpz_mul(t2, p->y, p->y), modp(t2);                         // b
    mpz_mul(t3, t2, t2), modp(t3);                             // c
    mpz_add(t4, p->x, t2), mpz_mul(t4, t4, t4), modp(t4);      // (x1 + b)^2
    mpz_sub(t4, t4, t1), mpz_sub(t4, t4, t3);
    mpz_mul_ui(t4, t4, 2), modp(t4);                           // d
    mpz_mul_ui(t5, t1, 3), modp(t5);                           // e
    mpz_mul(t6, t5, t5), modp(t6);                             // f
    mpz_mul(t7, p->y, p->z), mpz_mul_ui(t7, t7, 2), modp(t7);  // z3
    mpz_submul_ui(t6, t4, 2), modp(t6);                        // x3
    mpz_sub(t8, t4, t6), mpz_mul(t8, t8, t5);
    mpz_submul_ui(t8, t3, 8), modp(t8);                        // y3
    mpz_set(r->x, t6);
    mpz_set(r->y, t8);
    mpz_set(r->z, t7);
}

static void point_add(Point *r, const Point *p, const Point *q) {
    if (mpz_sgn(q->x) == 0 || mpz_sgn(q->y) == 0) {
        point_copy(r, p);
        return;
    }
    if (mpz_sgn(p->x) == 0 || mpz_sgn(p->y) == 0) {
        point_copy(r, q);
        return;
    }
    mpz_mul(t1, p->z, p->z), modp(t1);                        // z1z1
    mpz_mul(t2, q->z, q->z), modp(t2);                        // z2z2
    mpz_mul(t3, p->x, t2), modp(t3);                          // u1
    mpz_mul(t4, q->x, t1), modp(t4);                          // u2
    mpz_mul(t5, p->y, q->z), mpz_mul(t5, t5, t2), modp(t5);   // s1
    mpz_mul(t6, q->y, p->z), modp(t6);
    mpz_mul(t6, t6, t1), modp(t6);                            // s2
    mpz_sub(t7, t4, t3), modp(t7);                            // h
    mpz_sub(t8, t6, t5), modp(t8);                            // r
    if (mpz_sgn(t7) == 0) {
        if (mpz_sgn(t8) == 0) {
            point_double(r, p);
        } else {
            point_zero(r);
        }
        return;
    }
    mpz_mul(t9, t7, t7), modp(t9);                            // hh
    mpz_mul(t10, t7, t9), modp(t10);                          // hhh
    mpz_mul(t3, t3, t9), modp(t3);                            // v
    mpz_mul(t1, p->z, q->z), mpz_mul(t1, t1, t7), modp(t1);   // z3
    mpz_mul(t2, t8, t8), mpz_sub(t2, t2, t10);
    mpz_submul_ui(t2, t3, 2), modp(t2);                       // x3
    mpz_sub(t4, t3, t2), mpz_mul(t4, t8, t4);
    mpz_submul(t4, t5, t10), modp(t4);                        // y3
    mpz_set(r->x, t2);
    mpz_set(r->y, t4);
    mpz_set(r->z, t1);
}

// (a + b/2) // b
static void div_nearest(mpz_t r, const mpz_t a, const mpz_t b) {
    mpz_t half;
    mpz_init(half);
    mpz_fdiv_q_ui(half, b, 2);
    mpz_add(r, a, half);
    mpz_fdiv_q(r, r, b);
    mpz_clear(half);
}

static void multiply(Point *result, const Point *base, const mpz_t k) {
    mpz_t c1, c2, k1, k2, tmp;
    mpz_inits(c1, c2, k1, k2, tmp, NULL);
    mpz_mul(tmp, A1, k), div_nearest(c1, tmp, N);   // b2 == a1
    mpz_neg(tmp, B1), mpz_mul(tmp, tmp, k), div_nearest(c2, tmp, N);
    mpz_set(k1, k), mpz_submul(k1, c1, A1), mpz_submul(k1, c2, A2), mpz_mod(k1, k1, N);
    mpz_mul(k2, c1, B1), mpz_neg(k2, k2), mpz_submul(k2, c2, A1), mpz_mod(k2, k2, N);
    int k1neg = mpz_cmp(k1, POW_2_128) > 0, k2neg = mpz_cmp(k2, POW_2_128) > 0;
    if (k1neg) mpz_sub(k1, N, k1);
    if (k2neg) mpz_sub(k2, N, k2);

    Point k1p, k2p, d;
    point_init(&k1p), point_init(&k2p), point_init(&d);
    point_zero(&k1p), point_zero(&k2p), point_copy(&d, base);
    while (mpz_sgn(k1) > 0 || mpz_sgn(k2) > 0) {
        if (mpz_odd_p(k1)) point_add(&k1p, &k1p, &d);
        if (mpz_odd_p(k2)) point_add(&k2p, &k2p, &d);
        point_double(&d, &d);
        mpz_fdiv_q_2exp(k1, k1, 1);
        mpz_fdiv_q_2exp(k2, k2, 1);
    }
    if (k1neg) mpz_neg(k1p.y, k1p.y), modp(k1p.y);
    if (k2neg) mpz_neg(k2p.y, k2p.y), modp(k2p.y);
    mpz_mul(k2p.x, k2p.x, BETA), modp(k2p.x);
    point_add(result, &k1p, &k2p);

    point_clear(&k1p), point_clear(&k2p), point_clear(&d);
    mpz_clears(c1, c2, k1, k2, tmp, NULL);
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 1;
    mpz_inits(t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, NULL);
    mpz_init_set_str(P, "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f", 16);
    mpz_init_set_str(N, "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141", 16);
    mpz_init_set_str(BETA, "7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee", 16);
    mpz_init(POW_2_128), mpz_ui_pow_ui(POW_2_128, 2, 128);
    mpz_init_set_str(A1, "3086d221a7d46bcde86c90e49284eb15", 16);
    mpz_init_set_str(B1, "-e4437ed6010e88286f547fa90abfe4c3", 16);
    mpz_init_set_str(A2, "114ca50f7a8e2f3f657c1108d9d44cfd8", 16);

    mpz_t key, inv, inv2;
    mpz_inits(inv, inv2, NULL);
    mpz_init_set_str(key, "2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693", 16);
    Point point, jacobian;
    point_init(&point), point_init(&jacobian);
    mpz_set_str(point.x, "55066263022277343669578718895168534326250603453777594175500187360389116729240", 10);
    mpz_set_str(point.y, "32670510020758816978083085130507043184471273380659243275938904335757337482424", 10);
    mpz_set_ui(point.z, 1);

    for (int i = 0; i < n; i++) {
        multiply(&jacobian, &point, key);
        mpz_invert(inv, jacobian.z, P);
        mpz_mul(inv2, inv, inv), modp(inv2);
        mpz_mul(point.x, jacobian.x, inv2), modp(point.x);
        mpz_mul(point.y, jacobian.y, inv), mpz_mul(point.y, point.y, inv2), modp(point.y);
        mpz_set_ui(point.z, 1);
    }
    gmp_printf("%Zx,%Zx\n", point.x, point.y);
    return 0;
}
