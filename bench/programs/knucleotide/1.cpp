// k-nucleotide: counts every k-mer of the THREE sequence in a std::unordered_map keyed by 2-bit packed codes.
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

static uint8_t code_of(char c) {
    switch (c) {
        case 'A': return 0;
        case 'C': return 1;
        case 'G': return 2;
        default: return 3;  // 'T'
    }
}

static std::unordered_map<uint64_t, int> count_kmers(const std::vector<uint8_t> &seq, size_t k) {
    std::unordered_map<uint64_t, int> counts;
    const uint64_t mask = (k == 32 ? ~0ull : (1ull << (2 * k)) - 1);
    uint64_t key = 0;
    for (size_t i = 0; i < seq.size(); i++) {
        key = ((key << 2) | seq[i]) & mask;
        if (i + 1 >= k) counts[key]++;
    }
    return counts;
}

static uint64_t pack(const std::string &kmer) {
    uint64_t key = 0;
    for (char c : kmer) key = (key << 2) | code_of(c);
    return key;
}

static std::string unpack(uint64_t key, size_t k) {
    std::string kmer(k, 'A');
    for (size_t i = k; i-- > 0; key >>= 2) kmer[i] = "ACGT"[key & 3];
    return kmer;
}

static void print_frequencies(const std::vector<uint8_t> &seq, size_t k) {
    auto counts = count_kmers(seq, k);
    std::vector<std::pair<std::string, int>> sorted;
    for (auto &[key, count] : counts) sorted.emplace_back(unpack(key, k), count);
    std::sort(sorted.begin(), sorted.end(), [](auto &a, auto &b) {
        return a.second != b.second ? a.second > b.second : a.first < b.first;
    });
    double total = static_cast<double>(seq.size() - k + 1);
    for (auto &[kmer, count] : sorted) std::printf("%s %.3f\n", kmer.c_str(), count * 100.0 / total);
    std::printf("\n");
}

int main(int argc, char **argv) {
    std::ifstream file(argc > 1 ? argv[1] : "25000_in");
    std::string line;
    while (std::getline(file, line) && line.rfind(">THREE", 0) != 0) {
    }
    std::vector<uint8_t> seq;
    while (std::getline(file, line) && line[0] != '>')
        for (char c : line)
            if (c != '\r' && c != ' ' && c != '\t') seq.push_back(code_of(static_cast<char>(c & ~0x20)));

    print_frequencies(seq, 1);
    print_frequencies(seq, 2);
    for (std::string kmer : {"GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"}) {
        auto counts = count_kmers(seq, kmer.size());
        auto found = counts.find(pack(kmer));
        std::printf("%d\t%s\n", found == counts.end() ? 0 : found->second, kmer.c_str());
    }
}
