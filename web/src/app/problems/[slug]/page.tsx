import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { LangIcon } from "@/components/LangIcon";
import { ProblemResults, type ProblemDataset } from "@/components/ProblemResults";
import { TrendChart, TrendEmpty } from "@/components/TrendChart";
import { formatMs, inputsOf, problemsIn } from "@/lib/analysis";
import { CATEGORY_TINT, categoryLabel, langName, problemInfo } from "@/lib/catalog";
import { getDefaultProfile, getProfiles } from "@/lib/data";
import { formatDate } from "@/lib/format";
import { getSnapshots, problemHistory } from "@/lib/history";
import { sourceOrigins } from "@/lib/sources";

interface Params {
  params: Promise<{ slug: string }>;
}

export function generateStaticParams() {
  return problemsIn(getDefaultProfile().run.rows).map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { slug } = await params;
  return { title: slug, description: problemInfo(slug).summary };
}

export default async function ProblemPage({ params }: Params) {
  const { slug } = await params;
  const datasets: ProblemDataset[] = getProfiles()
    .map((p) => ({
      profile: p.id,
      name: p.name,
      date: formatDate(p.run.started_at),
      inputs: inputsOf(p.run.rows, slug),
      rows: p.run.rows.filter((r) => r.problem === slug),
    }))
    .filter((d) => d.rows.length > 0);
  if (datasets.length === 0) notFound();
  const info = problemInfo(slug);

  const profile = getDefaultProfile();
  const snapshots = getSnapshots(profile.id);
  const times = problemHistory(snapshots, slug);
  const top = [...(times.at(-1) ?? new Map<string, number>())]
    .sort((a, b) => a[1] - b[1])
    .slice(0, 5)
    .map(([lang]) => lang);

  return (
    <>
      <nav aria-label="Breadcrumb" className="pt-10 text-[15px]">
        <Link href="/problems/" className="font-semibold underline">
          Problems
        </Link>{" "}
        / {slug}
      </nav>
      <div className="mt-4 flex flex-wrap items-center gap-4">
        <h1 className="text-balance font-mono text-[clamp(36px,5vw,60px)] leading-none font-bold tracking-[-0.03em]">{slug}</h1>
        <span className={`rounded-full border-2 border-ink px-3 py-1 text-sm font-semibold ${CATEGORY_TINT[info.category]}`}>
          {categoryLabel(info.category)}
        </span>
      </div>
      <p className="mt-4 max-w-[640px] text-[19px] text-ink-soft">{info.summary}</p>
      <ProblemResults problem={slug} datasets={datasets} origins={sourceOrigins(slug)} />

      <section aria-labelledby="history" className="mt-14">
        <h2 id="history" className="text-balance text-3xl font-bold">
          Fastest times over time
        </h2>
        <p className="mt-1 mb-4 text-ink-soft">
          Today&apos;s top {top.length} on {profile.name}, single-thread, largest input. Log scale.
        </p>
        {snapshots.length < 2 || top.length === 0 ? (
          <TrendEmpty date={snapshots[0] ? formatDate(snapshots[0].startedAt) : null} />
        ) : (
          <div className="rounded-card border-[2.5px] border-ink bg-card p-5 shadow-brutal-lg">
            <TrendChart
              caption={`Fastest ${slug} time per run for ${top.map(langName).join(", ")}`}
              dates={snapshots.map((s) => formatDate(s.startedAt))}
              series={top.map((lang) => ({
                id: lang,
                name: langName(lang),
                label: (
                  <>
                    <LangIcon slug={lang} size="sm" />
                    {langName(lang)}
                  </>
                ),
                values: times.map((t) => t.get(lang) ?? null),
              }))}
              format={formatMs}
              log
            />
          </div>
        )}
      </section>
    </>
  );
}
