// Spectral norm by power iteration on A^T A, single-threaded.
import Foundation

@inline(__always) func a(_ i: Int, _ j: Int) -> Double {
    1.0 / Double((i + j) * (i + j + 1) / 2 + i + 1)
}

func multAv(_ v: [Double], _ out: inout [Double]) {
    let n = v.count
    for i in 0..<n {
        var sum = 0.0
        for j in 0..<n { sum += a(i, j) * v[j] }
        out[i] = sum
    }
}

func multAtv(_ v: [Double], _ out: inout [Double]) {
    let n = v.count
    for i in 0..<n {
        var sum = 0.0
        for j in 0..<n { sum += a(j, i) * v[j] }
        out[i] = sum
    }
}

let n = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 100
var u = [Double](repeating: 1, count: n)
var v = [Double](repeating: 0, count: n)
var tmp = [Double](repeating: 0, count: n)
for _ in 0..<10 {
    multAv(u, &tmp)
    multAtv(tmp, &v)
    multAv(v, &tmp)
    multAtv(tmp, &u)
}
var vbv = 0.0, vv = 0.0
for i in 0..<n {
    vbv += u[i] * v[i]
    vv += v[i] * v[i]
}
print(String(format: "%.9f", sqrt(vbv / vv)))
