import type { Metadata } from "next";

import { LeaderboardView, type BoardSet } from "@/components/LeaderboardView";
import { leaderboard } from "@/lib/analysis";
import { CATEGORIES, type Category } from "@/lib/catalog";
import { getProfiles } from "@/lib/data";
import { formatDate } from "@/lib/format";

export const metadata: Metadata = { title: "Leaderboard" };

const SCOPES: { id: "overall" | Category; label: string }[] = [{ id: "overall", label: "Overall" }, ...CATEGORIES];

export default function LeaderboardPage() {
  const sets: BoardSet[] = getProfiles().map((profile) => ({
    profile: profile.id,
    name: profile.name,
    date: formatDate(profile.run.started_at),
    boards: SCOPES.flatMap((scope) =>
      [false, true].map((allowMulti) => ({
        scope: scope.id,
        allowMulti,
        board: leaderboard(profile.run.rows, {
          category: scope.id === "overall" ? null : scope.id,
          allowMulti,
        }),
      })),
    ),
  }));

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-6 pt-14">
        <div className="min-w-0 flex-[1_1_560px]">
          <h1 className="text-balance text-[clamp(42px,6vw,72px)] leading-none font-bold tracking-[-0.035em]">Leaderboard</h1>
          <p className="mt-4 max-w-[640px] text-[19px] text-ink-soft">
            How far each language lands from the fastest result, averaged over every problem it solves. Lower is better.
          </p>
        </div>
      </div>
      <LeaderboardView sets={sets} scopes={SCOPES} />
    </>
  );
}
