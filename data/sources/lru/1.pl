# LRU cache: a hash from key to node, nodes linked in recency order as array refs [key, value, prev, next].
use strict;
use warnings;

my $size = shift || 100;
my $n = shift || 1000;
my $mod = $size * 10;
my %index;
my ($head, $tail);

sub unlink_node {
    my ($node) = @_;
    if ($node->[2]) { $node->[2][3] = $node->[3] } else { $head = $node->[3] }
    if ($node->[3]) { $node->[3][2] = $node->[2] } else { $tail = $node->[2] }
}

sub push_back {
    my ($node) = @_;
    $node->[2] = $tail;
    $node->[3] = undef;
    if ($tail) { $tail->[3] = $node } else { $head = $node }
    $tail = $node;
}

sub lru_get {
    my $node = $index{$_[0]} or return undef;
    unlink_node($node);
    push_back($node);
    return $node->[1];
}

sub lru_put {
    my ($key, $value) = @_;
    if (my $node = $index{$key}) {
        unlink_node($node);
        $node->[1] = $value;
        push_back($node);
        return;
    }
    if (keys %index == $size) {
        my $oldest = $head;
        unlink_node($oldest);
        delete $index{$oldest->[0]};
    }
    my $node = [$key, $value, undef, undef];
    $index{$key} = $node;
    push_back($node);
}

my ($seed0, $seed1) = (0, 1);
my ($hit, $missed) = (0, 0);
for (1 .. $n) {
    $seed0 = (1103515245 * $seed0 + 12345) % 2147483648;
    my $n0 = $seed0 % $mod;
    lru_put($n0, $n0);
    $seed1 = (1103515245 * $seed1 + 12345) % 2147483648;
    my $n1 = $seed1 % $mod;
    if (defined lru_get($n1)) { $hit++ } else { $missed++ }
}
print "$hit\n$missed\n";
