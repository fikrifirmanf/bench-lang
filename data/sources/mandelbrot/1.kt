// Scalar mandelbrot: 50 iterations per pixel, then the MD5 of the packed bitmap. The JVM never fuses
// multiply-add on its own, so this rounds exactly like the reference.
import java.security.MessageDigest

fun pixelByte(xs: DoubleArray, offset: Int, ci: Double): Byte {
    var bits = 0
    for (k in 0 until 8) {
        val cr = xs[offset + k]
        var zr = 0.0
        var zi = 0.0
        var tr = 0.0
        var ti = 0.0
        var escaped = false
        var i = 0
        while (i < 50 && !escaped) {
            zi = (zr + zr) * zi + ci
            zr = tr - ti + cr
            tr = zr * zr
            ti = zi * zi
            escaped = tr + ti > 4.0
            i++
        }
        if (!escaped) bits = bits or (0x80 shr k)
    }
    return bits.toByte()
}

fun main(args: Array<String>) {
    var size = if (args.isNotEmpty()) args[0].toInt() else 200
    size = (size + 7) / 8 * 8
    val rowBytes = size / 8
    val inv = 2.0 / size
    val xs = DoubleArray(size) { it * inv - 1.5 }
    val pixels = ByteArray(size * rowBytes)
    for (y in 0 until size) {
        val ci = y * inv - 1.0
        for (i in 0 until rowBytes) pixels[y * rowBytes + i] = pixelByte(xs, i * 8, ci)
    }
    val digest = MessageDigest.getInstance("MD5").digest(pixels)
    println("P4\n$size $size\n${digest.joinToString("") { "%02x".format(it) }}")
}
