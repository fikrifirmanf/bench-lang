# Merkle trees as array refs [value, left, right, hash]; leaves carry the value 1.
use strict;
use warnings;
no warnings 'recursion';

sub make {
    my ($depth) = @_;
    return [1, undef, undef, undef] if $depth == 0;
    return [undef, make($depth - 1), make($depth - 1), undef];
}

sub get_hash { defined $_[0][3] ? $_[0][3] : -1 }

sub cal_hash {
    my ($node) = @_;
    return if defined $node->[3];
    if (defined $node->[0]) {
        $node->[3] = $node->[0];
    } elsif ($node->[1] && $node->[2]) {
        cal_hash($node->[1]);
        cal_hash($node->[2]);
        $node->[3] = get_hash($node->[1]) + get_hash($node->[2]);
    }
}

sub check {
    my ($node) = @_;
    return 0 unless defined $node->[3];
    return 1 if defined $node->[0];
    return $node->[1] && $node->[2] && check($node->[1]) && check($node->[2]);
}

my $n = shift || 6;
my $min_depth = 4;
my $max_depth = $n > $min_depth + 2 ? $n : $min_depth + 2;
my $stretch_depth = $max_depth + 1;

my $stretch = make($stretch_depth);
cal_hash($stretch);
printf "stretch tree of depth %d\t root hash: %d check: %s\n", $stretch_depth, get_hash($stretch),
    check($stretch) ? 'true' : 'false';
undef $stretch;

my $long_lived = make($max_depth);
for (my $depth = $min_depth; $depth <= $max_depth; $depth += 2) {
    my $iterations = 1 << ($max_depth - $depth + $min_depth);
    my $sum = 0;
    for (1 .. $iterations) {
        my $tree = make($depth);
        cal_hash($tree);
        $sum += get_hash($tree);
    }
    printf "%d\t trees of depth %d\t root hash sum: %d\n", $iterations, $depth, $sum;
}
cal_hash($long_lived);
printf "long lived tree of depth %d\t root hash: %d check: %s\n", $n, get_hash($long_lived),
    check($long_lived) ? 'true' : 'false';
