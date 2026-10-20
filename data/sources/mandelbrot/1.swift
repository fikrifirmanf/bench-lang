// Scalar mandelbrot: 50 iterations per pixel, then the MD5 of the packed bitmap.
func pixelByte(_ xs: UnsafeBufferPointer<Double>, _ offset: Int, _ ci: Double) -> UInt8 {
    var bits: UInt8 = 0
    for k in 0..<8 {
        let cr = xs[offset + k]
        var zr = 0.0, zi = 0.0, tr = 0.0, ti = 0.0
        var escaped = false
        var i = 0
        while i < 50 && !escaped {
            zi = (zr + zr) * zi + ci
            zr = tr - ti + cr
            tr = zr * zr
            ti = zi * zi
            escaped = tr + ti > 4.0
            i += 1
        }
        if !escaped { bits |= UInt8(0x80) >> UInt8(k) }
    }
    return bits
}

var size = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 200
size = (size + 7) / 8 * 8
let rowBytes = size / 8
let inv = 2.0 / Double(size)
let xs = (0..<size).map { Double($0) * inv - 1.5 }
var pixels = [UInt8](repeating: 0, count: size * rowBytes)
xs.withUnsafeBufferPointer { xp in
    for y in 0..<size {
        let ci = Double(y) * inv - 1.0
        for i in 0..<rowBytes {
            pixels[y * rowBytes + i] = pixelByte(xp, i * 8, ci)
        }
    }
}
print("P4\n\(size) \(size)\n\(md5Hex(pixels))")
