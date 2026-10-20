// Unbounded spigot for the digits of pi, with GMP integers.
#include <gmp.h>
#include <stdio.h>
#include <stdlib.h>

static mpz_t tmp1, tmp2, acc, den, num;

static unsigned long extract_digit(unsigned long nth) {
    mpz_mul_ui(tmp1, num, nth);
    mpz_add(tmp2, tmp1, acc);
    mpz_tdiv_q(tmp1, tmp2, den);
    return mpz_get_ui(tmp1);
}

static void eliminate_digit(unsigned long d) {
    mpz_submul_ui(acc, den, d);
    mpz_mul_ui(acc, acc, 10);
    mpz_mul_ui(num, num, 10);
}

static void next_term(unsigned long k) {
    unsigned long k2 = k * 2 + 1;
    mpz_addmul_ui(acc, num, 2);
    mpz_mul_ui(acc, acc, k2);
    mpz_mul_ui(den, den, k2);
    mpz_mul_ui(num, num, k);
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 27;
    mpz_inits(tmp1, tmp2, acc, NULL);
    mpz_init_set_ui(den, 1);
    mpz_init_set_ui(num, 1);

    int i = 0;
    for (unsigned long k = 1; i < n; k++) {
        next_term(k);
        if (mpz_cmp(num, acc) > 0) continue;
        unsigned long d = extract_digit(3);
        if (d != extract_digit(4)) continue;
        putchar('0' + (int)d);
        if (++i % 10 == 0) printf("\t:%d\n", i);
        eliminate_digit(d);
    }
    if (i % 10 != 0) printf("%*s\t:%d\n", 10 - i % 10, "", i);
    return 0;
}
