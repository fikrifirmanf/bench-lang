// Writes the three FASTA sections through one stdout buffer, 60 characters per line.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define WIDTH 60

static const char ALU[] =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

typedef struct {
    char symbol;
    double prob;
} Entry;

static Entry IUB[] = {
    {'a', 0.27}, {'c', 0.12}, {'g', 0.12}, {'t', 0.27}, {'B', 0.02}, {'D', 0.02}, {'H', 0.02}, {'K', 0.02},
    {'M', 0.02}, {'N', 0.02}, {'R', 0.02}, {'S', 0.02}, {'V', 0.02}, {'W', 0.02}, {'Y', 0.02},
};

static Entry HOMO_SAPIENS[] = {
    {'a', 0.3029549426680}, {'c', 0.1979883004921}, {'g', 0.1975473066391}, {'t', 0.3015094502008},
};

static unsigned seed = 42;

static double next_random(void) {
    seed = (seed * 3877 + 29573) % 139968;
    return seed / 139968.0;
}

static void repeat_fasta(const char *src, int n) {
    int len = (int)strlen(src);
    char line[WIDTH + 1];
    int pos = 0;
    for (int done = 0; done < n; done += WIDTH) {
        int count = n - done < WIDTH ? n - done : WIDTH;
        for (int i = 0; i < count; i++) {
            line[i] = src[pos];
            if (++pos == len) pos = 0;
        }
        line[count] = '\n';
        fwrite(line, 1, count + 1, stdout);
    }
}

static void random_fasta(Entry *table, int size, int n) {
    double cumulative[16];
    double total = 0.0;
    for (int i = 0; i < size; i++) {
        total += table[i].prob;
        cumulative[i] = total;
    }
    char line[WIDTH + 1];
    for (int done = 0; done < n; done += WIDTH) {
        int count = n - done < WIDTH ? n - done : WIDTH;
        for (int i = 0; i < count; i++) {
            double r = next_random();
            int k = 0;
            // Python's bisect: the first entry whose cumulative probability is greater than r.
            while (k < size - 1 && cumulative[k] <= r) k++;
            line[i] = table[k].symbol;
        }
        line[count] = '\n';
        fwrite(line, 1, count + 1, stdout);
    }
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 1000;
    static char buffer[1 << 16];
    setvbuf(stdout, buffer, _IOFBF, sizeof buffer);
    fputs(">ONE Homo sapiens alu\n", stdout);
    repeat_fasta(ALU, n * 2);
    fputs(">TWO IUB ambiguity codes\n", stdout);
    random_fasta(IUB, sizeof IUB / sizeof IUB[0], n * 3);
    fputs(">THREE Homo sapiens frequency\n", stdout);
    random_fasta(HOMO_SAPIENS, sizeof HOMO_SAPIENS / sizeof HOMO_SAPIENS[0], n * 5);
    return 0;
}
