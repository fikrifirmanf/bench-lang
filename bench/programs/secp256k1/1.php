<?php
// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, with the GMP extension.
$P = gmp_init('fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f', 16);
$N = gmp_init('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141', 16);
$BETA = gmp_init('7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee', 16);
$POW_2_128 = gmp_pow(2, 128);

// gmp_mod always returns a non-negative result.
function md(GMP $a, ?GMP $m = null): GMP
{
    global $P;
    return gmp_mod($a, $m ?? $P);
}

final class Jacobian
{
    public function __construct(public GMP $x, public GMP $y, public GMP $z)
    {
    }

    public static function zero(): self
    {
        return new self(gmp_init(0), gmp_init(1), gmp_init(0));
    }

    public function double(): self
    {
        $a = md($this->x * $this->x);
        $b = md($this->y * $this->y);
        $c = md($b * $b);
        $xb = $this->x + $b;
        $d = md(2 * (md($xb * $xb) - $a - $c));
        $e = md(3 * $a);
        $f = md($e * $e);
        $x3 = md($f - 2 * $d);
        $y3 = md($e * ($d - $x3) - 8 * $c);
        $z3 = md(2 * $this->y * $this->z);
        return new self($x3, $y3, $z3);
    }

    public function add(self $o): self
    {
        if ($o->x == 0 || $o->y == 0) {
            return $this;
        }
        if ($this->x == 0 || $this->y == 0) {
            return $o;
        }
        $z1z1 = md($this->z * $this->z);
        $z2z2 = md($o->z * $o->z);
        $u1 = md($this->x * $z2z2);
        $u2 = md($o->x * $z1z1);
        $s1 = md($this->y * $o->z * $z2z2);
        $s2 = md(md($o->y * $this->z) * $z1z1);
        $h = md($u2 - $u1);
        $r = md($s2 - $s1);
        if ($h == 0) {
            return $r == 0 ? $this->double() : self::zero();
        }
        $hh = md($h * $h);
        $hhh = md($h * $hh);
        $v = md($u1 * $hh);
        $x3 = md($r * $r - $hhh - 2 * $v);
        $y3 = md($r * ($v - $x3) - $s1 * $hhh);
        $z3 = md($this->z * $o->z * $h);
        return new self($x3, $y3, $z3);
    }

    public function multiply(GMP $k): self
    {
        global $N, $BETA, $POW_2_128;
        $a1 = gmp_init('3086d221a7d46bcde86c90e49284eb15', 16);
        $b1 = -gmp_init('e4437ed6010e88286f547fa90abfe4c3', 16);
        $a2 = gmp_init('114ca50f7a8e2f3f657c1108d9d44cfd8', 16);
        $b2 = $a1;
        $c1 = divNearest($b2 * $k, $N);
        $c2 = divNearest(-$b1 * $k, $N);
        $k1 = md($k - $c1 * $a1 - $c2 * $a2, $N);
        $k2 = md(-$c1 * $b1 - $c2 * $b2, $N);
        $k1neg = $k1 > $POW_2_128;
        $k2neg = $k2 > $POW_2_128;
        if ($k1neg) {
            $k1 = $N - $k1;
        }
        if ($k2neg) {
            $k2 = $N - $k2;
        }
        $k1p = self::zero();
        $k2p = self::zero();
        $d = $this;
        while ($k1 > 0 || $k2 > 0) {
            if (gmp_testbit($k1, 0)) {
                $k1p = $k1p->add($d);
            }
            if (gmp_testbit($k2, 0)) {
                $k2p = $k2p->add($d);
            }
            $d = $d->double();
            $k1 >>= 1;
            $k2 >>= 1;
        }
        if ($k1neg) {
            $k1p = new self($k1p->x, md(-$k1p->y), $k1p->z);
        }
        if ($k2neg) {
            $k2p = new self($k2p->x, md(-$k2p->y), $k2p->z);
        }
        $k2p = new self(md($k2p->x * $BETA), $k2p->y, $k2p->z);
        return $k1p->add($k2p);
    }
}

// (a + b / 2) floor-divided by b.
function divNearest(GMP $a, GMP $b): GMP
{
    return gmp_div_q($a + gmp_div_q($b, 2, GMP_ROUND_MINUSINF), $b, GMP_ROUND_MINUSINF);
}

$n = (int) ($argv[1] ?? 1);
$key = gmp_init('2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693', 16);
$x = gmp_init('55066263022277343669578718895168534326250603453777594175500187360389116729240');
$y = gmp_init('32670510020758816978083085130507043184471273380659243275938904335757337482424');
for ($i = 0; $i < $n; $i++) {
    $j = (new Jacobian($x, $y, gmp_init(1)))->multiply($key);
    $inv = gmp_invert($j->z, $P);
    $inv2 = md($inv * $inv);
    $x = md($j->x * $inv2);
    $y = md($j->y * $inv * $inv2);
}
echo gmp_strval($x, 16), ',', gmp_strval($y, 16), "\n";
