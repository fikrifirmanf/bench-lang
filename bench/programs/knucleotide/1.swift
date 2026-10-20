// k-nucleotide: counts every k-mer of the THREE sequence in a Dictionary keyed by 2-bit packed codes.
import Foundation

func codeOf(_ c: UInt8) -> UInt64 {
    switch c {
    case UInt8(ascii: "A"): return 0
    case UInt8(ascii: "C"): return 1
    case UInt8(ascii: "G"): return 2
    default: return 3
    }
}

func countKmers(_ seq: [UInt8], _ k: Int) -> [UInt64: Int] {
    var counts = [UInt64: Int]()
    let mask: UInt64 = (1 << UInt64(2 * k)) - 1
    var key: UInt64 = 0
    for (i, c) in seq.enumerated() {
        key = ((key << 2) | UInt64(c)) & mask
        if i + 1 >= k { counts[key, default: 0] += 1 }
    }
    return counts
}

func unpack(_ key: UInt64, _ k: Int) -> String {
    let letters = Array("ACGT")
    var chars = [Character](repeating: "A", count: k)
    var rest = key
    for i in stride(from: k - 1, through: 0, by: -1) {
        chars[i] = letters[Int(rest & 3)]
        rest >>= 2
    }
    return String(chars)
}

let fileName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "25000_in"
let text = try! String(contentsOfFile: fileName, encoding: .ascii)
var seq = [UInt8]()
var inThree = false
for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
    if inThree {
        if line.hasPrefix(">") { break }
        for c in line.utf8 where c != UInt8(ascii: " ") && c != UInt8(ascii: "\r") && c != UInt8(ascii: "\t") {
            seq.append(UInt8(codeOf(c & ~0x20)))
        }
    } else if line.hasPrefix(">THREE") {
        inThree = true
    }
}

var out = ""
for k in 1...2 {
    let total = Double(seq.count - k + 1)
    let sorted = countKmers(seq, k).map { (unpack($0.key, k), $0.value) }
        .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
    for (kmer, count) in sorted { out += "\(kmer) \(String(format: "%.3f", Double(count) * 100.0 / total))\n" }
    out += "\n"
}
for kmer in ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"] {
    let key = kmer.utf8.reduce(UInt64(0)) { ($0 << 2) | codeOf($1) }
    out += "\(countKmers(seq, kmer.count)[key] ?? 0)\t\(kmer)\n"
}
print(out, terminator: "")
