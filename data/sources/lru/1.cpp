// LRU cache: std::list keeps recency order, std::unordered_map points at list nodes.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <list>
#include <optional>
#include <unordered_map>
#include <utility>

class Lru {
  public:
    explicit Lru(size_t size) : size_(size) { index_.reserve(size * 2); }

    std::optional<uint32_t> get(uint32_t key) {
        auto found = index_.find(key);
        if (found == index_.end()) return std::nullopt;
        order_.splice(order_.end(), order_, found->second);
        return found->second->second;
    }

    void put(uint32_t key, uint32_t value) {
        auto found = index_.find(key);
        if (found != index_.end()) {
            order_.splice(order_.end(), order_, found->second);
            found->second->second = value;
            return;
        }
        if (index_.size() == size_) {
            index_.erase(order_.front().first);
            order_.pop_front();
        }
        order_.emplace_back(key, value);
        index_.emplace(key, std::prev(order_.end()));
    }

  private:
    size_t size_;
    std::list<std::pair<uint32_t, uint32_t>> order_;
    std::unordered_map<uint32_t, std::list<std::pair<uint32_t, uint32_t>>::iterator> index_;
};

static uint32_t lcg(uint32_t &seed) {
    seed = static_cast<uint32_t>((1103515245ull * seed + 12345) % (1ull << 31));
    return seed;
}

int main(int argc, char **argv) {
    int size = argc > 1 ? std::atoi(argv[1]) : 100;
    int n = argc > 2 ? std::atoi(argv[2]) : 1000;
    uint32_t mod = static_cast<uint32_t>(size) * 10;
    uint32_t seed0 = 0, seed1 = 1;
    long hit = 0, missed = 0;
    Lru lru(size);
    for (int i = 0; i < n; i++) {
        uint32_t n0 = lcg(seed0) % mod;
        lru.put(n0, n0);
        uint32_t n1 = lcg(seed1) % mod;
        if (lru.get(n1)) hit++; else missed++;
    }
    std::printf("%ld\n%ld\n", hit, missed);
}
