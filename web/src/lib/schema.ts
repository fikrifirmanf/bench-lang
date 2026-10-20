import { z } from "zod";

export const Status = z.enum(["ok", "fail", "build-fail", "timeout", "oom", "wrong-output"]);
export type Status = z.infer<typeof Status>;

export const ResultRow = z.object({
  problem: z.string(),
  input: z.string(),
  input_index: z.number().int().nonnegative(),
  lang: z.string(),
  compiler: z.string(),
  version: z.string(),
  code: z.string(),
  flags: z.array(z.string()),
  status: Status,
  time_ms: z.number().nullable(),
  stddev_ms: z.number().nullable(),
  user_ms: z.number().nullable(),
  sys_ms: z.number().nullable(),
  peak_mem_mb: z.number().nullable(),
  measured_at: z.string(),
});
export type ResultRow = z.infer<typeof ResultRow>;

export const Machine = z.object({
  profile: z.string(),
  cpu: z.string(),
  cores: z.number().int(),
  memory_mb: z.number().int(),
  os: z.string(),
  arch: z.string(),
});
export type Machine = z.infer<typeof Machine>;

export const Run = z.object({
  id: z.string(),
  profile: z.string(),
  source: z.enum(["runner", "import"]),
  started_at: z.string(),
  upstream_commit: z.string().nullable(),
  machine: Machine,
  rows: z.array(ResultRow),
});
export type Run = z.infer<typeof Run>;

export const DataIndex = z.object({
  profiles: z.array(z.object({ id: z.string(), name: z.string(), latest_run: z.string().nullable() })),
  runs: z.array(
    z.object({
      id: z.string(),
      profile: z.string(),
      started_at: z.string(),
      source: z.enum(["runner", "import"]),
      rows: z.number().int(),
    }),
  ),
});
export type DataIndex = z.infer<typeof DataIndex>;

export const VersionReport = z.object({
  checked_at: z.string(),
  toolchains: z.array(
    z.object({
      id: z.string(),
      lang: z.string(),
      compiler: z.string(),
      current: z.string(),
      latest: z.string().nullable(),
      status: z.enum(["current", "behind", "unknown"]),
      error: z.string().nullable(),
    }),
  ),
});
export type VersionReport = z.infer<typeof VersionReport>;

export const ToolchainFile = z.object({
  toolchains: z.array(
    z.object({
      id: z.string(),
      lang: z.string(),
      compiler: z.string(),
      version: z.string(),
      image: z.string(),
      exclude_profiles: z.array(z.string()).optional(),
    }),
  ),
});
export type Toolchain = z.infer<typeof ToolchainFile>["toolchains"][number];

export const SourceIndex = z.object({
  programs: z.array(
    z.object({
      problem: z.string(),
      file: z.string(),
      origin: z.enum(["own", "upstream"]),
    }),
  ),
});
export type SourceIndex = z.infer<typeof SourceIndex>;
export type SourceOrigin = SourceIndex["programs"][number]["origin"];
