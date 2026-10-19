import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mt-14 max-w-[720px] rounded-card border-[2.5px] border-ink bg-card p-8 shadow-brutal-lg">
      <p className="font-mono text-sm font-bold">404</p>
      <h1 className="text-balance mt-2 text-3xl font-bold">No benchmark here</h1>
      <p className="mt-3 text-lg text-ink-soft">That language or problem has no published results.</p>
      <div className="mt-6 flex flex-wrap gap-3">
        <Link href="/problems/" className="press inline-flex h-12 items-center rounded-xl border-[2.5px] border-ink bg-lemon px-5 font-bold shadow-brutal-sm">
          All problems
        </Link>
        <Link href="/languages/" className="press inline-flex h-12 items-center rounded-xl border-[2.5px] border-ink bg-card px-5 font-bold shadow-brutal-sm">
          All languages
        </Link>
      </div>
    </div>
  );
}
