import type { Metadata } from "next";
import Link from "next/link";

import { LangIcon } from "@/components/LangIcon";
import { formatRatio, langsIn, leaderboard } from "@/lib/analysis";
import { langName } from "@/lib/catalog";
import { getDefaultProfile } from "@/lib/data";

export const metadata: Metadata = { title: "Languages" };

export default function LanguagesPage() {
  const { run } = getDefaultProfile();
  const board = leaderboard(run.rows, { category: null, allowMulti: false });
  const standing = new Map([...board.ranked, ...board.provisional].map((s) => [s.lang, s]));
  const rank = new Map(board.ranked.map((s, i) => [s.lang, i + 1]));
  const langs = langsIn(run.rows).sort((a, b) => langName(a).localeCompare(langName(b)));

  return (
    <>
      <h1 className="text-balance pt-14 text-[clamp(42px,6vw,72px)] leading-none font-bold tracking-[-0.035em]">Languages</h1>
      <p className="mt-4 max-w-[640px] text-[19px] text-ink-soft">
        {langs.length} languages. Open one to see where it wins, where it loses, and how it compares head to head.
      </p>
      <ul className="mt-10 overflow-hidden rounded-card border-[2.5px] border-ink bg-card shadow-brutal-lg">
        {langs.map((lang) => {
          const s = standing.get(lang);
          const r = rank.get(lang);
          return (
            <li key={lang} className="border-b-2 border-dashed border-line last:border-b-0">
              <Link href={`/languages/${lang}/`} className="grid grid-cols-[40px_minmax(0,1fr)_auto] items-center gap-4 px-5 py-3 hover:bg-paper">
                <LangIcon slug={lang} />
                <span className="text-lg font-semibold">{langName(lang)}</span>
                <span className="font-mono text-sm">
                  {r ? (
                    <span className="rounded-lg border-2 border-ink bg-lemon px-2 py-0.5 font-bold">#{r}</span>
                  ) : (
                    <span className="text-ink-soft">unranked</span>
                  )}{" "}
                  {s ? `${formatRatio(s.score)} · ${s.coverage}/${board.problems.length}` : "no scored results"}
                </span>
              </Link>
            </li>
          );
        })}
      </ul>
    </>
  );
}
