# k-nucleotide: counts every k-mer of the THREE sequence with substr into a hash.
use strict;
use warnings;

my $file_name = shift || '25000_in';
open my $fh, '<', $file_name or die "$file_name: $!";
while (<$fh>) { last if /^>THREE/ }
my $seq = '';
while (<$fh>) {
    last if /^>/;
    chomp;
    $seq .= uc $_;
}
$seq =~ s/\s//g;

sub count_kmers {
    my ($k) = @_;
    my %counts;
    my $last = length($seq) - $k;
    $counts{substr($seq, $_, $k)}++ for 0 .. $last;
    return \%counts;
}

my $out = '';
for my $k (1, 2) {
    my $counts = count_kmers($k);
    my $total = length($seq) - $k + 1;
    for my $kmer (sort { $counts->{$b} <=> $counts->{$a} || $a cmp $b } keys %$counts) {
        $out .= sprintf "%s %.3f\n", $kmer, $counts->{$kmer} * 100 / $total;
    }
    $out .= "\n";
}
for my $kmer (qw(GGT GGTA GGTATT GGTATTTTAATT GGTATTTTAATTTATAGT)) {
    $out .= (count_kmers(length $kmer)->{$kmer} || 0) . "\t$kmer\n";
}
print $out;
