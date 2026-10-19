"""Fold per-toolchain results into a dated run and refresh the site's data files.

`data/latest/<profile>.json` keeps the newest result for every (language, compiler):
a run that only re-measured Rust replaces Rust rows and leaves every other language as it was.
"""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

from .config import DATA_DIR, load_profiles, write_json
from .models import DataIndex, ProfileSummary, ResultRow, Run, RunIndexEntry


def _read_run(path: Path) -> Run:
    return Run.model_validate_json(path.read_text())


def combine(parts: list[Run], run_id: str) -> Run:
    if not parts:
        raise ValueError("no results to merge")
    first = min(parts, key=lambda r: r.started_at)
    return Run(
        id=run_id,
        profile=first.profile,
        source=first.source,
        started_at=first.started_at,
        upstream_commit=first.upstream_commit,
        machine=first.machine,
        rows=[row for part in parts for row in part.rows],
    )


def fold_latest(previous: Run | None, fresh: Run) -> Run:
    replaced = {(r.lang, r.compiler) for r in fresh.rows}
    kept: list[ResultRow] = [] if previous is None else [r for r in previous.rows if (r.lang, r.compiler) not in replaced]
    return fresh.model_copy(update={"id": "latest", "rows": sorted([*kept, *fresh.rows], key=_row_key)})


def _row_key(row: ResultRow) -> tuple[str, int, str, str, str]:
    return (row.problem, row.input_index, row.lang, row.compiler, row.code)


def publish(run: Run) -> None:
    runs_dir = DATA_DIR / "runs" / run.profile
    write_json(runs_dir / f"{run.id}.json", run.model_dump())
    latest_path = DATA_DIR / "latest" / f"{run.profile}.json"
    previous = _read_run(latest_path) if latest_path.is_file() else None
    write_json(latest_path, fold_latest(previous, run).model_dump())
    rebuild_index()


def rebuild_index() -> DataIndex:
    entries: list[RunIndexEntry] = []
    for path in sorted((DATA_DIR / "runs").glob("*/*.json")):
        run = _read_run(path)
        entries.append(
            RunIndexEntry(id=run.id, profile=run.profile, started_at=run.started_at, source=run.source, rows=len(run.rows))
        )
    entries.sort(key=lambda e: e.started_at, reverse=True)
    summaries = [
        ProfileSummary(
            id=p.id,
            name=p.name,
            latest_run=next((e.id for e in entries if e.profile == p.id), None),
        )
        for p in load_profiles()
    ]
    index = DataIndex(profiles=summaries, runs=entries)
    write_json(DATA_DIR / "index.json", index.model_dump())
    return index


def merge_results(results: Path, run_id: str | None = None) -> Run:
    parts = [_read_run(p) for p in sorted(results.glob("*.json"))]
    stamp = run_id or datetime.now(UTC).strftime("%Y-%m-%d-%H%M")
    run = combine(parts, stamp)
    publish(run)
    return run
