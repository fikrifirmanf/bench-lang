// Merkle trees of class nodes; leaves carry the value 1 and a parent's hash is the sum of its children's.
final class Node {
    let value: Int?
    let left: Node?
    let right: Node?
    var hash: Int?

    init(value: Int?, left: Node?, right: Node?) {
        self.value = value
        self.left = left
        self.right = right
    }

    func getHash() -> Int { hash ?? -1 }

    func calHash() {
        if hash != nil { return }
        if let value = value {
            hash = value
        } else if let left = left, let right = right {
            left.calHash()
            right.calHash()
            hash = left.getHash() + right.getHash()
        }
    }

    func check() -> Bool {
        guard hash != nil else { return false }
        if value != nil { return true }
        guard let left = left, let right = right else { return false }
        return left.check() && right.check()
    }
}

func make(_ depth: Int) -> Node {
    depth > 0 ? Node(value: nil, left: make(depth - 1), right: make(depth - 1)) : Node(value: 1, left: nil, right: nil)
}

let n = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 6
let minDepth = 4
let maxDepth = max(minDepth + 2, n)
let stretchDepth = maxDepth + 1

let stretch = make(stretchDepth)
stretch.calHash()
print("stretch tree of depth \(stretchDepth)\t root hash: \(stretch.getHash()) check: \(stretch.check())")

let longLived = make(maxDepth)
for depth in stride(from: minDepth, through: maxDepth, by: 2) {
    let iterations = 1 << (maxDepth - depth + minDepth)
    var sum = 0
    for _ in 0..<iterations {
        let tree = make(depth)
        tree.calHash()
        sum += tree.getHash()
    }
    print("\(iterations)\t trees of depth \(depth)\t root hash sum: \(sum)")
}
longLived.calHash()
print("long lived tree of depth \(n)\t root hash: \(longLived.getHash()) check: \(longLived.check())")
