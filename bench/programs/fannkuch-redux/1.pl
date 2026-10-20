# Single-threaded fannkuch-redux.
use strict;
use warnings;

my $n = shift || 7;
my @perm1 = (0 .. $n - 1);
my @count = (0) x $n;
my ($max_flips, $checksum, $perm_count) = (0, 0, 0);
my $r = $n;
OUTER: while (1) {
    while ($r != 1) {
        $count[$r - 1] = $r;
        $r--;
    }
    my @perm = @perm1;
    my $flips = 0;
    while ((my $k = $perm[0]) != 0) {
        @perm[0 .. $k] = reverse @perm[0 .. $k];
        $flips++;
    }
    $max_flips = $flips if $flips > $max_flips;
    $checksum += $perm_count % 2 == 0 ? $flips : -$flips;
    while (1) {
        last OUTER if $r == $n;
        my $first = shift @perm1;
        splice @perm1, $r, 0, $first;
        last if --$count[$r] > 0;
        $r++;
    }
    $perm_count++;
}
print "$checksum\nPfannkuchen($n) = $max_flips\n";
