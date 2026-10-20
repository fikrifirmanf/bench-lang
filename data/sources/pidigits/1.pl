# Unbounded spigot for the digits of pi, with Math::GMP integers.
use strict;
use warnings;
use Math::GMP;

my $n = shift || 27;
my $acc = Math::GMP->new(0);
my $den = Math::GMP->new(1);
my $num = Math::GMP->new(1);
my ($i, $k, $line, $out) = (0, 0, '', '');
while ($i < $n) {
    $k++;
    my $k2 = $k * 2 + 1;
    $acc = ($acc + $num * 2) * $k2;
    $den = $den * $k2;
    $num = $num * $k;
    next if $num > $acc;
    my $d = ($num * 3 + $acc) / $den;
    next if $d != ($num * 4 + $acc) / $den;
    $line .= $d;
    if (++$i % 10 == 0) {
        $out .= "$line\t:$i\n";
        $line = '';
    }
    $acc = ($acc - $den * $d) * 10;
    $num = $num * 10;
}
$out .= sprintf("%-10s", $line) . "\t:$i\n" if length $line;
print $out;
