// Digits of e by binary splitting of sum(1/k!), on java.math.BigInteger.
import java.math.BigInteger
import kotlin.math.PI
import kotlin.math.ln

fun sumTerms(a: Long, b: Long): Pair<BigInteger, BigInteger> {
    if (b == a + 1) return Pair(BigInteger.ONE, BigInteger.valueOf(b))
    val mid = (a + b) / 2
    val (pLeft, qLeft) = sumTerms(a, mid)
    val (pRight, qRight) = sumTerms(mid, b)
    return Pair(pLeft * qRight + pRight, qLeft * qRight)
}

fun testK(n: Int, k: Long): Boolean {
    if (k <= 0) return false
    val lnKFactorial = k * (ln(k.toDouble()) - 1) + 0.5 * ln(2 * PI)
    return lnKFactorial / ln(10.0) >= n + 50
}

fun binarySearch(n: Int): Long {
    var a = 0L
    var b = 1L
    while (!testK(n, b)) {
        a = b
        b *= 2
    }
    while (b - a > 1) {
        val m = (a + b) / 2
        if (testK(n, m)) b = m else a = m
    }
    return b
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 27
    val (p, q) = sumTerms(0, binarySearch(n) - 1)
    val s = ((p + q) * BigInteger.TEN.pow(n - 1) / q).toString()
    val out = StringBuilder()
    for (i in 0 until n step 10) {
        if (i + 10 <= n) {
            out.append(s, i, i + 10).append("\t:").append(i + 10).append('\n')
        } else {
            out.append(s.substring(i, n).padEnd(10)).append("\t:").append(n).append('\n')
        }
    }
    print(out)
}
