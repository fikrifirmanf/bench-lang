<?php
// regex-redux with PHP's PCRE functions (PCRE2 with JIT).
ini_set('pcre.jit', '1');
// Several 25 MB strings exceed PHP's default 128 MB; the container caps memory instead.
ini_set('memory_limit', '-1');
ini_set('pcre.backtrack_limit', '100000000');
$input = file_get_contents($argv[1] ?? '25000_in');
$seq = preg_replace('/>.*\n|\n/', '', $input);

$variants = [
    'agggtaaa|tttaccct', '[cgt]gggtaaa|tttaccc[acg]', 'a[act]ggtaaa|tttacc[agt]t',
    'ag[act]gtaaa|tttac[agt]ct', 'agg[act]taaa|ttta[agt]cct', 'aggg[acg]aaa|ttt[cgt]ccct',
    'agggt[cgt]aa|tt[acg]accct', 'agggta[cgt]a|t[acg]taccct', 'agggtaa[cgt]|[acg]ttaccct',
];
$out = '';
foreach ($variants as $variant) {
    $out .= $variant . ' ' . preg_match_all("/$variant/", $seq) . "\n";
}

$substitutions = [
    '/tHa[Nt]/' => '<4>', '/aND|caN|Ha[DS]|WaS/' => '<3>', '/a[NSt]|BY/' => '<2>',
    '/<[^>]*>/' => '|', '/\|[^|][^|]*\|/' => '-',
];
$replaced = $seq;
foreach ($substitutions as $pattern => $replacement) {
    $replaced = preg_replace($pattern, $replacement, $replaced);
}
echo $out, "\n", strlen($input), "\n", strlen($seq), "\n", strlen($replaced), "\n";
