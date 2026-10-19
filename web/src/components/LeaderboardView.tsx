"use client";

import Link from "next/link";
import { useId, useState } from "react";

import type { Leaderboard, Standing } from "@/lib/analysis";
import { formatRatio } from "@/lib/analysis";
import { langName } from "@/lib/catalog";

import { LangIcon } from "./LangIcon";

export interface BoardSet {
  profile: string;
  name: string;
  date: string;
  boards: { scope: string; allowMulti: boolean; board: Leaderboard }[];
}

interface Props {
  sets: BoardSet[];
  scopes: { id: string; label: string }[];
}

const RANK_TINT = ["bg-lemon", "bg-stone", "bg-coral"];

export function LeaderboardView({ sets, scopes }: Props) {
  const [profile, setProfile] = useState(sets[0]?.profile ?? "");
  const [scope, setScope] = useState("overall");
  const [allowMulti, setAllowMulti] = useState(false);
  const [showUnranked, setShowUnranked] = useState(false);
  const machineId = useId();
  const panelId = useId();

  const set = sets.find((s) => s.profile === profile) ?? sets[0];
  const board = set?.boards.find((b) => b.scope === scope && b.allowMulti === allowMulti)?.board;

  if (!set || !board) {
    return (
      <div role="alert" className="mt-8 rounded-card border-[2.5px] border-ink bg-coral p-8">
        <h2 className="text-balance text-xl font-bold">No results published yet</h2>
        <p className="mt-2">Run the benchmark workflow, then rebuild the site.</p>
      </div>
    );
  }

  const top = board.ranked[0]?.score ?? 1;
  const worst = Math.max(...board.ranked.map((s) => s.score), 1);
  const pickScope = (id: string) => {
    setScope(id);
    setShowUnranked(false);
  };

  return (
    <>
      <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-3.5">
        <div role="tablist" aria-label="Problem category" className="flex flex-wrap gap-2">
          {scopes.map((s) => {
            const selected = s.id === scope;
            return (
              <button
                key={s.id}
                type="button"
                role="tab"
                aria-selected={selected}
                aria-controls={panelId}
                onClick={() => pickScope(s.id)}
                className={`h-[46px] rounded-xl border-[2.5px] border-ink px-4 text-[15px] font-semibold ${
                  selected ? "bg-ink text-card" : "press bg-card shadow-brutal-sm"
                }`}
              >
                {s.label}
              </button>
            );
          })}
        </div>
        <label className="inline-flex min-h-11 items-center gap-2.5 font-semibold">
          <input
            type="checkbox"
            checked={allowMulti}
            onChange={(e) => setAllowMulti(e.target.checked)}
            className="size-5 accent-ink"
          />
          Include multi-thread versions
        </label>
        <div className="flex items-center gap-2.5 sm:ml-auto">
          <label htmlFor={machineId} className="font-semibold">
            Machine
          </label>
          <select
            id={machineId}
            value={set.profile}
            onChange={(e) => setProfile(e.target.value)}
            className="h-[46px] rounded-xl border-[2.5px] border-ink bg-card px-3 text-[15px] font-semibold"
          >
            {sets.map((s) => (
              <option key={s.profile} value={s.profile}>
                {s.name}
              </option>
            ))}
          </select>
        </div>
      </div>
      <p className="mt-3 font-mono text-[13px] text-ink-soft">
        {set.date} · {board.problems.length} problems · ranked with {board.minCoverage}+ results
      </p>

      <section id={panelId} role="tabpanel" aria-label="Ranked languages" className="mt-6">
        {board.ranked.length === 0 && !showUnranked ? (
          <div className="rounded-card border-[2.5px] border-ink bg-card p-8 shadow-brutal-lg">
            <h2 className="text-balance text-xl font-bold">No language qualifies here yet</h2>
            <p className="mt-2 max-w-[560px] text-ink-soft">
              Nobody has results for {board.minCoverage} of the {board.problems.length} problems in this category. Show the
              unranked scores, or go back to the overall view.
            </p>
            <div className="mt-5 flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => setShowUnranked(true)}
                className="press h-11 rounded-xl border-[2.5px] border-ink bg-lemon px-4 font-bold shadow-brutal-sm"
              >
                Show unranked
              </button>
              <button
                type="button"
                onClick={() => pickScope("overall")}
                className="press h-11 rounded-xl border-[2.5px] border-ink bg-card px-4 font-bold shadow-brutal-sm"
              >
                Back to Overall
              </button>
            </div>
          </div>
        ) : (
          <StandingsTable
            standings={showUnranked ? board.provisional : board.ranked}
            total={board.problems.length}
            top={top}
            worst={showUnranked ? Math.max(...board.provisional.map((s) => s.score), 1) : worst}
          />
        )}
      </section>

      {board.provisional.length > 0 && !showUnranked ? (
        <div className="mt-10 flex flex-wrap items-start gap-6">
          <section
            aria-labelledby="prov"
            className="min-w-0 flex-[999_1_560px] rounded-card border-[2.5px] border-dashed border-ink bg-card p-6"
          >
            <h2 id="prov" className="text-balance text-[22px] font-bold">
              Not enough data yet
            </h2>
            <p className="mt-2 mb-4 text-[15px] text-ink-soft">
              Fewer than {board.minCoverage} of {board.problems.length} problems, so these stay unranked until coverage grows.
            </p>
            <ul className="flex flex-wrap gap-2.5">
              {board.provisional.map((s) => (
                <li key={s.lang}>
                  <Link
                    href={`/languages/${s.lang}/`}
                    className="inline-flex h-12 items-center gap-2.5 rounded-xl border-2 border-ink bg-paper pr-3.5 pl-1.5 hover:bg-card"
                  >
                    <LangIcon slug={s.lang} size="sm" bordered={false} />
                    <span className="font-semibold">{langName(s.lang)}</span>
                    <span className="font-mono text-[13px] text-ink-soft">
                      {formatRatio(s.score)} · {s.coverage}/{board.problems.length}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          </section>
          <HowScored minCoverage={board.minCoverage} />
        </div>
      ) : (
        <div className="mt-10">
          <HowScored minCoverage={board.minCoverage} />
        </div>
      )}
    </>
  );
}

function StandingsTable({ standings, total, top, worst }: { standings: Standing[]; total: number; top: number; worst: number }) {
  return (
    <div className="overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[640px] border-collapse">
          <thead>
            <tr className="border-b-[2.5px] border-ink bg-sky text-left text-sm">
              <th scope="col" className="w-14 px-5 py-3.5 font-bold">#</th>
              <th scope="col" className="px-5 py-3.5 font-bold">Language</th>
              <th scope="col" className="w-[40%] px-5 py-3.5 font-bold">Score (× fastest)</th>
              <th scope="col" className="px-5 py-3.5 font-bold">Coverage</th>
              <th scope="col" className="px-5 py-3.5 text-right font-bold">Wins</th>
            </tr>
          </thead>
          <tbody>
            {standings.map((s, i) => (
              <tr key={s.lang} className="border-t-2 border-dashed border-line first:border-t-0">
                <td className="px-5 py-2.5">
                  <span className={`inline-flex size-[34px] items-center justify-center rounded-[10px] border-2 border-ink font-mono text-[15px] font-bold ${RANK_TINT[i] ?? "bg-card"}`}>
                    {i + 1}
                  </span>
                </td>
                <td className="px-5 py-2.5">
                  <Link href={`/languages/${s.lang}/`} className="inline-flex min-h-12 items-center gap-3 text-lg font-semibold hover:underline">
                    <LangIcon slug={s.lang} />
                    {langName(s.lang)}
                  </Link>
                </td>
                <td className="px-5 py-2.5">
                  <span className="flex items-center gap-3.5">
                    <span className="h-[18px] flex-1 overflow-hidden rounded-md border-2 border-ink bg-paper">
                      <span
                        className={`block h-full border-r-2 border-ink ${s.score === top ? "bg-lemon" : "bg-sky"}`}
                        style={{ width: `${Math.max(4, (s.score / worst) * 100)}%` }}
                      />
                    </span>
                    <span className="w-16 text-right font-mono text-base font-bold">{formatRatio(s.score)}</span>
                  </span>
                </td>
                <td className="px-5 py-2.5 font-mono text-[15px]">
                  {s.coverage}/{total}
                </td>
                <td className="px-5 py-2.5 text-right font-mono text-base font-bold">{s.wins}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function HowScored({ minCoverage }: { minCoverage: number }) {
  return (
    <section aria-labelledby="how" className="flex-[1_1_300px] rounded-card bg-ink p-6 text-paper">
      <h2 id="how" className="text-balance mb-3 text-[22px] font-bold">
        How the score works
      </h2>
      <ol className="flex list-decimal flex-col gap-2 pl-5 text-[15px] text-stone">
        <li>Take each language&apos;s fastest result per problem, at the largest input.</li>
        <li>Divide by the fastest result of any language.</li>
        <li>Geometric mean across problems. 1.00× would win everything.</li>
        <li>Rank only with {minCoverage}+ problems. helloworld is excluded.</li>
      </ol>
    </section>
  );
}
