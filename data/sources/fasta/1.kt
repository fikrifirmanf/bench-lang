// FASTA generator writing 60-character lines through one buffered byte stream.
import java.io.BufferedOutputStream

const val WIDTH = 60
const val ALU =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" +
    "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" +
    "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" +
    "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" +
    "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" +
    "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" +
    "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

val out = BufferedOutputStream(System.out, 1 shl 16)
var seed = 42

fun nextRandom(): Double {
    seed = (seed * 3877 + 29573) % 139968
    return seed / 139968.0
}

fun repeatFasta(src: String, n: Int) {
    var pos = 0
    var done = 0
    while (done < n) {
        val count = minOf(WIDTH, n - done)
        repeat(count) {
            out.write(src[pos].code)
            if (++pos == src.length) pos = 0
        }
        out.write('\n'.code)
        done += WIDTH
    }
}

fun randomFasta(table: List<Pair<Char, Double>>, n: Int) {
    var total = 0.0
    val cumulative = DoubleArray(table.size) { total += table[it].second; total }
    var done = 0
    while (done < n) {
        val count = minOf(WIDTH, n - done)
        repeat(count) {
            val r = nextRandom()
            // Python's bisect: the first entry whose cumulative probability is greater than r.
            var k = 0
            while (k < cumulative.size - 1 && cumulative[k] <= r) k++
            out.write(table[k].first.code)
        }
        out.write('\n'.code)
        done += WIDTH
    }
}

fun main(args: Array<String>) {
    val n = if (args.isNotEmpty()) args[0].toInt() else 1000
    val iub = listOf('a' to 0.27, 'c' to 0.12, 'g' to 0.12, 't' to 0.27) +
        "BDHKMNRSVWY".map { it to 0.02 }
    val homoSapiens = listOf('a' to 0.3029549426680, 'c' to 0.1979883004921, 'g' to 0.1975473066391, 't' to 0.3015094502008)
    out.write(">ONE Homo sapiens alu\n".toByteArray())
    repeatFasta(ALU, n * 2)
    out.write(">TWO IUB ambiguity codes\n".toByteArray())
    randomFasta(iub, n * 3)
    out.write(">THREE Homo sapiens frequency\n".toByteArray())
    randomFasta(homoSapiens, n * 5)
    out.flush()
}
