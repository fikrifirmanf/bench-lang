// JSON round trip with a hand-written parser (Foundation's JSONSerialization does not keep key order):
// serialize exactly as Python's json.dumps(separators=(',', ':')) does, then print the MD5.
import Foundation

indirect enum JSON {
    case null, bool(Bool), int(Int), double(Double), string(String), array([JSON]), object([(String, JSON)])
}

struct Parser {
    let bytes: [UInt8]
    var i = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func skipSpace() {
        while i < bytes.count, bytes[i] == 0x20 || bytes[i] == 0x0a || bytes[i] == 0x0d || bytes[i] == 0x09 { i += 1 }
    }

    mutating func parse() -> JSON {
        skipSpace()
        switch bytes[i] {
        case UInt8(ascii: "{"):
            i += 1
            var members: [(String, JSON)] = []
            skipSpace()
            if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(members) }
            while true {
                skipSpace()
                let key = parseString()
                skipSpace()
                i += 1  // ':'
                members.append((key, parse()))
                skipSpace()
                let c = bytes[i]
                i += 1
                if c == UInt8(ascii: "}") { return .object(members) }
            }
        case UInt8(ascii: "["):
            i += 1
            var items: [JSON] = []
            skipSpace()
            if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
            while true {
                items.append(parse())
                skipSpace()
                let c = bytes[i]
                i += 1
                if c == UInt8(ascii: "]") { return .array(items) }
            }
        case UInt8(ascii: "\""): return .string(parseString())
        case UInt8(ascii: "t"): i += 4; return .bool(true)
        case UInt8(ascii: "f"): i += 5; return .bool(false)
        case UInt8(ascii: "n"): i += 4; return .null
        default: return parseNumber()
        }
    }

    mutating func hex4() -> UInt32 {
        let text = String(decoding: bytes[i..<(i + 4)], as: UTF8.self)
        i += 4
        return UInt32(text, radix: 16)!
    }

    mutating func parseString() -> String {
        i += 1
        let start = i
        while bytes[i] != UInt8(ascii: "\"") && bytes[i] != UInt8(ascii: "\\") { i += 1 }
        if bytes[i] == UInt8(ascii: "\"") {
            defer { i += 1 }
            return String(decoding: bytes[start..<i], as: UTF8.self)
        }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: String(decoding: bytes[start..<i], as: UTF8.self).unicodeScalars)
        var pending = [UInt8]()
        func flush() {
            if !pending.isEmpty {
                scalars.append(contentsOf: String(decoding: pending, as: UTF8.self).unicodeScalars)
                pending.removeAll()
            }
        }
        while bytes[i] != UInt8(ascii: "\"") {
            let c = bytes[i]
            i += 1
            if c != UInt8(ascii: "\\") { pending.append(c); continue }
            flush()
            let e = bytes[i]
            i += 1
            switch e {
            case UInt8(ascii: "b"): scalars.append("\u{08}")
            case UInt8(ascii: "f"): scalars.append("\u{0C}")
            case UInt8(ascii: "n"): scalars.append("\n")
            case UInt8(ascii: "r"): scalars.append("\r")
            case UInt8(ascii: "t"): scalars.append("\t")
            case UInt8(ascii: "u"):
                var cp = hex4()
                if cp >= 0xd800 && cp < 0xdc00 && bytes[i] == UInt8(ascii: "\\") && bytes[i + 1] == UInt8(ascii: "u") {
                    i += 2
                    let low = hex4()
                    cp = 0x10000 + ((cp - 0xd800) << 10) + (low - 0xdc00)
                }
                scalars.append(Unicode.Scalar(cp) ?? "\u{FFFD}")
            default: scalars.append(Unicode.Scalar(e))
            }
        }
        flush()
        i += 1
        return String(scalars)
    }

    mutating func parseNumber() -> JSON {
        let start = i
        var isFloat = false
        while i < bytes.count {
            let c = bytes[i]
            if c == UInt8(ascii: ".") || c == UInt8(ascii: "e") || c == UInt8(ascii: "E") { isFloat = true }
            else if !(c == UInt8(ascii: "-") || c == UInt8(ascii: "+") || (c >= 0x30 && c <= 0x39)) { break }
            i += 1
        }
        let text = String(decoding: bytes[start..<i], as: UTF8.self)
        return isFloat ? .double(Double(text)!) : .int(Int(text)!)
    }
}

