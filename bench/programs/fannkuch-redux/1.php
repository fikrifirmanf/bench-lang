<?php
// Single-threaded fannkuch-redux.
function fannkuch(int $n): array
{
    $perm1 = range(0, $n - 1);
    $count = array_fill(0, $n, 0);
    $maxFlips = $checksum = $permCount = 0;
    $r = $n;
    while (true) {
        while ($r != 1) {
            $count[$r - 1] = $r;
            $r--;
        }
        $perm = $perm1;
        $flips = 0;
        while (($k = $perm[0]) != 0) {
            for ($i = 0, $j = $k; $i < $j; $i++, $j--) {
                $t = $perm[$i];
                $perm[$i] = $perm[$j];
                $perm[$j] = $t;
            }
            $flips++;
        }
        if ($flips > $maxFlips) {
            $maxFlips = $flips;
        }
        $checksum += $permCount % 2 == 0 ? $flips : -$flips;
        while (true) {
            if ($r == $n) {
                return [$checksum, $maxFlips];
            }
            $first = $perm1[0];
            for ($i = 0; $i < $r; $i++) {
                $perm1[$i] = $perm1[$i + 1];
            }
            $perm1[$r] = $first;
            if (--$count[$r] > 0) {
                break;
            }
            $r++;
        }
        $permCount++;
    }
}

$n = (int) ($argv[1] ?? 7);
[$checksum, $maxFlips] = fannkuch($n);
echo "$checksum\nPfannkuchen($n) = $maxFlips\n";
