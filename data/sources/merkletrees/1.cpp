// Merkle trees with std::optional for the not-yet-computed hash; leaves carry the value 1.
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <optional>

struct Node {
    std::optional<long> value;
    std::optional<long> hash;
    std::unique_ptr<Node> left, right;

    long get_hash() const { return hash.value_or(-1); }

    void cal_hash() {
        if (hash) return;
        if (value) {
            hash = value;
        } else if (left && right) {
            left->cal_hash();
            right->cal_hash();
            hash = left->get_hash() + right->get_hash();
        }
    }

    bool check() const {
        if (!hash) return false;
        if (value) return true;
        return left && right && left->check() && right->check();
    }
};

static std::unique_ptr<Node> make(int depth) {
    auto node = std::make_unique<Node>();
    if (depth > 0) {
        node->left = make(depth - 1);
        node->right = make(depth - 1);
    } else {
        node->value = 1;
    }
    return node;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 6;
    const int min_depth = 4;
    int max_depth = std::max(min_depth + 2, n);
    int stretch_depth = max_depth + 1;

    auto stretch = make(stretch_depth);
    stretch->cal_hash();
    std::printf("stretch tree of depth %d\t root hash: %ld check: %s\n", stretch_depth, stretch->get_hash(),
                stretch->check() ? "true" : "false");
    stretch.reset();

    auto long_lived = make(max_depth);
    for (int depth = min_depth; depth <= max_depth; depth += 2) {
        long iterations = 1L << (max_depth - depth + min_depth);
        long sum = 0;
        for (long i = 0; i < iterations; i++) {
            auto tree = make(depth);
            tree->cal_hash();
            sum += tree->get_hash();
        }
        std::printf("%ld\t trees of depth %d\t root hash sum: %ld\n", iterations, depth, sum);
    }
    long_lived->cal_hash();
    std::printf("long lived tree of depth %d\t root hash: %ld check: %s\n", n, long_lived->get_hash(),
                long_lived->check() ? "true" : "false");
}