// Python's repr(float). Swift's description has the shortest round-trip digits but its own layout.
func appendFloat(_ out: inout [UInt8], _ x: Double) {
    let text = x.magnitude.description
    var mantissa = Substring(text), exponent = 0
    if let e = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
        mantissa = text[..<e]
        exponent = Int(text[text.index(after: e)...])!
    }
    var digits = Array(mantissa.utf8.filter { $0 != UInt8(ascii: ".") })
    exponent += (mantissa.firstIndex(of: ".").map { mantissa.distance(from: mantissa.startIndex, to: $0) } ?? mantissa.count) - 1
    while digits.count > 1 && digits[0] == UInt8(ascii: "0") { digits.removeFirst(); exponent -= 1 }
    while digits.count > 1 && digits.last == UInt8(ascii: "0") { digits.removeLast() }

    if x.sign == .minus { out.append(UInt8(ascii: "-")) }
    let zero = UInt8(ascii: "0"), dot = UInt8(ascii: ".")
    if exponent >= -4 && exponent < 16 {
        if exponent < 0 {
            out += [zero, dot] + [UInt8](repeating: zero, count: -exponent - 1) + digits
        } else if digits.count > exponent + 1 {
            out += digits[0...exponent] + [dot] + digits[(exponent + 1)...]
        } else {
            out += digits + [UInt8](repeating: zero, count: exponent + 1 - digits.count) + [dot, zero]
        }
    } else {
        out.append(digits[0])
        if digits.count > 1 { out += [dot] + digits[1...] }
        let e = String(abs(exponent))
        out += Array("e\(exponent < 0 ? "-" : "+")\(e.count < 2 ? "0" : "")\(e)".utf8)
    }
}

func appendString(_ out: inout [UInt8], _ s: String) {
    out.append(UInt8(ascii: "\""))
    for unit in s.utf16 {
        switch unit {
        case 0x22: out += Array("\\\"".utf8)
        case 0x5c: out += Array("\\\\".utf8)
        case 0x0a: out += Array("\\n".utf8)
        case 0x0d: out += Array("\\r".utf8)
        case 0x09: out += Array("\\t".utf8)
        case 0x08: out += Array("\\b".utf8)
        case 0x0c: out += Array("\\f".utf8)
        case 0x20..<0x80: out.append(UInt8(unit))
        default:
            // Python escapes control and non-ASCII characters as \uXXXX of their UTF-16 code units.
            let hex = String(unit, radix: 16)
            out += Array(("\\u" + String(repeating: "0", count: 4 - hex.count) + hex).utf8)
        }
    }
    out.append(UInt8(ascii: "\""))
}

func dump(_ out: inout [UInt8], _ value: JSON) {
    switch value {
    case .null: out += Array("null".utf8)
    case .bool(let b): out += Array((b ? "true" : "false").utf8)
    case .int(let i): out += Array(String(i).utf8)
    case .double(let d): appendFloat(&out, d)
    case .string(let s): appendString(&out, s)
    case .array(let items):
        out.append(UInt8(ascii: "["))
        for (i, item) in items.enumerated() {
            if i > 0 { out.append(UInt8(ascii: ",")) }
            dump(&out, item)
        }
        out.append(UInt8(ascii: "]"))
    case .object(let members):
        out.append(UInt8(ascii: "{"))
        for (i, (key, item)) in members.enumerated() {
            if i > 0 { out.append(UInt8(ascii: ",")) }
            appendString(&out, key)
            out.append(UInt8(ascii: ":"))
            dump(&out, item)
        }
        out.append(UInt8(ascii: "}"))
    }
}

func printHash(_ value: JSON) {
    var out = [UInt8]()
    out.reserveCapacity(1 << 20)
    dump(&out, value)
    print(md5Hex(out))
}

let args = CommandLine.arguments
let fileName = args.count > 1 ? args[1] : "sample"
let n = args.count > 2 ? Int(args[2])! : 3
var bytes = [UInt8](FileManager.default.contents(atPath: "\(fileName).json")!)
if bytes.starts(with: [0xef, 0xbb, 0xbf]) { bytes.removeFirst(3) }
var single = Parser(bytes)
printHash(single.parse())
var items: [JSON] = []
for _ in 0..<n {
    var parser = Parser(bytes)
    items.append(parser.parse())
}
printHash(.array(items))
