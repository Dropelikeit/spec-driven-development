# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] — 2026-06-05

### Fixed
- Claude plugin manifest `repository` field was an npm-style object (`{ "type": "git", "url": "..." }`), which the Claude Code plugin loader rejected with `repository: Invalid input: expected string, received object`, blocking installation. It is now a string URL, matching the other agents' manifests.
- Bumped all plugin and marketplace manifest `version` fields to match the released `0.2.0` line (they had been left at `0.1.0`).

## [0.2.0] — 2026-05-28

### Added
- Multi-agent distribution: the SDD skill is now built for Codex, Augment, Junie and Roo in addition to Claude.
- Kernel-plus-adapter build system (`core/kernel.md`, `core/references/`, `adapters/<agent>/`) as the single source of truth, with per-agent placeholder substitution (`scripts/substitute.py`, `scripts/build.sh`).
- Per-agent plugin manifests and marketplaces (`.codex-plugin/`, `.augment-plugin/`, `.junie-plugin/`, `.roo-plugin/`, `.agents/plugins/marketplace.json`) plus self-contained marketplace bundles under `plugins/<agent>/`.
- Direct-install script (`scripts/install.sh`) for Codex, Roo and Junie with `--user`/`--project` targets.
- Validation and build smoke tests (`scripts/validate.py`, `tests/build_test.sh`).
- GitHub Actions release pipeline (`.github/workflows/release.yml`) and PR build verification (`.github/workflows/verify-build.yml`), plus dependabot, PR labeler and auto-assign workflows.
- Documentation of the multi-agent build (`docs/multi-agent-build.md`).

### Changed
- Sprint Mode degrades gracefully on non-Claude agents: Claude keeps the full Agent Teams parallel workflow while Codex, Augment, Junie and Roo get a sequential fallback.
- Claude marketplace source path moved to `./plugins/claude/spec-driven-development`.
- Renamed the context-file reference template from `claude-md-template.md` to the agent-agnostic `context-file-template.md`.

## [0.1.0] — 2026-04-25

### Added
- Initial public release of the Spec-Driven Development plugin.
- `skills/sdd` skill covering the five-phase workflow (initialize, specify, plan, task, execute) plus Sprint Mode.
- Graphify integration in the Plan phase.
- Claude Code marketplace manifest (`.claude-plugin/marketplace.json`) for one-command install from GitHub.
- Plugin icon (`icon.png`).
