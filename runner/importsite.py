"""Seed data/ with the last published upstream run, read from its static site.

The upstream site has no data API; every problem page is a set of plain HTML tables,
one per input size. This turns those tables into our Run format so the site has real
numbers before our own runner has produced any.
"""

from __future__ import annotations

import logging
import re
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from html.parser import HTMLParser

from .models import Machine, ProblemSpec, ResultRow, Run, Status
from .stats import parse_flags, split_compiler

log = logging.getLogger(__name__)

SITE = "https://programming-language-benchmarks.vercel.app"
HTTP_TIMEOUT_S = 30

_UNITS_MS = {"ms": 1.0, "s": 1000.0, "min": 60000.0}
_UNITS_MB = {"KB": 1 / 1024, "MB": 1.0, "GB": 1024.0}


@dataclass
class Table:
    input: str
    rows: list[list[str]] = field(default_factory=list)


class _ProblemPage(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.tables: list[Table] = []
        self._last_input = ""
        self._in_table = False
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "table":
            self._in_table = True
            self.tables.append(Table(input=self._last_input))
        elif self._in_table and tag == "tr":
            self._row = []
        elif self._row is not None and tag == "td":
            self._cell = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "table":
            self._in_table = False
        elif tag == "td" and self._row is not None and self._cell is not None:
            self._row.append(" ".join("".join(self._cell).split()))
            self._cell = None
        elif tag == "tr" and self._row is not None:
            if len(self._row) >= 8:
                self.tables[-1].rows.append(self._row)
            self._row = None

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)
        elif not self._in_table:
            match = re.search(r"Input:\s*(.+)", data)
            if match:
                self._last_input = match.group(1).strip()


def parse_ms(text: str) -> float | None:
    match = re.fullmatch(r"([\d.]+)\s*(ms|s|min)", text.strip())
    return float(match.group(1)) * _UNITS_MS[match.group(2)] if match else None


def parse_mb(text: str) -> float | None:
    match = re.fullmatch(r"([\d.]+)\s*(KB|MB|GB)", text.strip())
    return round(float(match.group(1)) * _UNITS_MB[match.group(2)], 1) if match else None


def parse_page(html: str, spec: ProblemSpec, measured_at: str) -> list[ResultRow]:
    page = _ProblemPage()
    page.feed(html)
    inputs = [t.input for t in spec.tests]
    rows: list[ResultRow] = []
    for table in page.tables:
        if table.input not in inputs:
            log.warning("%s: unknown input %r, skipped", spec.name, table.input)
            continue
        for cells in table.rows:
            lang, code, time_text, stddev, mem, user, sys_, compiler_text = cells[:8]
            compiler, version = split_compiler(compiler_text)
            time_ms = parse_ms(time_text)
            status: Status = "ok" if time_ms is not None else "timeout"
            rows.append(
                ResultRow(
                    problem=spec.name,
                    input=table.input,
                    input_index=inputs.index(table.input),
                    lang=lang,
                    compiler=compiler,
                    version=version,
                    code=code,
                    flags=parse_flags(code),
                    status=status,
                    time_ms=time_ms,
                    stddev_ms=parse_ms(stddev) if status == "ok" else None,
                    user_ms=parse_ms(user) if status == "ok" else None,
                    sys_ms=parse_ms(sys_) if status == "ok" else None,
                    peak_mem_mb=parse_mb(mem) if status == "ok" else None,
                    measured_at=measured_at,
                )
            )
    return rows


def _fetch(name: str) -> str:
    request = urllib.request.Request(f"{SITE}/problem/{name}", headers={"User-Agent": "bench-lang-import"})
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_S) as response:
            return response.read().decode()
    except urllib.error.URLError as exc:
        raise RuntimeError(f"could not fetch problem page '{name}': {exc}") from exc


def import_site(specs: list[ProblemSpec], measured_at: str, upstream_commit: str) -> Run:
    with ThreadPoolExecutor(max_workers=6) as pool:
        pages = list(pool.map(_fetch, [s.name for s in specs]))
    rows = [row for spec, html in zip(specs, pages, strict=True) for row in parse_page(html, spec, measured_at)]
    machine = Machine(
        profile="ci-4vcpu",
        cpu="AMD EPYC 7763 64-Core Processor",
        cores=4,
        memory_mb=16384,
        os="Ubuntu 22.04 (GitHub Actions)",
        arch="amd64",
    )
    return Run(
        id=f"{measured_at}-upstream",
        profile="ci-4vcpu",
        source="import",
        started_at=f"{measured_at}T00:00:00+00:00",
        upstream_commit=upstream_commit,
        machine=machine,
        rows=rows,
    )
