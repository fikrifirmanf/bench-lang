"""Which toolchains changed, and how fresh results moved against the published ones."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from .config import load_lang_file, load_source_changes, load_toolchains, select_environment
from .models import ResultRow, Run, SourceChanges, ToolchainFile

THRESHOLD = 0.05


def changed_toolchains(base_file: Path, head_file: Path) -> list[str]:
    """Ids whose config differs between two versions of bench/toolchains.json (new ids included)."""
    head = ToolchainFile.model_validate_json(head_file.read_text()).toolchains
    if not base_file.is_file() or not base_file.read_text().strip():
        return [t.id for t in head]
    base = {t.id: t for t in ToolchainFile.model_validate_json(base_file.read_text()).toolchains}
    return [t.id for t in head if base.get(t.id) != t]


def program_toolchains(changed_paths: list[str], base_sources: Path | None) -> list[str]:
    """Ids whose programs, include overlay or sources.json entry are among the changed repository paths.

    `base_sources` is the previous bench/programs/sources.json; without it a changed sources.json selects every
    toolchain it mentions."""
    paths = {p for p in changed_paths if p.startswith("bench/programs/")}
    if not paths:
        return []
    head = load_source_changes()
    base = (
        SourceChanges.model_validate_json(base_sources.read_text())
        if base_sources and base_sources.is_file() and base_sources.read_text().strip()
        else SourceChanges()
    )
    sources_changed = "bench/programs/sources.json" in paths
    ids: list[str] = []
    for toolchain in load_toolchains():
        config = toolchain.config
        entry_changed = (head.add.get(config), head.drop.get(config)) != (base.add.get(config), base.drop.get(config))
        if sources_changed and entry_changed:
            ids.append(toolchain.id)
            continue
        lang_file = load_lang_file(toolchain)
        programs = {f"bench/programs/{p.name}/{s}" for p in lang_file.problems for s in p.source}
        include = select_environment(lang_file, toolchain).include
        prefix = f"bench/programs/include/{include}/" if include else None
        if paths & programs or (prefix and any(p.startswith(prefix) for p in paths)):
            ids.append(toolchain.id)
    return ids


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
