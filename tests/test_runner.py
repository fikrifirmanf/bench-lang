from runner.importsite import parse_mb, parse_ms, parse_page
from runner.merge import fold_latest
from runner.models import BenchInput, LangProblem, Machine, ProblemSpec, ResultRow, Run, VersionCheck
from runner.stats import Sample, outputs_match, parse_flags, split_compiler, summarize
from runner.versions import newest


def test_parse_flags_reads_upstream_suffixes() -> None:
    assert parse_flags("1.rs") == []
    assert parse_flags("4-i.rs") == ["intrinsics"]
    assert parse_flags("2-m.go") == ["multi-thread"]
    assert parse_flags("6-im.cpp") == ["intrinsics", "multi-thread"]
    assert parse_flags("1-mffi.c") == ["ffi", "multi-thread"]
    assert parse_flags("0-ffi.go") == ["ffi"]
    assert parse_flags("1-http2.go") == []
    assert parse_flags("0-unsafe.rs") == []


def test_split_compiler_drops_distro_suffix() -> None:
    assert split_compiler("rustc 1.88.0") == ("rustc", "1.88.0")
    assert split_compiler("clang++ 14.0.0-1ubuntu1.1") == ("clang++", "14.0.0")
    assert split_compiler("rustc 1.90.0-nightly") == ("rustc", "1.90.0-nightly")
    assert split_compiler("openjdk/zgc 21") == ("openjdk/zgc", "21")


def test_summarize_uses_mean_and_peak() -> None:
    summary = summarize([Sample(100, 90, 5, 2048), Sample(110, 95, 5, 4096)])
    assert summary.time_ms == 105
    assert summary.stddev_ms == 5
    assert summary.peak_mem_mb == 4.0


def test_outputs_match_ignores_trailing_whitespace() -> None:
    assert outputs_match("a  \nb\n\n", "a\nb")
    assert not outputs_match("a\nc", "a\nb")


def test_newest_picks_highest_stable_tag() -> None:
    check = VersionCheck(source="dockerhub", repo="library/x", tag_regex=r"^(\d+\.\d+\.\d+)-slim$")
    tags = ["1.9.0-slim", "1.10.2-slim", "1.11.0rc1-slim", "latest", "1.10.2"]
    assert newest(check, tags) == "1.10.2"
    assert newest(check, ["latest"]) is None


def test_lang_problem_accepts_empty_source() -> None:
    assert LangProblem.model_validate({"name": "nbody", "source": None}).source == []


def _row(lang: str, compiler: str, time_ms: float) -> ResultRow:
    return ResultRow(
        problem="nbody", input="500", input_index=0, lang=lang, compiler=compiler, version="1", code="1.x",
        flags=[], status="ok", time_ms=time_ms, measured_at="2026-01-01",
    )


def _run(rows: list[ResultRow]) -> Run:
    machine = Machine(profile="ci-4vcpu", cpu="cpu", cores=4, memory_mb=1, os="linux", arch="amd64")
    return Run(id="r", profile="ci-4vcpu", source="runner", started_at="2026-01-01T00:00:00+00:00",
               upstream_commit=None, machine=machine, rows=rows)


def test_fold_latest_replaces_only_remeasured_compilers() -> None:
    previous = _run([_row("rust", "rustc", 200), _row("go", "go", 300)])
    fresh = _run([_row("rust", "rustc", 150)])
    latest = fold_latest(previous, fresh)
    times = {(r.lang, r.time_ms) for r in latest.rows}
    assert times == {("rust", 150), ("go", 300)}
    assert latest.id == "latest"


PAGE = """
<p>Input: 500000</p>
<table><tr><th>lang</th></tr><tbody>
<tr><td><a href="/rust">rust</a></td><td><a>1.rs</a></td><td> 163ms </td><td>0.3ms</td><td>1.8MB</td>
<td>157ms</td><td>0ms</td><td title="g++ x > y">rustc 1.88.0</td></tr>
<tr><td>ruby</td><td>1.rb</td><td>timeout</td><td>0.0ms</td><td>13.5MB</td><td>4980ms</td><td>0ms</td><td>ruby 3.4.5</td></tr>
</tbody></table>
"""


def test_parse_page_reads_tables_and_timeouts() -> None:
    spec = ProblemSpec(name="nbody", tests=[BenchInput(input="500000"), BenchInput(input="5000000")])
    rows = parse_page(PAGE, spec, "2025-08-01")
    assert [(r.lang, r.status, r.time_ms, r.compiler) for r in rows] == [
        ("rust", "ok", 163.0, "rustc"),
        ("ruby", "timeout", None, "ruby"),
    ]
    assert rows[0].peak_mem_mb == 1.8
    assert rows[0].input_index == 0


def test_units() -> None:
    assert parse_ms("1.5s") == 1500
    assert parse_ms("timeout") is None
    assert parse_mb("2.0GB") == 2048
