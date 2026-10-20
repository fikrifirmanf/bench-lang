// regex-redux with the engine's built-in RegExp.
const input = Deno.readTextFileSync(Deno.args[0] || "25000_in");
const seq = input.replace(/>.*\n|\n/g, "");

const variants = [
  "agggtaaa|tttaccct",
  "[cgt]gggtaaa|tttaccc[acg]",
  "a[act]ggtaaa|tttacc[agt]t",
  "ag[act]gtaaa|tttac[agt]ct",
  "agg[act]taaa|ttta[agt]cct",
  "aggg[acg]aaa|ttt[cgt]ccct",
  "agggt[cgt]aa|tt[acg]accct",
  "agggta[cgt]a|t[acg]taccct",
  "agggtaa[cgt]|[acg]ttaccct",
];
let out = "";
for (const variant of variants) {
  const re = new RegExp(variant, "g");
  let count = 0;
  while (re.exec(seq) !== null) count++;
  out += `${variant} ${count}\n`;
}

const substitutions: [RegExp, string][] = [
  [/tHa[Nt]/g, "<4>"],
  [/aND|caN|Ha[DS]|WaS/g, "<3>"],
  [/a[NSt]|BY/g, "<2>"],
  [/<[^>]*>/g, "|"],
  [/\|[^|][^|]*\|/g, "-"],
];
let replaced = seq;
for (const [pattern, replacement] of substitutions) replaced = replaced.replace(pattern, replacement);
console.log(`${out}\n${input.length}\n${seq.length}\n${replaced.length}`);
