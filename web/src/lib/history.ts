import { bestPerLang, leaderboard, type Leaderboard } from "./analysis";
import { getIndex, readRun } from "./data";
import type { ResultRow, Run } from "./schema";

/** What the site would have shown right after one run was published. */
export interface Snapshot {
  runId: string;
  startedAt: string;
  source: Run["source"];
  rows: ResultRow[];
  board: Leaderboard;
}

function rowKey(row: ResultRow): string {
  return `${row.lang}\u0000${row.compiler}`;
}

/** Same rule as runner/merge.py fold_latest: a run replaces every row of the (language, compiler) pairs it measured. */
function fold(previous: ResultRow[], fresh: ResultRow[]): ResultRow[] {
  const replaced = new Set(fresh.map(rowKey));
  return [...previous.filter((r) => !replaced.has(rowKey(r))), ...fresh];
}

const cache = new Map<string, Snapshot[]>();

/** Every published run of a profile, oldest first, each folded onto the ones before it. */
export function getSnapshots(profile: string): Snapshot[] {
  const cached = cache.get(profile);
  if (cached) return cached;
  const entries = getIndex()
    .runs.filter((r) => r.profile === profile)
    .sort((a, b) => a.started_at.localeCompare(b.started_at));
  let rows: ResultRow[] = [];
  const snapshots = entries.map((entry): Snapshot => {
    const run = readRun(profile, entry.id);
    rows = fold(rows, run.rows);
    return {
      runId: run.id,
      startedAt: run.started_at,
      source: run.source,
      rows,
      board: leaderboard(rows, { category: null, allowMulti: false }),
    };
  });
  cache.set(profile, snapshots);
  return snapshots;
}

export interface LangPoint {
  runId: string;
  startedAt: string;
  source: Run["source"];
  score: number | null;
  rank: number | null;
  versions: string[];
}

export function langHistory(snapshots: Snapshot[], lang: string): LangPoint[] {
  return snapshots.flatMap((s) => {
    const own = s.rows.filter((r) => r.lang === lang);
    if (own.length === 0) return [];
    const rankIndex = s.board.ranked.findIndex((st) => st.lang === lang);
    const standing = s.board.ranked[rankIndex] ?? s.board.provisional.find((st) => st.lang === lang);
    return [
      {
        runId: s.runId,
        startedAt: s.startedAt,
        source: s.source,
        score: standing?.score ?? null,
        rank: rankIndex >= 0 ? rankIndex + 1 : null,
        versions: [...new Set(own.map((r) => `${r.compiler} ${r.version}`.trim()))].sort(),
      },
    ];
  });
}

/** Fastest single-thread time per language for one problem, per snapshot. */
export function problemHistory(snapshots: Snapshot[], problem: string): Map<string, number>[] {
  return snapshots.map((s) => new Map([...bestPerLang(s.rows, problem, false)].map(([lang, row]) => [lang, row.time_ms])));
}
