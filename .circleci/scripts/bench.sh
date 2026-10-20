#!/usr/bin/env bash
# Builds and measures this node's share of .work/plan.txt. A failing toolchain is logged and skipped
# so it never blocks the others; its log is kept as a build artifact.
#
# Branches other than main only build: that catches a broken toolchain bump before merge, and the
# measuring happens once, on main, where the results are published. A manual trigger always measures.
set -uo pipefail

measure=true
if [ "${CIRCLE_BRANCH:-}" != "main" ] && [ -z "${REQUESTED:-}" ]; then
  measure=false
  echo "Branch ${CIRCLE_BRANCH:-?}: building only."
fi

mkdir -p .work/results/ci-4vcpu .work/logs
# Longest toolchain first, each to the node with the least work so far, so no node exceeds the plan's
# one-hour job limit by drawing two slow interpreters.
mine=$(python3 - .work/plan.txt .circleci/weights.json "${CIRCLE_NODE_INDEX:-0}" "${CIRCLE_NODE_TOTAL:-1}" <<'PY'
import json, sys
plan, weights_file, index, total = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
ids = [line.strip() for line in open(plan) if line.strip()]
weights = json.load(open(weights_file))
load = [0] * total
nodes = [[] for _ in range(total)]
for tid in sorted(ids, key=lambda t: -weights.get(t, 300)):
    node = load.index(min(load))
    nodes[node].append(tid)
    load[node] += weights.get(tid, 300)
print(" ".join(nodes[index]))
PY
)
if [ -z "$mine" ]; then
  echo "Nothing assigned to this node."
  circleci-agent step halt
  exit 0
fi

python3 -m venv .venv
.venv/bin/pip install -q -r requirements.txt

failed=()
for id in $mine; do
  echo "=== $id"
  if ! { .venv/bin/python -m runner build --toolchain "$id" \
      && { [ "$measure" = false ] || .venv/bin/python -m runner measure --toolchain "$id" --profile ci-4vcpu; }; } \
      2>&1 | tee ".work/logs/$id.log"; then
    failed+=("$id")
  fi
  # Each toolchain image is several GB; the machine's disk only fits a few at once.
  docker image prune -af > /dev/null
done

.venv/bin/python -m runner compare --profile ci-4vcpu || true

if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}. Results from the others are still published; see the logs under Artifacts."
fi
