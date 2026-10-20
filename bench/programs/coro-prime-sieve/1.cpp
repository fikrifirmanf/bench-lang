// Prime sieve as a chain of C++20 coroutines: a generator of 2, 3, 4, ... and one filter per prime found.
#include <coroutine>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <utility>

class Generator {
  public:
    struct promise_type {
        int value = 0;
        Generator get_return_object() { return Generator{Handle::from_promise(*this)}; }
        std::suspend_always initial_suspend() noexcept { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        std::suspend_always yield_value(int v) noexcept {
            value = v;
            return {};
        }
        void return_void() {}
        void unhandled_exception() { std::abort(); }
    };
    using Handle = std::coroutine_handle<promise_type>;

    explicit Generator(Handle handle) : handle_(handle) {}
    Generator(Generator &&other) noexcept : handle_(std::exchange(other.handle_, {})) {}
    Generator(const Generator &) = delete;
    ~Generator() {
        if (handle_) handle_.destroy();
    }

    int next() {
        handle_.resume();
        return handle_.promise().value;
    }

  private:
    Handle handle_;
};

static Generator generate() {
    for (int i = 2;; i++) co_yield i;
}

static Generator filter(std::unique_ptr<Generator> source, int prime) {
    for (;;) {
        int value = source->next();
        if (value % prime != 0) co_yield value;
    }
}

int main(int argc, char **argv) {
    int n = argc > 1 ? std::atoi(argv[1]) : 100;
    auto chain = std::make_unique<Generator>(generate());
    for (int i = 0; i < n; i++) {
        int prime = chain->next();
        std::printf("%d\n", prime);
        chain = std::make_unique<Generator>(filter(std::move(chain), prime));
    }
}
