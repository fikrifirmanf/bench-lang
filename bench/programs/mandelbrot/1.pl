# Scalar mandelbrot: 50 iterations per pixel, then the MD5 of the packed bitmap.
use strict;
use warnings;
use Digest::MD5;

my $size = shift || 200;
$size = int(($size + 7) / 8) * 8;
my $inv = 2.0 / $size;
my @xs = map { $_ * $inv - 1.5 } 0 .. $size - 1;
my $md5 = Digest::MD5->new;
for my $y (0 .. $size - 1) {
    my $ci = $y * $inv - 1.0;
    my $row = '';
    for my $byte (0 .. $size / 8 - 1) {
        my $bits = 0;
        for my $k (0 .. 7) {
            my $cr = $xs[$byte * 8 + $k];
            my ($zr, $zi, $tr, $ti) = (0.0, 0.0, 0.0, 0.0);
            my $escaped = 0;
            for (1 .. 50) {
                $zi = ($zr + $zr) * $zi + $ci;
                $zr = $tr - $ti + $cr;
                $tr = $zr * $zr;
                $ti = $zi * $zi;
                if ($tr + $ti > 4.0) {
                    $escaped = 1;
                    last;
                }
            }
            $bits |= 0x80 >> $k unless $escaped;
        }
        $row .= chr($bits);
    }
    $md5->add($row);
}
print "P4\n$size $size\n", $md5->hexdigest, "\n";
