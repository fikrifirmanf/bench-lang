<?php
// Digits of e by binary splitting of sum(1/k!), with the GMP extension.
function sumTerms(int $a, int $b): array
{
    if ($b == $a + 1) {
        return [gmp_init(1), gmp_init($b)];
    }
    $mid = intdiv($a + $b, 2);
    [$pLeft, $qLeft] = sumTerms($a, $mid);
    [$pRight, $qRight] = sumTerms($mid, $b);
    return [$pLeft * $qRight + $pRight, $qLeft * $qRight];
}

function testK(int $n, int $k): bool
{
    if ($k <= 0) {
        return false;
    }
    $lnKFactorial = $k * (log($k) - 1) + 0.5 * log(2 * M_PI);
    return $lnKFactorial / log(10) >= $n + 50;
}

function binarySearch(int $n): int
{
    $a = 0;
    $b = 1;
    while (!testK($n, $b)) {
        $a = $b;
        $b *= 2;
    }
    while ($b - $a > 1) {
        $m = intdiv($a + $b, 2);
        if (testK($n, $m)) {
            $b = $m;
        } else {
            $a = $m;
        }
    }
    return $b;
}

$n = (int) ($argv[1] ?? 27);
[$p, $q] = sumTerms(0, binarySearch($n) - 1);
$s = gmp_strval(gmp_div_q(($p + $q) * gmp_pow(10, $n - 1), $q));
$out = '';
for ($i = 0; $i < $n; $i += 10) {
    if ($i + 10 <= $n) {
        $out .= substr($s, $i, 10) . "\t:" . ($i + 10) . "\n";
    } else {
        $out .= str_pad(substr($s, $i, $n - $i), 10) . "\t:$n\n";
    }
}
echo $out;
