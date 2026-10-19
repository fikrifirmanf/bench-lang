const DATE = new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" });

export function formatDate(iso: string): string {
  return DATE.format(new Date(iso));
}

export function latestMeasuredAt(dates: string[]): string {
  return dates.reduce((max, d) => (d > max ? d : max), "");
}
