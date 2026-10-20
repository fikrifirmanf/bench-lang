// secp256k1 point multiplication in Jacobian coordinates with the GLV endomorphism, on Zig's native
// fixed-width integers: field elements are u256, products widen to u512 before reduction.
const std = @import("std");

const P: u256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
const N: u256 = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;
const BETA: u256 = 0x7ae96a2b657c07106e64479eac3434e99cf0497512f58995c1396c28719501ee;
const POW_2_128: u256 = 1 << 128;
const A1: i512 = 0x3086d221a7d46bcde86c90e49284eb15;
const B1: i512 = -0xe4437ed6010e88286f547fa90abfe4c3;
const A2: i512 = 0x114ca50f7a8e2f3f657c1108d9d44cfd8;
const GX: u256 = 55066263022277343669578718895168534326250603453777594175500187360389116729240;
const GY: u256 = 32670510020758816978083085130507043184471273380659243275938904335757337482424;

// Field arithmetic modulo P on reduced operands.
fn mul(a: u256, b: u256) u256 {
    return @intCast((@as(u512, a) * b) % P);
}
fn add(a: u256, b: u256) u256 {
    return @intCast((@as(u512, a) + b) % P);
}
fn sub(a: u256, b: u256) u256 {
    return if (a >= b) a - b else @intCast(@as(u512, a) + P - b);
}
fn small(k: u256, a: u256) u256 {
    return mul(k, a);
}

const Jacobian = struct {
    x: u256,
    y: u256,
    z: u256,

    const zero = Jacobian{ .x = 0, .y = 1, .z = 0 };

    fn double(p: Jacobian) Jacobian {
        const a = mul(p.x, p.x);
        const b = mul(p.y, p.y);
        const c = mul(b, b);
        const xb = add(p.x, b);
        const d = small(2, sub(sub(mul(xb, xb), a), c));
        const e = small(3, a);
        const f = mul(e, e);
        const x3 = sub(f, small(2, d));
        const y3 = sub(mul(e, sub(d, x3)), small(8, c));
        const z3 = small(2, mul(p.y, p.z));
        return .{ .x = x3, .y = y3, .z = z3 };
    }

    fn plus(p: Jacobian, o: Jacobian) Jacobian {
        if (o.x == 0 or o.y == 0) return p;
        if (p.x == 0 or p.y == 0) return o;
        const z1z1 = mul(p.z, p.z);
        const z2z2 = mul(o.z, o.z);
        const u_1 = mul(p.x, z2z2);
        const u_2 = mul(o.x, z1z1);
        const s1 = mul(mul(p.y, o.z), z2z2);
        const s2 = mul(mul(o.y, p.z), z1z1);
        const h = sub(u_2, u_1);
        const r = sub(s2, s1);
        if (h == 0) return if (r == 0) p.double() else zero;
        const hh = mul(h, h);
        const hhh = mul(h, hh);
        const v = mul(u_1, hh);
        const x3 = sub(sub(mul(r, r), hhh), small(2, v));
        const y3 = sub(mul(r, sub(v, x3)), mul(s1, hhh));
        const z3 = mul(mul(p.z, o.z), h);
        return .{ .x = x3, .y = y3, .z = z3 };
    }

    fn multiply(p: Jacobian, k: u256) Jacobian {
        const n: i512 = N;
        const kk: i512 = k;
        const b2 = A1;
        const c1 = divNearest(b2 * kk, n);
        const c2 = divNearest(-B1 * kk, n);
        var k1: u256 = @intCast(@mod(kk - c1 * A1 - c2 * A2, n));
        var k2: u256 = @intCast(@mod(-c1 * B1 - c2 * b2, n));
        const k1neg = k1 > POW_2_128;
        const k2neg = k2 > POW_2_128;
        if (k1neg) k1 = N - k1;
        if (k2neg) k2 = N - k2;
        var k1p = zero;
        var k2p = zero;
        var d = p;
        while (k1 > 0 or k2 > 0) {
            if (k1 & 1 == 1) k1p = k1p.plus(d);
            if (k2 & 1 == 1) k2p = k2p.plus(d);
            d = d.double();
            k1 >>= 1;
            k2 >>= 1;
        }
        if (k1neg) k1p.y = sub(0, k1p.y);
        if (k2neg) k2p.y = sub(0, k2p.y);
        k2p.x = mul(k2p.x, BETA);
        return k1p.plus(k2p);
    }
};

// (a + b / 2) floor-divided by b.
fn divNearest(a: i512, b: i512) i512 {
    return @divFloor(a + @divFloor(b, 2), b);
}

// Inverse modulo P by the extended Euclidean algorithm.
fn invert(number: u256) u256 {
    var a: i512 = number;
    var b: i512 = P;
    var x: i512 = 0;
    var y: i512 = 1;
    var u: i512 = 1;
    var v: i512 = 0;
    while (a != 0) {
        const q = @divFloor(b, a);
        const r = @mod(b, a);
        const m = x - u * q;
        const nn = y - v * q;
        b = a;
        a = r;
        x = u;
        y = v;
        u = m;
        v = nn;
    }
    return @intCast(@mod(x, @as(i512, P)));
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const n = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 1;
    const key: u256 = 0x2DEE927079283C3C4FCA3EF970FF4D38B64592E3FE0AB0DAD9132D70B5BC7693;
    var x = GX;
    var y = GY;
    for (0..n) |_| {
        const j = (Jacobian{ .x = x, .y = y, .z = 1 }).multiply(key);
        const inv = invert(j.z);
        const inv2 = mul(inv, inv);
        x = mul(j.x, inv2);
        y = mul(mul(j.y, inv), inv2);
    }
    try std.io.getStdOut().writer().print("{x},{x}\n", .{ x, y });
}
