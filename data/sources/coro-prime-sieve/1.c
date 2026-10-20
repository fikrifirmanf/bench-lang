// Prime sieve as a chain of coroutines (ucontext): a generator of 2, 3, 4, ... and one filter per prime found.
#include <stdio.h>
#include <stdlib.h>
#include <ucontext.h>

#define STACK_SIZE (32 * 1024)

typedef struct Coro {
    ucontext_t context;
    ucontext_t *caller;
    struct Coro *source;
    int prime;
    int value;
    int started;
} Coro;

static Coro *current_coro;

static void yield(Coro *self, int value) {
    self->value = value;
    swapcontext(&self->context, self->caller);
}

static int next(Coro *coro) {
    ucontext_t here;
    if (!coro->started) {
        // A body reads its own Coro from here on its first run.
        coro->started = 1;
        current_coro = coro;
    }
    coro->caller = &here;
    swapcontext(&here, &coro->context);
    return coro->value;
}

static void generate(void) {
    Coro *self = current_coro;
    for (int i = 2;; i++) yield(self, i);
}

static void filter(void) {
    Coro *self = current_coro;
    for (;;) {
        int value = next(self->source);
        if (value % self->prime != 0) yield(self, value);
    }
}

static Coro *spawn(void (*body)(void), Coro *source, int prime) {
    Coro *coro = calloc(1, sizeof *coro);
    coro->source = source;
    coro->prime = prime;
    getcontext(&coro->context);
    coro->context.uc_stack.ss_sp = malloc(STACK_SIZE);
    coro->context.uc_stack.ss_size = STACK_SIZE;
    coro->context.uc_link = NULL;
    makecontext(&coro->context, body, 0);
    return coro;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 100;
    Coro *chain = spawn(generate, NULL, 0);
    for (int i = 0; i < n; i++) {
        int prime = next(chain);
        printf("%d\n", prime);
        chain = spawn(filter, chain, prime);
    }
    return 0;
}
