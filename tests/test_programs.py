from pathlib import Path

import pytest

from runner.compare import program_toolchains
from runner.config import PROGRAMS_DIR, UPSTREAM_BENCH, load_source_changes
from runner.measure import Attempt, Measurer, _measure_entry
from runner.models import BenchInput, BuildEntry, ProblemSpec, Profile, Toolchain
from runner.stats import Sample

OWN_PROGRAMS = sorted(
    p for p in PROGRAMS_DIR.glob("*/*") if p.is_file() and p.parent.name != "include" and p.name != "sources.json"
)


def _added() -> set[tuple[str, str]]:
    return {
        (problem, name)
        for problems in load_source_changes().add.values()
        for problem, names in problems.items()
        for name in names
    }


def test_every_own_program_is_listed_in_sources() -> None:
    listed = _added()
    unlisted = [str(p.relative_to(PROGRAMS_DIR)) for p in OWN_PROGRAMS if (p.parent.name, p.name) not in listed]
    assert unlisted == []


@pytest.mark.skipif(not UPSTREAM_BENCH.is_dir(), reason="upstream programs not synced")
def test_listed_programs_exist_and_never_shadow_upstream() -> None:
    for problem, name in _added():
        own = PROGRAMS_DIR / problem / name
        upstream = UPSTREAM_BENCH / "algorithm" / problem / name
        assert own.is_file() or upstream.is_file(), f"{problem}/{name} exists nowhere"
        assert not (own.is_file() and upstream.is_file()), f"{problem}/{name} would hide upstream's file"


def test_c_and_cpp_share_one_md5_header() -> None:
    c = (PROGRAMS_DIR / "include" / "c" / "md5.h").read_text()
    assert c == (PROGRAMS_DIR / "include" / "cpp" / "md5.h").read_text()


@pytest.mark.skipif(not UPSTREAM_BENCH.is_dir(), reason="upstream programs not synced")
def test_changed_programs_select_only_the_toolchains_that_use_them() -> None:
    paths = ["bench/programs/regex-redux/1.c", "bench/programs/include/ocaml/dune", "web/src/app/page.tsx"]
    assert program_toolchains(paths, None) == ["c-gcc", "ocaml"]


class FakeMeasurer(Measurer):
    """Replays canned attempts instead of running anything in a container."""

    def __init__(self, profile: Profile, attempts: list[Attempt]) -> None:
        self.profile = profile
        self.attempts = attempts
        self.calls = 0

    def once(self, argv: list[str], workdir: str, cpus: str) -> Attempt:
        self.calls += 1
        return self.attempts[min(self.calls, len(self.attempts)) - 1]


def _measure(tmp_path: Path, attempts: list[Attempt]) -> tuple[FakeMeasurer, str]:
    profile = Profile(
        id="t", name="t", cpuset_single="0", cpuset_multi="0", memory_mb=512, warmup=1, repeats=3,
        timeout_s=600, slow_s=30, inputs="largest",
    )
    entry = BuildEntry(problem="p", source="1.c", path="p/1_c", out_dir="out", run_cmd="app", status="ok", build_ms=1)
    (tmp_path / "p" / "1_c" / "out").mkdir(parents=True)
    toolchain = Toolchain(id="c", lang="c", config="c.yaml", compiler="gcc", version="1", image="gcc")
    measurer = FakeMeasurer(profile, attempts)
    rows = _measure_entry(measurer, entry, ProblemSpec(name="p", tests=[BenchInput(input="5")]), tmp_path, toolchain)
    return measurer, rows[0].status


def test_slow_warmup_is_followed_by_a_single_timed_run(tmp_path: Path) -> None:
    measurer, status = _measure(tmp_path, [Attempt("ok", Sample(45_000, 45_000, 0, 1024))])
    assert (measurer.calls, status) == (2, "ok")


def test_fast_programs_keep_every_repeat(tmp_path: Path) -> None:
    measurer, status = _measure(tmp_path, [Attempt("ok", Sample(100, 100, 0, 1024))])
    assert (measurer.calls, status) == (4, "ok")


def test_failed_warmup_is_recorded_without_more_runs(tmp_path: Path) -> None:
    measurer, status = _measure(tmp_path, [Attempt("timeout", None)])
    assert (measurer.calls, status) == (1, "timeout")
