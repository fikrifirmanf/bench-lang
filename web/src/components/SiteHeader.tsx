"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const LINKS = [
  { href: "/leaderboard/", label: "Leaderboard" },
  { href: "/problems/", label: "Problems" },
  { href: "/languages/", label: "Languages" },
  { href: "/versions/", label: "Versions" },
];

export function SiteHeader() {
  const pathname = usePathname();
  return (
    <header className="mx-auto max-w-[1240px] px-4 pt-6 sm:px-6">
      <div className="flex flex-wrap items-center gap-x-6 gap-y-3 rounded-[18px] border-[2.5px] border-ink bg-card py-3 pr-3 pl-5 shadow-brutal">
        <Link href="/" className="font-mono text-[19px] font-bold">
          bench<span className="rounded bg-lemon px-1">/</span>lang
        </Link>
        <nav
          aria-label="Primary"
          className="order-last -mx-1 flex w-full gap-1.5 overflow-x-auto px-1 md:order-none md:mx-0 md:w-auto md:flex-1 md:overflow-visible md:px-0"
        >
          {LINKS.map((link) => {
            const active = pathname.startsWith(link.href.slice(0, -1));
            return (
              <Link
                key={link.href}
                href={link.href}
                aria-current={active ? "page" : undefined}
                className={`inline-flex h-11 shrink-0 items-center rounded-xl px-4 font-semibold ${
                  active ? "border-2 border-ink bg-lemon" : "hover:bg-paper"
                }`}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>
        <a
          href="https://github.com/hanabi1224/Programming-Language-Benchmarks"
          className="ml-auto inline-flex h-11 items-center rounded-xl border-[2.5px] border-ink bg-ink px-4 font-semibold text-card md:ml-0"
        >
          <span className="sm:hidden">Source</span>
          <span className="hidden sm:inline">Benchmark source</span>
        </a>
      </div>
    </header>
  );
}
