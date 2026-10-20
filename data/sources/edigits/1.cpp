// Digits of e by binary splitting of sum(1/k!), with GMP's C++ integers.
#include <gmpxx.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <numbers>
#include <string>
#include <utility>

static std::pair<mpz_class, mpz_class> sum_terms(long a, long b) {
    if (b == a + 1) return {1, b};
    long mid = (a + b) / 2;
    auto [p_left, q_left] = sum_terms(a, mid);
    auto [p_right, q_right] = sum_terms(mid, b);
    return {p_left * q_right + p_right, q_left * q_right};
}

static bool test_k(long n, long k) {
    if (k <= 0) return false;
    double ln_k_factorial = k * (std::log(static_cast<double>(k)) - 1) + 0.5 * std::log(2 * std::numbers::pi);
    return ln_k_factorial / std::log(10.0) >= n + 50;
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
    long n = argc > 1 ? std::atol(argv[1]) : 27;
    auto [p, q] = sum_terms(0, binary_search(n) - 1);
    mpz_class scale;
    mpz_ui_pow_ui(scale.get_mpz_t(), 10, n - 1);
    mpz_class answer = (p + q) * scale / q;
    std::string digits = answer.get_str();
    for (long i = 0; i < n; i += 10) {
        if (i + 10 <= n) {
            std::printf("%s\t:%ld\n", digits.substr(i, 10).c_str(), i + 10);
        } else {
            std::printf("%s%s\t:%ld\n", digits.substr(i).c_str(), std::string(10 - n % 10, ' ').c_str(), n);
        }
    }
}
