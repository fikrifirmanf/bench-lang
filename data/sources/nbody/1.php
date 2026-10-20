<?php
// n-body with the bodies' coordinates, velocities and masses in parallel arrays.
const PI = 3.14159265358979323;
const SOLAR_MASS = 4 * PI * PI;
const DAYS_PER_YEAR = 365.24;

$bodies = [
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, SOLAR_MASS],
    [4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
        1.66007664274403694e-03 * DAYS_PER_YEAR, 7.69901118419740425e-03 * DAYS_PER_YEAR,
        -6.90460016972063023e-05 * DAYS_PER_YEAR, 9.54791938424326609e-04 * SOLAR_MASS],
    [8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
        -2.76742510726862411e-03 * DAYS_PER_YEAR, 4.99852801234917238e-03 * DAYS_PER_YEAR,
        2.30417297573763929e-05 * DAYS_PER_YEAR, 2.85885980666130812e-04 * SOLAR_MASS],
    [1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
        2.96460137564761618e-03 * DAYS_PER_YEAR, 2.37847173959480950e-03 * DAYS_PER_YEAR,
        -2.96589568540237556e-05 * DAYS_PER_YEAR, 4.36624404335156298e-05 * SOLAR_MASS],
    [1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
        2.68067772490389322e-03 * DAYS_PER_YEAR, 1.62824170038242295e-03 * DAYS_PER_YEAR,
        -9.51592254519715870e-05 * DAYS_PER_YEAR, 5.15138902046611451e-05 * SOLAR_MASS],
];
[$x, $y, $z, $vx, $vy, $vz, $m] = array_map(null, ...$bodies);

// Potential energy over every pair first, then kinetic energy, in the reference's order.
function energy(array $x, array $y, array $z, array $vx, array $vy, array $vz, array $m): float
{
    $e = 0.0;
    for ($i = 0; $i < 5; $i++) {
        for ($j = $i + 1; $j < 5; $j++) {
            $dx = $x[$i] - $x[$j];
            $dy = $y[$i] - $y[$j];
            $dz = $z[$i] - $z[$j];
            $e -= ($m[$i] * $m[$j]) / sqrt($dx * $dx + $dy * $dy + $dz * $dz);
        }
    }
    for ($i = 0; $i < 5; $i++) {
        $e += $m[$i] * ($vx[$i] * $vx[$i] + $vy[$i] * $vy[$i] + $vz[$i] * $vz[$i]) / 2.0;
    }
    return $e;
}

$px = $py = $pz = 0.0;
for ($i = 0; $i < 5; $i++) {
    $px -= $vx[$i] * $m[$i];
    $py -= $vy[$i] * $m[$i];
    $pz -= $vz[$i] * $m[$i];
}
$vx[0] = $px / $m[0];
$vy[0] = $py / $m[0];
$vz[0] = $pz / $m[0];

printf("%.9f\n", energy($x, $y, $z, $vx, $vy, $vz, $m));
$n = (int) ($argv[1] ?? 1000);
$dt = 0.01;
for ($step = 0; $step < $n; $step++) {
    for ($i = 0; $i < 5; $i++) {
        for ($j = $i + 1; $j < 5; $j++) {
            $dx = $x[$i] - $x[$j];
            $dy = $y[$i] - $y[$j];
            $dz = $z[$i] - $z[$j];
            $d2 = $dx * $dx + $dy * $dy + $dz * $dz;
            $mag = $dt / ($d2 * sqrt($d2));
            $mi = $m[$i] * $mag;
            $mj = $m[$j] * $mag;
            $vx[$i] -= $dx * $mj;
            $vy[$i] -= $dy * $mj;
            $vz[$i] -= $dz * $mj;
            $vx[$j] += $dx * $mi;
            $vy[$j] += $dy * $mi;
            $vz[$j] += $dz * $mi;
        }
    }
    for ($i = 0; $i < 5; $i++) {
        $x[$i] += $dt * $vx[$i];
        $y[$i] += $dt * $vy[$i];
        $z[$i] += $dt * $vz[$i];
    }
}
printf("%.9f\n", energy($x, $y, $z, $vx, $vy, $vz, $m));
