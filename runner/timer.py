"""Build the static measuring binary for the docker host's architecture."""

from __future__ import annotations

from pathlib import Path

from . import docker
from .config import BENCH_DIR, WORK_DIR

BUILDER_IMAGE = "alpine:3.20"


def ensure_timer() -> Path:
    arch = docker.arch()
    out_dir = WORK_DIR / "timer"
    binary = out_dir / f"timer-{arch}"
    source = BENCH_DIR / "timer" / "timer.c"
    if binary.is_file() and binary.stat().st_mtime >= source.stat().st_mtime:
        return binary
    out_dir.mkdir(parents=True, exist_ok=True)
    script = (
        "apk add --no-cache build-base >/dev/null && "
        f"gcc -O2 -static -Wall -o /out/timer-{arch} /src/timer.c"
    )
    result = docker.run_once(BUILDER_IMAGE, script, [(source.parent, "/src"), (out_dir, "/out")])
    if result.code != 0 or not binary.is_file():
        raise docker.DockerError(f"timer build failed: {result.stderr.strip()[-400:]}")
    return binary
