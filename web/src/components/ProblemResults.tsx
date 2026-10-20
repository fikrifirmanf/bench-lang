"use client";

import Link from "next/link";
import { Fragment, useId, useState, useSyncExternalStore } from "react";

import { formatMb, formatMs, formatRatio, isMulti } from "@/lib/analysis";
import { FLAG_LABELS, langName } from "@/lib/catalog";
import { codeAnchor } from "@/lib/format";
import type { ResultRow, SourceOrigin, Status } from "@/lib/schema";

import { CodeView } from "./CodeView";
import { LangIcon } from "./LangIcon";

function subscribeHash(onChange: () => void): () => void {
  window.addEventListener("hashchange", onChange);
  return () => window.removeEventListener("hashchange", onChange);
}

export interface ProblemDataset {
  profile: string;
  name: string;
  date: string;
  inputs: { index: number; input: string }[];
  rows: ResultRow[];
}

const STATUS_TEXT: Record<Status, string> = {
  ok: "ok",
  fail: "crashed",
  "build-fail": "did not build",
  timeout: "timed out",
  oom: "out of memory",
  "wrong-output": "wrong output",
};

export function ProblemResults({ problem, datasets, origins }: {
  problem: string;
  datasets: ProblemDataset[];
  origins: Record<string, SourceOrigin>;
}) {
  const [profile, setProfile] = useState(datasets[0]?.profile ?? "");
  const data = datasets.find((d) => d.profile === profile) ?? datasets[0];
  const [inputIndex, setInputIndex] = useState(data?.inputs[0]?.index ?? 0);
  const [allowMulti, setAllowMulti] = useState(false);
  const machineId = useId();
  // The row whose code is open: whatever the visitor last toggled, or else the one the URL's #anchor names.
  const hash = useSyncExternalStore(subscribeHash, () => window.location.hash.slice(1), () => "");
  const [toggled, setToggled] = useState<string | null>();
  const openRow = toggled === undefined ? hash : toggled;

  if (!data) return null;
  const input = data.inputs.find((i) => i.index === inputIndex) ?? data.inputs[0];
  const scoped = data.rows.filter((r) => r.input_index === input?.index && (allowMulti || !isMulti(r)));
  const measured = scoped
    .filter((r): r is ResultRow & { time_ms: number } => r.status === "ok" && r.time_ms !== null)
    .sort((a, b) => a.time_ms - b.time_ms);
  const unfinished = scoped.filter((r) => r.status !== "ok");
  const best = measured[0]?.time_ms ?? 1;
  const slowest = measured.at(-1)?.time_ms ?? 1;
  // Results span 1× to 100×+, so bars use a log scale: the fastest gets a stub, the slowest a full bar.
  const spread = Math.log(Math.max(slowest / best, 1.0001));
  const barWidth = (ms: number) => `${8 + 92 * (Math.log(ms / best) / spread)}%`;

  const switchProfile = (id: string) => {
    setProfile(id);
    const next = datasets.find((d) => d.profile === id);
    setInputIndex(next?.inputs[0]?.index ?? 0);
  };

  return (
    <>
      <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-3.5 rounded-card border-[2.5px] border-ink bg-card p-4 shadow-brutal">
        <div role="group" aria-label="Input size" className="flex flex-wrap items-center gap-2">
          <span className="font-semibold">Input</span>
          {data.inputs.map((i) => (
            <button
              key={i.index}
              type="button"
              aria-pressed={i.index === input?.index}
              onClick={() => setInputIndex(i.index)}
              className={`h-11 rounded-xl border-2 border-ink px-3.5 font-mono text-sm font-bold ${
                i.index === input?.index ? "bg-ink text-card" : "bg-paper hover:bg-lemon"
              }`}
            >
              {i.input}
            </button>
          ))}
        </div>
        <label className="inline-flex min-h-11 items-center gap-2.5 font-semibold">
          <input type="checkbox" checked={allowMulti} onChange={(e) => setAllowMulti(e.target.checked)} className="size-5 accent-ink" />
          Include multi-thread versions
        </label>
        {datasets.length > 1 ? (
          <div className="flex items-center gap-2.5 sm:ml-auto">
            <label htmlFor={machineId} className="font-semibold">
              Machine
            </label>
            <select
              id={machineId}
              value={data.profile}
              onChange={(e) => switchProfile(e.target.value)}
              className="h-11 rounded-xl border-2 border-ink bg-card px-3 font-semibold"
            >
              {datasets.map((d) => (
                <option key={d.profile} value={d.profile}>
                  {d.name}
                </option>
              ))}
            </select>
          </div>
        ) : null}
      </div>
      <p className="mt-3 font-mono text-[13px] text-ink-soft">
        {data.name} · {data.date} · {measured.length} results
      </p>

      {measured.length === 0 ? (
        <div className="mt-6 rounded-card border-[2.5px] border-ink bg-card p-8 shadow-brutal-lg">
          <h2 className="text-balance text-xl font-bold">No finished results for this input</h2>
          <p className="mt-2 text-ink-soft">Try another input size, or include multi-thread versions.</p>
          {!allowMulti ? (
            <button
              type="button"
              onClick={() => setAllowMulti(true)}
              className="press mt-5 h-11 rounded-xl border-[2.5px] border-ink bg-lemon px-4 font-bold shadow-brutal-sm"
            >
              Include multi-thread
            </button>
          ) : null}
        </div>
      ) : (
        <div className="mt-6 overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[980px] border-collapse">
              <caption className="sr-only">
                {problem} results for input {input?.input}, fastest first
              </caption>
              <thead>
                <tr className="border-b-[2.5px] border-ink bg-sky text-left text-sm">
                  <th scope="col" className="w-12 px-4 py-3.5 font-bold">#</th>
                  <th scope="col" className="px-4 py-3.5 font-bold">Language</th>
                  <th scope="col" className="px-4 py-3.5 font-bold">Code</th>
                  <th scope="col" className="w-[28%] px-4 py-3.5 font-bold">Time (log scale)</th>
                  <th scope="col" className="px-4 py-3.5 text-right font-bold">vs best</th>
                  <th scope="col" className="px-4 py-3.5 text-right font-bold">± stddev</th>
                  <th scope="col" className="px-4 py-3.5 text-right font-bold">Peak mem</th>
                  <th scope="col" className="px-4 py-3.5 font-bold">Compiler</th>
                </tr>
              </thead>
              <tbody>
                {measured.map((r, i) => {
                  const anchor = codeAnchor(r.lang, r.compiler, r.code);
                  const origin = origins[r.code];
                  const open = origin !== undefined && openRow === anchor;
                  return (
                    <Fragment key={anchor}>
                      <tr id={anchor} className="scroll-mt-24 border-t-2 border-dashed border-line first:border-t-0">
                        <td className="px-4 py-2 font-mono font-bold">{i + 1}</td>
                        <td className="px-4 py-2">
                          <Link href={`/languages/${r.lang}/`} className="inline-flex min-h-11 items-center gap-2.5 font-semibold hover:underline">
                            <LangIcon slug={r.lang} size="sm" />
                            {langName(r.lang)}
                          </Link>
                        </td>
                        <td className="px-4 py-2">
                          <span className="flex flex-wrap items-center gap-x-2.5">
                            <span className="font-mono text-[15px] font-medium">{r.code}</span>
                            {origin !== undefined ? (
                              <button
                                type="button"
                                aria-expanded={open}
                                aria-controls={`${anchor}-code`}
                                onClick={() => setToggled(open ? null : anchor)}
                                className={`inline-flex min-h-11 items-center rounded-lg px-1.5 text-sm font-semibold underline ${
                                  open ? "text-ink" : "text-ink-soft hover:text-ink"
                                }`}
                              >
                                {open ? "Hide code" : "View code"}
                              </button>
                            ) : null}
                          </span>
                          {r.flags.length > 0 ? (
                            <span className="mt-1 flex flex-wrap gap-1">
                              {r.flags.map((f) => (
                                <span key={f} className="rounded-full border-[1.5px] border-ink bg-stone px-2 text-xs font-semibold">
                                  {FLAG_LABELS[f] ?? f}
                                </span>
                              ))}
                            </span>
                          ) : null}
                        </td>
                        <td className="px-4 py-2">
                          <span className="flex items-center gap-3">
                            <span className="h-3.5 flex-1 overflow-hidden rounded border-2 border-ink bg-paper">
                              <span
                                className={`block h-full ${i === 0 ? "bg-lemon" : "bg-sky"}`}
                                style={{ width: barWidth(r.time_ms) }}
                              />
                            </span>
                            <span className="w-16 text-right font-mono font-bold">{formatMs(r.time_ms)}</span>
                          </span>
                        </td>
                        <td className="px-4 py-2 text-right font-mono">{formatRatio(r.time_ms / best)}</td>
                        <td className="px-4 py-2 text-right font-mono text-ink-soft">{formatMs(r.stddev_ms)}</td>
                        <td className="px-4 py-2 text-right font-mono">{formatMb(r.peak_mem_mb)}</td>
                        <td className="px-4 py-2 font-mono text-sm text-ink-soft">
                          {r.compiler} {r.version}
                        </td>
                      </tr>
                      {open ? (
                        <tr id={`${anchor}-code`}>
                          <td colSpan={8} className="p-0">
                            {/* Pinned to the visible width, so on a phone the panel does not scroll away with the wide table. */}
                            <div className="sticky left-0 max-w-[calc(100vw-2rem-5px)] sm:max-w-[calc(100vw-3rem-5px)]">
                              <CodeView problem={problem} file={r.code} origin={origin} onClose={() => setToggled(null)} />
                            </div>
                          </td>
                        </tr>
                      ) : null}
                    </Fragment>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {unfinished.length > 0 ? (
        <details className="mt-6 rounded-card border-[2.5px] border-dashed border-ink bg-card p-5">
          <summary className="cursor-pointer text-lg font-bold">Did not finish ({unfinished.length})</summary>
          <ul className="mt-4 grid grid-cols-[repeat(auto-fill,minmax(min(100%,300px),1fr))] gap-x-6">
            {unfinished.map((r) => (
              <li
                key={`${r.lang}-${r.compiler}-${r.code}`}
                className="flex min-h-11 items-center justify-between gap-3 border-b-2 border-dashed border-line"
              >
                <span className="font-semibold">
                  {langName(r.lang)} <span className="font-mono text-sm font-normal">{r.code}</span>
                </span>
                <span className="font-mono text-sm text-alert">{STATUS_TEXT[r.status]}</span>
              </li>
            ))}
          </ul>
        </details>
      ) : null}
    </>
  );
}
