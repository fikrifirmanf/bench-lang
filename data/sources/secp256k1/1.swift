// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on attaswift's BigInt.
import BigInt

let P = BigInt(2).power(256) - BigInt(2).power(32) - 977
let N = BigInt(2).power(256) - BigInt("432420386565659656852420866394968145599")
let GX = BigInt("55066263022277343669578718895168534326250603453777594175500187360389116729240")
let GY = BigInt("32670510020758816978083085130507043184471273380659243275938904335757337482424")
let BETA = BigInt("7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee", radix: 16)!
let POW_2_128 = BigInt(2).power(128)
let A1 = BigInt("3086d221a7d46bcde86c90e49284eb15", radix: 16)!
let B1 = -BigInt("e4437ed6010e88286f547fa90abfe4c3", radix: 16)!
let A2 = BigInt("114ca50f7a8e2f3f657c1108d9d44cfd8", radix: 16)!

// BigInt's % keeps the dividend's sign, so negative values are shifted back into [0, m).
@inline(__always) func mod(_ a: BigInt, _ m: BigInt = P) -> BigInt {
    let r = a % m
    return r.sign == .minus ? r + m : r
}

struct Jacobian {
    var x, y, z: BigInt

    static let zero = Jacobian(x: 0, y: 1, z: 0)

    func double() -> Jacobian {
        let a = mod(x * x), b = mod(y * y), c = mod(b * b)
        let xb = x + b
        let d = mod(2 * (mod(xb * xb) - a - c))
        let e = mod(3 * a), f = mod(e * e)
        let x3 = mod(f - 2 * d)
        let y3 = mod(e * (d - x3) - 8 * c)
        let z3 = mod(2 * y * z)
        return Jacobian(x: x3, y: y3, z: z3)
    }

    func add(_ o: Jacobian) -> Jacobian {
        if o.x.isZero || o.y.isZero { return self }
        if x.isZero || y.isZero { return o }
        let z1z1 = mod(z * z), z2z2 = mod(o.z * o.z)
        let u1 = mod(x * z2z2), u2 = mod(o.x * z1z1)
        let s1 = mod(y * o.z * z2z2), s2 = mod(mod(o.y * z) * z1z1)
        let h = mod(u2 - u1), r = mod(s2 - s1)
        if h.isZero { return r.isZero ? double() : .zero }
        let hh = mod(h * h), hhh = mod(h * hh), v = mod(u1 * hh)
        let x3 = mod(r * r - hhh - 2 * v)
        let y3 = mod(r * (v - x3) - s1 * hhh)
        let z3 = mod(z * o.z * h)
        return Jacobian(x: x3, y: y3, z: z3)
    }

    func multiply(_ k: BigInt) -> Jacobian {
        let b2 = A1
        let c1 = divNearest(b2 * k, N), c2 = divNearest(-B1 * k, N)
        var k1 = mod(k - c1 * A1 - c2 * A2, N), k2 = mod(-c1 * B1 - c2 * b2, N)
        let k1neg = k1 > POW_2_128, k2neg = k2 > POW_2_128
        if k1neg { k1 = N - k1 }
        if k2neg { k2 = N - k2 }
        var k1p = Jacobian.zero, k2p = Jacobian.zero, d = self
        while k1 > 0 || k2 > 0 {
            if k1.magnitude[bitAt: 0] { k1p = k1p.add(d) }
            if k2.magnitude[bitAt: 0] { k2p = k2p.add(d) }
            d = d.double()
            k1 >>= 1
            k2 >>= 1
        }
        if k1neg { k1p.y = mod(-k1p.y) }
        if k2neg { k2p.y = mod(-k2p.y) }
        k2p.x = mod(k2p.x * BETA)
        return k1p.add(k2p)
    }
}

// (a + b / 2) / b; every caller passes non-negative values, so truncation is floor division.
func divNearest(_ a: BigInt, _ b: BigInt) -> BigInt { (a + b / 2) / b }

let n = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 1
let key = BigInt("2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693", radix: 16)!
var x = GX, y = GY
for _ in 0..<n {
    let j = Jacobian(x: x, y: y, z: 1).multiply(key)
    let inv = j.z.inverse(P)!
    let inv2 = mod(inv * inv)
    x = mod(j.x * inv2)
    y = mod(j.y * inv * inv2)
}
print("\(String(x, radix: 16)),\(String(y, radix: 16))")
