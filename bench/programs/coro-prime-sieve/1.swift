// Prime sieve as a chain of async iterators (Swift async functions are coroutines): a generator of
// 2, 3, 4, ... and one filter per prime found, each pulling from the one before it.
protocol IntSource: AnyObject {
    func next() async -> Int
}

final class Generate: IntSource {
    private var i = 1
    func next() async -> Int {
        i += 1
        return i
    }
}

final class Filter: IntSource {
    private let source: IntSource
    private let prime: Int
    init(_ source: IntSource, _ prime: Int) {
        self.source = source
        self.prime = prime
    }
    func next() async -> Int {
        while true {
            let value = await source.next()
            if value % prime != 0 { return value }
        }
    }
}

let n = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 100
var chain: IntSource = Generate()
var out = ""
for _ in 0..<n {
    let prime = await chain.next()
    out += "\(prime)\n"
    chain = Filter(chain, prime)
}
print(out, terminator: "")
