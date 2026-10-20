<?php
// Sieve of Eratosthenes over a string of flag bytes.
function nsieve(int $n): void
{
    $flags = str_repeat("\1", $n);
    $count = 0;
    for ($i = 2; $i < $n; $i++) {
        if ($flags[$i] === "\1") {
            $count++;
            for ($j = $i << 1; $j < $n; $j += $i) {
                $flags[$j] = "\0";
            }
        }
    }
    printf("Primes up to %8d %8d\n", $n, $count);
}

$n = (int) ($argv[1] ?? 4);
for ($i = 0; $i < 3; $i++) {
    nsieve(10000 << ($n - $i));
}
