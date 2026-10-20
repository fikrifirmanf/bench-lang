// Digits of e by binary splitting of sum(1/k!), on attaswift's BigInt (already in the Swift package).
import BigInt
import Foundation

func sumTerms(_ a: Int, _ b: Int) -> (BigInt, BigInt) {
    if b == a + 1 { return (1, BigInt(b)) }
    let mid = (a + b) / 2
    let (pLeft, qLeft) = sumTerms(a, mid)
    let (pRight, qRight) = sumTerms(mid, b)
    return (pLeft * qRight + pRight, qLeft * qRight)
}

func testK(_ n: Int, _ k: Int) -> Bool {
    if k <= 0 { return false }
    let lnKFactorial = Double(k) * (log(Double(k)) - 1) + 0.5 * log(2 * Double.pi)
    return lnKFactorial / log(10.0) >= Double(n + 50)
}

func binarySearch(_ n: Int) -> Int {
    var a = 0, b = 1
    while !testK(n, b) {
        a = b
        b *= 2
    }
    while b - a > 1 {
        let m = (a + b) / 2
        if testK(n, m) { b = m } else { a = m }
    }
    return b
}

let n = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 27
let (p, q) = sumTerms(0, binarySearch(n) - 1)
let digits = Array(((p + q) * BigInt(10).power(n - 1) / q).description.utf8)
var out = [UInt8]()
for i in stride(from: 0, to: n, by: 10) {
    if i + 10 <= n {
        out += digits[i..<(i + 10)]
        out += Array("\t:\(i + 10)\n".utf8)
    } else {
        out += digits[i..<n]
        out += [UInt8](repeating: UInt8(ascii: " "), count: 10 - n % 10)
        out += Array("\t:\(n)\n".utf8)
    }
}
print(String(decoding: out, as: UTF8.self), terminator: "")
