"""Compare each toolchain's pinned version against the newest stable tag upstream."""

from __future__ import annotations

import json
import logging
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict

from .config import DATA_DIR, TOOLCHAINS_FILE, load_toolchains, write_json
from .models import Toolchain, VersionCheck, VersionReport, VersionStatus
from .stats import version_key

log = logging.getLogger(__name__)

HTTP_TIMEOUT_S = 20
MAX_PAGES = 5
RETRIES = 2


class LookupFailed(Exception):
    pass


class _TagPage(BaseModel):
    model_config = ConfigDict(extra="ignore")
    next: str | None = None
    results: list[dict[str, object]] = []


def _get_json(url: str) -> object:
    headers = {"Accept": "application/json", "User-Agent": "bench-lang-version-bot"}
    token = os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    last: Exception | None = None
    for attempt in range(RETRIES + 1):
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_S) as response:
                return json.loads(response.read())
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last = exc
            time.sleep(1.5 * (attempt + 1))
    raise LookupFailed(f"{url}: {last}")


def _dockerhub_tags(check: VersionCheck) -> list[str]:
    namespace, name = check.repo.split("/", 1)
    query = urllib.parse.urlencode({"page_size": 100, "name": check.name_hint, "ordering": "last_updated"})
    url: str | None = f"https://hub.docker.com/v2/namespaces/{namespace}/repositories/{name}/tags?{query}"
    tags: list[str] = []
    pages = 0
    while url and pages < MAX_PAGES:
        page = _TagPage.model_validate(_get_json(url))
        tags += [str(item.get("name", "")) for item in page.results]
        url = page.next
        pages += 1
    return tags


def _github_tags(check: VersionCheck) -> list[str]:
    payload = _get_json(f"https://api.github.com/repos/{check.repo}/tags?per_page=100")
    if not isinstance(payload, list):
        raise LookupFailed("unexpected GitHub response")
    return [str(item.get("name", "")) for item in payload if isinstance(item, dict)]


def _mcr_tags(check: VersionCheck) -> list[str]:
    payload = _get_json(f"https://mcr.microsoft.com/v2/{check.repo}/tags/list")
    if not isinstance(payload, dict) or not isinstance(payload.get("tags"), list):
        raise LookupFailed("unexpected MCR response")
    return [str(tag) for tag in payload["tags"]]


SOURCES = {"dockerhub": _dockerhub_tags, "github-tags": _github_tags, "mcr": _mcr_tags}


def newest(check: VersionCheck, tags: list[str]) -> str | None:
    pattern = re.compile(check.tag_regex)
    versions = {m.group(1) for tag in tags if (m := pattern.match(tag))}
    return max(versions, key=version_key) if versions else None


def _lookup(check: VersionCheck) -> tuple[str | None, str | None]:
    try:
        return newest(check, SOURCES[check.source](check)), None
    except LookupFailed as exc:
        log.warning("version lookup failed for %s: %s", check.repo, exc)
        return None, str(exc)[:300]


def _status(toolchain: Toolchain, latest: str | None, error: str | None) -> VersionStatus:
    if latest is None:
        state = "unknown"
    elif version_key(latest) > version_key(toolchain.version):
        state = "behind"
    else:
        state = "current"
    return VersionStatus(
        id=toolchain.id,
        lang=toolchain.lang,
        compiler=toolchain.compiler,
        current=toolchain.version,
        latest=latest,
        status=state,
        error=error,
    )


def check_all() -> VersionReport:
    toolchains = load_toolchains()
    checks = {t.check.model_dump_json(): t.check for t in toolchains if t.check}
    with ThreadPoolExecutor(max_workers=6) as pool:
        found = dict(zip(checks, pool.map(_lookup, checks.values()), strict=True))
    statuses = [
        _status(t, *found[t.check.model_dump_json()]) if t.check else _status(t, None, "no version source configured")
        for t in toolchains
    ]
    return VersionReport(checked_at=datetime.now(UTC).isoformat(timespec="seconds"), toolchains=statuses)


def write_report(report: VersionReport) -> None:
    write_json(DATA_DIR / "versions.json", report.model_dump())


def apply_updates(report: VersionReport) -> list[str]:
    """Bump pinned versions in bench/toolchains.json. Returns a line per change."""
    behind = {s.id: s.latest for s in report.toolchains if s.status == "behind" and s.latest}
    if not behind:
        return []
    raw = json.loads(TOOLCHAINS_FILE.read_text())
    changes: list[str] = []
    for entry in raw["toolchains"]:
        latest = behind.get(entry["id"])
        if latest:
            changes.append(f"{entry['id']}: {entry['version']} -> {latest}")
            entry["version"] = latest
    write_json(TOOLCHAINS_FILE, raw)
    load_toolchains()
    return changes
