#!/usr/bin/env python3
"""Validate generated SKILL.md frontmatter, snippet coverage, and plugin bundles."""
import re
import sys
from pathlib import Path

REQUIRED_KEYS = {"name", "description"}

ROOT = Path(__file__).resolve().parent.parent
ADAPTERS_DIR = ROOT / "adapters"
KERNEL_PATH = ROOT / "core" / "kernel.md"
REFERENCES_DIR = ROOT / "core" / "references"

SKILL_NAME = "sdd"
PLUGIN_NAME = "spec-driven-development"

# Output paths per agent — must match scripts/build.sh
OUT_PATHS = {
    "claude":  ROOT / f"skills/{SKILL_NAME}/SKILL.md",
    "codex":   ROOT / f"dist/codex/skills/{SKILL_NAME}/SKILL.md",
    "augment": ROOT / f"dist/augment/skills/{SKILL_NAME}/SKILL.md",
    "junie":   ROOT / f"dist/junie/.junie/skills/{SKILL_NAME}/SKILL.md",
    "roo":     ROOT / f"dist/roo/.roo/skills/{SKILL_NAME}/SKILL.md",
}

MANIFEST_DIR = {
    "claude": ".claude-plugin",
    "codex": ".codex-plugin",
    "augment": ".augment-plugin",
    "junie": ".junie-plugin",
    "roo": ".roo-plugin",
}

errors = []


def parse_frontmatter(path):
    text = path.read_text()
    match = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
    if not match:
        errors.append(f"{path}: missing or malformed frontmatter")
        return {}
    fm = {}
    for line in match.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    return fm


def validate_frontmatter(agent, path):
    if not path.exists():
        errors.append(f"{agent}: output missing at {path}")
        return
    fm = parse_frontmatter(path)
    if not fm:
        return
    missing = REQUIRED_KEYS - fm.keys()
    if missing:
        errors.append(f"{agent}: frontmatter missing keys: {sorted(missing)}")
    if fm.get("name") != SKILL_NAME:
        errors.append(f"{agent}: frontmatter name must be '{SKILL_NAME}' (got {fm.get('name')!r})")


def validate_snippet_coverage():
    if not KERNEL_PATH.exists():
        errors.append(f"kernel missing at {KERNEL_PATH}")
        return
    keys = set(re.findall(r'<!-- ADAPTER: ([a-z0-9-]+) -->', KERNEL_PATH.read_text()))
    for ref in REFERENCES_DIR.glob("*.md"):
        keys |= set(re.findall(r'<!-- ADAPTER: ([a-z0-9-]+) -->', ref.read_text()))
    if not ADAPTERS_DIR.exists():
        return
    for adapter in sorted(ADAPTERS_DIR.iterdir()):
        if not adapter.is_dir():
            continue
        snippets_dir = adapter / "snippets"
        present = {p.stem for p in snippets_dir.glob("*.md")} if snippets_dir.exists() else set()
        missing = keys - present
        if missing:
            print(f"NOTE: {adapter.name} has no snippet for: {sorted(missing)} (will substitute empty)", file=sys.stderr)


def validate_no_stray_placeholders():
    for agent, path in OUT_PATHS.items():
        if not path.exists():
            continue
        if "<!-- ADAPTER: " in path.read_text():
            errors.append(f"{agent}: output contains unsubstituted placeholders")
        refs_dir = path.parent / "references"
        for ref in refs_dir.glob("*.md"):
            if "<!-- ADAPTER: " in ref.read_text():
                errors.append(f"{agent}: reference {ref.name} contains unsubstituted placeholders")


def validate_references():
    expected = {p.name for p in REFERENCES_DIR.glob("*.md")}
    for agent, path in OUT_PATHS.items():
        if not path.exists():
            continue
        refs_dir = path.parent / "references"
        present = {p.name for p in refs_dir.glob("*.md")} if refs_dir.exists() else set()
        missing = expected - present
        if missing:
            errors.append(f"{agent}: missing reference files: {sorted(missing)}")


def validate_plugin_bundles():
    for agent in OUT_PATHS:
        bundle = ROOT / f"plugins/{agent}/{PLUGIN_NAME}"
        manifest = bundle / MANIFEST_DIR[agent] / "plugin.json"
        skill = bundle / "skills" / SKILL_NAME / "SKILL.md"
        if not manifest.exists():
            errors.append(f"{agent}: plugin bundle manifest missing at {manifest}")
        if not skill.exists():
            errors.append(f"{agent}: plugin bundle skill missing at {skill}")
            continue
        if "<!-- ADAPTER: " in skill.read_text():
            errors.append(f"{agent}: plugin bundle skill contains unsubstituted placeholders")
        if agent != "claude":
            mtext = manifest.read_text()
            if '"skills": "./skills/"' not in mtext:
                errors.append(f"{agent}: bundle manifest skills path not rewritten to ./skills/")


def main():
    for agent, path in OUT_PATHS.items():
        validate_frontmatter(agent, path)
    validate_snippet_coverage()
    validate_no_stray_placeholders()
    validate_references()
    validate_plugin_bundles()
    if errors:
        for e in errors:
            print(f"FAIL: {e}", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
