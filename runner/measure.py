"""Run built implementations under a machine profile and record their cost."""

from __future__ import annotations

import json
import logging
import shlex
import shutil
import zipfile
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from . import docker
from .build import builds_dir
from .config import UPSTREAM_BENCH, WORK_DIR, load_bench_file, write_json
from .machine import describe
from .models import BuildEntry, BuildManifest, Profile, ProblemSpec, ResultRow, Run, Status, Toolchain
from .stats import Sample, outputs_match, parse_flags, summarize
from .timer import ensure_timer
from .upstream import current_commit

log = logging.getLogger(__name__)

STDOUT_FILE = "_bench_stdout"


def results_dir(profile: Profile) -> Path:
    return WORK_DIR / "results" / profile.id


@dataclass(frozen=True)
class Attempt:
    status: Status
    sample: Sample | None


def _stage_data(spec: ProblemSpec, out: Path) -> None:
    for name in spec.data:
        source = (UPSTREAM_BENCH / "algorithm" / spec.name / name).resolve()
        if not source.is_relative_to(UPSTREAM_BENCH.resolve()):
            raise ValueError(f"data path escapes upstream tree: {name}")
        if source.suffix == ".zip":
            with zipfile.ZipFile(source) as archive:
                archive.extractall(out)
        else:
            shutil.copyfile(source, out / source.name)


class Measurer:
    def __init__(self, box: docker.Container, profile: Profile) -> None:
        self.box = box
        self.profile = profile

    def once(self, argv: list[str], workdir: str, cpus: str) -> Attempt:
        timeout_ms = self.profile.timeout_s * 1000
        cmd = ["/opt/bench/timer", "--timeout-ms", str(timeout_ms), "--cpus", cpus, "--stdout", STDOUT_FILE, "--", *argv]
        result = self.box.exec(cmd, workdir=workdir, timeout_s=self.profile.timeout_s + 60)
        try:
            report = json.loads(result.stdout.strip().splitlines()[-1])
        except (json.JSONDecodeError, IndexError):
            log.warning("timer gave no report: %s", result.stderr.strip()[-200:])
            return Attempt("fail", None)
        if "error" in report:
            log.warning("timer error: %s", report["error"])
            return Attempt("fail", None)
        if report["timeout"]:
            return Attempt("timeout", None)
        if report["signal"] == 9:
            return Attempt("oom", None)
        if report["exit"] != 0:
            return Attempt("fail", None)
        sample = Sample(report["wall_ms"], report["user_ms"], report["sys_ms"], report["maxrss_kb"])
        return Attempt("ok", sample)


def _argv(run_cmd: str, out: Path, args: str) -> list[str]:
    argv = shlex.split(run_cmd)
    if (out / argv[0]).is_file():
        argv[0] = f"./{argv[0]}"
    return [*argv, *shlex.split(args)]


def _measure_entry(
    measurer: Measurer, entry: BuildEntry, spec: ProblemSpec, root: Path, toolchain: Toolchain
) -> list[ResultRow]:
    profile = measurer.profile
    out = root / entry.path / entry.out_dir
    workdir = f"/work/{entry.path}/{entry.out_dir}"
    flags = parse_flags(entry.source)
    cpus = profile.cpuset_multi if "multi-thread" in flags else profile.cpuset_single
    _stage_data(spec, out)

    indexed = list(enumerate(spec.tests))
    targets = indexed if profile.inputs == "all" else indexed[-1:]
    now = datetime.now(UTC).date().isoformat()

    def row(index: int, test_input: str, status: Status, sample_rows: list[Sample]) -> ResultRow:
        fields: dict[str, float] = {}
        if status == "ok":
            summary = summarize(sample_rows)
            fields = {
                "time_ms": summary.time_ms,
                "stddev_ms": summary.stddev_ms,
                "user_ms": summary.user_ms,
                "sys_ms": summary.sys_ms,
                "peak_mem_mb": summary.peak_mem_mb,
            }
        return ResultRow(
            problem=entry.problem,
            input=test_input,
            input_index=index,
            code=entry.source,
            flags=flags,
            status=status,
            measured_at=now,
            lang=toolchain.lang,
            compiler=toolchain.compiler,
            version=toolchain.version,
            **fields,
        )

    if entry.status != "ok":
        return [row(i, t.input, "build-fail", []) for i, t in targets]

    for unit in spec.unittests:
        attempt = measurer.once(_argv(entry.run_cmd, out, unit.input), workdir, cpus)
        expected = (UPSTREAM_BENCH / "algorithm" / spec.name / unit.output).read_text()
        produced = (out / STDOUT_FILE).read_text(errors="replace") if (out / STDOUT_FILE).is_file() else ""
        if attempt.status != "ok" or not outputs_match(produced, expected):
            status: Status = attempt.status if attempt.status != "ok" else "wrong-output"
            log.info("%s %s failed check %s: %s", entry.problem, entry.source, unit.input, status)
            return [row(i, t.input, status, []) for i, t in targets]

    rows: list[ResultRow] = []
    for index, test in targets:
        argv = _argv(entry.run_cmd, out, test.input)
        for _ in range(profile.warmup):
            measurer.once(argv, workdir, cpus)
        samples: list[Sample] = []
        final: Status = "ok"
        for _ in range(profile.repeats):
            attempt = measurer.once(argv, workdir, cpus)
            if attempt.status != "ok" or attempt.sample is None:
                final = attempt.status
                break
            samples.append(attempt.sample)
        rows.append(row(index, test.input, final, samples))
        log.info("%s %s input=%s -> %s", entry.problem, entry.source, test.input, rows[-1].time_ms or final)
    return rows


def measure(toolchain: Toolchain, profile: Profile, problems: set[str] | None = None) -> Run:
    if profile.id in toolchain.exclude_profiles:
        raise ValueError(f"{toolchain.id} is excluded from profile {profile.id}")
    root = builds_dir(toolchain)
    manifest = BuildManifest.model_validate_json((root / "manifest.json").read_text())
    specs = {p.name: p for p in load_bench_file().problems}
    timer = ensure_timer()
    started = datetime.now(UTC)

    image = manifest.image
    docker.pull(image)
    box = docker.Container(
        image=image,
        name=f"bench-run-{toolchain.id}",
        mounts=[(root, "/work", False), (timer, "/opt/bench/timer", True)],
        env={**toolchain.env, **profile.env},
        cpuset=profile.cpuset_multi,
        memory_mb=profile.memory_mb,
    )
    rows: list[ResultRow] = []
    with box:
        if toolchain.image_setup:
            setup = box.sh(" && ".join(toolchain.fill(s) for s in toolchain.image_setup), timeout_s=900)
            if setup.code != 0:
                raise docker.DockerError(f"image setup failed: {setup.stderr.strip()[-400:]}")
        measurer = Measurer(box, profile)
        selected = [e for e in manifest.entries if problems is None or e.problem in problems]
        for entry in selected:
            rows += _measure_entry(measurer, entry, specs[entry.problem], root, toolchain)

    run = Run(
        id=toolchain.id,
        profile=profile.id,
        source="runner",
        started_at=started.isoformat(timespec="seconds"),
        upstream_commit=current_commit(),
        machine=describe(profile.id, manifest.arch),
        rows=rows,
    )
    write_json(results_dir(profile) / f"{toolchain.id}.json", run.model_dump())
    return run
