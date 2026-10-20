"""Locations and loaders for the project's config files."""

from __future__ import annotations

import json
from pathlib import Path

import yaml

from .models import (
    BenchFile,
    Environment,
    LangFile,
    LangProblem,
    Profile,
    ProfileFile,
    SourceChanges,
    Toolchain,
    ToolchainFile,
    Upstream,
)

ROOT = Path(__file__).resolve().parent.parent
BENCH_DIR = ROOT / "bench"
DATA_DIR = ROOT / "data"
WORK_DIR = ROOT / ".work"
UPSTREAM_DIR = ROOT / "vendor" / "upstream"
UPSTREAM_BENCH = UPSTREAM_DIR / "bench"
TOOLCHAINS_FILE = BENCH_DIR / "toolchains.json"
# This project's own implementations for problems upstream has no program for, laid out like upstream's tree.
PROGRAMS_DIR = BENCH_DIR / "programs"


class ConfigError(Exception):
    pass


def load_toolchains() -> list[Toolchain]:
    return ToolchainFile.model_validate_json(TOOLCHAINS_FILE.read_text()).toolchains


def get_toolchain(toolchain_id: str) -> Toolchain:
    found = next((t for t in load_toolchains() if t.id == toolchain_id), None)
    if found is None:
        raise ConfigError(f"unknown toolchain '{toolchain_id}'")
    return found


def load_profiles() -> list[Profile]:
    return ProfileFile.model_validate_json((BENCH_DIR / "profiles.json").read_text()).profiles


def get_profile(profile_id: str) -> Profile:
    found = next((p for p in load_profiles() if p.id == profile_id), None)
    if found is None:
        raise ConfigError(f"unknown profile '{profile_id}'")
    return found


def load_upstream() -> Upstream:
    return Upstream.model_validate_json((BENCH_DIR / "upstream.json").read_text())


def _upstream_yaml(name: str) -> object:
    path = UPSTREAM_BENCH / name
    if not path.is_file():
        raise ConfigError(f"{path} not found; run `python -m runner sync-upstream` first")
    return yaml.safe_load(path.read_text())


def load_bench_file() -> BenchFile:
    return BenchFile.model_validate(_upstream_yaml("bench.yaml"))


def load_source_changes() -> SourceChanges:
    return SourceChanges.model_validate_json((PROGRAMS_DIR / "sources.json").read_text())


def load_lang_file(toolchain: Toolchain) -> LangFile:
    """Upstream's problem list for the language, changed as bench/programs/sources.json says."""
    lang_file = LangFile.model_validate(_upstream_yaml(toolchain.config))
    changes = load_source_changes()
    problems = {p.name: list(p.source) for p in lang_file.problems}
    for name, sources in changes.add.get(toolchain.config, {}).items():
        listed = problems.setdefault(name, [])
        listed += [s for s in sources if s not in listed]
    for name, sources in changes.drop.get(toolchain.config, {}).items():
        problems[name] = [s for s in problems.get(name, []) if s not in sources]
    return lang_file.model_copy(update={"problems": [LangProblem(name=n, source=s) for n, s in problems.items()]})


def source_path(problem: str, name: str) -> Path:
    """A program from bench/programs/ if this project wrote one, otherwise upstream's file."""
    own = PROGRAMS_DIR / problem / name
    return own if own.is_file() else UPSTREAM_BENCH / "algorithm" / problem / name


def include_dirs(include: str) -> list[Path]:
    """Upstream's project skeleton for a language, then this project's additions to it (copied on top)."""
    return [d for d in (UPSTREAM_BENCH / "include" / include, PROGRAMS_DIR / "include" / include) if d.is_dir()]


def select_environment(lang_file: LangFile, toolchain: Toolchain) -> Environment:
    found = next((e for e in lang_file.environments if e.compiler == toolchain.compiler and e.enabled), None)
    if found is None:
        raise ConfigError(f"{toolchain.config} has no enabled environment for compiler '{toolchain.compiler}'")
    return found


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path)
