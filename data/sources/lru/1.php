<?php
// LRU cache: PHP arrays keep insertion order, so moving a key to the end is unset + re-insert,
// and the least recently used key is the first one.
final class Lru
{
    private array $entries = [];

    public function __construct(private int $size)
    {
    }

    public function get(int $key): ?int
    {
        if (!array_key_exists($key, $this->entries)) {
            return null;
        }
        $value = $this->entries[$key];
        unset($this->entries[$key]);
        $this->entries[$key] = $value;
        return $value;
    }

    public function put(int $key, int $value): void
    {
        if (array_key_exists($key, $this->entries)) {
            unset($this->entries[$key]);
        } elseif (count($this->entries) == $this->size) {
            unset($this->entries[array_key_first($this->entries)]);
        }
        $this->entries[$key] = $value;
    }
}

$size = (int) ($argv[1] ?? 100);
$n = (int) ($argv[2] ?? 1000);
$mod = $size * 10;
$seed0 = 0;
$seed1 = 1;
$lru = new Lru($size);
$hit = $missed = 0;
for ($i = 0; $i < $n; $i++) {
    $seed0 = (1103515245 * $seed0 + 12345) % 2147483648;
    $n0 = $seed0 % $mod;
    $lru->put($n0, $n0);
    $seed1 = (1103515245 * $seed1 + 12345) % 2147483648;
    $n1 = $seed1 % $mod;
    if ($lru->get($n1) === null) {
        $missed++;
    } else {
        $hit++;
    }
}
echo "$hit\n$missed\n";
