// k-nucleotide: counts every k-mer of the THREE sequence in a Map keyed by base-4 packed numbers
// (kept below 2^53, so plain arithmetic instead of 32-bit bitwise operators).
const CODE: Record<string, number> = { A: 0, C: 1, G: 2, T: 3 };

function readSequence(fileName: string): Uint8Array {
  const lines = Deno.readTextFileSync(fileName).split("\n");
  let i = lines.findIndex((line) => line.startsWith(">THREE")) + 1;
  const parts = [];
  for (; i < lines.length && lines[i][0] !== ">"; i++) parts.push(lines[i].trim().toUpperCase());
  const text = parts.join("");
  const seq = new Uint8Array(text.length);
  for (let j = 0; j < text.length; j++) seq[j] = CODE[text[j]];
  return seq;
}

function countKmers(seq: Uint8Array, k: number): Map<number, number> {
  const counts = new Map<number, number>();
  const modulus = 4 ** k;
  let key = 0;
  for (let i = 0; i < seq.length; i++) {
    key = (key * 4 + seq[i]) % modulus;
    if (i + 1 >= k) counts.set(key, (counts.get(key) || 0) + 1);
  }
  return counts;
}

function unpack(key: number, k: number): string {
  let kmer = "";
  for (let i = 0; i < k; i++, key = Math.floor(key / 4)) kmer = "ACGT"[key % 4] + kmer;
  return kmer;
}

function frequencies(seq: Uint8Array, k: number): string {
  const total = seq.length - k + 1;
  const sorted: [string, number][] = [...countKmers(seq, k)].map(([key, count]) => [unpack(key, k), count]);
  sorted.sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1));
  return sorted.map(([kmer, count]) => `${kmer} ${((count * 100) / total).toFixed(3)}\n`).join("") + "\n";
}

const seq = readSequence(Deno.args[0] || "25000_in");
let out = frequencies(seq, 1) + frequencies(seq, 2);
for (const kmer of ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"]) {
  let key = 0;
  for (const c of kmer) key = key * 4 + CODE[c];
  out += `${countKmers(seq, kmer.length).get(key) || 0}\t${kmer}\n`;
}
const bytes = new TextEncoder().encode(out);
for (let written = 0; written < bytes.length;) written += Deno.stdout.writeSync(bytes.subarray(written));
