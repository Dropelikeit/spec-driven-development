# Agent Context File — SDD Section Template

Add this section to `.junie/guidelines.md`. If the file already exists, append it — don't replace existing content (there may be build commands, linting config, or other project-specific instructions already there that the SDD workflow needs to read).

```markdown
## Development Methodology — Spec-Driven Development (SDD)

This project uses Spec-Driven Development. All feature work follows the spec → plan → tasks → execute pipeline.

### Build & Test Commands
<!-- SDD reads these commands during task generation and checkpoint execution.
     Update them if your build tooling changes. -->
- Build: `[e.g., npm run build]`
- Test: `[e.g., npm test]`
- Lint: `[e.g., npm run lint]`
- Platform targets: `[e.g., npm run build:prod, docker build .]`

### Before implementing any feature:
1. Read `specs/[feature]/spec.md` to understand what to build and why
2. Read `specs/[feature]/plan.md` to understand the technical approach
3. Read `specs/[feature]/tasks.md` to find the current task
4. Read `specs/memory/constitution.md` for architectural principles

### While implementing:
- Follow the task list in strict order — don't skip ahead
- Write the test FIRST. Run it to confirm it fails. Then implement until it passes. This is non-negotiable.
- Mark tasks `[~]` when starting, `[x]` when done — keep tasks.md in sync at all times
- For `[P]` (parallel) tasks: they flag genuinely independent work. This agent has no parallel-subagent API, so it executes them sequentially (one at a time) — but the independence guarantee still matters, because it means the order is free to choose and a `[C]` checkpoint can safely batch-verify the group
- At `[C]` (checkpoint) tasks: run the full test suite AND the build, audit task marks, check against spec acceptance criteria, and record results in progress.md before continuing

### Non-goals in the spec are hard boundaries
Do not implement anything listed under "Non-Goals" in a feature's spec.md, even if it seems like a small addition.

### When starting a new session
1. Read `specs/[feature]/progress.md` to understand where the previous session left off
2. Run the full test suite and build to verify the current state matches the last checkpoint
3. Pick up from the first incomplete task in tasks.md

### Sprint Mode (multi-feature workflow)
When working in Sprint Mode:
- Read `specs/sprints/sprint-[N].md` for the current sprint manifest
- Tasks are annotated with `@role` — work follows those role boundaries
- Phase gates: do NOT start Phase N+1 until the current phase's checkpoint passes
- Checkpoints in sprint mode verify ALL features in the sprint, not just the current one
- Report status in compressed format: `STATUS: done|blocked | TASK: [id] | FILES: [changed] | RESULT: [one line]`
```

During Phase 1 initialization, after writing this template into the context file, ask the user to fill in the actual build and test commands for their project. If the project already has a context file with build commands defined, preserve those — the SDD section should reference whatever is already there rather than duplicating it.
