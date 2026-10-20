# regex-redux with Perl's own regex engine.
use strict;
use warnings;

my $file_name = shift || '25000_in';
open my $fh, '<', $file_name or die "$file_name: $!";
my $input = do { local $/; <$fh> };
(my $seq = $input) =~ s/>.*\n|\n//g;

my @variants = qw(
    agggtaaa|tttaccct [cgt]gggtaaa|tttaccc[acg] a[act]ggtaaa|tttacc[agt]t
    ag[act]gtaaa|tttac[agt]ct agg[act]taaa|ttta[agt]cct aggg[acg]aaa|ttt[cgt]ccct
    agggt[cgt]aa|tt[acg]accct agggta[cgt]a|t[acg]taccct agggtaa[cgt]|[acg]ttaccct
);
my $out = '';
for my $variant (@variants) {
    my $count = () = $seq =~ /$variant/g;
    $out .= "$variant $count\n";
}

my @substitutions = (
    [qr/tHa[Nt]/, '<4>'], [qr/aND|caN|Ha[DS]|WaS/, '<3>'], [qr/a[NSt]|BY/, '<2>'],
    [qr/<[^>]*>/, '|'], [qr/\|[^|][^|]*\|/, '-'],
);
my $replaced = $seq;
$replaced =~ s/$_->[0]/$_->[1]/g for @substitutions;
print $out, "\n", length($input), "\n", length($seq), "\n", length($replaced), "\n";
