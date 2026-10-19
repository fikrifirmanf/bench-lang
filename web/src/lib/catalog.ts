/** Display names, logos and problem metadata. Slugs match the runner's `lang` values. */

const LANG_NAMES: Record<string, string> = {
  acton: "Acton",
  c: "C",
  chapel: "Chapel",
  codon: "Codon",
  cpp: "C++",
  crystal: "Crystal",
  csharp: "C#",
  d: "D",
  dart: "Dart",
  go: "Go",
  haxe: "Haxe",
  java: "Java",
  javascript: "JavaScript",
  kotlin: "Kotlin",
  lua: "Lua",
  nim: "Nim",
  ocaml: "OCaml",
  odin: "Odin",
  perl: "Perl",
  php: "PHP",
  python: "Python",
  ruby: "Ruby",
  rust: "Rust",
  swift: "Swift",
  typescript: "TypeScript",
  v: "V",
  wasm: "Wasm",
  zig: "Zig",
};

// Logos from the Devicon set (MIT). Languages without one get a lettered tile.
const WITH_LOGO = new Set([
  "c", "cpp", "crystal", "csharp", "dart", "go", "haxe", "java", "javascript", "kotlin", "lua",
  "nim", "ocaml", "perl", "php", "python", "ruby", "rust", "swift", "typescript", "wasm", "zig",
]);

export function langName(slug: string): string {
  return LANG_NAMES[slug] ?? slug;
}

export function langLogo(slug: string): string | null {
  return WITH_LOGO.has(slug) ? `/icons/${slug}.svg` : null;
}

export function langMonogram(slug: string): string {
  return langName(slug).slice(0, 2);
}

export type Category = "cpu" | "memory" | "concurrency" | "big-numbers" | "text";

export const CATEGORIES: { id: Category; label: string }[] = [
  { id: "cpu", label: "CPU" },
  { id: "memory", label: "Memory" },
  { id: "concurrency", label: "Concurrency" },
  { id: "big-numbers", label: "Big numbers" },
  { id: "text", label: "Text & data" },
];

interface ProblemInfo {
  summary: string;
  category: Category | "startup";
}

const PROBLEMS: Record<string, ProblemInfo> = {
  binarytrees: { summary: "Allocate, walk and free many binary trees.", category: "memory" },
  "coro-prime-sieve": { summary: "A prime sieve built from a chain of coroutines.", category: "concurrency" },
  edigits: { summary: "Digits of e with arbitrary-precision integers.", category: "big-numbers" },
  "fannkuch-redux": { summary: "Count pancake flips over every permutation.", category: "cpu" },
  fasta: { summary: "Generate DNA sequences from weighted random choices.", category: "cpu" },
  helloworld: { summary: "Print one line. Measures startup cost.", category: "startup" },
  "http-server": { summary: "Serve and call HTTP requests on localhost.", category: "concurrency" },
  "json-serde": { summary: "Parse and re-serialize JSON documents.", category: "text" },
  knucleotide: { summary: "Count DNA k-mers in a hash map.", category: "text" },
  lru: { summary: "Hits and misses on a least-recently-used cache.", category: "memory" },
  mandelbrot: { summary: "Render the Mandelbrot set to a bitmap.", category: "cpu" },
  merkletrees: { summary: "Build and hash Merkle trees.", category: "memory" },
  nbody: { summary: "Simulate the orbits of the Jovian planets.", category: "cpu" },
  nsieve: { summary: "Sieve of Eratosthenes over large ranges.", category: "cpu" },
  pidigits: { summary: "Digits of pi with arbitrary-precision integers.", category: "big-numbers" },
  "regex-redux": { summary: "Regex match and replace over DNA input.", category: "text" },
  secp256k1: { summary: "Elliptic-curve point multiplication.", category: "big-numbers" },
  "spectral-norm": { summary: "Spectral norm of an infinite matrix.", category: "cpu" },
};

export function problemInfo(name: string): ProblemInfo {
  return PROBLEMS[name] ?? { summary: "", category: "cpu" };
}

export function categoryLabel(category: Category | "startup"): string {
  return CATEGORIES.find((c) => c.id === category)?.label ?? "Startup";
}

export const CATEGORY_TINT: Record<Category | "startup", string> = {
  cpu: "bg-lemon",
  memory: "bg-mint",
  concurrency: "bg-sky",
  "big-numbers": "bg-coral",
  text: "bg-stone",
  startup: "bg-card",
};

export const FLAG_LABELS: Record<string, string> = {
  "multi-thread": "multi-thread",
  intrinsics: "intrinsics",
  ffi: "native lib",
};
