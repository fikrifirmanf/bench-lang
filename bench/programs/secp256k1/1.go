// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on math/big only
// (0-ffi.go calls go-ethereum's C library instead).
package main

import (
	"fmt"
	"math/big"
	"os"
	"strconv"
)

func hex(s string) *big.Int {
	v, _ := new(big.Int).SetString(s, 16)
	return v
}

var (
	P         = hex("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f")
	N         = hex("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141")
	BETA      = hex("7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee")
	POW_2_128 = new(big.Int).Lsh(big.NewInt(1), 128)
	A1        = hex("3086d221a7d46bcde86c90e49284eb15")
	B1        = hex("-e4437ed6010e88286f547fa90abfe4c3")
	A2        = hex("114ca50f7a8e2f3f657c1108d9d44cfd8")
)

// mod returns a mod m in [0, m); big.Int.Mod is already Euclidean.
func mod(a *big.Int, m *big.Int) *big.Int { return new(big.Int).Mod(a, m) }

func mul(a, b *big.Int) *big.Int    { return new(big.Int).Mul(a, b) }
func sub(a, b *big.Int) *big.Int    { return new(big.Int).Sub(a, b) }
func add(a, b *big.Int) *big.Int    { return new(big.Int).Add(a, b) }
func small(k int64, a *big.Int) *big.Int { return new(big.Int).Mul(big.NewInt(k), a) }

type Jacobian struct{ x, y, z *big.Int }

func zero() Jacobian { return Jacobian{big.NewInt(0), big.NewInt(1), big.NewInt(0)} }

func (p Jacobian) double() Jacobian {
	a := mod(mul(p.x, p.x), P)
	b := mod(mul(p.y, p.y), P)
	c := mod(mul(b, b), P)
	xb := add(p.x, b)
	d := mod(small(2, sub(sub(mod(mul(xb, xb), P), a), c)), P)
	e := mod(small(3, a), P)
	f := mod(mul(e, e), P)
	x3 := mod(sub(f, small(2, d)), P)
	y3 := mod(sub(mul(e, sub(d, x3)), small(8, c)), P)
	z3 := mod(small(2, mul(p.y, p.z)), P)
	return Jacobian{x3, y3, z3}
}

func (p Jacobian) add(o Jacobian) Jacobian {
	if o.x.Sign() == 0 || o.y.Sign() == 0 {
		return p
	}
	if p.x.Sign() == 0 || p.y.Sign() == 0 {
		return o
	}
	z1z1 := mod(mul(p.z, p.z), P)
	z2z2 := mod(mul(o.z, o.z), P)
	u1 := mod(mul(p.x, z2z2), P)
	u2 := mod(mul(o.x, z1z1), P)
	s1 := mod(mul(mul(p.y, o.z), z2z2), P)
	s2 := mod(mul(mod(mul(o.y, p.z), P), z1z1), P)
	h := mod(sub(u2, u1), P)
	r := mod(sub(s2, s1), P)
	if h.Sign() == 0 {
		if r.Sign() == 0 {
			return p.double()
		}
		return zero()
	}
	hh := mod(mul(h, h), P)
	hhh := mod(mul(h, hh), P)
	v := mod(mul(u1, hh), P)
	x3 := mod(sub(sub(mul(r, r), hhh), small(2, v)), P)
	y3 := mod(sub(mul(r, sub(v, x3)), mul(s1, hhh)), P)
	z3 := mod(mul(mul(p.z, o.z), h), P)
	return Jacobian{x3, y3, z3}
}

// divNearest returns (a + b/2) / b with floor division; callers pass non-negative values.
func divNearest(a, b *big.Int) *big.Int {
	return new(big.Int).Div(add(a, new(big.Int).Rsh(b, 1)), b)
}

func (p Jacobian) multiply(k *big.Int) Jacobian {
	b2 := A1
	c1 := divNearest(mul(b2, k), N)
	c2 := divNearest(mul(new(big.Int).Neg(B1), k), N)
	k1 := mod(sub(sub(k, mul(c1, A1)), mul(c2, A2)), N)
	k2 := mod(sub(new(big.Int).Neg(mul(c1, B1)), mul(c2, b2)), N)
	k1neg := k1.Cmp(POW_2_128) > 0
	k2neg := k2.Cmp(POW_2_128) > 0
	if k1neg {
		k1 = sub(N, k1)
	}
	if k2neg {
		k2 = sub(N, k2)
	}
	k1p, k2p, d := zero(), zero(), p
	for k1.Sign() > 0 || k2.Sign() > 0 {
		if k1.Bit(0) == 1 {
			k1p = k1p.add(d)
		}
		if k2.Bit(0) == 1 {
			k2p = k2p.add(d)
		}
		d = d.double()
		k1 = new(big.Int).Rsh(k1, 1)
		k2 = new(big.Int).Rsh(k2, 1)
	}
	if k1neg {
		k1p = Jacobian{k1p.x, mod(new(big.Int).Neg(k1p.y), P), k1p.z}
	}
	if k2neg {
		k2p = Jacobian{k2p.x, mod(new(big.Int).Neg(k2p.y), P), k2p.z}
	}
	k2p = Jacobian{mod(mul(k2p.x, BETA), P), k2p.y, k2p.z}
	return k1p.add(k2p)
}

func main() {
	n := 1
	if len(os.Args) > 1 {
		n, _ = strconv.Atoi(os.Args[1])
	}
	key := hex("2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693")
	x, _ := new(big.Int).SetString("55066263022277343669578718895168534326250603453777594175500187360389116729240", 10)
	y, _ := new(big.Int).SetString("32670510020758816978083085130507043184471273380659243275938904335757337482424", 10)
	for i := 0; i < n; i++ {
		j := Jacobian{x, y, big.NewInt(1)}.multiply(key)
		inv := new(big.Int).ModInverse(j.z, P)
		inv2 := mod(mul(inv, inv), P)
		x = mod(mul(j.x, inv2), P)
		y = mod(mul(mul(j.y, inv), inv2), P)
	}
	fmt.Printf("%x,%x\n", x, y)
}
