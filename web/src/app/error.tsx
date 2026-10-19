"use client";

import Link from "next/link";

export default function ErrorPage({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div role="alert" className="mt-14 max-w-[720px] rounded-card border-[2.5px] border-ink bg-coral p-8 shadow-brutal-lg">
      <h1 className="text-balance text-3xl font-bold">This page could not load</h1>
      <p className="mt-3 text-lg">
        Something went wrong while showing these results. Your filters are kept if you try again.
      </p>
      {error.digest ? <p className="mt-2 font-mono text-sm">Reference: {error.digest}</p> : null}
      <div className="mt-6 flex flex-wrap gap-3">
        <button
          type="button"
          onClick={reset}
          className="press h-12 rounded-xl border-[2.5px] border-ink bg-card px-5 font-bold shadow-brutal-sm"
        >
          Try again
        </button>
        <Link href="/" className="inline-flex h-12 items-center rounded-xl px-2 font-bold underline">
          Go to the home page
        </Link>
      </div>
    </div>
  );
}
