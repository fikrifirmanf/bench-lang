"use client";

import { useEffect, useRef, useState } from "react";

import type { SourceOrigin } from "@/lib/schema";

// MIT asks that copies of upstream's programs carry its copyright and license, so every one shown says so.
const UPSTREAM_LICENSE =
  "https://github.com/hanabi1224/Programming-Language-Benchmarks/blob/ad18b203dd1769724f4eea94fc3ac1e99f6593e0/LICENSE";

type Load = { state: "loading" } | { state: "ready"; html: string } | { state: "error" };

export function CodeView({ problem, file, origin, onClose }: {
  problem: string;
  file: string;
  origin: SourceOrigin;
  onClose: () => void;
}) {
  const [load, setLoad] = useState<Load>({ state: "loading" });
  const [attempt, setAttempt] = useState(0);
  const [copy, setCopy] = useState<"idle" | "copied" | "failed">("idle");
  const codeRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const controller = new AbortController();
    fetch(`/code/${problem}/${file}.txt`, { signal: AbortSignal.any([controller.signal, AbortSignal.timeout(15_000)]) })
      .then((res) => (res.ok ? res.text() : Promise.reject(new Error(`HTTP ${res.status}`))))
      .then((html) => setLoad({ state: "ready", html }))
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        console.error(`Could not load the code of ${problem}/${file}`, error);
        setLoad({ state: "error" });
      });
    return () => controller.abort();
  }, [problem, file, attempt]);

  const retry = () => {
    setLoad({ state: "loading" });
    setAttempt((n) => n + 1);
  };

  const copyCode = () => {
    navigator.clipboard.writeText(codeRef.current?.textContent ?? "").then(
      () => setCopy("copied"),
      () => setCopy("failed"),
    );
  };

  return (
    <div className="border-t-[2.5px] border-ink bg-paper p-4 sm:p-5">
      <div className="flex flex-wrap items-center gap-3">
        <span className="font-mono text-[15px] font-bold">{file}</span>
        <span className="text-[14px] text-ink-soft">
          {origin === "upstream" ? (
            <>
              From Programming-Language-Benchmarks · © 2021 hanabi1224 ·{" "}
              <a href={UPSTREAM_LICENSE} className="underline">
                MIT License
              </a>
            </>
          ) : (
            "Written for bench/lang"
          )}
        </span>
        <span className="ml-auto flex gap-2">
          <button
            type="button"
            onClick={copyCode}
            disabled={load.state !== "ready"}
            aria-live="polite"
            className={`press h-11 rounded-xl border-2 border-ink bg-card px-4 font-semibold shadow-brutal-sm disabled:opacity-50 ${
              copy === "failed" ? "text-alert" : ""
            }`}
          >
            {copy === "copied" ? "Copied" : copy === "failed" ? "Copy failed" : "Copy"}
          </button>
          <button
            type="button"
            onClick={onClose}
            className="press h-11 rounded-xl border-2 border-ink bg-lemon px-4 font-semibold shadow-brutal-sm"
          >
            Close
          </button>
        </span>
      </div>

      <div className="mt-3 overflow-hidden rounded-xl border-2 border-ink bg-card">
        {load.state === "loading" ? (
          <div role="status" aria-label="Loading code" className="space-y-2.5 p-4">
            {["w-2/5", "w-4/5", "w-3/5", "w-11/12", "w-1/2", "w-3/4", "w-2/3", "w-1/3"].map((width, i) => (
              <span key={i} className={`block h-3.5 animate-pulse rounded bg-stone ${width}`} />
            ))}
          </div>
        ) : load.state === "error" ? (
          <div className="flex flex-wrap items-center gap-4 p-5">
            <p className="text-pretty font-semibold">The code could not be loaded.</p>
            <button
              type="button"
              onClick={retry}
              className="press h-11 rounded-xl border-2 border-ink bg-lemon px-4 font-semibold shadow-brutal-sm"
            >
              Try again
            </button>
          </div>
        ) : (
          <div
            ref={codeRef}
            className="max-h-[560px] overflow-auto font-mono text-[13.5px] leading-relaxed [&_pre]:w-max [&_pre]:min-w-full [&_pre]:p-4 [&_pre]:font-mono [&_pre]:focus-visible:outline-2"
            // The fragment is Shiki's output for a file from this repository, generated at build time.
            dangerouslySetInnerHTML={{ __html: load.html }}
          />
        )}
      </div>
    </div>
  );
}
