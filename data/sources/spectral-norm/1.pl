# Spectral norm by power iteration on A^T A, single-threaded (the image's perl is built without threads,
# which 4.pl needs).
use strict;
use warnings;

my $n = shift || 100;

sub mult_av {
    my ($v) = @_;
    my @out;
    for my $i (0 .. $n - 1) {
        my $sum = 0;
        for my $j (0 .. $n - 1) {
            my $ij = $i + $j;
            $sum += $v->[$j] / ((($ij * ($ij + 1)) >> 1) + $i + 1);
        }
        push @out, $sum;
    }
    return \@out;
}

sub mult_atv {
    my ($v) = @_;
    my @out;
    for my $i (0 .. $n - 1) {
        my $sum = 0;
        for my $j (0 .. $n - 1) {
            my $ij = $i + $j;
            $sum += $v->[$j] / ((($ij * ($ij + 1)) >> 1) + $j + 1);
        }
        push @out, $sum;
    }
    return \@out;
}

my $u = [(1) x $n];
my $v;
for (1 .. 10) {
    $v = mult_atv(mult_av($u));
    $u = mult_atv(mult_av($v));
}
my ($vbv, $vv) = (0, 0);
for my $i (0 .. $n - 1) {
    $vbv += $u->[$i] * $v->[$i];
    $vv += $v->[$i] * $v->[$i];
}
printf "%.9f\n", sqrt($vbv / $vv);
