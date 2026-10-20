<?php
// Spectral norm by power iteration on A^T A.
function multAv(array $v, int $n): array
{
    $out = [];
    for ($i = 0; $i < $n; $i++) {
        $sum = 0.0;
        for ($j = 0; $j < $n; $j++) {
            $ij = $i + $j;
            $sum += $v[$j] / (($ij * ($ij + 1) >> 1) + $i + 1);
        }
        $out[$i] = $sum;
    }
    return $out;
}

function multAtv(array $v, int $n): array
{
    $out = [];
    for ($i = 0; $i < $n; $i++) {
        $sum = 0.0;
        for ($j = 0; $j < $n; $j++) {
            $ij = $i + $j;
            $sum += $v[$j] / (($ij * ($ij + 1) >> 1) + $j + 1);
        }
        $out[$i] = $sum;
    }
    return $out;
}

$n = (int) ($argv[1] ?? 100);
$u = array_fill(0, $n, 1.0);
for ($i = 0; $i < 10; $i++) {
    $v = multAtv(multAv($u, $n), $n);
    $u = multAtv(multAv($v, $n), $n);
}
$vbv = $vv = 0.0;
for ($i = 0; $i < $n; $i++) {
    $vbv += $u[$i] * $v[$i];
    $vv += $v[$i] * $v[$i];
}
printf("%.9f\n", sqrt($vbv / $vv));
