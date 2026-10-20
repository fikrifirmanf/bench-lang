// LRU cache: an open-addressing hash table of node indexes plus an intrusive doubly linked list.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    uint32_t key, value;
    int prev, next;
} Node;

typedef struct {
    int size, count, head, tail, slots_mask;
    Node *nodes;
    int *slots;  // node index + 1; 0 marks an empty slot
} Lru;

static uint32_t hash_key(uint32_t key) {
    key ^= key >> 16;
    key *= 0x45d9f3bu;
    key ^= key >> 16;
    return key;
}

static void lru_init(Lru *lru, int size) {
    int slots = 1;
    while (slots < size * 2) slots <<= 1;
    lru->size = size;
    lru->count = 0;
    lru->head = lru->tail = -1;
    lru->slots_mask = slots - 1;
    lru->nodes = malloc(sizeof(Node) * size);
    lru->slots = calloc(slots, sizeof(int));
}

static int *find_slot(Lru *lru, uint32_t key) {
    for (uint32_t i = hash_key(key) & lru->slots_mask;; i = (i + 1) & lru->slots_mask) {
        int *slot = &lru->slots[i];
        if (*slot == 0 || lru->nodes[*slot - 1].key == key) return slot;
    }
}

// Backward-shift deletion keeps every probe sequence unbroken without tombstones.
static void remove_slot(Lru *lru, int *slot) {
    uint32_t hole = (uint32_t)(slot - lru->slots);
    for (uint32_t i = (hole + 1) & lru->slots_mask; lru->slots[i] != 0; i = (i + 1) & lru->slots_mask) {
        uint32_t home = hash_key(lru->nodes[lru->slots[i] - 1].key) & lru->slots_mask;
        if (((i - home) & lru->slots_mask) >= ((i - hole) & lru->slots_mask)) {
            lru->slots[hole] = lru->slots[i];
            hole = i;
        }
    }
    lru->slots[hole] = 0;
}

static void unlink_node(Lru *lru, int index) {
    Node *node = &lru->nodes[index];
    if (node->prev >= 0) lru->nodes[node->prev].next = node->next; else lru->head = node->next;
    if (node->next >= 0) lru->nodes[node->next].prev = node->prev; else lru->tail = node->prev;
}

static void push_back(Lru *lru, int index) {
    Node *node = &lru->nodes[index];
    node->prev = lru->tail;
    node->next = -1;
    if (lru->tail >= 0) lru->nodes[lru->tail].next = index; else lru->head = index;
    lru->tail = index;
}

static int lru_get(Lru *lru, uint32_t key, uint32_t *value) {
    int *slot = find_slot(lru, key);
    if (*slot == 0) return 0;
    int index = *slot - 1;
    unlink_node(lru, index);
    push_back(lru, index);
    *value = lru->nodes[index].value;
    return 1;
}

static void lru_put(Lru *lru, uint32_t key, uint32_t value) {
    int *slot = find_slot(lru, key);
    int index;
    if (*slot != 0) {
        index = *slot - 1;
        unlink_node(lru, index);
    } else {
        if (lru->count == lru->size) {
            index = lru->head;
            unlink_node(lru, index);
            remove_slot(lru, find_slot(lru, lru->nodes[index].key));
            slot = find_slot(lru, key);
        } else {
            index = lru->count++;
        }
        lru->nodes[index].key = key;
        *slot = index + 1;
    }
    lru->nodes[index].value = value;
    push_back(lru, index);
}

static uint32_t lcg(uint32_t *seed) {
    *seed = (uint32_t)((1103515245ull * *seed + 12345) % (1ull << 31));
    return *seed;
}

int main(int argc, char **argv) {
    int size = argc > 1 ? atoi(argv[1]) : 100;
    int n = argc > 2 ? atoi(argv[2]) : 1000;
    uint32_t mod = (uint32_t)size * 10;
    uint32_t seed0 = 0, seed1 = 1, value;
    long hit = 0, missed = 0;
    Lru lru;
    lru_init(&lru, size);
    for (int i = 0; i < n; i++) {
        uint32_t n0 = lcg(&seed0) % mod;
        lru_put(&lru, n0, n0);
        uint32_t n1 = lcg(&seed1) % mod;
        if (lru_get(&lru, n1, &value)) hit++; else missed++;
    }
    printf("%ld\n%ld\n", hit, missed);
    return 0;
}
