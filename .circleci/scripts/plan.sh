#!/usr/bin/env bash
# Writes .work/plan.txt: one toolchain id per line, the toolchains this pipeline should benchmark.
set -euo pipefail

mkdir -p .work
if [ -n "${REQUESTED:-}" ]; then
  if [ "$REQUESTED" = "all" ]; then select=(--all); else select=(--all --only "$REQUESTED"); fi
else
  if [ "${CIRCLE_BRANCH:-}" = "main" ]; then
    # The commit main pointed at before this push; empty on a project's first build.
    base="${BASE_REVISION:-}"
    git cat-file -e "${base:-none}^{commit}" 2>/dev/null || base=$(git rev-parse HEAD~1)
  else
    git fetch -q origin main
    base=$(git merge-base origin/main HEAD)
  fi
  echo "Comparing against $base"
  if git diff --name-only "$base" HEAD | grep -qE '^(runner/|bench/timer/|bench/profiles.json)'; then
    select=(--all)
  else
    git show "$base:bench/toolchains.json" > .work/base-toolchains.json 2>/dev/null || : > .work/base-toolchains.json
    git show "$base:bench/programs/sources.json" > .work/base-sources.json 2>/dev/null || : > .work/base-sources.json
    git diff --name-only "$base" HEAD > .work/changed-files.txt
    # Telling which toolchains use a changed program needs upstream's per-language YAML files.
    if grep -q '^bench/programs/' .work/changed-files.txt; then
      python -m runner sync-upstream
    fi
    select=(--base .work/base-toolchains.json --changed-files .work/changed-files.txt
            --base-sources .work/base-sources.json)
  fi
fi

python -m runner changed "${select[@]}" --profile ci-4vcpu \
  | python -c 'import json, sys; print("\n".join(json.load(sys.stdin)["toolchain"]))' \
  | sed '/^$/d' > .work/plan.txt

if [ -s .work/plan.txt ]; then
  echo "Toolchains to benchmark:"
  cat .work/plan.txt
else
  echo "No toolchain changed; nothing to benchmark."
fi
