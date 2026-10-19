"""Fetch the upstream benchmark programs at the commit pinned in bench/upstream.json."""

from __future__ import annotations

import subprocess

from .config import UPSTREAM_DIR, load_upstream


class UpstreamError(Exception):
    pass


def _git(args: list[str], timeout_s: float = 600) -> str:
    try:
        proc = subprocess.run(
            ["git", "-C", str(UPSTREAM_DIR), *args], capture_output=True, text=True, timeout=timeout_s, check=False
        )
    except subprocess.TimeoutExpired as exc:
        raise UpstreamError(f"git {args[0]} timed out") from exc
    if proc.returncode != 0:
        raise UpstreamError(f"git {' '.join(args)} failed: {proc.stderr.strip()[-400:]}")
    return proc.stdout.strip()


def current_commit() -> str | None:
    if not (UPSTREAM_DIR / ".git").is_dir():
        return None
    try:
        return _git(["rev-parse", "HEAD"], timeout_s=30)
    except UpstreamError:
        return None


def sync() -> str:
    upstream = load_upstream()
    if current_commit() == upstream.commit:
        return upstream.commit
    UPSTREAM_DIR.mkdir(parents=True, exist_ok=True)
    if not (UPSTREAM_DIR / ".git").is_dir():
        _git(["init", "-q"])
        _git(["remote", "add", "origin", upstream.repo])
    _git(["fetch", "-q", "--depth", "1", "origin", upstream.commit])
    _git(["checkout", "-q", "--force", "FETCH_HEAD"])
    return upstream.commit
