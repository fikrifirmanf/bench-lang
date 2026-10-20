<?php
// Scalar mandelbrot: 50 iterations per pixel, then the MD5 of the packed bitmap.
$size = (int) ($argv[1] ?? 200);
$size = intdiv($size + 7, 8) * 8;
$rowBytes = intdiv($size, 8);
$inv = 2.0 / $size;
$xs = [];
for ($i = 0; $i < $size; $i++) {
    $xs[$i] = $i * $inv - 1.5;
}
$context = hash_init('md5');
for ($y = 0; $y < $size; $y++) {
    $ci = $y * $inv - 1.0;
    $row = '';
    for ($byte = 0; $byte < $rowBytes; $byte++) {
        $bits = 0;
        for ($k = 0; $k < 8; $k++) {
            $cr = $xs[$byte * 8 + $k];
            $zr = $zi = $tr = $ti = 0.0;
            $escaped = false;
            for ($i = 0; $i < 50; $i++) {
                $zi = ($zr + $zr) * $zi + $ci;
                $zr = $tr - $ti + $cr;
                $tr = $zr * $zr;
                $ti = $zi * $zi;
                if ($tr + $ti > 4.0) {
                    $escaped = true;
                    break;
                }
            }
            if (!$escaped) {
                $bits |= 0x80 >> $k;
            }
        }
        $row .= chr($bits);
    }
    hash_update($context, $row);
}
echo "P4\n$size $size\n" . hash_final($context) . "\n";
