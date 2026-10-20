import { getSourceIndex, highlightSource } from "@/lib/sources";

// One static HTML fragment per program (out/code/<problem>/<file>.html), fetched when a visitor opens its code,
// so problem pages stay small.
export const dynamic = "force-static";

const SUFFIX = ".html";

export function generateStaticParams() {
  return getSourceIndex().programs.map((p) => ({ problem: p.problem, file: `${p.file}${SUFFIX}` }));
}

export async function GET(_request: Request, { params }: { params: Promise<{ problem: string; file: string }> }) {
  const { problem, file } = await params;
  const html = await highlightSource(problem, file.slice(0, -SUFFIX.length));
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
}
