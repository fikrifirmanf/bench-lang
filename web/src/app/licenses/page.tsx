import type { Metadata } from "next";

import { getSourceIndex, upstreamLicense } from "@/lib/sources";

export const metadata: Metadata = { title: "Licenses" };

export default function LicensesPage() {
  const upstream = getSourceIndex().programs.filter((p) => p.origin === "upstream").length;

  return (
    <>
      <h1 className="text-balance pt-14 text-[clamp(40px,5.5vw,68px)] leading-none font-bold tracking-[-0.035em]">
        Licenses
      </h1>
      <p className="text-pretty mt-4 max-w-[680px] text-[19px] text-ink-soft">
        {upstream} of the benchmark programs whose code this site shows come from Programming-Language-Benchmarks and
        are used under the license below.
      </p>
      <section aria-labelledby="upstream" className="mt-10 max-w-[760px]">
        <h2 id="upstream" className="text-balance text-2xl font-bold">
          Programming-Language-Benchmarks
        </h2>
        <pre className="mt-4 overflow-x-auto rounded-card border-[2.5px] border-ink bg-card p-6 font-mono text-[14px] leading-relaxed whitespace-pre-wrap shadow-brutal">
          {upstreamLicense()}
        </pre>
      </section>
    </>
  );
}
