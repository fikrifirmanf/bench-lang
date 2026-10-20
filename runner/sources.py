"""Copy the source of every published program into data/sources/, so the site can show the code behind each result.

The site is built without upstream's checkout, so the files it shows have to live in data/ next to the results.
"""

from __future__ import annotations

import shutil
from typing import Literal

from .config import DATA_DIR, PROGRAMS_DIR, UPSTREAM_BENCH, ConfigError, source_path, write_json
from .models import Run, SourceEntry, SourceIndex

SOURCES_DIR = DATA_DIR / "sources"


def _published_programs() -> set[tuple[str, str]]:
    programs: set[tuple[str, str]] = set()
    for path in sorted((DATA_DIR / "latest").glob("*.json")):
        run = Run.model_validate_json(path.read_text())
        programs |= {(r.problem, r.code) for r in run.rows if r.status == "ok"}
    return programs


def export_sources() -> SourceIndex:
    """Rewrite data/sources/ to hold exactly the programs that have a published result."""
    if not UPSTREAM_BENCH.is_dir():
        raise ConfigError("upstream programs are missing; run `python -m runner sync-upstream` first")
    entries: list[SourceEntry] = []
    if SOURCES_DIR.is_dir():
        shutil.rmtree(SOURCES_DIR)
    for problem, name in sorted(_published_programs()):
        source = source_path(problem, name)
        if not source.is_file():
            raise ConfigError(f"no source file for {problem}/{name}")
        origin: Literal["own", "upstream"] = "own" if source.is_relative_to(PROGRAMS_DIR) else "upstream"
        target = SOURCES_DIR / problem / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        entries.append(SourceEntry(problem=problem, file=name, origin=origin))
    index = SourceIndex(programs=entries)
    write_json(SOURCES_DIR / "index.json", index.model_dump())
    return index
