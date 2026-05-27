# Multi-Agent Build & Distribution

How the SDD skill is authored once and shipped to five different AI coding agents
(Claude Code, Codex, Augment, Junie, Roo), and what runs when.

This document explains the **why**, the **what**, and the **when** behind the
`core/` + `adapters/` source model, the `scripts/`, the generated artifacts, the
plugin manifests, and the GitHub workflows. It is the reference for anyone
editing the skill or adding a new agent.

---

## 1. Why this exists

The skill body is ~840 lines of carefully tuned instructions. Each target agent
needs *almost* the same text, but differs in a handful of specifics:

- the **context file** it reads conventions from (`.claude/CLAUDE.md` vs
  `AGENTS.md` vs `.junie/guidelines.md`),
- whether it can **run subagents in parallel** (only Claude Code can),
- whether it supports **Agent Teams** for Sprint Mode (only Claude Code does),
- how it refers to **itself** by name.

Maintaining five near-duplicate copies by hand guarantees drift: a fix lands in
one copy and silently rots in the other four. Instead we keep **one source of
truth** and **generate** every agent's copy from it. A change is made once, in
`core/` or in an adapter, and `scripts/build.sh` regenerates all five outputs
deterministically.

This mirrors the proven structure of the `pr-comments-resolver` project.

---

## 2. The build model

```
            core/kernel.md                adapters/<agent>/
        (shared skill body with      (frontmatter + prelude + snippets
         <!-- ADAPTER: key --> )         that fill each placeholder)
                    \                         /
                     \                       /
                      v                     v
                 scripts/substitute.py  +  scripts/build.sh
                              |
                              v
        ┌─────────────────────────────────────────────────────┐
        │ generated SKILL.md + references/ per agent            │
        │   claude  -> skills/sdd/                              │
        │   others  -> dist/<agent>/.../skills/sdd/             │
        ├─────────────────────────────────────────────────────┤
        │ self-contained marketplace bundles                    │
        │   plugins/<agent>/spec-driven-development/            │
        └─────────────────────────────────────────────────────┘
```

**Rule of thumb:** never edit a generated file. Edit the source
(`core/` or `adapters/`) and rebuild. Generated files are committed to the repo
only so that marketplaces and direct installs can fetch them without a build
step — the CI release pipeline regenerates and re-commits them after every merge.

---

## 3. Directory structure

| Path | Tracked? | Hand-edited? | Purpose |
|------|----------|--------------|---------|
| `core/kernel.md` | yes | **yes** | The shared skill body. Contains `<!-- ADAPTER: key -->` placeholders for the agent-specific parts. |
| `core/references/*.md` | yes | **yes** | Shared templates the skill writes into a user's repo (constitution, sprint, context-file). May contain placeholders. |
| `adapters/<agent>/frontmatter.yaml` | yes | **yes** | YAML frontmatter (`name`, `description`) wrapped around the generated SKILL.md. Identical across agents today. |
| `adapters/<agent>/prelude.md` | yes | **yes** | The `# Spec-Driven Development (SDD)` title plus a one-line, agent-flavored note that sits above the kernel. |
| `adapters/<agent>/snippets/<key>.md` | yes | **yes** | The text that replaces `<!-- ADAPTER: key -->` for that agent. One file per placeholder key. |
| `scripts/` | yes | **yes** | Build, substitution, validation, install, smoke-test tooling. |
| `tests/build_test.sh` | yes | **yes** | Smoke test asserting the build produced correct, well-formed outputs. |
| `skills/sdd/` | yes | **no (generated)** | The **Claude** build output (SKILL.md + references/). This is the path Claude Code's marketplace expects. |
| `dist/<agent>/.../skills/sdd/` | yes | **no (generated)** | The build output for codex / augment / junie / roo. |
| `plugins/<agent>/spec-driven-development/` | yes | **no (generated)** | Self-contained marketplace bundle: manifest + copied skill tree + icon. |
| `.<agent>-plugin/plugin.json` | yes | **yes** | The per-agent plugin manifest *source*. Copied into the bundle at build time. |
| `.claude-plugin/marketplace.json`, `.augment-plugin/marketplace.json`, `.agents/plugins/marketplace.json` | yes | **yes** | Marketplace catalog files pointing at the bundles. |
| `.github/` | yes | **yes** | CI workflows + dependabot + labeler config. |

