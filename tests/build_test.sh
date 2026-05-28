#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Smoke test: the build script produces non-empty, well-formed outputs for every agent.
bash scripts/build.sh all

# --- Claude (canonical) ---
OUT="skills/sdd/SKILL.md"
test -s "$OUT" || { echo "FAIL: $OUT empty or missing"; exit 1; }
head -1 "$OUT" | grep -q '^---$' || { echo "FAIL: $OUT missing frontmatter"; exit 1; }
grep -q '^name: sdd$' "$OUT" || { echo "FAIL: missing name"; exit 1; }
! grep -q '<!-- ADAPTER: ' "$OUT" || { echo "FAIL: unsubstituted placeholders remain in $OUT"; exit 1; }

# Claude-specific substitutions must be present
grep -q 'Agent tool' "$OUT" || { echo "FAIL: claude parallel snippet not substituted"; exit 1; }
grep -q '\.claude/CLAUDE\.md' "$OUT" || { echo "FAIL: claude context-file not substituted"; exit 1; }
grep -q 'Agent Teams' "$OUT" || { echo "FAIL: claude sprint-mode snippet missing"; exit 1; }

for needle in "Phase 1" "Phase 5" "Sprint Mode" "Communication Protocol" "Graphify"; do
  grep -qF "$needle" "$OUT" || { echo "FAIL: missing '$needle' in built Claude SKILL.md"; exit 1; }
done

# Claude references must be built
for r in constitution-template sprint-template context-file-template; do
  test -s "skills/sdd/references/$r.md" || { echo "FAIL: missing reference skills/sdd/references/$r.md"; exit 1; }
done

# --- Non-claude agents: well-formed, no stray placeholders, sequential sprint fallback ---
for spec in "codex:dist/codex/skills/sdd/SKILL.md:AGENTS.md" \
            "augment:dist/augment/skills/sdd/SKILL.md:AGENTS.md" \
            "junie:dist/junie/.junie/skills/sdd/SKILL.md:.junie/guidelines.md" \
            "roo:dist/roo/.roo/skills/sdd/SKILL.md:AGENTS.md"; do
  agent="${spec%%:*}"; rest="${spec#*:}"; out="${rest%%:*}"; ctx="${rest#*:}"
  test -s "$out" || { echo "FAIL: $out empty or missing"; exit 1; }
  grep -q '^name: sdd$' "$out" || { echo "FAIL: missing name in $out"; exit 1; }
  ! grep -q '<!-- ADAPTER: ' "$out" || { echo "FAIL: unsubstituted placeholders in $out"; exit 1; }
  grep -qF "$ctx" "$out" || { echo "FAIL: $agent context-file '$ctx' not substituted in $out"; exit 1; }
  grep -q 'runs \*\*sequentially\*\*' "$out" || { echo "FAIL: $agent sprint sequential fallback missing"; exit 1; }
  ! grep -q 'concurrent subagents using the Agent tool' "$out" || { echo "FAIL: $agent leaked claude Agent-tool wording"; exit 1; }
done

# --- Plugin bundles for all five agents ---
for agent in claude codex augment junie roo; do
  b="plugins/$agent/spec-driven-development"
  test -f "$b/skills/sdd/SKILL.md" || { echo "FAIL: $agent bundle skill missing"; exit 1; }
  test -f "$b/icon.png" || { echo "FAIL: $agent bundle icon missing"; exit 1; }
done
test -f plugins/claude/spec-driven-development/.claude-plugin/plugin.json || { echo "FAIL: claude bundle manifest missing"; exit 1; }
test -f plugins/codex/spec-driven-development/.codex-plugin/plugin.json || { echo "FAIL: codex bundle manifest missing"; exit 1; }
grep -q '"skills": "\./skills/"' plugins/codex/spec-driven-development/.codex-plugin/plugin.json \
  || { echo "FAIL: codex bundle manifest skills path not rewritten"; exit 1; }

# --- Codex direct-install path must be self-contained ---
TMP_HOME="$(mktemp -d)"
HOME="$TMP_HOME" bash scripts/install.sh codex --user
test -f "$TMP_HOME/.codex/skills/sdd/SKILL.md" \
  || { echo "FAIL: Codex install did not place SKILL.md into ~/.codex/skills"; exit 1; }

echo "build smoke test: OK"
