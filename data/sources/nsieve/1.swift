// Sieve of Eratosthenes over a [Bool] of flags.
func nsieve(_ n: Int) {
    var composite = [Bool](repeating: false, count: n)
    var count = 0
    for i in 2..<n where !composite[i] {
        count += 1
        var j = i << 1
        while j < n {
            composite[j] = true
            j += i
        }
    }
    let size = String(n), found = String(count)
    print("Primes up to \(String(repeating: " ", count: max(0, 8 - size.count)))\(size) \(String(repeating: " ", count: max(0, 8 - found.count)))\(found)")
}

let n = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 4
for i in 0..<3 {
    nsieve(10000 << (n - i))
}