The five agents and their output locations:

| Agent | Context file | Generated SKILL.md | Manifest dir | Install path |
|-------|--------------|--------------------|--------------|--------------|
| claude | `.claude/CLAUDE.md` | `skills/sdd/SKILL.md` | `.claude-plugin` | marketplace |
| codex | `AGENTS.md` | `dist/codex/skills/sdd/SKILL.md` | `.codex-plugin` | marketplace + `install.sh codex` |
| augment | `AGENTS.md` | `dist/augment/skills/sdd/SKILL.md` | `.augment-plugin` | marketplace |
| junie | `.junie/guidelines.md` | `dist/junie/.junie/skills/sdd/SKILL.md` | `.junie-plugin` | marketplace + `install.sh junie` |
| roo | `AGENTS.md` | `dist/roo/.roo/skills/sdd/SKILL.md` | `.roo-plugin` | marketplace + `install.sh roo` |

---

## 4. The adapter placeholders

`core/kernel.md` contains exactly six placeholder keys. `scripts/substitute.py`
replaces each `<!-- ADAPTER: key -->` with the contents of
`adapters/<agent>/snippets/<key>.md`. A missing snippet substitutes to empty
string (so an agent can intentionally omit a section).

| Key | What it controls | Claude resolves to | Other agents resolve to |
|-----|------------------|--------------------|--------------------------|
| `context-file` | The project conventions file the skill reads/writes | `.claude/CLAUDE.md` | `AGENTS.md` (junie: `.junie/guidelines.md`) |
| `agent-name` | How the skill names the running agent in prose | `Claude Code` | `Codex` / `Augment` / `Junie` / `Roo` |
| `parallel-legend` | The `[P]` line in the `tasks.md` legend | "executed concurrently via subagents" | "independent … run sequentially" |
| `parallel-tasks` | The clause describing how `[P]` tasks run (Phase 4) | "launched as concurrent subagents using the Agent tool" | sequential-execution explanation |
| `parallel-exec` | The Phase 5 block executing a `[P]` group | full Agent-tool spawn + minimal-prompt protocol | sequential per-task rhythm |
| `sprint-mode` | The entire Sprint Mode section body | full Agent Teams workflow (~370 lines) | sequential graceful-degradation workflow |

Net effect on size: the Claude build is ~844 lines (full Agent Teams); the other
four are ~547 lines (sequential fallback). The fallback keeps the same artifacts,
phase gates, role annotations and checkpoints — it only removes live concurrency,
because those agents have no parallel-subagent or Agent-Teams API.

> **Why graceful degradation instead of Claude-only?** Sprint Mode's *value*
> (multi-feature coordination, role-annotated tasks, phase gates) is real even
> without parallel teammates. Cutting it entirely for four agents would strip a
> feature they can still run usefully — just one role at a time.

---

## 5. The scripts — what, why, when

All scripts live in `scripts/` and assume the repo root as working directory
(they `cd` there themselves). The build is bash 3.2-compatible (macOS default)
and uses Python 3 only for text substitution and validation.

### `scripts/substitute.py`
- **What:** reads a source file, replaces every `<!-- ADAPTER: key -->` with the
  matching snippet from a given snippets directory, prints the result to stdout.
- **Why:** the single, dumb primitive the whole build is made of. One regex pass,
  no recursion — so snippets must be self-contained (no nested placeholders).
- **When:** invoked by `build.sh` once per agent for `kernel.md` and once per file
  in `core/references/`.

