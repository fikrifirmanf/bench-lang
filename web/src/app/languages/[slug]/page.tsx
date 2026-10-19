import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { LangIcon } from "@/components/LangIcon";
import { LanguageCompare, type BestTimes } from "@/components/LanguageCompare";
import { TrendChart, TrendEmpty } from "@/components/TrendChart";
import { bestPerLang, formatMb, formatMs, formatRatio, langResults, langsIn, leaderboard, problemsIn, UNSCORED } from "@/lib/analysis";
import { langName } from "@/lib/catalog";
import { getDefaultProfile } from "@/lib/data";
import { formatDate } from "@/lib/format";
import { getSnapshots, langHistory } from "@/lib/history";

interface Params {
  params: Promise<{ slug: string }>;
}

export function generateStaticParams() {
  return langsIn(getDefaultProfile().run.rows).map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { slug } = await params;
  return { title: langName(slug) };
}

export default async function LanguagePage({ params }: Params) {
  const { slug } = await params;
  const profile = getDefaultProfile();
  const { run } = profile;
  const rows = run.rows;
  const own = rows.filter((r) => r.lang === slug);
  if (own.length === 0) notFound();

  const compilers = [...new Set(own.map((r) => `${r.compiler} ${r.version}`.trim()))].sort();
  const results = langResults(rows, slug).filter((r) => !UNSCORED.has(r.problem));
  const board = leaderboard(rows, { category: null, allowMulti: false });
  const rankIndex = board.ranked.findIndex((s) => s.lang === slug);
  const standing = [...board.ranked, ...board.provisional].find((s) => s.lang === slug);
  const failed = own.filter((r) => r.status !== "ok").length;

  const best: BestTimes = {};
  for (const problem of problemsIn(rows).filter((p) => !UNSCORED.has(p))) {
    for (const [lang, row] of bestPerLang(rows, problem, false)) {
      best[lang] = { ...best[lang], [problem]: { time: row.time_ms, code: row.code } };
    }
  }
  const others = langsIn(rows).filter((l) => l !== slug);
  const defaultOther = board.ranked.find((s) => s.lang !== slug)?.lang ?? others[0] ?? "";

  const history = langHistory(getSnapshots(profile.id), slug);
  const recent = history
    .map((point, i) => ({ point, change: describeChange(point.score, history[i - 1]?.score) }))
    .slice(-10)
    .reverse();

  return (
    <>
      <nav aria-label="Breadcrumb" className="pt-10 text-[15px]">
        <Link href="/languages/" className="font-semibold underline">
          Languages
        </Link>{" "}
        / {langName(slug)}
      </nav>
      <div className="mt-5 flex flex-wrap items-center gap-6">
        <LangIcon slug={slug} size="lg" />
        <div className="min-w-0 flex-[1_1_320px]">
          <h1 className="text-balance text-[clamp(40px,5.5vw,64px)] leading-none font-bold tracking-[-0.03em]">{langName(slug)}</h1>
          <p className="mt-2 font-mono text-sm text-ink-soft">{compilers.join(" · ")}</p>
        </div>
      </div>

      <section aria-label="Summary" className="mt-8 grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
        <Stat label="Overall rank" value={rankIndex >= 0 ? `#${rankIndex + 1}` : "unranked"} tint="bg-lemon" />
        <Stat label="Score" value={standing ? formatRatio(standing.score) : "–"} tint="bg-mint" />
        <Stat label="Problems covered" value={`${results.length}/${board.problems.length}`} tint="bg-sky" />
        <Stat label="Did not finish" value={String(failed)} tint="bg-card" />
      </section>

      <section aria-labelledby="best" className="mt-14">
        <h2 id="best" className="text-balance mb-4 text-3xl font-bold">
          Best result per problem
        </h2>
        {results.length === 0 ? (
          <p className="rounded-card border-[2.5px] border-dashed border-ink bg-card p-6">
            No finished single-thread results yet. Check the problem pages for timeouts and failures.
          </p>
        ) : (
          <div className="overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] border-collapse">
                <thead>
                  <tr className="border-b-[2.5px] border-ink bg-sky text-left text-sm">
                    <th scope="col" className="px-5 py-3.5 font-bold">Problem</th>
                    <th scope="col" className="px-5 py-3.5 font-bold">Rank</th>
                    <th scope="col" className="px-5 py-3.5 font-bold">Code</th>
                    <th scope="col" className="px-5 py-3.5 text-right font-bold">Time</th>
                    <th scope="col" className="px-5 py-3.5 text-right font-bold">Peak mem</th>
                  </tr>
                </thead>
                <tbody>
                  {results.map((r) => (
                    <tr key={r.problem} className="border-t-2 border-dashed border-line first:border-t-0">
                      <td className="px-5 py-3">
                        <Link href={`/problems/${r.problem}/`} className="font-mono font-bold underline">
                          {r.problem}
                        </Link>
                      </td>
                      <td className="px-5 py-3">
                        <span className={`rounded-lg border-2 border-ink px-2 py-0.5 font-mono text-sm font-bold ${r.rank === 1 ? "bg-lemon" : "bg-card"}`}>
                          #{r.rank} of {r.of}
                        </span>
                      </td>
                      <td className="px-5 py-3 font-mono text-[15px]">{r.row.code}</td>
                      <td className="px-5 py-3 text-right font-mono font-bold">{formatMs(r.row.time_ms)}</td>
                      <td className="px-5 py-3 text-right font-mono">{formatMb(r.row.peak_mem_mb)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </section>

      {others.length > 0 ? <LanguageCompare lang={slug} others={others} initial={defaultOther} best={best} /> : null}

      <section aria-labelledby="history" className="mt-14">
        <h2 id="history" className="text-balance text-3xl font-bold">
          Over time
        </h2>
        <p className="mt-1 mb-4 text-ink-soft">Overall score after each run on {profile.name}. Lower is faster.</p>
        {history.length < 2 ? (
          <TrendEmpty date={history[0] ? formatDate(history[0].startedAt) : null} />
        ) : (
          <div className="rounded-card border-[2.5px] border-ink bg-card p-5 shadow-brutal-lg">
            <TrendChart
              caption={`${langName(slug)} overall score per run`}
              dates={history.map((p) => formatDate(p.startedAt))}
              series={[{ id: slug, name: langName(slug), label: langName(slug), values: history.map((p) => p.score) }]}
              format={formatRatio}
            />
            <div className="mt-6 overflow-x-auto">
              <table className="w-full min-w-[640px] border-collapse">
                <caption className="sr-only">Recent runs, newest first</caption>
                <thead>
                  <tr className="border-b-[2.5px] border-ink text-left text-sm">
                    <th scope="col" className="px-3 py-2.5 font-bold">Run</th>
                    <th scope="col" className="px-3 py-2.5 font-bold">Version</th>
                    <th scope="col" className="px-3 py-2.5 font-bold">Rank</th>
                    <th scope="col" className="px-3 py-2.5 text-right font-bold">Score</th>
                    <th scope="col" className="px-3 py-2.5 text-right font-bold">Change</th>
                  </tr>
                </thead>
                <tbody>
                  {recent.map(({ point, change }) => (
                    <tr key={point.runId} className="border-t-2 border-dashed border-line first:border-t-0">
                      <td className="px-3 py-2.5 font-mono text-sm">
                        {formatDate(point.startedAt)}
                        {point.source === "import" ? (
                          <span className="ml-2 rounded-full border-[1.5px] border-ink bg-stone px-2 font-sans text-xs font-semibold">
                            imported
                          </span>
                        ) : null}
                      </td>
                      <td className="px-3 py-2.5 font-mono text-sm text-ink-soft">{point.versions.join(" · ")}</td>
                      <td className="px-3 py-2.5 font-mono font-bold">{point.rank ? `#${point.rank}` : "unranked"}</td>
                      <td className="px-3 py-2.5 text-right font-mono font-bold">{point.score === null ? "–" : formatRatio(point.score)}</td>
                      <td className="px-3 py-2.5 text-right font-mono text-sm">{change}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </section>
    </>
  );
}

/** Score change from the previous run; the score is a time ratio, so lower means faster. */
function describeChange(score: number | null, previous: number | null | undefined): string {
  if (score === null || previous === null || previous === undefined) return "–";
  const pct = (score / previous - 1) * 100;
  if (Math.abs(pct) < 0.5) return "no change";
  return pct < 0 ? `${Math.abs(pct).toFixed(1)}% faster` : `${pct.toFixed(1)}% slower`;
}

function Stat({ label, value, tint }: { label: string; value: string; tint: string }) {
  return (
    <div className={`border-b-[2.5px] border-ink px-6 py-5 sm:border-r-[2.5px] sm:border-b-0 sm:last:border-r-0 ${tint}`}>
      <div className="font-mono text-[34px] leading-none font-bold">{value}</div>
      <div className="mt-1.5 font-semibold">{label}</div>
    </div>
  );
}
