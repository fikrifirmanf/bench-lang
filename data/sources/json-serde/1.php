<?php
// JSON round trip with json_decode/json_encode; objects stay stdClass so key order and {} survive.
// The flags make json_encode match Python's json.dumps: no escaped slashes, floats keep ".0".
ini_set('serialize_precision', '-1');
// 15 decoded copies of canada.json need far more than PHP's default 128 MB; the container caps memory instead.
ini_set('memory_limit', '-1');

function printHash($value): void
{
    echo md5(json_encode($value, JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION)), "\n";
}

$name = $argv[1] ?? 'sample';
$n = (int) ($argv[2] ?? 3);
$text = file_get_contents("$name.json");
if (str_starts_with($text, "\xEF\xBB\xBF")) {
    $text = substr($text, 3);
}
printHash(json_decode($text));
$array = [];
for ($i = 0; $i < $n; $i++) {
    $array[] = json_decode($text);
}
printHash($array);
