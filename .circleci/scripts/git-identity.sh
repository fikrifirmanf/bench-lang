#!/usr/bin/env bash
# Commits as the owner of GH_BOT_TOKEN, using their GitHub no-reply address. Vercel's Hobby plan only deploys
# commits to a private repository whose author is the account owner, so a separate bot identity would be blocked.
set -euo pipefail

: "${GH_BOT_TOKEN:?is not set. Add it in CircleCI Project Settings > Environment Variables (see README, CircleCI section)}"

identity=$(curl -fsS --max-time 20 --retry 2 \
  -H "Authorization: Bearer ${GH_BOT_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user \
  | python -c '
import json, sys
u = json.load(sys.stdin)
print(u["name"] or u["login"])
print("{}+{}@users.noreply.github.com".format(u["id"], u["login"]))
')

git config user.name "$(sed -n 1p <<< "$identity")"
git config user.email "$(sed -n 2p <<< "$identity")"
