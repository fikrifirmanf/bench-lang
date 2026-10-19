"""Compile every implementation of a toolchain inside its pinned docker image."""

from __future__ import annotations

import logging
import shutil
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from . import docker
from .config import UPSTREAM_BENCH, WORK_DIR, load_bench_file, load_lang_file, select_environment, write_json
from .models import BuildEntry, BuildManifest, Environment, Toolchain

log = logging.getLogger(__name__)

BUILD_TIMEOUT_S = 1800
X86 = {"amd64", "x86_64"}
# Upstream tunes for x86 (broadwell). On other hosts those flags would not compile.
ARCH_REWRITES = [("-march=broadwell", ""), ("broadwell", "native"), ("-a x86_64", ""), ("linux-x64", "linux-arm64")]


def builds_dir(toolchain: Toolchain) -> Path:
    return WORK_DIR / "builds" / toolchain.id


def _rewrite(text: str, arch: str) -> str:
    if arch in X86:
        return text
    for old, new in ARCH_REWRITES:
        text = text.replace(old, new)
    return text


def _rewrite_tree(root: Path, arch: str) -> None:
    if arch in X86:
        return
    for path in root.rglob("*"):
        if not path.is_file() or path.stat().st_size > 65536:
            continue
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue
        updated = _rewrite(text, arch)
        if updated != text:
            path.write_text(updated)


def _strip_sudo(cmd: str) -> str:
    return cmd[5:] if cmd.startswith("sudo ") else cmd


@dataclass(frozen=True)
class Job:
    problem: str
    source: str
    rel: str


def _stage(env: Environment, toolchain: Toolchain, rename_to: str, job: Job, arch: str) -> None:
    target = builds_dir(toolchain) / job.rel
    if env.include:
        shutil.copytree(UPSTREAM_BENCH / "include" / env.include, target, dirs_exist_ok=True)
    source_dir = target / env.include_sub_dir if env.include_sub_dir else target
    source_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(UPSTREAM_BENCH / "algorithm" / job.problem / job.source, source_dir / rename_to)
    (target / env.out_dir).mkdir(parents=True, exist_ok=True)
    _rewrite_tree(target, arch)


def _jobs(toolchain: Toolchain, problems: set[str] | None) -> tuple[Environment, str, list[Job]]:
    lang_file = load_lang_file(toolchain)
    env = select_environment(lang_file, toolchain)
    known = {p.name for p in load_bench_file().problems}
    jobs = [
        Job(problem.name, source, f"{problem.name}/{source.replace('.', '_')}")
        for problem in lang_file.problems
        if problem.name in known and (problems is None or problem.name in problems)
        for source in problem.source
    ]
    return env, lang_file.source_rename_to, jobs


def build(toolchain: Toolchain, problems: set[str] | None = None, jobs: int = 1) -> BuildManifest:
    env, rename_to, work = _jobs(toolchain, problems)
    if not work:
        raise ValueError(f"no implementations selected for {toolchain.id}")
    arch = docker.arch()
    root = builds_dir(toolchain)
    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True)
    for job in work:
        _stage(env, toolchain, rename_to, job, arch)

    image = toolchain.image_ref
    log.info("pulling %s", image)
    docker.pull(image)
    build_env = {k: _rewrite(v, arch) for k, v in {**env.env, **toolchain.env}.items()}
    mounts: list[tuple[Path | str, str, bool]] = [(root, "/work", False)]
    mounts += [(f"bench-cache-{toolchain.id}-{i}", path, False) for i, path in enumerate(toolchain.cache_dirs)]
    steps = [
        *(toolchain.fill(s) for s in toolchain.setup),
        *(_strip_sudo(c) for c in env.before_build),
        toolchain.fill(toolchain.build or env.build),
        *(_strip_sudo(c) for c in env.after_build),
    ]
    script = " && ".join(_rewrite(step, arch) for step in steps)
    run_cmd = toolchain.run_cmd or env.run_cmd

    with docker.Container(image=image, name=f"bench-build-{toolchain.id}", mounts=mounts, env=build_env) as box:
        if toolchain.image_setup:
            setup = box.sh(" && ".join(toolchain.fill(s) for s in toolchain.image_setup), timeout_s=900)
            if setup.code != 0:
                raise docker.DockerError(f"image setup failed: {setup.stderr.strip()[-400:]}")
        detail = ""
        if toolchain.version_command:
            lines = box.sh(toolchain.version_command, timeout_s=60).stdout.strip().splitlines()
            detail = lines[0] if lines else ""

        def compile_one(job: Job) -> BuildEntry:
            started = time.monotonic()
            result = box.sh(script, workdir=f"/work/{job.rel}", timeout_s=BUILD_TIMEOUT_S)
            elapsed = int((time.monotonic() - started) * 1000)
            (root / job.rel / "build.log").write_text(result.stdout + "\n--- stderr ---\n" + result.stderr)
            out = root / job.rel / env.out_dir
            ok = result.code == 0 and out.is_dir() and any(out.iterdir())
            log.info("%s %s/%s in %ss", "built" if ok else "FAILED", job.problem, job.source, elapsed // 1000)
            return BuildEntry(
                problem=job.problem,
                source=job.source,
                path=job.rel,
                out_dir=env.out_dir,
                run_cmd=run_cmd,
                status="ok" if ok else "build-fail",
                build_ms=elapsed,
            )

        with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
            entries = list(pool.map(compile_one, work))

    manifest = BuildManifest(
        toolchain=toolchain.id,
        image=image,
        compiler=toolchain.compiler,
        version=toolchain.version,
        version_detail=detail,
        arch=arch,
        entries=entries,
    )
    write_json(root / "manifest.json", manifest.model_dump())
    return manifest
