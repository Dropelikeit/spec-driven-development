#!/usr/bin/env python3
"""Validate generated SKILL.md frontmatter, snippet coverage, and plugin bundles."""
import json
import re
import sys
from pathlib import Path

REQUIRED_KEYS = {"name", "description"}
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.\-]+)*$")

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


def _load_json(path):
    try:
        return json.loads(path.read_text())
    except Exception as exc:  # noqa: BLE001 - report any parse/read failure
        errors.append(f"{path}: invalid JSON ({exc})")
        return None


def validate_versions_and_repository():
    """Every manifest must declare the same string semver version, and any
    `repository` field must be a string URL (an object form is rejected by the
    Claude plugin loader at install time)."""
    versions = []  # (label, value)

    def record_version(label, value):
        if not isinstance(value, str):
            errors.append(f"{label}: version must be a string, got {type(value).__name__}")
            return
        if not SEMVER_RE.match(value):
            errors.append(f"{label}: version {value!r} is not valid semver (X.Y.Z)")
        versions.append((label, value))

    def record_repository(label, value):
        if value is not None and not isinstance(value, str):
            errors.append(
                f"{label}: repository must be a string URL, got {type(value).__name__}"
            )

    for agent, mdir in MANIFEST_DIR.items():
        # Source plugin manifest (hand-edited; version bumped in the PR).
        src = ROOT / mdir / "plugin.json"
        if not src.exists():
            errors.append(f"{agent}: source manifest missing at {src}")
        else:
            data = _load_json(src)
            if data is not None:
                record_version(str(src), data.get("version"))
                record_repository(str(src), data.get("repository"))

        # Optional marketplace manifest (root version and/or plugins[] entry).
        mkt = ROOT / mdir / "marketplace.json"
        if mkt.exists():
            mdata = _load_json(mkt)
            if mdata is not None:
                if "version" in mdata:
                    record_version(f"{mkt} (root)", mdata.get("version"))
                for entry in mdata.get("plugins", []) or []:
                    if entry.get("name") == PLUGIN_NAME:
                        record_version(f"{mkt} (plugins[{PLUGIN_NAME}])", entry.get("version"))

        # Generated bundle manifest (must match the source it was copied from).
        bundle = ROOT / f"plugins/{agent}/{PLUGIN_NAME}/{mdir}/plugin.json"
        if bundle.exists():
            bdata = _load_json(bundle)
            if bdata is not None:
                record_version(str(bundle), bdata.get("version"))
                record_repository(str(bundle), bdata.get("repository"))

    distinct = sorted({v for _, v in versions})
    if len(distinct) > 1:
        detail = ", ".join(f"{label}={value}" for label, value in versions)
        errors.append(f"inconsistent plugin versions across manifests: {distinct} ({detail})")


def main():
    for agent, path in OUT_PATHS.items():
        validate_frontmatter(agent, path)
    validate_snippet_coverage()
    validate_no_stray_placeholders()
    validate_references()
    validate_plugin_bundles()
    validate_versions_and_repository()
    if errors:
        for e in errors:
            print(f"FAIL: {e}", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
