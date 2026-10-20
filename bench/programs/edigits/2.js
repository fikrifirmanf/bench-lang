// Digits of e by binary splitting, as 1.js, but the final (p + q) * 10^(n-1) / q is done as long division in
// 20000-digit chunks: JavaScriptCore (Bun) caps a BigInt at 2^20 bits, and the one-shot product needs 1.6M.
const CHUNK = 20000;

function sumTerms(a, b) {
  if (b === a + 1n) return [1n, b];
  const mid = (a + b) / 2n;
  const [pLeft, qLeft] = sumTerms(a, mid);
  const [pRight, qRight] = sumTerms(mid, b);
  return [pLeft * qRight + pRight, qLeft * qRight];
}

function testK(n, k) {
  if (k <= 0) return false;
  const lnKFactorial = k * (Math.log(k) - 1) + 0.5 * Math.log(2 * Math.PI);
  return lnKFactorial / Math.LN10 >= n + 50;
}

function binarySearch(n) {
  let a = 0, b = 1;
  while (!testK(n, b)) {
    a = b;
    b *= 2;
  }
  while (b - a > 1) {
    const m = Math.floor((a + b) / 2);
    if (testK(n, m)) b = m;
    else a = m;
  }
  return b;
}

// The first n significant digits of numerator / denominator, which is between 1 and 10.
function digits(numerator, denominator, n) {
  let s = (numerator / denominator).toString();
  let remainder = numerator % denominator;
  while (s.length < n) {
    const take = Math.min(CHUNK, n - s.length);
    remainder *= 10n ** BigInt(take);
    s += (remainder / denominator).toString().padStart(take, "0");
    remainder %= denominator;
  }
  return s;
}

const n = +process.argv[2] || 27;
const [p, q] = sumTerms(0n, BigInt(binarySearch(n) - 1));
const s = digits(p + q, q, n);
let out = "";
for (let i = 0; i < n; i += 10) {
  out += i + 10 <= n ? `${s.slice(i, i + 10)}\t:${i + 10}\n` : `${s.slice(i, n).padEnd(10)}\t:${n}\n`;
}
process.stdout.write(out);
