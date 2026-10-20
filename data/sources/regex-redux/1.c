// regex-redux with PCRE2 and its JIT compiler.
#define PCRE2_CODE_UNIT_WIDTH 8
#include <pcre2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static pcre2_code *compile(const char *pattern) {
    int error;
    PCRE2_SIZE offset;
    pcre2_code *re = pcre2_compile((PCRE2_SPTR)pattern, PCRE2_ZERO_TERMINATED, 0, &error, &offset, NULL);
    if (!re) {
        fprintf(stderr, "bad pattern %s\n", pattern);
        exit(1);
    }
    pcre2_jit_compile(re, PCRE2_JIT_COMPLETE);
    return re;
}

static long count_matches(const char *pattern, const char *text, size_t length) {
    pcre2_code *re = compile(pattern);
    pcre2_match_data *match = pcre2_match_data_create_from_pattern(re, NULL);
    long count = 0;
    for (PCRE2_SIZE start = 0; start < length; count++) {
        if (pcre2_jit_match(re, (PCRE2_SPTR)text, length, start, 0, match, NULL) < 0) break;
        start = pcre2_get_ovector_pointer(match)[1];
    }
    pcre2_match_data_free(match);
    pcre2_code_free(re);
    return count;
}

// Replaces every match; returns a new buffer and its length through *length.
static char *replace_all(const char *pattern, const char *replacement, const char *text, size_t *length) {
    pcre2_code *re = compile(pattern);
    pcre2_match_data *match = pcre2_match_data_create_from_pattern(re, NULL);
    size_t capacity = *length + 1, used = 0;
    char *out = malloc(capacity);
    size_t replacement_length = strlen(replacement);
    PCRE2_SIZE start = 0;
    while (start <= *length && pcre2_jit_match(re, (PCRE2_SPTR)text, *length, start, 0, match, NULL) >= 0) {
        PCRE2_SIZE *ovector = pcre2_get_ovector_pointer(match);
        size_t keep = ovector[0] - start;
        if (used + keep + replacement_length + 1 > capacity) {
            capacity = (used + keep + replacement_length + 1) * 2;
            out = realloc(out, capacity);
        }
        memcpy(out + used, text + start, keep);
        used += keep;
        memcpy(out + used, replacement, replacement_length);
        used += replacement_length;
        start = ovector[1];
        if (ovector[1] == ovector[0]) {
            // An empty match: keep the next character and move past it.
            if (start == *length) break;
            out[used++] = text[start++];
        }
    }
    if (start < *length) {
        size_t rest = *length - start;
        if (used + rest + 1 > capacity) out = realloc(out, used + rest + 1);
        memcpy(out + used, text + start, rest);
        used += rest;
    }
    out[used] = '\0';
    pcre2_match_data_free(match);
    pcre2_code_free(re);
    *length = used;
    return out;
}

int main(int argc, char **argv) {
    const char *file_name = argc > 1 ? argv[1] : "25000_in";
    FILE *fp = fopen(file_name, "rb");
    if (!fp) {
        perror(file_name);
        return 1;
    }
    fseek(fp, 0, SEEK_END);
    size_t input_length = (size_t)ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *input = malloc(input_length + 1);
    if (fread(input, 1, input_length, fp) != input_length) return 1;
    input[input_length] = '\0';
    fclose(fp);

    size_t length = input_length;
    char *seq = replace_all(">.*\n|\n", "", input, &length);
    size_t clean_length = length;

    static const char *variants[] = {
        "agggtaaa|tttaccct",         "[cgt]gggtaaa|tttaccc[acg]", "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct", "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct", "agggtaa[cgt]|[acg]ttaccct",
    };
    for (size_t i = 0; i < sizeof variants / sizeof variants[0]; i++)
        printf("%s %ld\n", variants[i], count_matches(variants[i], seq, clean_length));

    static const char *substitutions[][2] = {
        {"tHa[Nt]", "<4>"}, {"aND|caN|Ha[DS]|WaS", "<3>"}, {"a[NSt]|BY", "<2>"}, {"<[^>]*>", "|"}, {"\\|[^|][^|]*\\|", "-"},
    };
    for (size_t i = 0; i < sizeof substitutions / sizeof substitutions[0]; i++) {
        char *next = replace_all(substitutions[i][0], substitutions[i][1], seq, &length);
        free(seq);
        seq = next;
    }
    printf("\n%zu\n%zu\n%zu\n", input_length, clean_length, length);
    return 0;
}
