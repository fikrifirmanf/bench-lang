# Digits of e by binary splitting of sum(1/k!), with Math::GMP integers.
use strict;
use warnings;
no warnings 'recursion';
use Math::GMP;

sub sum_terms {
    my ($a, $b) = @_;
    return (Math::GMP->new(1), Math::GMP->new($b)) if $b == $a + 1;
    my $mid = int(($a + $b) / 2);
    my ($p_left, $q_left) = sum_terms($a, $mid);
    my ($p_right, $q_right) = sum_terms($mid, $b);
    return ($p_left * $q_right + $p_right, $q_left * $q_right);
}

sub test_k {
    my ($n, $k) = @_;
    return 0 if $k <= 0;
    my $ln_k_factorial = $k * (log($k) - 1) + 0.5 * log(2 * 3.141592653589793);
    return $ln_k_factorial / log(10) >= $n + 50;
}

sub binary_search {
    my ($n) = @_;
    my ($a, $b) = (0, 1);
    until (test_k($n, $b)) {
        $a = $b;
        $b *= 2;
    }
    while ($b - $a > 1) {
        my $m = int(($a + $b) / 2);
        if (test_k($n, $m)) { $b = $m } else { $a = $m }
    }
    return $b;
}

my $n = shift || 27;
my ($p, $q) = sum_terms(0, binary_search($n) - 1);
my $s = "" . (($p + $q) * Math::GMP->new(10)**($n - 1) / $q);
my $out = '';
for (my $i = 0; $i < $n; $i += 10) {
    if ($i + 10 <= $n) {
        $out .= substr($s, $i, 10) . "\t:" . ($i + 10) . "\n";
    } else {
        $out .= sprintf("%-10s", substr($s, $i, $n - $i)) . "\t:$n\n";
    }
}
print $out;
