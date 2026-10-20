const DATE = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" });

export function formatDate(iso: string): string {
  return DATE.format(new Date(iso));
}

export function latestMeasuredAt(dates: string[]): string {
  return dates.reduce((max, d) => (d > max ? d : max), "");
}

/** Element id of a program's row on its problem page; `#<id>` opens that program's code. */
export function codeAnchor(lang: string, compiler: string, file: string): string {
  return `code-${lang}-${compiler}-${file}`.replace(/[^A-Za-z0-9_-]+/g, "-");
}
