// Spectral norm by power iteration on A^T A, single-threaded.
import kotlin.math.sqrt

fun a(i: Int, j: Int): Double = 1.0 / ((i + j) * (i + j + 1) / 2 + i + 1)

fun multAv(v: DoubleArray, out: DoubleArray) {
    for (i in v.indices) {
        var sum = 0.0
        for (j in v.indices) sum += a(i, j) * v[j]
        out[i] = sum
    }
}

fun multAtv(v: DoubleArray, out: DoubleArray) {
    for (i in v.indices) {
        var sum = 0.0
        for (j in v.indices) sum += a(j, i) * v[j]
        out[i] = sum
    }
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 100
    val u = DoubleArray(n) { 1.0 }
    val v = DoubleArray(n)
    val tmp = DoubleArray(n)
    repeat(10) {
        multAv(u, tmp)
        multAtv(tmp, v)
        multAv(v, tmp)
        multAtv(tmp, u)
    }
    var vbv = 0.0
    var vv = 0.0
    for (i in 0 until n) {
        vbv += u[i] * v[i]
        vv += v[i] * v[i]
    }
    println("%.9f".format(sqrt(vbv / vv)))
}
