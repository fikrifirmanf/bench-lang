import { readFileSync } from "node:fs";
import path from "node:path";

import { createHighlighter, type BundledLanguage, type Highlighter } from "shiki";

import { readJson } from "./data";
import { SourceIndex, type SourceOrigin } from "./schema";

// Shiki grammar per file extension; every extension upstream and bench/programs use has an entry.
const GRAMMARS: Record<string, BundledLanguage> = {
  ".c": "c",
  ".cpp": "cpp",
  ".cr": "crystal",
  ".cs": "csharp",
  ".dart": "dart",
  ".go": "go",
  ".java": "java",
  ".js": "javascript",
  ".kt": "kotlin",
  ".ml": "ocaml",
  ".nim": "nim",
  ".php": "php",
  ".pl": "perl",
  ".py": "python",
  ".rb": "ruby",
  ".rs": "rust",
  ".swift": "swift",
  ".ts": "typescript",
  ".zig": "zig",
};
const THEME = "github-light";

let index: SourceIndex | undefined;

export function getSourceIndex(): SourceIndex {
  index ??= readJson("data/sources/index.json", SourceIndex);
  return index;
}

/** Origin of each program of one problem with published code, keyed by file name. */
export function sourceOrigins(problem: string): Record<string, SourceOrigin> {
  return Object.fromEntries(getSourceIndex().programs.filter((p) => p.problem === problem).map((p) => [p.file, p.origin]));
}

let highlighter: Promise<Highlighter> | undefined;

/** The program as highlighted HTML (a <pre> fragment), rendered once at build time. */
export async function highlightSource(problem: string, file: string): Promise<string> {
  const known = getSourceIndex().programs.some((p) => p.problem === problem && p.file === file);
  if (!known) throw new Error(`data/sources has no ${problem}/${file}`);
  const code = readFileSync(path.join(sourcesRoot(), problem, file), "utf8");
  highlighter ??= createHighlighter({ themes: [THEME], langs: [...new Set(Object.values(GRAMMARS))] });
  const lang = GRAMMARS[path.extname(file)];
  return (await highlighter).codeToHtml(code, { lang: lang ?? "text", theme: THEME });
}

function sourcesRoot(): string {
  return path.join(process.env.BENCH_REPO_ROOT ?? path.join(process.cwd(), ".."), "data", "sources");
}
