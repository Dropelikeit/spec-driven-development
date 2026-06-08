#!/usr/bin/env bash
# Rebuild every agent and fail if the committed generated artifacts (skills/,
# dist/, plugins/) differ from a fresh build.
#
# The marketplace installs plugins directly from the repo tree on `main`
# (`/plugin marketplace add GameFixxer/spec-driven-development` reads
# ./plugins/claude/...), and release.yml no longer regenerates artifacts after a
# merge. So the committed artifacts ARE the distribution and must always match
# the sources. This gate (run by verify-build.yml on every PR) enforces that a
# contributor who changed a source also committed the rebuilt artifacts.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/build.sh all >/dev/null

if ! git diff --quiet -- skills dist plugins \
  || [ -n "$(git ls-files --others --exclude-standard -- skills dist plugins)" ]; then
  echo "::error::Generated artifacts are out of date. Run 'bash scripts/build.sh all' and commit the result."
  git status --porcelain -- skills dist plugins
  git --no-pager diff -- skills dist plugins
  exit 1
fi

echo "Generated artifacts are up to date."
