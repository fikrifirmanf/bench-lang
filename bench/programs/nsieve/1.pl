# Sieve of Eratosthenes over a bit string (vec).
use strict;
use warnings;

sub nsieve {
    my ($n) = @_;
    my $composite = '';
    vec($composite, $n, 1) = 0;
    my $count = 0;
    for my $i (2 .. $n - 1) {
        next if vec($composite, $i, 1);
        $count++;
        for (my $j = $i << 1; $j < $n; $j += $i) {
            vec($composite, $j, 1) = 1;
        }
    }
    printf "Primes up to %8d %8d\n", $n, $count;
}

my $n = shift || 4;
nsieve(10000 << ($n - $_)) for 0 .. 2;
