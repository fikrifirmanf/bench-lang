"""Command line entry point: `python -m runner <command>`."""

from __future__ import annotations

import argparse
import logging
import sys

from pathlib import Path

from . import build as build_mod
from . import compare, upstream, versions
from . import measure as measure_mod
from . import merge as merge_mod
from .config import DATA_DIR, TOOLCHAINS_FILE, ConfigError, get_profile, get_toolchain, load_bench_file, load_toolchains
from .docker import DockerError
from .importsite import import_site
from .measure import results_dir
from .models import Run


def _problems(value: str | None) -> set[str] | None:
    return {p.strip() for p in value.split(",") if p.strip()} if value else None


def cmd_list(_args: argparse.Namespace) -> int:
    for t in load_toolchains():
        excluded = f"  (not on: {', '.join(t.exclude_profiles)})" if t.exclude_profiles else ""
        print(f"{t.id:12} {t.lang:11} {t.compiler:12} {t.version:9} {t.image_ref}{excluded}")
    return 0


def cmd_sync(_args: argparse.Namespace) -> int:
    print(f"upstream at {upstream.sync()}")
    return 0


def cmd_build(args: argparse.Namespace) -> int:
    upstream.sync()
    manifest = build_mod.build(get_toolchain(args.toolchain), _problems(args.problems), args.jobs)
    failed = [e for e in manifest.entries if e.status != "ok"]
    print(f"{args.toolchain}: {len(manifest.entries) - len(failed)} built, {len(failed)} failed ({manifest.version_detail})")
    return 0


def cmd_measure(args: argparse.Namespace) -> int:
    upstream.sync()
    run = measure_mod.measure(get_toolchain(args.toolchain), get_profile(args.profile), _problems(args.problems))
    ok = sum(1 for r in run.rows if r.status == "ok")
    print(f"{args.toolchain} on {args.profile}: {ok}/{len(run.rows)} results ok")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    upstream.sync()
    toolchain, profile = get_toolchain(args.toolchain), get_profile(args.profile)
    results = measure_mod.check(toolchain, profile, _problems(args.problems), args.timing)
    for key, status in results.items():
        print(f"{key:32} {status}")
    passed = sum(1 for s in results.values() if s.startswith("ok"))
    print(f"{args.toolchain}: {passed}/{len(results)} pass the correctness checks")
    return 0 if passed == len(results) else 1


def cmd_merge(args: argparse.Namespace) -> int:
    run = merge_mod.merge_results(results_dir(get_profile(args.profile)), args.run_id)
    print(f"published {run.profile}/{run.id} with {len(run.rows)} rows")
    return 0


def cmd_versions(args: argparse.Namespace) -> int:
    report = versions.check_all()
    for status in report.toolchains:
        print(f"{status.id:12} {status.current:10} -> {status.latest or '?':10} {status.status}")
    if args.write:
        changes = versions.apply_updates(report)
        bumped = {line.split(":", 1)[0] for line in changes}
        report = report.model_copy(
            update={
                "toolchains": [
                    s.model_copy(update={"current": s.latest, "status": "current"}) if s.id in bumped else s
                    for s in report.toolchains
                ]
            }
        )
        if args.changes_file:
            with open(args.changes_file, "w") as handle:
                handle.write("\n".join(changes) + ("\n" if changes else ""))
        print(f"{len(changes)} toolchain(s) bumped")
    versions.write_report(report)
    return 0


def cmd_import(args: argparse.Namespace) -> int:
    commit = upstream.sync()
    run = import_site(load_bench_file().problems, args.date, commit)
    merge_mod.publish(run)
    print(f"imported {len(run.rows)} rows into {run.profile}/{run.id}")
    return 0


