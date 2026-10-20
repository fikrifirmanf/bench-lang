// Single-threaded fannkuch-redux: walks permutations in the benchmark's counting order.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 7;
    int perm[32], perm1[32], count[32];
    for (int i = 0; i < n; i++) perm1[i] = i;

    int max_flips = 0, checksum = 0, perm_count = 0, r = n;
    for (;;) {
        for (; r != 1; r--) count[r - 1] = r;

        memcpy(perm, perm1, sizeof(int) * n);
        int flips = 0;
        for (int k; (k = perm[0]) != 0; flips++) {
            for (int i = 0, j = k; i < j; i++, j--) {
                int t = perm[i];
                perm[i] = perm[j];
                perm[j] = t;
            }
        }
        if (flips > max_flips) max_flips = flips;
        checksum += perm_count % 2 == 0 ? flips : -flips;

        for (;;) {
            if (r == n) {
                printf("%d\nPfannkuchen(%d) = %d\n", checksum, n, max_flips);
                return 0;
            }
            int first = perm1[0];
            for (int i = 0; i < r; i++) perm1[i] = perm1[i + 1];
            perm1[r] = first;
            if (--count[r] > 0) break;
            r++;
        }
        perm_count++;
    }
}
