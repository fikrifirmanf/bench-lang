// Portable single-threaded fannkuch-redux with std::array; no SIMD intrinsics.
#include <algorithm>
#include <array>
#include <cstdio>
#include <cstdlib>

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 7;
    std::array<int, 32> perm{}, perm1{}, count{};
    for (int i = 0; i < n; i++) perm1[i] = i;

    int max_flips = 0, checksum = 0, perm_count = 0, r = n;
    for (;;) {
        for (; r != 1; r--) count[r - 1] = r;

        perm = perm1;
        int flips = 0;
        for (int k; (k = perm[0]) != 0; flips++) std::reverse(perm.begin(), perm.begin() + k + 1);
        max_flips = std::max(max_flips, flips);
        checksum += perm_count % 2 == 0 ? flips : -flips;

        for (;;) {
            if (r == n) {
                std::printf("%d\nPfannkuchen(%d) = %d\n", checksum, n, max_flips);
                return 0;
            }
            std::rotate(perm1.begin(), perm1.begin() + 1, perm1.begin() + r + 1);
            if (--count[r] > 0) break;
            r++;
        }
        perm_count++;
    }
}
