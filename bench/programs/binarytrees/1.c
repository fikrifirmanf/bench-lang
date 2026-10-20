// Allocates every node with malloc and frees each tree after checking it.
#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    struct Node *left, *right;
} Node;

static Node *make(int depth) {
    Node *node = malloc(sizeof *node);
    if (depth > 0) {
        node->left = make(depth - 1);
        node->right = make(depth - 1);
    } else {
        node->left = node->right = NULL;
    }
    return node;
}

static int check(const Node *node) {
    return node->left ? 1 + check(node->left) + check(node->right) : 1;
}

static void release(Node *node) {
    if (node->left) {
        release(node->left);
        release(node->right);
    }
    free(node);
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 6;
    int min_depth = 4;
    int max_depth = n > min_depth + 2 ? n : min_depth + 2;
    int stretch_depth = max_depth + 1;

    Node *stretch = make(stretch_depth);
    printf("stretch tree of depth %d\t check: %d\n", stretch_depth, check(stretch));
    release(stretch);

    Node *long_lived = make(max_depth);
    for (int depth = min_depth; depth <= max_depth; depth += 2) {
        int iterations = 1 << (max_depth - depth + min_depth);
        int sum = 0;
        for (int i = 0; i < iterations; i++) {
            Node *tree = make(depth);
            sum += check(tree);
            release(tree);
        }
        printf("%d\t trees of depth %d\t check: %d\n", iterations, depth, sum);
    }
    printf("long lived tree of depth %d\t check: %d\n", max_depth, check(long_lived));
    release(long_lived);
    return 0;
}
