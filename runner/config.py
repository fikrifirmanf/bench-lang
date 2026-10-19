"""Locations and loaders for the project's config files."""

from __future__ import annotations

import json
from pathlib import Path

import yaml

from .models import (
    BenchFile,
    Environment,
    LangFile,
    Profile,
    ProfileFile,
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


def load_lang_file(toolchain: Toolchain) -> LangFile:
    return LangFile.model_validate(_upstream_yaml(toolchain.config))


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
