# Prime sieve as a chain of generator closures (core Perl has no coroutines): a source of 2, 3, 4, ...
# and one filter per prime found, each pulling the next value from the one before it.
use strict;
use warnings;

my $n = shift || 100;
my $i = 1;
my $chain = sub { ++$i };
my $out = '';
for (1 .. $n) {
    my $prime = $chain->();
    $out .= "$prime\n";
    my $source = $chain;
    $chain = sub {
        while (1) {
            my $value = $source->();
            return $value if $value % $prime;
        }
    };
}
print $out;
