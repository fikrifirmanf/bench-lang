// Scalar mandelbrot: 50 iterations per pixel, then the MD5 of the packed bitmap.
const crypto = require("crypto");

function pixelByte(xs, offset, ci) {
  let bits = 0;
  for (let k = 0; k < 8; k++) {
    const cr = xs[offset + k];
    let zr = 0, zi = 0, tr = 0, ti = 0, escaped = false;
    for (let i = 0; i < 50 && !escaped; i++) {
      zi = (zr + zr) * zi + ci;
      zr = tr - ti + cr;
      tr = zr * zr;
      ti = zi * zi;
      escaped = tr + ti > 4;
    }
    if (!escaped) bits |= 0x80 >> k;
  }
  return bits;
}

let size = +process.argv[2] || 200;
size = Math.floor((size + 7) / 8) * 8;
const rowBytes = size / 8;
const inv = 2 / size;
const xs = new Float64Array(size);
for (let i = 0; i < size; i++) xs[i] = i * inv - 1.5;
const pixels = Buffer.alloc(size * rowBytes);
for (let y = 0; y < size; y++) {
  const ci = y * inv - 1;
  for (let i = 0; i < rowBytes; i++) pixels[y * rowBytes + i] = pixelByte(xs, i * 8, ci);
}
console.log(`P4\n${size} ${size}\n${crypto.createHash("md5").update(pixels).digest("hex")}`);
