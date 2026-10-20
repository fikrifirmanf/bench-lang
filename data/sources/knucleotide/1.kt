// k-nucleotide: counts every k-mer of the THREE sequence in a HashMap keyed by 2-bit packed codes.
import java.io.File

fun codeOf(c: Char): Long = when (c) {
    'A' -> 0
    'C' -> 1
    'G' -> 2
    else -> 3
}

fun countKmers(seq: ByteArray, k: Int): HashMap<Long, Int> {
    val counts = HashMap<Long, Int>()
    val mask = (1L shl (2 * k)) - 1
    var key = 0L
    for (i in seq.indices) {
        key = ((key shl 2) or seq[i].toLong()) and mask
        if (i + 1 >= k) counts.merge(key, 1, Int::plus)
    }
    return counts
}

fun unpack(key: Long, k: Int): String {
    val chars = CharArray(k)
    var rest = key
    for (i in k - 1 downTo 0) {
        chars[i] = "ACGT"[(rest and 3).toInt()]
        rest = rest shr 2
    }
    return String(chars)
}

fun main(args: Array<String>) {
    val lines = File(if (args.isNotEmpty()) args[0] else "25000_in").readLines()
    val start = lines.indexOfFirst { it.startsWith(">THREE") } + 1
    val text = StringBuilder()
    for (i in start until lines.size) {
        if (lines[i].startsWith(">")) break
        text.append(lines[i].trim().uppercase())
    }
    val seq = ByteArray(text.length) { codeOf(text[it]).toByte() }

    val out = StringBuilder()
    for (k in 1..2) {
        val total = (seq.size - k + 1).toDouble()
        countKmers(seq, k).map { (key, count) -> unpack(key, k) to count }
            .sortedWith(compareByDescending<Pair<String, Int>> { it.second }.thenBy { it.first })
            .forEach { (kmer, count) -> out.append(kmer).append(' ').append("%.3f".format(count * 100.0 / total)).append('\n') }
        out.append('\n')
    }
    for (kmer in listOf("GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT")) {
        val key = kmer.fold(0L) { acc, c -> (acc shl 2) or codeOf(c) }
        out.append(countKmers(seq, kmer.length)[key] ?: 0).append('\t').append(kmer).append('\n')
    }
    print(out)
}
