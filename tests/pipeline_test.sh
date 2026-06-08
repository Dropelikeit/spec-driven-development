#!/usr/bin/env bash
# Meta-tests for the build/release pipeline GATES. The build smoke test
# (build_test.sh) checks that a correct build produces correct output; this
# checks that the safeguards reject INCORRECT states — i.e. that the things that
# previously broke production would now fail CI:
#   1. a changed source without rebuilt artifacts is caught (drift gate)
#   2. a version mismatch across manifests is caught (validate.py)
#   3. a repository field as an object instead of a string is caught (validate.py)
#
# It mutates a few tracked files and restores exactly those files, so it is safe
# to run with other uncommitted work in the tree.
set -uo pipefail
cd "$(dirname "$0")/.."

TOUCHED="adapters/claude/prelude.md .roo-plugin/plugin.json .claude-plugin/plugin.json"

fail() { echo "PIPELINE TEST FAIL: $*" >&2; exit 1; }

restore() {
  # shellcheck disable=SC2086
  git checkout -- $TOUCHED >/dev/null 2>&1 || true
  bash scripts/build.sh all >/dev/null 2>&1 || true
}
trap restore EXIT

# Precondition: a fresh build leaves the tree clean.
bash scripts/build.sh all >/dev/null
git diff --quiet -- skills dist plugins \
  || fail "unexpected drift before tests — commit a clean build first"

# --- 1. Drift gate detects a source change with stale artifacts ---
printf '\n<!-- pipeline-test drift marker -->\n' >> adapters/claude/prelude.md
if bash scripts/check_drift.sh >/dev/null 2>&1; then
  fail "check_drift.sh did NOT detect drift after editing a source"
fi
git checkout -- adapters/claude/prelude.md
bash scripts/build.sh all >/dev/null
git diff --quiet -- skills dist plugins || fail "could not restore clean tree after drift test"
echo "  ok: drift gate detects stale artifacts"

# --- 2. validate.py rejects a version mismatch across manifests ---
tmp="$(mktemp)"
jq '.version = "9.9.9"' .roo-plugin/plugin.json > "$tmp" && mv "$tmp" .roo-plugin/plugin.json
if python3 scripts/validate.py >/dev/null 2>&1; then
  fail "validate.py did NOT reject a cross-manifest version mismatch"
fi
git checkout -- .roo-plugin/plugin.json
echo "  ok: validate.py rejects version mismatch"

# --- 3. validate.py rejects an object-form repository (the original prod bug) ---
tmp="$(mktemp)"
jq '.repository = {"type":"git","url":"https://example.invalid"}' \
  .claude-plugin/plugin.json > "$tmp" && mv "$tmp" .claude-plugin/plugin.json
if python3 scripts/validate.py >/dev/null 2>&1; then
  fail "validate.py did NOT reject an object-form repository field"
fi
git checkout -- .claude-plugin/plugin.json
echo "  ok: validate.py rejects object-form repository"

echo "pipeline self-tests: OK"
