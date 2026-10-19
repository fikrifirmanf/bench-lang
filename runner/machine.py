"""Describe the host that ran the benchmarks."""

from __future__ import annotations

import os
import platform
import subprocess
from pathlib import Path

from .models import Machine


def _sysctl(key: str) -> str:
    try:
        proc = subprocess.run(["sysctl", "-n", key], capture_output=True, text=True, timeout=10, check=False)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""
    return proc.stdout.strip()


def _cpu_model() -> str:
    cpuinfo = Path("/proc/cpuinfo")
    if cpuinfo.is_file():
        for line in cpuinfo.read_text().splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    return _sysctl("machdep.cpu.brand_string") or platform.processor() or "unknown"


def _memory_mb() -> int:
    meminfo = Path("/proc/meminfo")
    if meminfo.is_file():
        for line in meminfo.read_text().splitlines():
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) // 1024
    value = _sysctl("hw.memsize")
    return int(value) // (1024 * 1024) if value.isdigit() else 0


def describe(profile: str, docker_arch: str) -> Machine:
    return Machine(
        profile=profile,
        cpu=_cpu_model(),
        cores=os.cpu_count() or 1,
        memory_mb=_memory_mb(),
        os=platform.platform(terse=True),
        arch=docker_arch,
    )
