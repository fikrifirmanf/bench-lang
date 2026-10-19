import { problemInfo, type Category } from "./catalog";
import type { ResultRow } from "./schema";

/** helloworld measures process startup, not the language; it is left out of every score. */
export const UNSCORED = new Set(["helloworld"]);

/** A language is ranked once it has results for this share of the problems in scope. */
const MIN_COVERAGE_SHARE = 0.55;

export interface MeasuredRow extends ResultRow {
  time_ms: number;
}

function isMeasured(row: ResultRow): row is MeasuredRow {
  return row.status === "ok" && row.time_ms !== null;
}

export function isMulti(row: ResultRow): boolean {
  return row.flags.includes("multi-thread");
}

export function problemsIn(rows: ResultRow[]): string[] {
  return [...new Set(rows.map((r) => r.problem))].sort();
}

export function largestInput(rows: ResultRow[], problem: string): number {
  return rows.reduce((max, r) => (r.problem === problem ? Math.max(max, r.input_index) : max), 0);
}

export function inputsOf(rows: ResultRow[], problem: string): { index: number; input: string }[] {
  const seen = new Map<number, string>();
  for (const r of rows) if (r.problem === problem) seen.set(r.input_index, r.input);
  return [...seen].map(([index, input]) => ({ index, input })).sort((a, b) => b.index - a.index);
}

/** Fastest measured row per language for one problem at its largest input. */
export function bestPerLang(rows: ResultRow[], problem: string, allowMulti: boolean): Map<string, MeasuredRow> {
  const input = largestInput(rows, problem);
  const best = new Map<string, MeasuredRow>();
  for (const row of rows) {
    if (row.problem !== problem || row.input_index !== input || !isMeasured(row)) continue;
    if (!allowMulti && isMulti(row)) continue;
    const current = best.get(row.lang);
    if (!current || row.time_ms < current.time_ms) best.set(row.lang, row);
  }
  return best;
}

export interface Winner {
  problem: string;
  row: MeasuredRow | null;
}

export function winners(rows: ResultRow[]): Winner[] {
  return problemsIn(rows).map((problem) => {
    const best = [...bestPerLang(rows, problem, false).values()];
    const row = best.reduce<MeasuredRow | null>((min, r) => (min === null || r.time_ms < min.time_ms ? r : min), null);
    return { problem, row };
  });
}

export interface Standing {
  lang: string;
  score: number;
  coverage: number;
  wins: number;
}

export interface Leaderboard {
  problems: string[];
  minCoverage: number;
  ranked: Standing[];
  provisional: Standing[];
}

export function leaderboard(rows: ResultRow[], options: { category: Category | null; allowMulti: boolean }): Leaderboard {
  const problems = problemsIn(rows).filter(
    (p) => !UNSCORED.has(p) && (options.category === null || problemInfo(p).category === options.category),
  );
  const ratios = new Map<string, number[]>();
  const wins = new Map<string, number>();
  for (const problem of problems) {
    const best = bestPerLang(rows, problem, options.allowMulti);
    const fastest = Math.min(...[...best.values()].map((r) => r.time_ms));
    if (!Number.isFinite(fastest) || fastest <= 0) continue;
    for (const [lang, row] of best) {
      ratios.set(lang, [...(ratios.get(lang) ?? []), row.time_ms / fastest]);
      if (row.time_ms === fastest) wins.set(lang, (wins.get(lang) ?? 0) + 1);
    }
  }
  const standings: Standing[] = [...ratios].map(([lang, values]) => ({
    lang,
    score: Math.exp(values.reduce((sum, v) => sum + Math.log(v), 0) / values.length),
    coverage: values.length,
    wins: wins.get(lang) ?? 0,
  }));
  standings.sort((a, b) => a.score - b.score);
  const minCoverage = Math.max(1, Math.ceil(problems.length * MIN_COVERAGE_SHARE));
  return {
    problems,
    minCoverage,
    ranked: standings.filter((s) => s.coverage >= minCoverage),
    provisional: standings.filter((s) => s.coverage < minCoverage),
  };
}

export interface LangProblemResult {
  problem: string;
  row: MeasuredRow;
  rank: number;
  of: number;
}

export function langResults(rows: ResultRow[], lang: string): LangProblemResult[] {
  return problemsIn(rows).flatMap((problem) => {
    const ordered = [...bestPerLang(rows, problem, false).values()].sort((a, b) => a.time_ms - b.time_ms);
    const index = ordered.findIndex((r) => r.lang === lang);
    const row = ordered[index];
    return row ? [{ problem, row, rank: index + 1, of: ordered.length }] : [];
  });
}

export function langsIn(rows: ResultRow[]): string[] {
  return [...new Set(rows.map((r) => r.lang))].sort();
}

export function formatMs(ms: number | null): string {
  if (ms === null) return "–";
  if (ms < 10) return `${ms.toFixed(1)}ms`;
  if (ms < 1000) return `${Math.round(ms)}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
}

export function formatMb(mb: number | null): string {
  if (mb === null) return "–";
  return mb >= 1024 ? `${(mb / 1024).toFixed(1)}GB` : `${mb.toFixed(1)}MB`;
}

export function formatRatio(value: number): string {
  return `${value.toFixed(2)}×`;
}
