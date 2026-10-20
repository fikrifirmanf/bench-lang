<?php
// FASTA generator writing 60-character lines through one output buffer.
const WIDTH = 60;
const ALU = 'GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG'
    . 'GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA'
    . 'CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT'
    . 'ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA'
    . 'GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG'
    . 'AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC'
    . 'AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA';

$seed = 42;

function nextRandom(): float
{
    global $seed;
    $seed = ($seed * 3877 + 29573) % 139968;
    return $seed / 139968;
}

function repeatFasta(string $src, int $n): void
{
    $len = strlen($src);
    $doubled = $src . $src;
    $pos = 0;
    $out = '';
    for ($done = 0; $done < $n; $done += WIDTH) {
        $count = min(WIDTH, $n - $done);
        $line = '';
        while (strlen($line) < $count) {
            $take = min($count - strlen($line), $len - $pos);
            $line .= substr($doubled, $pos, $take);
            $pos = ($pos + $take) % $len;
        }
        $out .= $line . "\n";
        if (strlen($out) > 65536) {
            echo $out;
            $out = '';
        }
    }
    echo $out;
}

function randomFasta(array $table, int $n): void
{
    $symbols = array_keys($table);
    $cumulative = [];
    $total = 0.0;
    foreach ($table as $p) {
        $total += $p;
        $cumulative[] = $total;
    }
    $last = count($cumulative) - 1;
    $out = '';
    for ($done = 0; $done < $n; $done += WIDTH) {
        $count = min(WIDTH, $n - $done);
        $line = '';
        for ($i = 0; $i < $count; $i++) {
            $r = nextRandom();
            // Python's bisect: the first entry whose cumulative probability is greater than r.
            $k = 0;
            while ($k < $last && $cumulative[$k] <= $r) {
                $k++;
            }
            $line .= $symbols[$k];
        }
        $out .= $line . "\n";
        if (strlen($out) > 65536) {
            echo $out;
            $out = '';
        }
    }
    echo $out;
}

$n = (int) ($argv[1] ?? 1000);
$iub = ['a' => 0.27, 'c' => 0.12, 'g' => 0.12, 't' => 0.27];
foreach (str_split('BDHKMNRSVWY') as $c) {
    $iub[$c] = 0.02;
}
$homoSapiens = ['a' => 0.3029549426680, 'c' => 0.1979883004921, 'g' => 0.1975473066391, 't' => 0.3015094502008];
echo ">ONE Homo sapiens alu\n";
repeatFasta(ALU, $n * 2);
echo ">TWO IUB ambiguity codes\n";
randomFasta($iub, $n * 3);
echo ">THREE Homo sapiens frequency\n";
randomFasta($homoSapiens, $n * 5);
