// Scalar mandelbrot, 50 iterations per pixel, then the MD5 of the packed bitmap.
// Fused multiply-add would round differently from the reference output, so contraction is off.
#pragma GCC optimize("fp-contract=off")
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

#include "md5.h"

static uint8_t pixel_byte(const double *cr, double ci) {
    uint8_t bits = 0;
    for (int k = 0; k < 8; k++) {
        double zr = 0, zi = 0, tr = 0, ti = 0;
        bool escaped = false;
        for (int i = 0; i < 50 && !escaped; i++) {
            zi = (zr + zr) * zi + ci;
            zr = tr - ti + cr[k];
            tr = zr * zr;
            ti = zi * zi;
            escaped = tr + ti > 4.0;
        }
        if (!escaped) bits |= static_cast<uint8_t>(0x80 >> k);
    }
    return bits;
}

int main(int argc, char **argv) {
    int size = argc > 1 ? std::atoi(argv[1]) : 200;
    size = (size + 7) / 8 * 8;
    int row_bytes = size / 8;
    double inv = 2.0 / size;
    std::vector<double> xs(size);
    for (int i = 0; i < size; i++) xs[i] = i * inv - 1.5;
    std::vector<uint8_t> pixels(static_cast<size_t>(size) * row_bytes);
    for (int y = 0; y < size; y++) {
        double ci = y * inv - 1.0;
        for (int i = 0; i < row_bytes; i++) pixels[static_cast<size_t>(y) * row_bytes + i] = pixel_byte(&xs[i * 8], ci);
    }
    uint8_t digest[16];
    md5(pixels.data(), pixels.size(), digest);
    std::printf("P4\n%d %d\n", size, size);
    for (uint8_t byte : digest) std::printf("%02x", byte);
    std::printf("\n");
}
