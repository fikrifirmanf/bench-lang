# JSON round trip with a regex-driven parser that keeps key order (Perl hashes do not, and JSON::PP decodes
# into hashes): serialize exactly as Python's json.dumps(separators=(',', ':')) does, then print the MD5.
use strict;
use warnings;
no warnings 'recursion';
use Digest::MD5 qw(md5_hex);

# Values: [ 'n' ] null, [ 'b', 0|1 ], [ 'i', text ], [ 'f', number ], [ 's', string ], [ 'a', \@items ],
# [ 'o', \@key_value_pairs ].
sub parse_value {
    my ($text) = @_;
    $$text =~ /\G\s*/gc;
    if ($$text =~ /\G\{/gc) {
        my @pairs;
        $$text =~ /\G\s*/gc;
        return ['o', \@pairs] if $$text =~ /\G\}/gc;
        while (1) {
            $$text =~ /\G\s*/gc;
            my $key = parse_string($text);
            $$text =~ /\G\s*:/gc;
            push @pairs, $key, parse_value($text);
            $$text =~ /\G\s*/gc;
            return ['o', \@pairs] if $$text =~ /\G\}/gc;
            $$text =~ /\G,/gc;
        }
    }
    if ($$text =~ /\G\[/gc) {
        my @items;
        $$text =~ /\G\s*/gc;
        return ['a', \@items] if $$text =~ /\G\]/gc;
        while (1) {
            push @items, parse_value($text);
            $$text =~ /\G\s*/gc;
            return ['a', \@items] if $$text =~ /\G\]/gc;
            $$text =~ /\G,/gc;
        }
    }
    # A look-ahead here would be a second empty match at the same position, which //g refuses.
    return ['s', parse_string($text)] if substr($$text, pos($$text), 1) eq '"';
    return ['b', 1] if $$text =~ /\Gtrue/gc;
    return ['b', 0] if $$text =~ /\Gfalse/gc;
    return ['n'] if $$text =~ /\Gnull/gc;
    $$text =~ /\G(-?\d+)(\.\d+)?([eE][-+]?\d+)?/gc or die 'bad JSON at ' . pos($$text);
    return defined $2 || defined $3 ? ['f', 0 + ($1 . ($2 // '') . ($3 // ''))] : ['i', $1];
}

my %unescape = ('b' => "\b", 'f' => "\f", 'n' => "\n", 'r' => "\r", 't' => "\t", '"' => '"', '\\' => '\\', '/' => '/');

sub parse_string {
    my ($text) = @_;
    $$text =~ /\G"((?:[^"\\]|\\.)*)"/gcs or die 'bad string at ' . pos($$text);
    my $s = $1;
    return $s unless index($s, '\\') >= 0;
    utf8::decode($s);
    $s =~ s/\\u([dD][89abAB][0-9a-fA-F]{2})\\u([dD][c-fC-F][0-9a-fA-F]{2})/chr(0x10000 + ((hex($1) - 0xd800) << 10) + (hex($2) - 0xdc00))/ge;
    $s =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;
    $s =~ s/\\(.)/$unescape{$1}/g;
    utf8::encode($s);
    return $s;
}

# Python's repr(float): the fewest significant digits that read back as the same number, positional
# for 1e-4 <= |x| < 1e16.
sub format_float {
    my ($x) = @_;
    my ($low, $high) = (1, 17);
    while ($low < $high) {
        my $mid = int(($low + $high) / 2);
        if (sprintf('%.*e', $mid - 1, $x) == $x) { $high = $mid } else { $low = $mid + 1 }
    }
    my ($mantissa, $exponent) = sprintf('%.*e', $low - 1, abs $x) =~ /^([\d.]+)e([-+]\d+)$/;
    (my $digits = $mantissa) =~ tr/.//d;
    $digits =~ s/(?<=.)0+$//;
    $exponent += 0;
    my $sign = $x < 0 || ($x == 0 && sprintf('%g', $x) =~ /^-/) ? '-' : '';
    if ($exponent >= -4 && $exponent < 16) {
        return $sign . '0.' . ('0' x (-$exponent - 1)) . $digits if $exponent < 0;
        return $sign . substr($digits, 0, $exponent + 1) . '.' . substr($digits, $exponent + 1)
            if length($digits) > $exponent + 1;
        return $sign . $digits . ('0' x ($exponent + 1 - length $digits)) . '.0';
    }
    my $tail = length($digits) > 1 ? '.' . substr($digits, 1) : '';
    return sprintf('%s%s%se%s%02d', $sign, substr($digits, 0, 1), $tail, $exponent < 0 ? '-' : '+', abs $exponent);
}

my %escape = ('"' => '\\"', '\\' => '\\\\', "\n" => '\\n', "\r" => '\\r', "\t" => '\\t', "\b" => '\\b', "\f" => '\\f');

sub dump_string {
    my ($s) = @_;
    return qq("$s") unless $s =~ /[^\x20-\x21\x23-\x5b\x5d-\x7e]/;
    utf8::decode($s);
    $s =~ s/(["\\\n\r\t\b\f])/$escape{$1}/g;
    $s =~ s/([^\x00-\x7f])/ord($1) > 0xffff
        ? sprintf('\\u%04x\\u%04x', 0xd800 + ((ord($1) - 0x10000) >> 10), 0xdc00 + ((ord($1) - 0x10000) & 0x3ff))
        : sprintf('\\u%04x', ord($1))/ge;
    $s =~ s/([\x00-\x1f])/sprintf('\\u%04x', ord($1))/ge;
    return qq("$s");
}

sub dump_value {
    my ($v) = @_;
    my $kind = $v->[0];
    return $v->[1] if $kind eq 'i';
    return format_float($v->[1]) if $kind eq 'f';
    return dump_string($v->[1]) if $kind eq 's';
    return '[' . join(',', map { dump_value($_) } @{ $v->[1] }) . ']' if $kind eq 'a';
    if ($kind eq 'o') {
        my $pairs = $v->[1];
        return '{' . join(',', map { dump_string($pairs->[2 * $_]) . ':' . dump_value($pairs->[2 * $_ + 1]) }
                0 .. $#$pairs / 2) . '}';
    }
    return $v->[1] ? 'true' : 'false' if $kind eq 'b';
    return 'null';
}

my $name = shift || 'sample';
my $n = shift || 3;
open my $fh, '<:raw', "$name.json" or die "$name.json: $!";
my $json = do { local $/; <$fh> };
$json =~ s/^\xef\xbb\xbf//;

print md5_hex(dump_value(parse_value(\$json))), "\n";
my @items;
for (1 .. $n) {
    pos($json) = 0;
    push @items, parse_value(\$json);
}
print md5_hex(dump_value(['a', \@items])), "\n";
