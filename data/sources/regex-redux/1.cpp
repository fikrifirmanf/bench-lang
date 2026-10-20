// regex-redux with PCRE2 and its JIT compiler (std::regex is far too slow for 25 MB of input).
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <memory>
#include <string>
#include <utility>

class Regex {
  public:
    explicit Regex(const char *pattern) {
        int error;
        PCRE2_SIZE offset;
        code_.reset(pcre2_compile(reinterpret_cast<PCRE2_SPTR>(pattern), PCRE2_ZERO_TERMINATED, 0, &error, &offset, nullptr));
        if (!code_) {
            std::fprintf(stderr, "bad pattern %s\n", pattern);
            std::exit(1);
        }
        pcre2_jit_compile(code_.get(), PCRE2_JIT_COMPLETE);
        match_.reset(pcre2_match_data_create_from_pattern(code_.get(), nullptr));
    }

    // Finds the next match at or after `start`; returns false when there is none.
    bool find(const std::string &text, size_t start, size_t &begin, size_t &end) {
        if (pcre2_jit_match(code_.get(), reinterpret_cast<PCRE2_SPTR>(text.data()), text.size(), start, 0, match_.get(),
                            nullptr) < 0)
            return false;
        PCRE2_SIZE *ovector = pcre2_get_ovector_pointer(match_.get());
        begin = ovector[0];
        end = ovector[1];
        return true;
    }

  private:
    struct CodeFree {
        void operator()(pcre2_code *c) const { pcre2_code_free(c); }
    };
    struct MatchFree {
        void operator()(pcre2_match_data *m) const { pcre2_match_data_free(m); }
    };
    std::unique_ptr<pcre2_code, CodeFree> code_;
    std::unique_ptr<pcre2_match_data, MatchFree> match_;
};

static long count_matches(const char *pattern, const std::string &text) {
    Regex re(pattern);
    long count = 0;
    for (size_t start = 0, begin, end; start < text.size() && re.find(text, start, begin, end); start = end) count++;
    return count;
}

static std::string replace_all(const char *pattern, const std::string &replacement, const std::string &text) {
    Regex re(pattern);
    std::string out;
    out.reserve(text.size());
    size_t start = 0, begin, end;
    while (start <= text.size() && re.find(text, start, begin, end)) {
        out.append(text, start, begin - start);
        out += replacement;
        start = end;
        if (begin == end) {
            if (start == text.size()) break;
            out += text[start++];
        }
    }
    if (start < text.size()) out.append(text, start, std::string::npos);
    return out;
}

int main(int argc, char **argv) {
    const char *file_name = argc > 1 ? argv[1] : "25000_in";
    std::ifstream file(file_name, std::ios::binary);
    std::string input((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

    std::string seq = replace_all(">.*\n|\n", "", input);
    const char *variants[] = {
        "agggtaaa|tttaccct",         "[cgt]gggtaaa|tttaccc[acg]", "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct", "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct", "agggtaa[cgt]|[acg]ttaccct",
    };
    for (const char *variant : variants) std::printf("%s %ld\n", variant, count_matches(variant, seq));

    const std::pair<const char *, const char *> substitutions[] = {
        {"tHa[Nt]", "<4>"}, {"aND|caN|Ha[DS]|WaS", "<3>"}, {"a[NSt]|BY", "<2>"}, {"<[^>]*>", "|"}, {"\\|[^|][^|]*\\|", "-"},
    };
    std::string replaced = seq;
    for (auto &[pattern, replacement] : substitutions) replaced = replace_all(pattern, replacement, replaced);
    std::printf("\n%zu\n%zu\n%zu\n", input.size(), seq.size(), replaced.size());
}
