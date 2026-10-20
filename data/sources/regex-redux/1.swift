// regex-redux with Foundation's NSRegularExpression.
import Foundation

func regex(_ pattern: String) -> NSRegularExpression {
    try! NSRegularExpression(pattern: pattern)
}

func replaceAll(_ pattern: String, _ replacement: String, _ text: String) -> String {
    regex(pattern).stringByReplacingMatches(
        in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement)
}

let fileName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "25000_in"
let input = try! String(contentsOfFile: fileName, encoding: .ascii)
let seq = replaceAll(">.*\n|\n", "", input)

let variants = [
    "agggtaaa|tttaccct", "[cgt]gggtaaa|tttaccc[acg]", "a[act]ggtaaa|tttacc[agt]t",
    "ag[act]gtaaa|tttac[agt]ct", "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
    "agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct", "agggtaa[cgt]|[acg]ttaccct",
]
var out = ""
let whole = NSRange(seq.startIndex..., in: seq)
for variant in variants {
    out += "\(variant) \(regex(variant).numberOfMatches(in: seq, range: whole))\n"
}

let substitutions = [
    ("tHa[Nt]", "<4>"), ("aND|caN|Ha[DS]|WaS", "<3>"), ("a[NSt]|BY", "<2>"), ("<[^>]*>", "|"), ("\\|[^|][^|]*\\|", "-"),
]
var replaced = seq
for (pattern, replacement) in substitutions { replaced = replaceAll(pattern, replacement, replaced) }
print("\(out)\n\(input.utf8.count)\n\(seq.utf8.count)\n\(replaced.utf8.count)")
