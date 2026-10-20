// Spectral norm by power iteration on A^T A, single-threaded and without SIMD intrinsics.
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <numeric>
#include <vector>

static double a(int i, int j) {
    return 1.0 / ((i + j) * (i + j + 1) / 2 + i + 1);
}

static void mult_av(const std::vector<double> &v, std::vector<double> &out) {
    int n = static_cast<int>(v.size());
    for (int i = 0; i < n; i++) {
        double sum = 0;
        for (int j = 0; j < n; j++) sum += a(i, j) * v[j];
        out[i] = sum;
    }
}

static void mult_atv(const std::vector<double> &v, std::vector<double> &out) {
    int n = static_cast<int>(v.size());
    for (int i = 0; i < n; i++) {
        double sum = 0;
        for (int j = 0; j < n; j++) sum += a(j, i) * v[j];
        out[i] = sum;
    }
}

static void mult_atav(const std::vector<double> &v, std::vector<double> &out, std::vector<double> &tmp) {
    mult_av(v, tmp);
    mult_atv(tmp, out);
}

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 100;
    std::vector<double> u(n, 1.0), v(n), tmp(n);
    for (int i = 0; i < 10; i++) {
        mult_atav(u, v, tmp);
        mult_atav(v, u, tmp);
    }
    double vbv = std::inner_product(u.begin(), u.end(), v.begin(), 0.0);
    double vv = std::inner_product(v.begin(), v.end(), v.begin(), 0.0);
    std::printf("%.9f\n", std::sqrt(vbv / vv));
}
