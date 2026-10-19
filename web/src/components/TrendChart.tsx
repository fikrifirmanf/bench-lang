import type { ReactNode } from "react";

export interface TrendSeries {
  id: string;
  label: ReactNode;
  /** Plain-text name for the screen-reader table. */
  name: string;
  values: (number | null)[];
}

interface Props {
  caption: string;
  dates: string[];
  series: TrendSeries[];
  format: (value: number) => string;
  log?: boolean;
}

// Literal class strings so Tailwind generates them; series take colors in this order.
const STROKE = ["stroke-chart-1", "stroke-chart-2", "stroke-chart-3", "stroke-chart-4", "stroke-chart-5"];
const FILL = ["bg-chart-1", "bg-chart-2", "bg-chart-3", "bg-chart-4", "bg-chart-5"];
const TICKS = 4;
// Keep lines off the top and bottom edges so the extremes stay visible.
const PAD = 8;

/** Shown until a profile has two runs to draw a line between. */
export function TrendEmpty({ date }: { date: string | null }) {
  return (
    <div className="rounded-card border-[2.5px] border-dashed border-ink bg-card p-6">
      <p className="font-semibold">History starts with the next benchmark run.</p>
      <p className="mt-1 text-ink-soft">
        {date ? `Only one run so far (${date}). ` : "No runs yet. "}
        Every run adds a point here; older runs are kept in the repository, never overwritten.
      </p>
    </div>
  );
}

/**
 * Line chart for values across runs. The SVG stretches to any width, so text and dots are
 * HTML positioned on top of it instead of SVG elements that would distort.
 */
export function TrendChart({ caption, dates, series, format, log = false }: Props) {
  const scale = (v: number) => (log ? Math.log(v) : v);
  const unscale = (v: number) => (log ? Math.exp(v) : v);
  const all = series.flatMap((s) => s.values.filter((v): v is number => v !== null && (!log || v > 0)).map(scale));
  let lo = Math.min(...all);
  let hi = Math.max(...all);
  if (lo === hi) {
    const pad = Math.abs(lo) * 0.1 || 1;
    lo -= pad;
    hi += pad;
  }
  const x = (i: number) => (dates.length === 1 ? 50 : (i / (dates.length - 1)) * 100);
  const y = (v: number) => PAD + (1 - (scale(v) - lo) / (hi - lo)) * (100 - 2 * PAD);
  const ticks = Array.from({ length: TICKS }, (_, i) => unscale(hi - (i / (TICKS - 1)) * (hi - lo)));
  const showDots = dates.length <= 30;

  const path = (values: (number | null)[]) => {
    let d = "";
    let pen = false;
    values.forEach((v, i) => {
      if (v === null || (log && v <= 0)) {
        pen = false;
        return;
      }
      d += `${pen ? "L" : "M"}${(x(i) * 10).toFixed(1)} ${y(v).toFixed(2)} `;
      pen = true;
    });
    return d.trim();
  };

  return (
    <figure className="m-0">
      {series.length > 1 ? (
        <ul className="mb-4 flex flex-wrap gap-x-5 gap-y-2" aria-hidden="true">
          {series.map((s, i) => (
            <li key={s.id} className="inline-flex items-center gap-2 font-semibold">
              <span className={`h-1 w-5 rounded-full ${FILL[i % FILL.length]}`} />
              {s.label}
            </li>
          ))}
        </ul>
      ) : null}
      <div className="grid grid-cols-[auto_1fr] gap-x-3" aria-hidden="true">
        <div className="relative h-56 w-14">
          {ticks.map((t, i) => (
            <span
              key={i}
              className="absolute right-0 -translate-y-1/2 font-mono text-xs text-ink-soft"
              style={{ top: `${PAD + (i / (TICKS - 1)) * (100 - 2 * PAD)}%` }}
            >
              {format(t)}
            </span>
          ))}
        </div>
        <div className="relative h-56 rounded-xl border-2 border-ink bg-paper">
          <svg viewBox="0 0 1000 100" preserveAspectRatio="none" className="absolute inset-0 size-full overflow-visible">
            {ticks.map((_, i) => {
              const ty = PAD + (i / (TICKS - 1)) * (100 - 2 * PAD);
              return (
                <line key={i} x1="0" x2="1000" y1={ty} y2={ty} className="stroke-line" strokeDasharray="6 6" vectorEffect="non-scaling-stroke" />
              );
            })}
            {series.map((s, i) => (
              <path
                key={s.id}
                d={path(s.values)}
                fill="none"
                className={STROKE[i % STROKE.length]}
                strokeWidth="3"
                strokeLinejoin="round"
                strokeLinecap="round"
                vectorEffect="non-scaling-stroke"
              />
            ))}
          </svg>
          {series.map((s, i) =>
            s.values.map((v, j) =>
              v !== null && (showDots || j === s.values.length - 1) ? (
                <span
                  key={`${s.id}-${j}`}
                  className={`absolute size-3 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-ink ${FILL[i % FILL.length]}`}
                  style={{ left: `${x(j)}%`, top: `${y(v)}%` }}
                />
              ) : null,
            ),
          )}
        </div>
        <div />
        <div className="mt-2 flex justify-between font-mono text-xs text-ink-soft">
          <span>{dates[0]}</span>
          {dates.length > 2 ? <span className="max-sm:hidden">{dates[Math.floor(dates.length / 2)]}</span> : null}
          <span>{dates.at(-1)}</span>
        </div>
      </div>
      <figcaption className="sr-only">{caption}</figcaption>
      <table className="sr-only">
        <caption>{caption}</caption>
        <thead>
          <tr>
            <th scope="col">Run</th>
            {series.map((s) => (
              <th key={s.id} scope="col">
                {s.name}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {dates.map((d, j) => (
            <tr key={j}>
              <th scope="row">{d}</th>
              {series.map((s) => {
                const v = s.values[j];
                return <td key={s.id}>{v === null || v === undefined ? "no result" : format(v)}</td>;
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
}
