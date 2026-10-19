"""Pure helpers: implementation flags, sample statistics, output comparison."""

from __future__ import annotations

import re
import statistics
from dataclasses import dataclass

_SUFFIX = re.compile(r"-([a-z0-9]+)\.[A-Za-z0-9]+$")


def parse_flags(code: str) -> list[str]:
    """Read upstream's file-name suffixes: -m multi-thread, -i intrinsics, -ffi native libs."""
    match = _SUFFIX.search(code)
    if not match:
        return []
    suffix = match.group(1)
    flags: list[str] = []
    if "ffi" in suffix:
        flags.append("ffi")
        suffix = suffix.replace("ffi", "")
    if suffix and set(suffix) <= {"m", "i"}:
        if "m" in suffix:
            flags.append("multi-thread")
        if "i" in suffix:
            flags.append("intrinsics")
    return sorted(flags)


@dataclass(frozen=True)
class Sample:
    wall_ms: float
    user_ms: float
    sys_ms: float
    maxrss_kb: int


@dataclass(frozen=True)
class Summary:
    time_ms: float
    stddev_ms: float
    user_ms: float
    sys_ms: float
    peak_mem_mb: float


def summarize(samples: list[Sample]) -> Summary:
    if not samples:
        raise ValueError("no samples to summarize")
    walls = [s.wall_ms for s in samples]
    return Summary(
        time_ms=round(statistics.fmean(walls), 3),
        stddev_ms=round(statistics.pstdev(walls), 3),
        user_ms=round(statistics.fmean(s.user_ms for s in samples), 3),
        sys_ms=round(statistics.fmean(s.sys_ms for s in samples), 3),
        peak_mem_mb=round(max(s.maxrss_kb for s in samples) / 1024, 1),
    )


def normalize_output(text: str) -> str:
    lines = [line.rstrip() for line in text.replace("\r\n", "\n").split("\n")]
    while lines and not lines[-1]:
        lines.pop()
    return "\n".join(lines)


def outputs_match(actual: str, expected: str) -> bool:
    return normalize_output(actual) == normalize_output(expected)


def split_compiler(text: str) -> tuple[str, str]:
    """'rustc 1.88.0' -> ('rustc', '1.88.0'); 'clang++ 14.0.0-1ubuntu1.1' -> ('clang++', '14.0.0')."""
    parts = text.strip().split(None, 1)
    if not parts:
        return "", ""
    label = parts[0]
    version = parts[1] if len(parts) > 1 else ""
    clean = re.match(r"[0-9][0-9A-Za-z.+_]*", version)
    if clean and "ubuntu" in version:
        version = clean.group(0).split("-")[0]
    return label, version.strip()


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in re.findall(r"\d+", version))
