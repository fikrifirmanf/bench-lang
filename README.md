# bench/lang

A programming-language benchmark site that stays current on its own. Every compiler and runtime is pinned to an exact
Docker image. A daily bot opens a pull request when a newer stable release ships, CI reruns the benchmarks, and the
static site redeploys with the new numbers.

The benchmark programs come from
[hanabi1224/Programming-Language-Benchmarks](https://github.com/hanabi1224/Programming-Language-Benchmarks) (MIT),
pinned to a commit in `bench/upstream.json`. This project adds the runner, the automation and the website.

```
bench/            what to run: toolchains (image + version), machine profiles, the C timer
runner/           Python CLI: build, measure, merge, version checks
data/             published results, read by the website at build time
web/              Next.js static site (neo-brutal design)
deploy/vm/        setup script for the 2 vCPU / 2 GB benchmark VM
.github/workflows ci, daily version bot, benchmark pipeline
```

## How a measurement works

1. `runner build` copies each upstream implementation into `.work/builds/<toolchain>/`, starts the toolchain's pinned
   image once, and compiles every program inside it. Each program must then reproduce upstream's expected output.
2. `runner measure` starts the same image with a CPU set and a hard memory cap (memory and swap are equal, so the
   container can never swap). A static C program, `bench/timer/timer.c`, is mounted into the container and runs each
   benchmark. It records wall time, user and system CPU time, and peak RSS from `wait4`, so `docker exec` startup is
   never counted.
3. Each input gets warmup runs, then N measured runs (mean and standard deviation). Timeouts, OOM kills, crashes and
   wrong output are recorded as statuses instead of numbers.
4. `runner merge` writes a dated run to `data/runs/<profile>/` and folds it into `data/latest/<profile>.json`. Only the
   (language, compiler) pairs that were re-measured are replaced, so a run that only updated Rust leaves every other
   language as it was.

Upstream tunes for x86 (`-march=broadwell`). On an ARM machine, such as an Apple Silicon Mac, the runner swaps those
flags for portable ones so you can test locally. Programs written with x86 intrinsics will not build there, which is
expected.

## Machine profiles (`bench/profiles.json`)

| profile    | where                         | CPUs (single / multi) | memory cap | repeats | inputs  |
|------------|-------------------------------|-----------------------|------------|---------|---------|
| `ci-4vcpu` | GitHub-hosted `ubuntu-24.04`  | 0 / 0-3               | 12 GB      | 3       | all     |
| `small-vm` | your VM, self-hosted runner   | 1 / 0-1               | 1.7 GB     | 5       | largest |
| `local`    | your laptop, for trying things | 0 / 0-1              | 4 GB       | 1       | largest |

The small VM never compiles anything. CI builds the programs and uploads them, and the VM downloads and runs them one
toolchain at a time. Java with ZGC is excluded there because a single run needs more than 2 GB, and `JAVA_TOOL_OPTIONS`
caps the heap at 1 GB.

## Run it locally

Needs Docker, Python 3.11+ and Node 24 with pnpm.

```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m runner list                                   # configured toolchains
.venv/bin/python -m runner build   --toolchain go --problems nbody
.venv/bin/python -m runner measure --toolchain go --profile local --problems nbody
.venv/bin/python -m runner compare --profile local                 # what moved against data/
.venv/bin/python -m runner versions                                # newest stable releases
.venv/bin/python -m pytest -q tests

cd web && pnpm install && pnpm dev                                 # http://localhost:3000
```

`runner merge --profile local` publishes local results into `data/`. Until CI publishes, the site shows that profile.

## Adding a language

Add one entry to `bench/toolchains.json`:

```json
{
  "id": "go",
  "lang": "go",
  "config": "bench_go.yaml",
  "compiler": "go",
  "version": "1.24.5",
  "image": "golang:{version}-bookworm",
  "version_command": "go version",
  "check": { "source": "dockerhub", "repo": "library/golang", "name_hint": "bookworm", "tag_regex": "^(\\d+\\.\\d+\\.\\d+)-bookworm$" }
}
```

- `config` and `compiler` select the upstream YAML file and its environment. Build and run commands come from there.
- `build`, `run_cmd`, `env`, `setup` (per program) and `image_setup` (once per container) override or extend upstream.
- `check` tells the version bot where to look: `dockerhub`, `mcr` or `github-tags`. Make `tag_regex` match stable
  releases only. For example, the .NET entry matches `10.0.402` but not the `11.0` tag, which currently points at a
  release candidate. OCaml reads the compiler's GitHub tags because `ocaml/opam` publishes images for the next,
  unreleased minor. `kotlin-jvm` stays on JDK 21: upstream's Gradle 8.13 wrapper cannot run on newer JDKs, so widen
  its regex once that wrapper is upgraded. `zig` stays on 0.14.x for the same kind of reason: upstream's `build.zig`
uses the 0.14 build API, which 0.15 removed.

## Deploy

1. Push this folder to a GitHub repository.
2. **Website:** import the repository in Vercel with Root Directory `web`. The site is a static export, so every push
   that changes `data/` redeploys it.
3. **Version bot:** create a fine-grained token with *Contents* and *Pull requests* write access to the repository,
   and save it as the secret `BOT_TOKEN`. Pull requests opened with the default token do not trigger other workflows,
   so without it the benchmarks would not rerun on the bot's pull requests.
4. **Small VM (optional):** on an x86_64 Ubuntu VM, run
   `sudo REPO_URL=https://github.com/<you>/<repo> RUNNER_TOKEN=<token> deploy/vm/setup.sh`, then set the repository
   variable `SMALL_VM_ENABLED=true`.
5. Run the **bench** workflow manually once with `all` to replace the imported numbers with your own.

### CircleCI instead of GitHub Actions

`.circleci/config.yml` does the same jobs (without the small-VM leg) for when Actions is unavailable. Run only one
of the two: disable the GitHub workflows with `gh workflow disable <name>` while CircleCI is in use.

1. Sign in at circleci.com with GitHub, set up this repository and pick the existing `.circleci/config.yml`.
2. Project Settings → Environment Variables: add `GH_BOT_TOKEN`, the fine-grained token from step 3 above. It pushes
   results to `main` and the version bot's branch.
3. Project Settings → Triggers: add a daily schedule on `main` with the pipeline parameter `run_versions` = `true`.
4. Trigger a pipeline on `main` with the parameter `bench_toolchains` = `all` for the first full run.

The benchmark job uses the `large` machine class (4 vCPU, 15 GB), about 20 credits per minute, split over 4 parallel
machines. A full run is roughly 100–300 machine minutes; a version bump is 10–30.

## Data

The site currently publishes only the `local` profile (one run on an Apple M5 laptop). The earlier import of
upstream's results was removed; `ci-4vcpu` fills in again with the first CI run. `runner import-site` can still bring
upstream's numbers back.

There is no database. Every run stays in `data/runs/<profile>/` and git keeps the full record. At build time the site
replays those runs in order (the same fold as `runner merge`) to draw the "Over time" charts on language and problem
pages; they appear once a profile has two runs.

## Status

| part | state |
|------|-------|
| Runner, timer, statuses (timeout, OOM, wrong output) | tested locally with Docker |
| Toolchains verified end to end here | python, node, go, rust, c-gcc (on ARM; x86 intrinsics programs skipped) |
| Other toolchains in `bench/toolchains.json` | configured from upstream's commands, first verified by the first CI run |
| Version checker | tested against live Docker Hub, MCR and GitHub |
| Website | type-checked, linted, static build of 53 pages, checked at desktop and 390px widths |
| Workflows | pass actionlint and shellcheck; they first run once pushed to GitHub |
| VM setup script | passes shellcheck; not yet run on a real VM |
