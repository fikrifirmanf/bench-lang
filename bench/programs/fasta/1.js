// FASTA generator writing 60-character lines into one Buffer, flushed to stdout when full.
const fs = require("fs");

const WIDTH = 60;
const ALU =
  "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG" +
  "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA" +
  "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT" +
  "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA" +
  "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG" +
  "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC" +
  "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

const IUB = [["a", 0.27], ["c", 0.12], ["g", 0.12], ["t", 0.27],
  ...["B", "D", "H", "K", "M", "N", "R", "S", "V", "W", "Y"].map((c) => [c, 0.02])];
const HOMO_SAPIENS = [["a", 0.3029549426680], ["c", 0.1979883004921], ["g", 0.1975473066391], ["t", 0.3015094502008]];

const out = Buffer.allocUnsafe(1 << 16);
let used = 0;

function put(byte) {
  if (used === out.length) flush();
  out[used++] = byte;
}

function flush() {
  fs.writeSync(1, out, 0, used);
  used = 0;
}

function writeLine(text) {
  for (let i = 0; i < text.length; i++) put(text.charCodeAt(i));
  put(10);
}

let seed = 42;
function nextRandom() {
  seed = (seed * 3877 + 29573) % 139968;
  return seed / 139968;
}

function repeatFasta(src, n) {
  let pos = 0;
  for (let done = 0; done < n; done += WIDTH) {
    const count = Math.min(WIDTH, n - done);
    for (let i = 0; i < count; i++) {
      put(src.charCodeAt(pos));
      if (++pos === src.length) pos = 0;
    }
    put(10);
  }
}

function randomFasta(table, n) {
  const codes = table.map(([c]) => c.charCodeAt(0));
  const cumulative = [];
  let total = 0;
  for (const [, p] of table) cumulative.push((total += p));
  for (let done = 0; done < n; done += WIDTH) {
    const count = Math.min(WIDTH, n - done);
    for (let i = 0; i < count; i++) {
      const r = nextRandom();
      // Python's bisect: the first entry whose cumulative probability is greater than r.
      let k = 0;
      while (k < cumulative.length - 1 && cumulative[k] <= r) k++;
      put(codes[k]);
    }
    put(10);
  }
}

const n = +process.argv[2] || 1000;
writeLine(">ONE Homo sapiens alu");
repeatFasta(ALU, n * 2);
writeLine(">TWO IUB ambiguity codes");
randomFasta(IUB, n * 3);
writeLine(">THREE Homo sapiens frequency");
randomFasta(HOMO_SAPIENS, n * 5);
flush();
