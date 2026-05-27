#!/usr/bin/env bash
# Compatible with bash 3.2+ (macOS default ships bash 3.2; no associative arrays).
#
# Builds the SDD skill for every supported agent from the single source of truth:
#   core/kernel.md + core/references/ + adapters/<agent>/
#
# For each agent it produces a generated SKILL.md (frontmatter + prelude + substituted
# kernel) plus a substituted references/ tree, then packages a self-contained marketplace
# plugin bundle under plugins/<agent>/spec-driven-development.
set -euo pipefail

cd "$(dirname "$0")/.."

ALL_AGENTS=(claude codex augment junie roo)

PLUGIN_NAME="spec-driven-development"
SKILL_NAME="sdd"

# Resolve output path for an agent's generated SKILL.md.
out_path_for() {
  case "$1" in
    claude)  echo "skills/${SKILL_NAME}/SKILL.md" ;;
    codex)   echo "dist/codex/skills/${SKILL_NAME}/SKILL.md" ;;
    augment) echo "dist/augment/skills/${SKILL_NAME}/SKILL.md" ;;
    junie)   echo "dist/junie/.junie/skills/${SKILL_NAME}/SKILL.md" ;;
    roo)     echo "dist/roo/.roo/skills/${SKILL_NAME}/SKILL.md" ;;
    *) echo "ERROR: unknown agent '$1'" >&2; return 1 ;;
  esac
}

# Directory that holds the agent's skill tree (parent of the SKILL_NAME dir).
skill_root_dir_for() {
  case "$1" in
    claude)  echo "skills" ;;
    codex)   echo "dist/codex/skills" ;;
    augment) echo "dist/augment/skills" ;;
    junie)   echo "dist/junie/.junie/skills" ;;
    roo)     echo "dist/roo/.roo/skills" ;;
    *) return 1 ;;
  esac
}

plugin_package_dir_for() {
  echo "plugins/$1/${PLUGIN_NAME}"
}

plugin_manifest_dir_for() {
  case "$1" in
    claude)  echo ".claude-plugin" ;;
    codex)   echo ".codex-plugin" ;;
    augment) echo ".augment-plugin" ;;
    junie)   echo ".junie-plugin" ;;
    roo)     echo ".roo-plugin" ;;
    *) return 1 ;;
  esac
}

plugin_manifest_src_for() {
  echo "$(plugin_manifest_dir_for "$1")/plugin.json"
}

package_marketplace_plugin() {
  local agent="$1"
  local package_dir manifest_dir manifest_src tmp_manifest

  package_dir="$(plugin_package_dir_for "$agent")"
  manifest_dir="$(plugin_manifest_dir_for "$agent")"
  manifest_src="$(plugin_manifest_src_for "$agent")"

  test -f "$manifest_src" || { echo "ERROR: missing manifest source: $manifest_src" >&2; return 1; }

  mkdir -p "$package_dir/$manifest_dir" "$package_dir/skills"
  rm -rf "$package_dir/skills/${SKILL_NAME}"
  cp -R "$(skill_root_dir_for "$agent")/${SKILL_NAME}" "$package_dir/skills/"
  cp icon.png "$package_dir/icon.png"

  tmp_manifest="$package_dir/$manifest_dir/plugin.json"
  cp "$manifest_src" "$tmp_manifest"

  # Inside a packaged bundle the skill tree lives at ./skills/, so rewrite any
  # repo-root dist path in the "skills" field to the bundle-local path.
  case "$agent" in
    claude) : ;; # claude auto-discovers skills/; manifest has no "skills" field
    *)
      sed -i.bak 's#"skills": "\./dist/[^"]*"#"skills": "./skills/"#' "$tmp_manifest"
      rm -f "$tmp_manifest.bak"
      ;;
  esac
}

build_references() {
  local agent="$1"
  local adapter_dir="adapters/${agent}"
  local out_skill out_refs_dir
  out_skill="$(out_path_for "$agent")"
  out_refs_dir="$(dirname "$out_skill")/references"

  rm -rf "$out_refs_dir"
  mkdir -p "$out_refs_dir"
  shopt -s nullglob
  local src name
  for src in core/references/*.md; do
    name="$(basename "$src")"
    python3 scripts/substitute.py "$src" "$adapter_dir/snippets" > "$out_refs_dir/$name"
  done
  shopt -u nullglob
}

build_one() {
  local agent="$1"
  local adapter_dir="adapters/${agent}"
  local out
  out="$(out_path_for "$agent")"

  test -d "$adapter_dir" || { echo "ERROR: missing adapter dir: $adapter_dir" >&2; return 1; }
  test -f "$adapter_dir/frontmatter.yaml" || { echo "ERROR: missing frontmatter.yaml for $agent" >&2; return 1; }
  test -f "$adapter_dir/prelude.md" || { echo "ERROR: missing prelude.md for $agent" >&2; return 1; }

  mkdir -p "$(dirname "$out")"

  # Concatenate: frontmatter wrapper + prelude + kernel (with placeholder substitution)
  {
    printf -- '---\n'
    cat "$adapter_dir/frontmatter.yaml"
    printf -- '---\n\n'
    cat "$adapter_dir/prelude.md"
    printf '\n'
    python3 scripts/substitute.py core/kernel.md "$adapter_dir/snippets"
  } > "$out"

  echo "Built $agent -> $out"
  build_references "$agent"
  package_marketplace_plugin "$agent"
}

# Args: agent name(s) or 'all'
if [ $# -eq 0 ] || [ "$1" = "all" ]; then
  for agent in "${ALL_AGENTS[@]}"; do
    build_one "$agent"
  done
else
  for agent in "$@"; do
    build_one "$agent"
  done
fi