### `scripts/build.sh`
- **What:** for each agent — concatenates `frontmatter.yaml` + `prelude.md` +
  the substituted `kernel.md` into the agent's `SKILL.md`; substitutes and copies
  `core/references/*` into a sibling `references/` dir; then packages a
  self-contained marketplace bundle under `plugins/<agent>/spec-driven-development`
  (copies the skill tree + `icon.png`, copies the manifest source, and rewrites
  the bundle manifest's `skills` path to the bundle-local `./skills/`).
- **Why:** turns the source of truth into every shippable artifact in one
  deterministic step.
- **When:** `bash scripts/build.sh all` (all agents) or
  `bash scripts/build.sh claude codex` (a subset). Run it after **any** edit to
  `core/` or `adapters/`. CI runs it on every PR and every merge.

### `scripts/validate.py`
- **What:** checks generated outputs — frontmatter present with `name: sdd`, no
  leftover `<!-- ADAPTER: … -->` placeholders in any SKILL.md or reference, all
  expected reference files present, all five plugin bundles present with their
  manifest and skill, and non-claude bundle manifests rewritten to `./skills/`.
  Also prints a NOTE for any adapter missing a snippet key (substituted empty).
- **Why:** a fast structural gate that catches a broken or half-finished build
  before it reaches a marketplace.
- **When:** after `build.sh`. CI runs it on every PR and merge. Exit code ≠ 0
  fails the pipeline.

### `tests/build_test.sh`
- **What:** the smoke test. Builds all agents, then asserts concrete content:
  Claude has the Agent-tool wording, `.claude/CLAUDE.md`, and the Agent Teams
  section; each non-claude agent has its own context filename, the sequential
  sprint fallback, and **no** leaked Claude Agent-tool wording; all five bundles
  carry a skill + icon; and a Codex direct-install into a temp `$HOME` lands a
  `SKILL.md` under `~/.codex/skills/sdd/`.
- **Why:** `validate.py` proves the build is *structurally* sound; the smoke test
  proves the *content* came out per-agent correct.
- **When:** after `validate.py`. CI runs it on every PR and merge.

### `scripts/install.sh`
- **What:** copies a built skill tree into an agent's local config directory for
  agents that install by file rather than by marketplace. Supports
  `codex`, `roo`, `junie` with `--user` (`~/.<agent>/…`) or `--project`
  (`./.<agent>/…`).
- **Why:** Codex/Roo/Junie can consume a skill directly from disk; this gives
  users a one-command local install without a marketplace round-trip.
- **When:** run manually by a user after `build.sh <agent>`, e.g.
  `bash scripts/install.sh codex --user`. Not used by CI except inside the smoke
  test.

---

## 6. Generated artifacts & plugin bundles

Two kinds of generated output, both committed:

1. **Per-agent skill trees** — `skills/sdd/` (claude) and `dist/<agent>/…/skills/sdd/`.
   These hold the final `SKILL.md` + `references/`. Direct installs (`install.sh`)
   copy from `dist/`.

2. **Marketplace bundles** — `plugins/<agent>/spec-driven-development/`. Each bundle
   is self-contained: a manifest under its `.<agent>-plugin/` dir, the skill tree
   under `skills/sdd/`, and an `icon.png`. Marketplaces point at these bundle dirs.

The `skills` field handling differs by agent: Claude auto-discovers a `skills/`
directory, so its manifest has **no** `skills` field. The other four declare
`"skills": "./skills/"` in the bundle — `build.sh` rewrites whatever dist path the
manifest source carried down to that bundle-local value.

---

## 7. Manifests & marketplaces

Manifest **sources** (hand-edited) live in `.<agent>-plugin/plugin.json`. They all
carry the GameFixxer identity (author, homepage, repository) and the `0.1.0`
version. Codex additionally carries an `interface` block (display name, category,
default prompts, icon) for richer store presentation.

Marketplace **catalogs** (hand-edited) declare which bundle to install:

| File | Covers | Points at |
|------|--------|-----------|
| `.claude-plugin/marketplace.json` | claude | `./plugins/claude/spec-driven-development` |
| `.augment-plugin/marketplace.json` | augment | `./plugins/augment/spec-driven-development` |
| `.agents/plugins/marketplace.json` | codex, junie, roo | the three open-agents bundles via `source.local` paths |

> Junie and Roo have no formally standardized marketplace format yet; their
> bundles and `.agents/plugins` entries follow the same shape as Codex as a
> best-effort, so all five agents are installable.

---

## 8. GitHub workflows — what, why, when

Located in `.github/workflows/`. Two are the heart of the system
(`verify-build`, `release`); the rest are repo hygiene.

### `verify-build.yml`
- **When:** every `pull_request`.
- **What:** checks out the PR, sets up Python, then runs `build.sh all` →
  `validate.py` → `build_test.sh`.
- **Why:** proves a contributor's source change still builds cleanly for all five
  agents. It deliberately does **not** require the contributor to have rebuilt and
  committed the generated artifacts — the release pipeline does that after merge,
  so PRs stay small and reviewable (source-only).

### `release.yml`
- **When:** every push to `main` (i.e. after a merge). Tag pushes do not retrigger
  it; artifact commits carry `[skip ci]` and use the default `GITHUB_TOKEN` (which
  GitHub's recursion guard already prevents from re-triggering).
- **What:** a single ordered pipeline:
  1. **Determine next version** (dry run, no tag yet) via SemVer from commit
     messages, default bump `patch`.
  2. **Sync that version** into every manifest with `jq` — root `.version` on all
     `.<agent>-plugin/plugin.json`, the augment marketplace root, and the
     `plugins[]` entry named `spec-driven-development` in the claude/augment
     marketplaces. Skipped when there is no version bump.
  3. **Build all agents** (`build.sh all`) so the bundles embed the synced version.
  4. **Validate + smoke-test** the regenerated artifacts.
  5. **Commit** the regenerated `skills/ dist/ plugins/` and all manifest dirs back
     to `main` — only if something actually changed — with `[skip ci]`.
  6. **Tag** the resulting commit and push the tag.
- **Why:** keeps the committed generated artifacts and embedded versions always in
  sync with the sources, without burdening contributors. The tag points at the
  commit that *contains* the freshly built artifacts, not the triggering commit.
- **Operational requirement:** `github-actions[bot]` (via `GITHUB_TOKEN` with
  `contents: write`) must be allowed to push to `main`. If `main` is protected with
  "require pull request", the bot must be on the bypass list.

### `pr-labeler.yaml` + `.github/labeler.yml`
- **When:** PR opened/synchronized.
- **What:** applies labels based on which paths changed — `skill:sdd` (`core/`,
  `adapters/`, `skills/sdd/`), `build` (`scripts/`, `tests/`), `generated`
  (`dist/`, `plugins/`), `plugin:config` (manifest dirs), `documentation`, `ci`.
- **Why:** at-a-glance triage of what a PR touches (source vs generated vs CI).

### `dependabot.yml` + `dependabot-auto-merge.yml`
- **When:** weekly dependency scan of GitHub Actions; auto-merge fires on an
  approved Dependabot PR.
- **What:** Dependabot opens grouped minor/patch action-version bumps; the
  auto-merge workflow enables squash auto-merge once such a PR is approved.
- **Why:** keeps the pinned action versions current with minimal manual work.

### `auto-assign-pr-creator.yml`
- **When:** PR opened/reopened.
- **What:** assigns the PR to its (non-bot) author.
- **Why:** clear ownership in the PR list.

---

## 9. The contributor lifecycle (the "when" end-to-end)

1. **Edit a source file** — `core/kernel.md`, a `core/references/*` template, or an
   `adapters/<agent>/…` file. Never edit generated output.
2. **Rebuild locally:** `bash scripts/build.sh all`.
3. **Verify locally:** `python3 scripts/validate.py && bash tests/build_test.sh`.
4. **Open a PR** with the source change. `verify-build.yml` re-runs steps 2–3 in CI.
   You may include the regenerated artifacts or not — CI does not enforce it.
5. **Merge to `main`.** `release.yml` re-syncs versions, rebuilds, validates,
   commits the artifacts, and tags the release.

A change therefore propagates to all five agents from a single edit, and the
published artifacts can never silently diverge from the sources.

---

## 10. Adding a new agent

1. Create `adapters/<agent>/` with `frontmatter.yaml`, `prelude.md`, and a
   `snippets/` file for each of the six keys (copy the closest existing agent and
   adjust `context-file`, `agent-name`, and the parallel/sprint snippets).
2. Add the agent to `ALL_AGENTS` plus the `out_path_for`,
   `skill_root_dir_for`, and `plugin_manifest_dir_for` cases in `scripts/build.sh`.
3. Add its `OUT_PATHS` and `MANIFEST_DIR` entries in `scripts/validate.py`.
4. Create the manifest source `.<agent>-plugin/plugin.json`.
5. Register the bundle in the appropriate marketplace catalog.
6. Add a version-sync line in `release.yml` step 2.
7. Run build + validate + smoke test, and extend `tests/build_test.sh` with an
   assertion for the new agent.
