<?php
// k-nucleotide: counts every k-mer of the THREE sequence with substr into a PHP array (a hash table).
function readSequence(string $fileName): string
{
    $text = file_get_contents($fileName);
    $start = strpos($text, "\n", strpos($text, '>THREE')) + 1;
    $end = strpos($text, '>', $start);
    $section = $end === false ? substr($text, $start) : substr($text, $start, $end - $start);
    return strtoupper(str_replace(["\n", "\r", ' ', "\t"], '', $section));
}

function countKmers(string $seq, int $k): array
{
    $counts = [];
    $last = strlen($seq) - $k;
    for ($i = 0; $i <= $last; $i++) {
        $kmer = substr($seq, $i, $k);
        $counts[$kmer] = ($counts[$kmer] ?? 0) + 1;
    }
    return $counts;
}

$seq = readSequence($argv[1] ?? '25000_in');
$out = '';
foreach ([1, 2] as $k) {
    $counts = countKmers($seq, $k);
    $total = strlen($seq) - $k + 1;
    $kmers = array_map('strval', array_keys($counts));
    usort($kmers, fn($a, $b) => $counts[$b] <=> $counts[$a] ?: strcmp($a, $b));
    foreach ($kmers as $kmer) {
        $out .= sprintf("%s %.3f\n", $kmer, $counts[$kmer] * 100 / $total);
    }
    $out .= "\n";
}
foreach (['GGT', 'GGTA', 'GGTATT', 'GGTATTTTAATT', 'GGTATTTTAATTTATAGT'] as $kmer) {
    $out .= (countKmers($seq, strlen($kmer))[$kmer] ?? 0) . "\t$kmer\n";
}
echo $out;