def cmd_changed(args: argparse.Namespace) -> int:
    profile = get_profile(args.profile) if args.profile else None
    ids = [t.id for t in load_toolchains()] if args.all else compare.changed_toolchains(Path(args.base), TOOLCHAINS_FILE)
    if args.changed_files:
        paths = Path(args.changed_files).read_text().split()
        base_sources = Path(args.base_sources) if args.base_sources else None
        ids += [i for i in compare.program_toolchains(paths, base_sources) if i not in ids]
    if args.only:
        wanted = _problems(args.only) or set()
        ids = [i for i in ids if i in wanted]
    if profile:
        ids = [i for i in ids if profile.id not in get_toolchain(i).exclude_profiles]
    print(compare.matrix(ids))
    return 0


def cmd_compare(args: argparse.Namespace) -> int:
    profile = get_profile(args.profile)
    fresh = [row for path in sorted(results_dir(profile).glob("*.json")) for row in Run.model_validate_json(path.read_text()).rows]
    latest = DATA_DIR / "latest" / f"{profile.id}.json"
    published = Run.model_validate_json(latest.read_text()) if latest.is_file() else None
    print(compare.markdown(fresh, published), end="")
    return 0


def cmd_index(_args: argparse.Namespace) -> int:
    index = merge_mod.rebuild_index()
    print(f"index: {len(index.runs)} runs")
    return 0


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="runner", description="bench-lang benchmark runner")
    p.add_argument("-v", "--verbose", action="store_true")
    sub = p.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="list configured toolchains").set_defaults(func=cmd_list)
    sub.add_parser("sync-upstream", help="fetch upstream programs at the pinned commit").set_defaults(func=cmd_sync)

    b = sub.add_parser("build", help="compile a toolchain's implementations")
    b.add_argument("--toolchain", required=True)
    b.add_argument("--problems", help="comma-separated problem names")
    b.add_argument("--jobs", type=int, default=1)
    b.set_defaults(func=cmd_build)

    m = sub.add_parser("measure", help="run built implementations under a profile")
    m.add_argument("--toolchain", required=True)
    m.add_argument("--profile", required=True)
    m.add_argument("--problems", help="comma-separated problem names")
    m.set_defaults(func=cmd_measure)

    k = sub.add_parser("check", help="run only the correctness checks of the last build")
    k.add_argument("--toolchain", required=True)
    k.add_argument("--profile", default="local")
    k.add_argument("--problems", help="comma-separated problem names")
    k.add_argument("--timing", action="store_true", help="also run the largest input once and print its time")
    k.set_defaults(func=cmd_check)

    g = sub.add_parser("merge", help="publish measured results into data/")
    g.add_argument("--profile", required=True)
    g.add_argument("--run-id")
    g.set_defaults(func=cmd_merge)

    v = sub.add_parser("versions", help="check toolchains for newer releases")
    v.add_argument("--write", action="store_true", help="bump pinned versions in bench/toolchains.json")
    v.add_argument("--changes-file", help="write one line per bumped toolchain here")
    v.set_defaults(func=cmd_versions)

    i = sub.add_parser("import-site", help="seed data/ from the upstream site's last published run")
    i.add_argument("--date", default="2025-08-01")
    i.set_defaults(func=cmd_import)

    c = sub.add_parser("changed", help="print a CI matrix of toolchains that differ from a base toolchains.json")
    c.add_argument("--base", default="", help="path to the base version of bench/toolchains.json")
    c.add_argument("--all", action="store_true", help="select every toolchain")
    c.add_argument("--changed-files", help="file listing changed repository paths; adds toolchains whose programs changed")
    c.add_argument("--base-sources", help="path to the base version of bench/programs/sources.json")
    c.add_argument("--only", help="comma-separated toolchain ids to keep")
    c.add_argument("--profile", help="drop toolchains excluded from this profile")
    c.set_defaults(func=cmd_changed)

    r = sub.add_parser("compare", help="markdown summary of fresh results against published data")
    r.add_argument("--profile", required=True)
    r.set_defaults(func=cmd_compare)

    sub.add_parser("index", help="rebuild data/index.json").set_defaults(func=cmd_index)
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO, format="%(levelname)s %(message)s")
    try:
        return int(args.func(args))
    except (ConfigError, DockerError, upstream.UpstreamError, ValueError, RuntimeError) as exc:
        logging.getLogger("runner").error("%s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
