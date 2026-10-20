// Trees of std::unique_ptr nodes; each tree is freed as soon as it has been checked.
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <memory>

struct Node {
    std::unique_ptr<Node> left, right;
};

static std::unique_ptr<Node> make(int depth) {
    auto node = std::make_unique<Node>();
    if (depth > 0) {
        node->left = make(depth - 1);
        node->right = make(depth - 1);
    }
    return node;
}

static int check(const Node &node) {
    return node.left ? 1 + check(*node.left) + check(*node.right) : 1;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 6;
    const int min_depth = 4;
    int max_depth = std::max(min_depth + 2, n);
    int stretch_depth = max_depth + 1;

    std::printf("stretch tree of depth %d\t check: %d\n", stretch_depth, check(*make(stretch_depth)));
    auto long_lived = make(max_depth);
    for (int depth = min_depth; depth <= max_depth; depth += 2) {
        int iterations = 1 << (max_depth - depth + min_depth);
        int sum = 0;
        for (int i = 0; i < iterations; i++) sum += check(*make(depth));
        std::printf("%d\t trees of depth %d\t check: %d\n", iterations, depth, sum);
    }
    std::printf("long lived tree of depth %d\t check: %d\n", max_depth, check(*long_lived));
}
