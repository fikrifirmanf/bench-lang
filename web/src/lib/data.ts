import { readFileSync } from "node:fs";
import path from "node:path";
import type { z } from "zod";

import { DataIndex, Run, ToolchainFile, VersionReport, type Toolchain } from "./schema";

// The site is built from the repository's data/ and bench/ folders, one level above web/.
const REPO_ROOT = process.env.BENCH_REPO_ROOT ?? path.join(process.cwd(), "..");

function readJson<T extends z.ZodType>(relative: string, schema: T): z.infer<T> {
  const file = path.join(REPO_ROOT, relative);
  const parsed = schema.safeParse(JSON.parse(readFileSync(file, "utf8")));
  if (!parsed.success) {
    throw new Error(`${relative} does not match its schema: ${parsed.error.message}`);
  }
  return parsed.data;
}

/** Reads a file once per build, however many pages ask for it. */
function once<T>(load: () => T): () => T {
  let value: { current: T } | undefined;
  return () => {
    value ??= { current: load() };
    return value.current;
  };
}

export const getIndex = once((): DataIndex => readJson("data/index.json", DataIndex));

export interface ProfileData {
  id: string;
  name: string;
  run: Run;
}

/** Profiles that have at least one published run, in the order bench/profiles.json lists them. */
export const getProfiles = once((): ProfileData[] =>
  getIndex()
    .profiles.filter((p) => p.latest_run !== null)
    .map((p) => ({ id: p.id, name: p.name, run: readJson(`data/latest/${p.id}.json`, Run) })),
);

export function readRun(profile: string, id: string): Run {
  return readJson(`data/runs/${profile}/${id}.json`, Run);
}

export function getDefaultProfile(): ProfileData {
  const first = getProfiles()[0];
  if (!first) throw new Error("data/ has no published runs; run `python -m runner import-site` first");
  return first;
}

export const getVersionReport = once((): VersionReport => readJson("data/versions.json", VersionReport));

export const getToolchains = once((): Toolchain[] => readJson("bench/toolchains.json", ToolchainFile).toolchains);
