#!/usr/bin/env bash
# Merges the bench job's results into data/ and pushes them to main. [skip ci] keeps the push from
# starting another pipeline; Vercel still redeploys the site from it.
set -euo pipefail

if ! ls .work/results/ci-4vcpu/*.json > /dev/null 2>&1; then
  echo "No new results to publish."
  exit 0
fi

python -m runner compare --profile ci-4vcpu
python -m runner merge --profile ci-4vcpu

git add data
if git diff --cached --quiet; then
  echo "Results match what is published."
  exit 0
fi

git config user.name "bench-lang bot"
git config user.email "bench-lang-bot@users.noreply.github.com"
git commit -q -m "Publish benchmark results (CircleCI ${CIRCLE_BUILD_NUM}) [skip ci]"

remote="https://x-access-token:${GH_BOT_TOKEN}@github.com/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}.git"
# main may have moved while the benchmarks ran. Only this job writes data/, so the rebase does not conflict.
for attempt in 1 2 3; do
  git pull -q --rebase "$remote" main && git push -q "$remote" HEAD:main && exit 0
  echo "Push attempt $attempt failed, retrying"
  sleep $((attempt * 10))
done
echo "Could not push results to main" >&2
exit 1
