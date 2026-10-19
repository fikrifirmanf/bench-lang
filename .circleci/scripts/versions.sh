#!/usr/bin/env bash
# Looks for newer stable toolchains. When there are any, pushes the bumps to bot/toolchain-updates and
# opens (or refreshes) one pull request. Pushing that branch starts a pipeline that benchmarks them.
set -euo pipefail

: "${GH_BOT_TOKEN:?is not set. Add it in CircleCI Project Settings > Environment Variables (see README, CircleCI section)}"

python -m runner versions --write --changes-file .work-changes.txt
if [ ! -s .work-changes.txt ]; then
  echo "Every toolchain is current."
  exit 0
fi

branch=bot/toolchain-updates
repo="${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
remote="https://x-access-token:${GH_BOT_TOKEN}@github.com/${repo}.git"

git checkout -q -B "$branch"
git add bench/toolchains.json data/versions.json
git config user.name "bench-lang bot"
git config user.email "bench-lang-bot@users.noreply.github.com"
git commit -q -m "Bump toolchain versions"
git push -q --force "$remote" "$branch"

body=$(python - <<'PY'
import json
lines = [l.strip() for l in open(".work-changes.txt") if l.strip()]
text = "Newer stable toolchains were released. Merging reruns their benchmarks and publishes the results.\n\n"
print(json.dumps(text + "\n".join(f"- {l}" for l in lines)))
PY
)

api() {
  curl -fsS --max-time 20 --retry 2 \
    -H "Authorization: Bearer ${GH_BOT_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$@"
}

existing=$(api "https://api.github.com/repos/${repo}/pulls?state=open&head=${CIRCLE_PROJECT_USERNAME}:${branch}" \
  | python -c 'import json, sys; prs = json.load(sys.stdin); print(prs[0]["number"] if prs else "")')

if [ -n "$existing" ]; then
  api -X PATCH "https://api.github.com/repos/${repo}/pulls/${existing}" -d "{\"body\": ${body}}" > /dev/null
  echo "Updated pull request #${existing}"
else
  api -X POST "https://api.github.com/repos/${repo}/pulls" \
    -d "{\"title\": \"Toolchain updates\", \"head\": \"${branch}\", \"base\": \"main\", \"body\": ${body}}" > /dev/null
  echo "Opened a pull request from ${branch}"
fi
