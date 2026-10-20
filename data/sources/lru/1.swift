// LRU cache: a Dictionary from key to node index plus an array-backed doubly linked list.
struct Lru {
    private var keys: [UInt32], values: [UInt32], prev: [Int], next: [Int]
    private var index: [UInt32: Int]
    private var head = -1, tail = -1
    private let size: Int

    init(size: Int) {
        self.size = size
        keys = []; values = []; prev = []; next = []
        keys.reserveCapacity(size); values.reserveCapacity(size); prev.reserveCapacity(size); next.reserveCapacity(size)
        index = Dictionary(minimumCapacity: size * 2)
    }

    private mutating func unlink(_ i: Int) {
        if prev[i] >= 0 { next[prev[i]] = next[i] } else { head = next[i] }
        if next[i] >= 0 { prev[next[i]] = prev[i] } else { tail = prev[i] }
    }

    private mutating func pushBack(_ i: Int) {
        prev[i] = tail
        next[i] = -1
        if tail >= 0 { next[tail] = i } else { head = i }
        tail = i
    }

    mutating func get(_ key: UInt32) -> UInt32? {
        guard let i = index[key] else { return nil }
        unlink(i)
        pushBack(i)
        return values[i]
    }

    mutating func put(_ key: UInt32, _ value: UInt32) {
        if let i = index[key] {
            unlink(i)
            values[i] = value
            pushBack(i)
            return
        }
        let i: Int
        if keys.count == size {
            i = head
            unlink(i)
            index.removeValue(forKey: keys[i])
            keys[i] = key
            values[i] = value
        } else {
            i = keys.count
            keys.append(key); values.append(value); prev.append(-1); next.append(-1)
        }
        index[key] = i
        pushBack(i)
    }
}

struct Lcg {
    var seed: UInt64
    mutating func next() -> UInt32 {
        seed = (1103515245 &* seed &+ 12345) % (1 << 31)
        return UInt32(seed)
    }
}

let args = CommandLine.arguments
let size = args.count > 1 ? Int(args[1])! : 100
let n = args.count > 2 ? Int(args[2])! : 1000
let mod = UInt32(size * 10)
var rng0 = Lcg(seed: 0), rng1 = Lcg(seed: 1)
var lru = Lru(size: size)
var hit = 0, missed = 0
for _ in 0..<n {
    let n0 = rng0.next() % mod
    lru.put(n0, n0)
    let n1 = rng1.next() % mod
    if lru.get(n1) == nil { missed += 1 } else { hit += 1 }
}
print("\(hit)\n\(missed)")
