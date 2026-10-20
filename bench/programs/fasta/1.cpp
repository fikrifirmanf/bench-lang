// FASTA generator: repeated ALU text, then two random sections from cumulative probability tables.
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

constexpr int WIDTH = 60;

constexpr std::string_view ALU =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

using Table = std::vector<std::pair<char, double>>;

static unsigned seed = 42;

static double next_random() {
    seed = (seed * 3877 + 29573) % 139968;
    return seed / 139968.0;
}

static void repeat_fasta(std::string_view src, int n, std::string &out) {
    size_t pos = 0;
    for (int done = 0; done < n; done += WIDTH) {
        int count = std::min(WIDTH, n - done);
        for (int i = 0; i < count; i++) {
            out += src[pos];
            if (++pos == src.size()) pos = 0;
        }
        out += '\n';
    }
}

static void random_fasta(const Table &table, int n, std::string &out) {
    std::vector<double> cumulative;
    double total = 0.0;
    for (auto &[symbol, prob] : table) cumulative.push_back(total += prob);
    for (int done = 0; done < n; done += WIDTH) {
        int count = std::min(WIDTH, n - done);
        for (int i = 0; i < count; i++) {
            // Python's bisect: the first entry whose cumulative probability is greater than r.
            auto k = std::upper_bound(cumulative.begin(), cumulative.end() - 1, next_random()) - cumulative.begin();
            out += table[k].first;
        }
        out += '\n';
    }
}

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 1000;
    const Table iub = {{'a', 0.27}, {'c', 0.12}, {'g', 0.12}, {'t', 0.27}, {'B', 0.02}, {'D', 0.02},
                       {'H', 0.02}, {'K', 0.02}, {'M', 0.02}, {'N', 0.02}, {'R', 0.02}, {'S', 0.02},
                       {'V', 0.02}, {'W', 0.02}, {'Y', 0.02}};
    const Table homo_sapiens = {
        {'a', 0.3029549426680}, {'c', 0.1979883004921}, {'g', 0.1975473066391}, {'t', 0.3015094502008}};

    std::string out;
    out.reserve(static_cast<size_t>(n) * 11);
    out += ">ONE Homo sapiens alu\n";
    repeat_fasta(ALU, n * 2, out);
    out += ">TWO IUB ambiguity codes\n";
    random_fasta(iub, n * 3, out);
    out += ">THREE Homo sapiens frequency\n";
    random_fasta(homo_sapiens, n * 5, out);
    std::fwrite(out.data(), 1, out.size(), stdout);
}
