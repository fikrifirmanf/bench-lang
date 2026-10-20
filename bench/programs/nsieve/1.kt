// Sieve of Eratosthenes over a BooleanArray.
fun nsieve(n: Int) {
    val composite = BooleanArray(n)
    var count = 0
    for (i in 2 until n) {
        if (!composite[i]) {
            count++
            var j = i shl 1
            while (j < n) {
                composite[j] = true
                j += i
            }
        }
    }
    println("Primes up to %8d %8d".format(n, count))
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 4
    for (i in 0 until 3) nsieve(10000 shl (n - i))
}
