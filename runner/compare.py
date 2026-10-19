"""Which toolchains changed, and how fresh results moved against the published ones."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from .models import ResultRow, Run, ToolchainFile

THRESHOLD = 0.05


def changed_toolchains(base_file: Path, head_file: Path) -> list[str]:
    """Ids whose config differs between two versions of bench/toolchains.json (new ids included)."""
    head = ToolchainFile.model_validate_json(head_file.read_text()).toolchains
    if not base_file.is_file() or not base_file.read_text().strip():
        return [t.id for t in head]
    base = {t.id: t for t in ToolchainFile.model_validate_json(base_file.read_text()).toolchains}
    return [t.id for t in head if base.get(t.id) != t]


def matrix(ids: list[str]) -> str:
    return json.dumps({"toolchain": ids})


@dataclass(frozen=True)
class Shift:
    row: ResultRow
    before: float
    after: float

    @property
    def change(self) -> float:
        return self.after / self.before - 1


def _key(row: ResultRow) -> tuple[str, int, str, str]:
    return (row.problem, row.input_index, row.lang, row.code)


def shifts(fresh: list[ResultRow], published: Run | None) -> list[Shift]:
    if published is None:
        return []
    before = {_key(r): r.time_ms for r in published.rows if r.status == "ok" and r.time_ms}
    found = [
        Shift(r, before[_key(r)], r.time_ms)
        for r in fresh
        if r.status == "ok" and r.time_ms and before.get(_key(r))
    ]
    return sorted((s for s in found if abs(s.change) >= THRESHOLD), key=lambda s: s.change)


def markdown(fresh: list[ResultRow], published: Run | None) -> str:
    ok = sum(1 for r in fresh if r.status == "ok")
    failed = [r for r in fresh if r.status != "ok"]
    lines = [f"**{ok}** results measured, **{len(failed)}** did not finish.", ""]
    moved = shifts(fresh, published)
    if moved:
        lines += ["| problem | input | language | code | before | after | change |", "|---|---|---|---|---|---|---|"]
        lines += [
            f"| {s.row.problem} | {s.row.input} | {s.row.lang} | {s.row.code} | {s.before:.0f}ms | {s.after:.0f}ms | {s.change:+.1%} |"
            for s in moved
        ]
    else:
        lines.append(f"No result moved by {THRESHOLD:.0%} or more against the published data.")
    if failed:
        lines += ["", "<details><summary>Did not finish</summary>", ""]
        lines += [f"- {r.problem} `{r.code}` ({r.lang}, input {r.input}): {r.status}" for r in failed]
        lines += ["", "</details>"]
    return "\n".join(lines) + "\n"
