// Unbounded spigot for the digits of pi, with GMP's C++ integers.
#include <gmpxx.h>

#include <cstdio>
#include <cstdlib>
#include <string>

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 27;
    mpz_class acc = 0, den = 1, num = 1, tmp;
    auto extract_digit = [&](unsigned long nth) {
        tmp = (num * nth + acc) / den;
        return tmp.get_ui();
    };

    std::string line;
    int i = 0;
    for (unsigned long k = 1; i < n; k++) {
        unsigned long k2 = k * 2 + 1;
        acc = (acc + num * 2) * k2;
        den *= k2;
        num *= k;
        if (num > acc) continue;
        unsigned long d = extract_digit(3);
        if (d != extract_digit(4)) continue;
        line += static_cast<char>('0' + d);
        if (++i % 10 == 0) {
            std::printf("%s\t:%d\n", line.c_str(), i);
            line.clear();
        }
        acc = (acc - den * d) * 10;
        num *= 10;
    }
    if (!line.empty()) std::printf("%s%s\t:%d\n", line.c_str(), std::string(10 - line.size(), ' ').c_str(), i);
}
