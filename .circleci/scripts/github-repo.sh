#!/usr/bin/env bash
# Prints owner/name of the GitHub repository this checkout came from. CIRCLE_PROJECT_USERNAME is the
# CircleCI organization for projects connected through the GitHub App, which need not match the owner.
set -euo pipefail

git remote get-url origin | sed -E 's#^(git@github\.com:|ssh://git@github\.com/|https://github\.com/)##; s#\.git$##; s#/$##'
