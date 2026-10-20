# secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on Math::GMP integers.
use strict;
use warnings;
use Math::GMP;

sub big { Math::GMP->new(@_) }
my $P = big('fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f', 16);
my $N = big('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141', 16);
my $BETA = big('7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee', 16);
my $POW_2_128 = big(2)**128;
my $A1 = big('3086d221a7d46bcde86c90e49284eb15', 16);
my $B1 = -big('e4437ed6010e88286f547fa90abfe4c3', 16);
my $A2 = big('114ca50f7a8e2f3f657c1108d9d44cfd8', 16);
my ($ZERO, $ONE) = (big(0), big(1));

sub md {
    my ($a, $m) = @_;
    $m //= $P;
    my $r = $a % $m;
    return $r < 0 ? $r + $m : $r;
}

sub zero { [$ZERO, $ONE, $ZERO] }

sub double {
    my ($x, $y, $z) = @{ $_[0] };
    my $a = md($x * $x);
    my $b = md($y * $y);
    my $c = md($b * $b);
    my $xb = $x + $b;
    my $d = md(2 * (md($xb * $xb) - $a - $c));
    my $e = md(3 * $a);
    my $f = md($e * $e);
    my $x3 = md($f - 2 * $d);
    my $y3 = md($e * ($d - $x3) - 8 * $c);
    my $z3 = md(2 * $y * $z);
    return [$x3, $y3, $z3];
}

sub add {
    my ($p, $o) = @_;
    my ($x1, $y1, $z1) = @$p;
    my ($x2, $y2, $z2) = @$o;
    return $p if $x2 == 0 || $y2 == 0;
    return $o if $x1 == 0 || $y1 == 0;
    my $z1z1 = md($z1 * $z1);
    my $z2z2 = md($z2 * $z2);
    my $u1 = md($x1 * $z2z2);
    my $u2 = md($x2 * $z1z1);
    my $s1 = md($y1 * $z2 * $z2z2);
    my $s2 = md(md($y2 * $z1) * $z1z1);
    my $h = md($u2 - $u1);
    my $r = md($s2 - $s1);
    if ($h == 0) {
        return $r == 0 ? double($p) : zero();
    }
    my $hh = md($h * $h);
    my $hhh = md($h * $hh);
    my $v = md($u1 * $hh);
    my $x3 = md($r * $r - $hhh - 2 * $v);
    my $y3 = md($r * ($v - $x3) - $s1 * $hhh);
    my $z3 = md($z1 * $z2 * $h);
    return [$x3, $y3, $z3];
}

# (a + b / 2) / b; every caller passes non-negative values, so truncation is floor division.
sub div_nearest { my ($a, $b) = @_; ($a + $b / 2) / $b }

sub multiply {
    my ($point, $k) = @_;
    my $b2 = $A1;
    my $c1 = div_nearest($b2 * $k, $N);
    my $c2 = div_nearest(-$B1 * $k, $N);
    my $k1 = md($k - $c1 * $A1 - $c2 * $A2, $N);
    my $k2 = md(-$c1 * $B1 - $c2 * $b2, $N);
    my $k1neg = $k1 > $POW_2_128;
    my $k2neg = $k2 > $POW_2_128;
    $k1 = $N - $k1 if $k1neg;
    $k2 = $N - $k2 if $k2neg;
    my ($k1p, $k2p, $d) = (zero(), zero(), $point);
    while ($k1 > 0 || $k2 > 0) {
        $k1p = add($k1p, $d) if $k1 % 2 == 1;
        $k2p = add($k2p, $d) if $k2 % 2 == 1;
        $d = double($d);
        $k1 = $k1 / 2;
        $k2 = $k2 / 2;
    }
    $k1p = [$k1p->[0], md(-$k1p->[1]), $k1p->[2]] if $k1neg;
    $k2p = [$k2p->[0], md(-$k2p->[1]), $k2p->[2]] if $k2neg;
    $k2p = [md($k2p->[0] * $BETA), $k2p->[1], $k2p->[2]];
    return add($k1p, $k2p);
}

# Inverse modulo P by the extended Euclidean algorithm.
sub invert {
    my ($number) = @_;
    my ($a, $b) = (md($number), $P);
    my ($x, $y, $u, $v) = ($ZERO, $ONE, $ONE, $ZERO);
    while ($a != 0) {
        my $q = $b / $a;
        my $r = $b % $a;
        my $m = $x - $u * $q;
        my $n = $y - $v * $q;
        ($b, $a) = ($a, $r);
        ($x, $y) = ($u, $v);
        ($u, $v) = ($m, $n);
    }
    return md($x);
}

my $count = shift || 1;
my $key = big('2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693', 16);
my $x = big('55066263022277343669578718895168534326250603453777594175500187360389116729240');
my $y = big('32670510020758816978083085130507043184471273380659243275938904335757337482424');
for (1 .. $count) {
    my $j = multiply([$x, $y, $ONE], $key);
    my $inv = invert($j->[2]);
    my $inv2 = md($inv * $inv);
    $x = md($j->[0] * $inv2);
    $y = md($j->[1] * $inv * $inv2);
}
print lc($x->get_str_gmp(16)), ',', lc($y->get_str_gmp(16)), "\n";
