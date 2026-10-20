<?php
// Prime sieve as a chain of generators (PHP's coroutines): one source of 2, 3, 4, ... and one filter per prime.
function generate(): Generator
{
    for ($i = 2; ; $i++) {
        yield $i;
    }
}

function filter(Generator $source, int $prime): Generator
{
    for (; ; $source->next()) {
        $value = $source->current();
        if ($value % $prime != 0) {
            yield $value;
        }
    }
}

$n = (int) ($argv[1] ?? 100);
$chain = generate();
$out = '';
for ($i = 0; $i < $n; $i++) {
    $prime = $chain->current();
    $out .= "$prime\n";
    $chain = filter($chain, $prime);
}
echo $out;
