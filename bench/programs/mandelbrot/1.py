import hashlib
import sys

# Python's complex multiply rounds exactly like the reference's (zr+zr)*zi and zr*zr - zi*zi,
# so z*z + c reproduces its bitmap bit for bit.


def row_bytes(y, size, inv):
    ci = y * inv - 1.0
    out = bytearray(size // 8)
    for byte in range(size // 8):
        bits = 0
        for k in range(8):
            c = complex((byte * 8 + k) * inv - 1.5, ci)
            z = 0j
            for _ in range(50):
                z = z * z + c
                if z.real * z.real + z.imag * z.imag > 4.0:
                    break
            else:
                bits |= 0x80 >> k
        out[byte] = bits
    return out


def main():
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    size = (size + 7) // 8 * 8
    inv = 2.0 / size
    hasher = hashlib.md5()
    for y in range(size):
        hasher.update(row_bytes(y, size, inv))
    print(f"P4\n{size} {size}\n{hasher.hexdigest()}")


if __name__ == "__main__":
    main()
