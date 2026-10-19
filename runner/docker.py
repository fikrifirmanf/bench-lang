"""Thin wrappers over the docker CLI. Every call has a deadline."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass, field
from pathlib import Path


class DockerError(Exception):
    pass


@dataclass(frozen=True)
class ExecResult:
    code: int
    stdout: str
    stderr: str


def _docker(args: list[str], timeout_s: float) -> ExecResult:
    try:
        proc = subprocess.run(["docker", *args], capture_output=True, text=True, timeout=timeout_s, check=False)
    except subprocess.TimeoutExpired as exc:
        raise DockerError(f"docker {args[0]} timed out after {timeout_s}s") from exc
    except FileNotFoundError as exc:
        raise DockerError("docker CLI not found on PATH") from exc
    return ExecResult(proc.returncode, proc.stdout, proc.stderr)


def pull(image: str) -> None:
    result = _docker(["pull", "--quiet", image], timeout_s=1800)
    if result.code != 0:
        raise DockerError(f"pull {image} failed: {result.stderr.strip()[-400:]}")


def arch() -> str:
    result = _docker(["version", "--format", "{{.Server.Arch}}"], timeout_s=30)
    if result.code != 0:
        raise DockerError(f"docker daemon unavailable: {result.stderr.strip()[-400:]}")
    return result.stdout.strip()


@dataclass
class Container:
    """A long-lived container that build steps and measurements exec into."""

    image: str
    name: str
    mounts: list[tuple[Path | str, str, bool]] = field(default_factory=list)
    env: dict[str, str] = field(default_factory=dict)
    cpuset: str | None = None
    memory_mb: int | None = None

    def start(self) -> None:
        _docker(["rm", "-f", self.name], timeout_s=60)
        args = ["run", "-d", "--name", self.name, "--entrypoint", "sleep"]
        for source, target, read_only in self.mounts:
            spec = f"{source}:{target}" + (":ro" if read_only else "")
            args += ["-v", spec]
        for key, value in self.env.items():
            args += ["-e", f"{key}={value}"]
        if self.cpuset:
            args += ["--cpuset-cpus", self.cpuset]
        if self.memory_mb:
            # Equal memory and memory-swap: the container can never swap, so an overrun is an OOM, not a slow result.
            args += ["--memory", f"{self.memory_mb}m", "--memory-swap", f"{self.memory_mb}m"]
        args += [self.image, "infinity"]
        result = _docker(args, timeout_s=300)
        if result.code != 0:
            raise DockerError(f"start {self.image} failed: {result.stderr.strip()[-400:]}")

    def sh(self, script: str, workdir: str = "/", env: dict[str, str] | None = None, timeout_s: float = 3600) -> ExecResult:
        args = ["exec", "-w", workdir]
        for key, value in (env or {}).items():
            args += ["-e", f"{key}={value}"]
        args += [self.name, "sh", "-c", script]
        return _docker(args, timeout_s=timeout_s)

    def exec(self, argv: list[str], workdir: str = "/", env: dict[str, str] | None = None, timeout_s: float = 3600) -> ExecResult:
        args = ["exec", "-w", workdir]
        for key, value in (env or {}).items():
            args += ["-e", f"{key}={value}"]
        return _docker([*args, self.name, *argv], timeout_s=timeout_s)

    def stop(self) -> None:
        _docker(["rm", "-f", self.name], timeout_s=120)

    def __enter__(self) -> Container:
        self.start()
        return self

    def __exit__(self, *_exc: object) -> None:
        self.stop()


def run_once(image: str, script: str, mounts: list[tuple[Path, str]], timeout_s: float = 900) -> ExecResult:
    args = ["run", "--rm"]
    for source, target in mounts:
        args += ["-v", f"{source}:{target}"]
    return _docker([*args, image, "sh", "-c", script], timeout_s=timeout_s)
