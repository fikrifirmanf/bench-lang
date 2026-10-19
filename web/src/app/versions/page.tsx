import type { Metadata } from "next";

import { LangIcon } from "@/components/LangIcon";
import { langsIn } from "@/lib/analysis";
import { langName } from "@/lib/catalog";
import { getDefaultProfile, getToolchains, getVersionReport } from "@/lib/data";
import { formatDate } from "@/lib/format";

export const metadata: Metadata = { title: "Versions" };

const STEPS = [
  { title: "Detect", body: "A daily job reads Docker Hub, MCR and GitHub tags for each toolchain's newest stable release.", tool: "versions.yml" },
  { title: "Propose", body: "Newer versions are written to bench/toolchains.json and opened as a pull request.", tool: "create-pull-request" },
  { title: "Benchmark", body: "The pull request rebuilds and reruns the changed toolchains on the pinned runner.", tool: "bench.yml" },
  { title: "Publish", body: "On merge, results land in data/ and the static site redeploys.", tool: "Vercel" },
];

const STATUS_STYLE = {
  behind: { label: "newer release", tint: "bg-coral" },
  current: { label: "up to date", tint: "bg-mint" },
  unknown: { label: "check failed", tint: "bg-stone" },
} as const;

export default function VersionsPage() {
  const report = getVersionReport();
  const toolchains = new Map(getToolchains().map((t) => [t.id, t]));
  const automated = new Set(getToolchains().map((t) => t.lang));
  const manual = langsIn(getDefaultProfile().run.rows).filter((l) => !automated.has(l));
  const behind = report.toolchains.filter((t) => t.status === "behind").length;

  return (
    <>
      <h1 className="text-balance max-w-[820px] pt-14 text-[clamp(40px,5.5vw,68px)] leading-none font-bold tracking-[-0.035em]">
        Always on the latest toolchains
      </h1>
      <p className="mt-4 max-w-[680px] text-[19px] text-ink-soft">
        Every compiler and runtime is pinned to an exact image tag. A bot checks for new releases daily and opens a pull
        request that reruns the benchmarks.
      </p>

      <section aria-labelledby="pipe" className="mt-10 rounded-card border-[2.5px] border-ink bg-card p-6 shadow-brutal-lg">
        <h2 id="pipe" className="text-balance mb-5 text-lg font-bold">
          How an update ships
        </h2>
        <ol className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-6">
          {STEPS.map((step, i) => (
            <li key={step.title} className="flex flex-col gap-2">
              <div className="flex items-center gap-3">
                <span className="inline-flex size-9 items-center justify-center rounded-[10px] border-2 border-ink bg-lemon font-mono font-bold">
                  {i + 1}
                </span>
                <span aria-hidden="true" className={`h-[3px] flex-1 rounded ${i === STEPS.length - 1 ? "bg-transparent" : "bg-ink"}`} />
              </div>
              <span className="text-lg font-bold">{step.title}</span>
              <p className="text-[15px] text-ink-soft">{step.body}</p>
              <code className="font-mono text-xs">{step.tool}</code>
            </li>
          ))}
        </ol>
      </section>

      <section aria-labelledby="track" className="mt-14">
        <div className="mb-4 flex flex-wrap items-baseline justify-between gap-3">
          <h2 id="track" className="text-balance text-3xl font-bold">
            Version tracker
          </h2>
          <span className="font-mono text-[13px] text-ink-soft">
            Checked {formatDate(report.checked_at)} · {behind} of {report.toolchains.length} behind
          </span>
        </div>
        {report.toolchains.length === 0 ? (
          <p className="rounded-card border-[2.5px] border-dashed border-ink bg-card p-6">
            No version check has run yet. Run <code className="font-mono">python -m runner versions</code>.
          </p>
        ) : (
          <div className="overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[820px] border-collapse">
                <thead>
                  <tr className="border-b-[2.5px] border-ink bg-sky text-left text-sm">
                    <th scope="col" className="px-5 py-3.5 font-bold">Language</th>
                    <th scope="col" className="px-5 py-3.5 font-bold">Toolchain</th>
                    <th scope="col" className="px-5 py-3.5 font-bold">Pinned</th>
                    <th scope="col" className="px-5 py-3.5 font-bold">Newest stable</th>
                    <th scope="col" className="px-5 py-3.5 font-bold">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {report.toolchains.map((t) => {
                    const style = STATUS_STYLE[t.status];
                    return (
                      <tr key={t.id} className="border-t-2 border-dashed border-line first:border-t-0">
                        <td className="px-5 py-2.5">
                          <span className="inline-flex min-h-11 items-center gap-2.5 font-semibold">
                            <LangIcon slug={t.lang} size="sm" />
                            {langName(t.lang)}
                          </span>
                        </td>
                        <td className="px-5 py-2.5">
                          <span className="font-mono text-[15px] font-bold">{t.compiler}</span>
                          <span className="block font-mono text-xs text-ink-soft">{toolchains.get(t.id)?.image.replace("{version}", t.current)}</span>
                        </td>
                        <td className="px-5 py-2.5 font-mono">{t.current}</td>
                        <td className="px-5 py-2.5 font-mono font-bold">{t.latest ?? "–"}</td>
                        <td className="px-5 py-2.5">
                          <span title={t.error ?? undefined} className={`inline-flex h-7 items-center rounded-full border-2 border-ink px-3 text-sm font-semibold ${style.tint}`}>
                            {style.label}
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

      {manual.length > 0 ? (
        <section aria-labelledby="manual" className="mt-14 rounded-card border-[2.5px] border-dashed border-ink bg-card p-6">
          <h2 id="manual" className="text-balance text-2xl font-bold">
            Not automated yet
          </h2>
          <p className="mt-2 mb-4 max-w-[700px] text-ink-soft">
            These languages have no pinned toolchain image yet, so their results stay at the last imported run. Adding one is a
            single entry in <code className="font-mono">bench/toolchains.json</code>.
          </p>
          <ul className="flex flex-wrap gap-2.5">
            {manual.map((lang) => (
              <li key={lang} className="inline-flex h-12 items-center gap-2.5 rounded-xl border-2 border-ink bg-paper pr-3.5 pl-1.5 font-semibold">
                <LangIcon slug={lang} size="sm" bordered={false} />
                {langName(lang)}
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </>
  );
}
