// Single-threaded fannkuch-redux on IntArrays.
fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 7
    val perm = IntArray(n)
    val perm1 = IntArray(n) { it }
    val count = IntArray(n)
    var maxFlips = 0
    var checksum = 0
    var permCount = 0
    var r = n
    while (true) {
        while (r != 1) {
            count[r - 1] = r
            r--
        }
        perm1.copyInto(perm)
        var flips = 0
        var k = perm[0]
        while (k != 0) {
            var i = 0
            var j = k
            while (i < j) {
                val t = perm[i]
                perm[i] = perm[j]
                perm[j] = t
                i++
                j--
            }
            flips++
            k = perm[0]
        }
        if (flips > maxFlips) maxFlips = flips
        checksum += if (permCount % 2 == 0) flips else -flips

        while (true) {
            if (r == n) {
                println("$checksum\nPfannkuchen($n) = $maxFlips")
                return
            }
            val first = perm1[0]
            for (i in 0 until r) perm1[i] = perm1[i + 1]
            perm1[r] = first
            if (--count[r] > 0) break
            r++
        }
        permCount++
    }
}
