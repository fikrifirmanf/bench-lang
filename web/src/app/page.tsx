import Link from "next/link";

import { LangIcon } from "@/components/LangIcon";
import { formatMs, formatRatio, langsIn, leaderboard, winners } from "@/lib/analysis";
import { CATEGORY_TINT, categoryLabel, langName, problemInfo } from "@/lib/catalog";
import { getDefaultProfile } from "@/lib/data";
import { formatDate, latestMeasuredAt } from "@/lib/format";

const RANK_TINT = ["bg-lemon", "bg-stone", "bg-coral"];

export default function HomePage() {
  const { run } = getDefaultProfile();
  const rows = run.rows;
  const langs = langsIn(rows);
  const board = leaderboard(rows, { category: null, allowMulti: false });
  const top = board.ranked.slice(0, 5);
  const wins = winners(rows);
  const updated = formatDate(latestMeasuredAt(rows.map((r) => r.measured_at)));

  return (
    <>
      <section className="flex flex-wrap items-stretch gap-8 pt-16 pb-10">
        <div className="min-w-0 flex-[999_1_560px]">
          <p className="mb-6 inline-flex items-center gap-2 rounded-full border-2 border-ink bg-card px-3.5 py-1.5 font-mono text-[13px] font-medium">
            Latest results · {updated}
          </p>
          <h1 className="text-balance text-[clamp(42px,6vw,76px)] leading-none font-bold tracking-[-0.035em]">
            Same machine. Same run.{" "}
            <span className="rounded-[14px] bg-lemon px-2.5 [box-decoration-break:clone]">{langs.length} languages</span>, side
            by side.
          </h1>
          <p className="mt-7 max-w-[600px] text-xl text-ink-soft">
            Compare languages, compilers and runtimes across {wins.length} problems. Every result in a run comes from one
            machine, so the numbers are comparable.
          </p>
          <div className="mt-9 flex flex-wrap gap-3.5">
            <Link
              href="/leaderboard/"
              className="press inline-flex h-[54px] items-center rounded-[14px] border-[2.5px] border-ink bg-lemon px-6 text-lg font-bold shadow-brutal"
            >
              See the leaderboard
            </Link>
            <Link
              href="/problems/"
              className="press inline-flex h-[54px] items-center rounded-[14px] border-[2.5px] border-ink bg-card px-6 text-lg font-bold shadow-brutal"
            >
              Browse problems
            </Link>
          </div>
        </div>

        <section
          aria-labelledby="top5"
          className="flex flex-[1_1_360px] flex-col self-start overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg"
        >
          <div className="flex items-center justify-between gap-3 border-b-[2.5px] border-ink bg-sky px-5 py-4">
            <h2 id="top5" className="text-balance text-lg font-bold">
              Overall top 5
            </h2>
            <span className="font-mono text-xs font-medium">× fastest · lower wins</span>
          </div>
          <ol className="flex flex-1 flex-col px-5 pt-2 pb-3">
            {top.map((s, i) => (
              <li key={s.lang} className="grid min-h-14 grid-cols-[32px_40px_minmax(0,1fr)_auto] items-center gap-3 border-b-2 border-dashed border-line last:border-b-0">
                <span className={`inline-flex size-[30px] items-center justify-center rounded-[9px] border-2 border-ink font-mono text-sm font-bold ${RANK_TINT[i] ?? "bg-card"}`}>
                  {i + 1}
                </span>
                <LangIcon slug={s.lang} />
                <Link href={`/languages/${s.lang}/`} className="text-lg font-semibold hover:underline">
                  {langName(s.lang)}
                </Link>
                <span className="font-mono text-base font-bold">{formatRatio(s.score)}</span>
              </li>
            ))}
          </ol>
        </section>
      </section>

      <section aria-label="Run facts" className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
        <Fact value={String(langs.length)} label="languages" tint="bg-lemon" />
        <Fact value={String(wins.length)} label="problems" tint="bg-mint" />
        <Fact value={rows.length.toLocaleString("en-US")} label="results" tint="bg-coral" />
        <div className="border-ink px-6 py-5">
          <div className="font-mono text-xl leading-tight font-bold">{run.machine.cpu.replace(/ \d+-Core Processor$/, "")}</div>
          <div className="mt-1.5 font-semibold">
            {run.machine.cores} cores · {Math.round(run.machine.memory_mb / 1024)} GB
          </div>
        </div>
      </section>

      <section aria-labelledby="probs" className="pt-18">
        <div className="mb-5 flex flex-wrap items-baseline justify-between gap-3">
          <h2 id="probs" className="text-balance text-4xl font-bold tracking-[-0.02em]">
            Problems and who wins them
          </h2>
          <span className="text-[15px] text-ink-soft">Fastest single-thread result, largest input</span>
        </div>
        <div className="overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
          <ul className="-mb-0.5 grid grid-cols-[repeat(auto-fill,minmax(min(100%,540px),1fr))]">
            {wins.map(({ problem, row }) => {
              const info = problemInfo(problem);
              return (
                <li key={problem} className="border-b-2 border-ink">
                  <Link href={`/problems/${problem}/`} className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-5 py-4 hover:bg-paper">
                    <span className="flex min-w-0 flex-wrap items-center gap-2.5">
                      <span className="font-mono text-base font-bold">{problem}</span>
                      <span className={`rounded-full border-2 border-ink px-2.5 py-0.5 text-xs font-semibold ${CATEGORY_TINT[info.category]}`}>
                        {categoryLabel(info.category)}
                      </span>
                    </span>
                    {row ? (
                      <span className="inline-flex items-center gap-2.5">
                        <LangIcon slug={row.lang} size="sm" />
                        <span className="min-w-16 font-semibold">{langName(row.lang)}</span>
                        <span className="min-w-16 text-right font-mono text-[15px] font-bold">{formatMs(row.time_ms)}</span>
                      </span>
                    ) : (
                      <span className="text-sm text-ink-soft">No result yet</span>
                    )}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      </section>

      <section aria-labelledby="langs" className="pt-18">
        <h2 id="langs" className="text-balance mb-5 text-4xl font-bold tracking-[-0.02em]">
          Languages
        </h2>
        <ul className="flex flex-wrap gap-2.5">
          {langs.map((lang) => (
            <li key={lang}>
              <Link
                href={`/languages/${lang}/`}
                className="press inline-flex h-[50px] items-center gap-2.5 rounded-[14px] border-[2.5px] border-ink bg-card pr-4 pl-2 font-semibold shadow-brutal-sm"
              >
                <LangIcon slug={lang} size="sm" bordered={false} />
                {langName(lang)}
              </Link>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="meth" className="mt-18 flex flex-wrap gap-x-14 gap-y-6 rounded-card bg-ink p-9 text-paper">
        <h2 id="meth" className="text-balance flex-[1_1_240px] text-[28px] font-bold">
          Before you quote a number
        </h2>
        <ol className="flex flex-[999_1_520px] list-decimal flex-col gap-3 pl-5 text-stone">
          <li>Every language in a run is measured on the same machine in the same job, so results compare fairly within a run.</li>
          <li>
            Implementations differ. Files marked multi-thread, intrinsics or native lib use those techniques. Read the source
            before comparing.
          </li>
          <li>Your laptop is not your production host. Run the suite where your code ships.</li>
        </ol>
      </section>
    </>
  );
}

function Fact({ value, label, tint }: { value: string; label: string; tint: string }) {
  return (
    <div className={`border-b-[2.5px] border-ink px-6 py-5 sm:border-r-[2.5px] sm:border-b-0 ${tint}`}>
      <div className="font-mono text-[44px] leading-none font-bold">{value}</div>
      <div className="mt-1.5 font-semibold">{label}</div>
    </div>
  );
}
