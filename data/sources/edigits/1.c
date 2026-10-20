// Digits of e by binary splitting of sum(1/k!), with GMP integers.
#include <gmp.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void sum_terms(long a, long b, mpz_t p, mpz_t q) {
    if (b == a + 1) {
        mpz_set_ui(p, 1);
        mpz_set_ui(q, b);
        return;
    }
    long mid = (a + b) / 2;
    mpz_t pr, qr;
    mpz_inits(pr, qr, NULL);
    sum_terms(a, mid, p, q);
    sum_terms(mid, b, pr, qr);
    mpz_mul(p, p, qr);
    mpz_add(p, p, pr);
    mpz_mul(q, q, qr);
    mpz_clears(pr, qr, NULL);
}

static int test_k(long n, long k) {
    if (k <= 0) return 0;
    double ln_k_factorial = k * (log((double)k) - 1) + 0.5 * log(2 * M_PI);
    return ln_k_factorial / log(10.0) >= n + 50;
}

static long binary_search(long n) {
    long a = 0, b = 1;
    while (!test_k(n, b)) {
        a = b;
        b *= 2;
    }
    while (b - a > 1) {
        long m = (a + b) / 2;
        if (test_k(n, m)) b = m; else a = m;
    }
    return b;
}

int main(int argc, char **argv) {
    long n = argc > 1 ? atol(argv[1]) : 27;
    long k = binary_search(n);
    mpz_t p, q, scale;
    mpz_inits(p, q, scale, NULL);
    sum_terms(0, k - 1, p, q);
    mpz_add(p, p, q);
    mpz_ui_pow_ui(scale, 10, n - 1);
    mpz_mul(p, p, scale);
    mpz_fdiv_q(p, p, q);
    char *digits = mpz_get_str(NULL, 10, p);

    for (long i = 0; i < n; i += 10) {
        if (i + 10 <= n) {
            printf("%.10s\t:%ld\n", digits + i, i + 10);
        } else {
            printf("%s%*s\t:%ld\n", digits + i, (int)(10 - n % 10), "", n);
        }
    }
    return 0;
}
