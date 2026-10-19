"use client";

import Link from "next/link";
import { useId, useState } from "react";

import { formatMs } from "@/lib/analysis";
import { langName } from "@/lib/catalog";

import { LangIcon } from "./LangIcon";

/** lang -> problem -> fastest single-thread result at the largest input. */
export type BestTimes = Record<string, Record<string, { time: number; code: string }>>;

interface Props {
  lang: string;
  others: string[];
  initial: string;
  best: BestTimes;
}

export function LanguageCompare({ lang, others, initial, best }: Props) {
  const [other, setOther] = useState(initial);
  const selectId = useId();
  const mine = best[lang] ?? {};
  const theirs = best[other] ?? {};
  const shared = Object.keys(mine)
    .filter((p) => p in theirs)
    .sort();
  const faster = shared.filter((p) => (mine[p]?.time ?? 0) < (theirs[p]?.time ?? 0)).length;

  return (
    <section aria-labelledby="compare" className="mt-14">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-4">
        <h2 id="compare" className="text-balance text-3xl font-bold">
          Head to head
        </h2>
        <div className="flex items-center gap-2.5">
          <label htmlFor={selectId} className="font-semibold">
            Compare with
          </label>
          <select
            id={selectId}
            value={other}
            onChange={(e) => setOther(e.target.value)}
            className="h-[46px] rounded-xl border-[2.5px] border-ink bg-card px-3 font-semibold"
          >
            {others.map((l) => (
              <option key={l} value={l}>
                {langName(l)}
              </option>
            ))}
          </select>
        </div>
      </div>

      {shared.length === 0 ? (
        <div className="rounded-card border-[2.5px] border-dashed border-ink bg-card p-6">
          <p className="font-semibold">
            {langName(lang)} and {langName(other)} have no problem in common yet.
          </p>
          <p className="mt-1 text-ink-soft">Pick another language to compare.</p>
        </div>
      ) : (
        <div className="overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
          <p className="flex flex-wrap items-center gap-3 border-b-[2.5px] border-ink bg-mint px-5 py-4 text-lg font-semibold">
            <LangIcon slug={lang} size="sm" />
            {langName(lang)} is faster on {faster} of {shared.length} shared problems
            <LangIcon slug={other} size="sm" />
          </p>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[640px] border-collapse">
              <thead>
                <tr className="text-left text-sm">
                  <th scope="col" className="px-5 py-3 font-bold">Problem</th>
                  <th scope="col" className="px-5 py-3 text-right font-bold">{langName(lang)}</th>
                  <th scope="col" className="px-5 py-3 text-right font-bold">{langName(other)}</th>
                  <th scope="col" className="px-5 py-3 font-bold">Faster by</th>
                </tr>
              </thead>
              <tbody>
                {shared.map((p) => {
                  const a = mine[p]?.time ?? 0;
                  const b = theirs[p]?.time ?? 0;
                  const winner = a <= b ? lang : other;
                  const ratio = Math.max(a, b) / Math.max(Math.min(a, b), 0.001);
                  return (
                    <tr key={p} className="border-t-2 border-dashed border-line">
                      <td className="px-5 py-2.5">
                        <Link href={`/problems/${p}/`} className="font-mono font-bold underline">
                          {p}
                        </Link>
                      </td>
                      <td className={`px-5 py-2.5 text-right font-mono ${winner === lang ? "font-bold" : ""}`}>{formatMs(a)}</td>
                      <td className={`px-5 py-2.5 text-right font-mono ${winner === other ? "font-bold" : ""}`}>{formatMs(b)}</td>
                      <td className="px-5 py-2.5">
                        <span className="inline-flex items-center gap-2 font-semibold">
                          {langName(winner)} <span className="font-mono">{ratio.toFixed(2)}×</span>
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </section>
  );
}
