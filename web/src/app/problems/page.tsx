import type { Metadata } from "next";
import Link from "next/link";

import { LangIcon } from "@/components/LangIcon";
import { formatMs, winners } from "@/lib/analysis";
import { CATEGORIES, CATEGORY_TINT, categoryLabel, langName, problemInfo } from "@/lib/catalog";
import { getDefaultProfile } from "@/lib/data";

export const metadata: Metadata = { title: "Problems" };

export default function ProblemsPage() {
  const { run } = getDefaultProfile();
  const all = winners(run.rows);
  const groups = [...CATEGORIES.map((c) => c.id), "startup" as const].map((category) => ({
    category,
    items: all.filter((w) => problemInfo(w.problem).category === category),
  }));

  return (
    <>
      <h1 className="text-balance pt-14 text-[clamp(42px,6vw,72px)] leading-none font-bold tracking-[-0.035em]">Problems</h1>
      <p className="mt-4 max-w-[640px] text-[19px] text-ink-soft">
        {all.length} workloads, each implemented in many languages and checked against the same expected output before it is
        timed.
      </p>
      <div className="mt-10 flex flex-col gap-10">
        {groups
          .filter((g) => g.items.length > 0)
          .map((group) => (
            <section key={group.category} aria-labelledby={`cat-${group.category}`}>
              <h2 id={`cat-${group.category}`} className="text-balance mb-4 flex items-center gap-3 text-2xl font-bold">
                <span className={`size-4 rounded border-2 border-ink ${CATEGORY_TINT[group.category]}`} aria-hidden="true" />
                {categoryLabel(group.category)}
              </h2>
              <ul className="overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal">
                {group.items.map(({ problem, row }) => (
                  <li key={problem} className="border-b-2 border-dashed border-line last:border-b-0">
                    <Link
                      href={`/problems/${problem}/`}
                      className="grid grid-cols-1 items-center gap-2 px-5 py-4 hover:bg-paper sm:grid-cols-[220px_minmax(0,1fr)_auto] sm:gap-5"
                    >
                      <span className="font-mono text-base font-bold">{problem}</span>
                      <span className="text-[15px] text-ink-soft">{problemInfo(problem).summary}</span>
                      {row ? (
                        <span className="inline-flex items-center gap-2.5">
                          <LangIcon slug={row.lang} size="sm" />
                          <span className="font-semibold">{langName(row.lang)}</span>
                          <span className="font-mono font-bold">{formatMs(row.time_ms)}</span>
                        </span>
                      ) : (
                        <span className="text-sm text-ink-soft">No result yet</span>
                      )}
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          ))}
      </div>
    </>
  );
}
