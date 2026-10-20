<?php
// Unbounded spigot for the digits of pi, with the GMP extension.
$n = (int) ($argv[1] ?? 27);
$acc = gmp_init(0);
$den = gmp_init(1);
$num = gmp_init(1);
$out = '';
$line = '';
for ($i = 0, $k = 1; $i < $n; $k++) {
    $k2 = $k * 2 + 1;
    $acc = ($acc + $num * 2) * $k2;
    $den *= $k2;
    $num *= $k;
    if ($num > $acc) {
        continue;
    }
    $d = gmp_intval(gmp_div_q($num * 3 + $acc, $den));
    if ($d != gmp_intval(gmp_div_q($num * 4 + $acc, $den))) {
        continue;
    }
    $line .= $d;
    if (++$i % 10 == 0) {
        $out .= "$line\t:$i\n";
        $line = '';
    }
    $acc = ($acc - $den * $d) * 10;
    $num *= 10;
}
if ($line !== '') {
    $out .= str_pad($line, 10) . "\t:$i\n";
}
echo $out;
