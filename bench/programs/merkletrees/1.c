// Leaves carry the value 1; a parent's hash is the sum of its children's, computed lazily.
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    struct Node *left, *right;
    long value;
    long hash;
    bool has_value;
    bool has_hash;
} Node;

static Node *make(int depth) {
    Node *node = calloc(1, sizeof *node);
    if (depth > 0) {
        node->left = make(depth - 1);
        node->right = make(depth - 1);
    } else {
        node->value = 1;
        node->has_value = true;
    }
    return node;
}

static long get_hash(const Node *node) {
    return node->has_hash ? node->hash : -1;
}

static void cal_hash(Node *node) {
    if (node->has_hash) return;
    if (node->has_value) {
        node->hash = node->value;
        node->has_hash = true;
    } else if (node->left && node->right) {
        cal_hash(node->left);
        cal_hash(node->right);
        node->hash = get_hash(node->left) + get_hash(node->right);
        node->has_hash = true;
    }
}

static bool check(const Node *node) {
    if (!node->has_hash) return false;
    if (node->has_value) return true;
    return node->left && node->right && check(node->left) && check(node->right);
}

static void release(Node *node) {
    if (node->left) release(node->left);
    if (node->right) release(node->right);
    free(node);
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 6;
    int min_depth = 4;
    int max_depth = n > min_depth + 2 ? n : min_depth + 2;
    int stretch_depth = max_depth + 1;

    Node *stretch = make(stretch_depth);
    cal_hash(stretch);
    printf("stretch tree of depth %d\t root hash: %ld check: %s\n", stretch_depth, get_hash(stretch),
           check(stretch) ? "true" : "false");
    release(stretch);

    Node *long_lived = make(max_depth);
    for (int depth = min_depth; depth <= max_depth; depth += 2) {
        long iterations = 1L << (max_depth - depth + min_depth);
        long sum = 0;
        for (long i = 0; i < iterations; i++) {
            Node *tree = make(depth);
            cal_hash(tree);
            sum += get_hash(tree);
            release(tree);
        }
        printf("%ld\t trees of depth %d\t root hash sum: %ld\n", iterations, depth, sum);
    }
    cal_hash(long_lived);
    printf("long lived tree of depth %d\t root hash: %ld check: %s\n", n, get_hash(long_lived),
           check(long_lived) ? "true" : "false");
    release(long_lived);
    return 0;
}
