// Digits of e by binary splitting of sum(1/k!); the final division runs as long division in 20000-digit chunks.
const CHUNK = 20000;

function sumTerms(a: bigint, b: bigint): [bigint, bigint] {
  if (b === a + 1n) return [1n, b];
  const mid = (a + b) / 2n;
  const [pLeft, qLeft] = sumTerms(a, mid);
  const [pRight, qRight] = sumTerms(mid, b);
  return [pLeft * qRight + pRight, qLeft * qRight];
}

function testK(n: number, k: number): boolean {
  if (k <= 0) return false;
  const lnKFactorial = k * (Math.log(k) - 1) + 0.5 * Math.log(2 * Math.PI);
  return lnKFactorial / Math.LN10 >= n + 50;
}

function binarySearch(n: number): number {
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
function digits(numerator: bigint, denominator: bigint, n: number): string {
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

const n = +Deno.args[0] || 27;
const [p, q] = sumTerms(0n, BigInt(binarySearch(n) - 1));
const s = digits(p + q, q, n);
let out = "";
for (let i = 0; i < n; i += 10) {
  out += i + 10 <= n ? `${s.slice(i, i + 10)}\t:${i + 10}\n` : `${s.slice(i, n).padEnd(10)}\t:${n}\n`;
}
const bytes = new TextEncoder().encode(out);
for (let written = 0; written < bytes.length;) written += Deno.stdout.writeSync(bytes.subarray(written));
