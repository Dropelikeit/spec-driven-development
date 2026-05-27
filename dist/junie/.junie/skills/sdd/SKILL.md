---
name: sdd
description: >
  Spec-Driven Development (SDD) — a structured, specification-first development workflow.
  Guides you through 5 phases: initialize project structure, write feature specs, create
  technical plans, break work into tasks, and execute with progress tracking. Use this skill
  whenever the user mentions spec-driven development, SDD, creating or initializing specs,
  planning a feature, breaking work into tasks, resuming from a task list, tracking development
  progress, or reviewing implementation against a spec. Also trigger when the user says things
  like "set up SDD", "new feature spec", "plan this feature", "create tasks", "start working",
  "resume where we left off", "review against spec", "update progress", "start a sprint",
  "refine features", or "execute sprint". Even if the user doesn't use the term "SDD"
  explicitly, trigger this skill when they ask to create a structured spec-then-plan-then-tasks
  workflow for a feature or project, or when they want to coordinate multiple features with a
  team-based approach.
---

# Spec-Driven Development (SDD)

> Junie activates this skill when its description matches your task.

You are guiding the user through a specification-first development workflow. The core idea: never jump straight into code. Instead, write structured markdown files that capture *what* needs to be built and *why*, then *how* to build it, then break the *how* into small executable tasks. Only then do you write code — and when you do, you follow the task list and mark progress as you go.

This approach exists because projects that skip specification tend to accumulate drift between what was intended and what gets built. Specs catch misunderstandings early (when they're cheap to fix), plans force you to think through technical decisions before you're knee-deep in implementation, and task lists give both you and the user a shared view of what's done and what's left.

## Communication Protocol

All output from this skill follows a token-efficient format. This matters because SDD sessions are long-running, multi-phase workflows — and in Sprint Mode, multiple agents communicate simultaneously. Every unnecessary token compounds.

### Response format rules

1. **No preamble.** Don't say "Great, I'll now create the spec" — just create it.
2. **Structured over prose.** Use `key: value` pairs, tables, and checklists instead of paragraphs when reporting status.
3. **File-first.** Write artifacts to files, then reference them. Don't echo file contents back to the user/chat unless asked.
4. **Delta updates only.** When reporting progress, state only what changed since the last update — not the full state.
5. **Confirmation = one line.** After creating a file, confirm with: `✓ Created [path] — [one-line summary]`. Nothing more unless the user asks.
6. **Checkpoint reports use structured format** (see Phase 5 checkpoint template below).
7. **Subagent prompts are minimal** — context file paths + task description + constraint list. No narrative.

### User-facing communication

When talking to the user directly:
- Phase transitions: `→ Phase N: [name]` on one line
- File creation: `✓ [path]` on one line
- Questions: ask directly, no lead-in
- Review requests: present the file link, then list only items that need decision

## Graphify Integration

Graphify is a knowledge-graph tool that can be installed per repository inside Junie. When active, it maintains `graphify-out/GRAPH_REPORT.md` — a one-page structural summary of the codebase covering "god nodes" (highly-connected files), community clusters, and surprising cross-cutting connections. It may also install a pre-search hook and a `.junie/guidelines.md` directive asking the agent to consult the graph before architecture questions.

**Detecting Graphify:** At the start of Phase 3, Phase 4, and Phase 5, check whether `graphify-out/GRAPH_REPORT.md` exists. If it does, Graphify is active.

**When Graphify is active, use the graph first:**
- Read `graphify-out/GRAPH_REPORT.md` *before* doing any Glob/Grep-based codebase exploration. The graph already knows which files are structurally central — searching blind wastes tokens and may conflict with the PreToolUse hook's intent.
- In Phase 3 (Plan), use god nodes and community clusters to inform the Technical Approach and Data Model sections — they reveal actual architectural boundaries better than directory structure alone.
- In Phase 4 (Task), use community membership to assign `OWN_FILES` scopes for `[P]` parallel tasks. Tasks within the same community are more likely to conflict; tasks in different communities are safe to parallelize.
- In Phase 5 (Execute), when navigating to understand existing code before implementing, start from the graph's god nodes rather than open-ended Glob searches.
- In Sprint Mode execution, include `graphify-out/GRAPH_REPORT.md` in each subagent prompt's `READ:` list so teammates share the same structural map.

**When Graphify is not active:** proceed exactly as before — nothing changes.

---

## How to determine which phase to run

Read the user's message and match it to a phase:

| User says something like... | Phase to run |
|---|---|
| "Set up SDD", "Initialize specs", "start SDD for this project" | **Phase 1** — Initialize |
| "New feature: [name]", "Create a spec for [feature]", "spec out [feature]" | **Phase 2** — Specify |
| "Plan this feature", "Create the plan", "how should we build this?" | **Phase 3** — Plan |
| "Break into tasks", "Create tasks", "what are the steps?" | **Phase 4** — Task |
| "Start working", "Execute tasks", "let's build this" | **Phase 5** — Execute |
| "Resume", "Continue where we left off", "pick up from last time" | **Phase 5** — Resume variant |
| "Review against spec", "are we on track?", "check acceptance criteria" | **Review** — Compare implementation to spec |
| "Update progress", "log what we did" | **Progress update** |
| "Sprint", "start a sprint", "sprint mode", "team mode" | **Sprint Mode** — Multi-feature team workflow |
| "Refine features", "refinement meeting", "sprint planning" | **Sprint Mode** — Refinement phase |
| "Execute sprint", "start sprint execution" | **Sprint Mode** — Execution phase |

If the user's intent is ambiguous, ask which phase they want rather than guessing.

If the user asks to do multiple phases at once (e.g., "spec and plan this feature"), run them in sequence, pausing between phases to confirm the output before moving on.

---

## Phase 1 — Initialize Project Structure

This phase sets up the SDD scaffolding for a project. Run it once per project.

### Steps

1. **Create the specs directory.** At the project root, create `specs/` if it doesn't exist.

2. **Create the constitution.** Create `specs/memory/constitution.md` with the default architectural principles below. Then ask the user: *"Here are the default development principles. Want to customize any of these, or add your own?"*

   Default constitution content — use the template in `references/constitution-template.md`.

3. **Set up .junie/guidelines.md.** Add a development methodology section to `.junie/guidelines.md` (create the file if needed). This section tells future Junie sessions how to work within the SDD framework. Use the content in `references/context-file-template.md`.

4. **Confirm completion.** One-line per file created (`✓ [path]`), then: "Ready. Name a feature to start Phase 2."

### Important

- If `specs/` already exists, don't overwrite anything. Ask the user if they want to reinitialize.
- If `.junie/guidelines.md` already exists, append the SDD section rather than replacing the file.

---

## Phase 2 — Specify (spec.md)

This phase captures *what* a feature should do and *why* it matters. Specs deliberately avoid technical implementation details — those belong in the plan.

### Steps

1. **Create the feature directory.** Convert the feature name to kebab-case and create `specs/[feature-name]/`.

2. **Interview the user.** Ask clarifying questions. Don't ask them all at once — have a conversation. Key things to understand:
   - What problem does this feature solve? Who experiences that problem?
   - Who are the users? (Specific roles or personas, not just "users")
   - What does success look like? (These become acceptance criteria)
   - What is explicitly *out of scope*? (These become non-goals — they're just as important as goals because they prevent scope creep)
   - Are there dependencies on other features or systems?

   If the user has already provided a lot of detail in their initial message, don't re-ask things they've already answered. Extract what you can and only ask about gaps.

3. **Write the spec.** Generate `specs/[feature-name]/spec.md` following this structure:

   ```markdown
   # [Feature Name]

   ## Overview
   [1-2 paragraphs: what this feature does and why it matters. Focus on the
   problem being solved and the value delivered. No implementation details.]

   ## User Stories
   - As a [role], I want [capability] so that [benefit]
   - ...

   ## Acceptance Criteria
   - [ ] [Specific, testable criterion]
   - [ ] [Another criterion]
   - ...

   ## Non-Goals
   - [Thing that is explicitly out of scope]
   - ...

   ## Open Questions
   - [NEEDS CLARIFICATION: question about something unclear]
   - ...

   ## Dependencies
   - [External system, library, or feature this depends on]
   - ...
   ```

4. **Review with the user.** Say `✓ Created specs/[feature]/spec.md` then list only items needing decision (vague criteria, open questions). Don't echo the full spec.

### Guardrails

- If you catch yourself writing implementation details in the spec (database schemas, API endpoints, class names), stop. Move that thinking to a mental note for Phase 3.
- Mark anything uncertain with `[NEEDS CLARIFICATION: ...]` and ask the user about it. Never assume.
- Non-goals are hard boundaries. Once something is listed as a non-goal, it stays out of scope for the entire workflow unless the user explicitly changes the spec.

---

## Phase 3 — Plan (plan.md)

This phase is where technical decisions happen. The plan translates the *what* from the spec into a *how*.

### Steps

1. **Read the inputs.** Before writing anything:
   - Check whether `graphify-out/GRAPH_REPORT.md` exists. If it does, read it first — the god nodes and community clusters give you the real architectural map before you touch any Glob or Grep.
   - Read `specs/[feature-name]/spec.md`
   - Read `specs/memory/constitution.md`
   These documents together define what you're building, the principles you're building with, and (when Graphify is present) the structural landscape you're building into.

2. **Generate the plan.** Write `specs/[feature-name]/plan.md`:

   ```markdown
   # [Feature Name] — Technical Plan

   ## Technical Approach
   [High-level architecture: what components are involved, how they interact,
   what the data flow looks like. Keep it at the right altitude — detailed
   enough to guide implementation, abstract enough that it doesn't become
   pseudocode.]

   ## Key Decisions

   | Decision | Choice | Rationale |
   |----------|--------|-----------|
   | [What was decided] | [What was chosen] | [Why this over alternatives] |

   ## Data Model
   [Entities, their attributes, and relationships. Use whatever notation is
   clearest — ERD-style text, table definitions, TypeScript interfaces, etc.]

   ## API Contracts
   [Endpoints, methods, request/response shapes. If this feature doesn't
   have an API, replace this section with whatever interface is relevant
   (CLI commands, UI components, event schemas, etc.)]

   ## Implementation Phases
   1. **Foundation** — Core data structures, database setup, basic scaffolding
   2. **Business Logic** — Domain logic, validation, core algorithms
   3. **API/Interface Layer** — Endpoints, UI components, CLI commands
   4. **Testing** — Integration tests, edge cases, error scenarios
   5. **Polish** — Error handling, logging, documentation, cleanup

   ## Risks and Mitigations

   | Risk | Impact | Mitigation |
   |------|--------|------------|
   | [What could go wrong] | [How bad would it be] | [What to do about it] |
   ```

3. **For complex features**, optionally generate additional files:
   - `specs/[feature-name]/research.md` — Background research, links to relevant docs, analysis of similar implementations
   - `specs/[feature-name]/data-model.md` — Detailed data model if the one in plan.md would be too long

4. **Review with the user.** Say `✓ Created specs/[feature]/plan.md` then list only the Key Decisions that need user sign-off. Don't echo the full plan.

### Guardrails

- Every decision in the Key Decisions table should respect the constitutional principles. If there's a tension (e.g., simplicity vs. a user requirement that demands complexity), call it out explicitly.
- The implementation phases exist to guide task creation in Phase 4. They don't need to be followed rigidly, but they should reflect a sensible build order (foundations before features, features before polish).

---

## Phase 4 — Task (tasks.md)

This phase breaks the plan into small, actionable work items. Each task should be implementable and testable in isolation.

### Steps

1. **Read the inputs.** Read:
   - `specs/[feature-name]/plan.md`
   - `specs/[feature-name]/spec.md` (for acceptance criteria cross-reference)
   - `.junie/guidelines.md` (for build commands, test commands, and platform targets)

   .junie/guidelines.md is the source of truth for how to build and test this project. The build commands defined there become the verification steps in the task list.

2. **Generate the task list.** Write `specs/[feature-name]/tasks.md`:

   ```markdown
   # [Feature Name] — Tasks

   ## Status Legend
   - `[ ]` Not started
   - `[x]` Complete
   - `[~]` In progress
   - `[P]` Parallelizable — independent work that is safe to do in any order (this agent runs them sequentially)
   - `[C]` Checkpoint — stop and verify before continuing

   ## Phase 1: Foundation
   - [ ] [Test: describe what the foundation should do] — write failing tests first
   - [ ] [Implement: build the thing the tests describe]
   - [C] Checkpoint: run tests, verify all pass, update tasks.md

   ## Phase 2: Business Logic
   - [P] [Test + Implement: independent unit A] — test first, then implement
   - [P] [Test + Implement: independent unit B] — test first, then implement
   - [C] Checkpoint: run full test suite, verify no regressions, update tasks.md

   ## Phase 3: API/Interface Layer
   - [ ] [Test: integration tests for endpoints] (depends on Phase 2)
   - [ ] [Implement: wire up endpoints]
   - [C] Checkpoint: run full test suite, verify against acceptance criteria

   ## Phase 4: Polish
   - [ ] [Error handling improvements]
   - [ ] [Documentation]
   - [C] Checkpoint: run all tests, review against spec acceptance criteria

   ## Build Verification
   - [ ] Full build: [build command from .junie/guidelines.md, e.g. `npm run build`]
   - [ ] Full test suite: [test command from .junie/guidelines.md, e.g. `npm test`]
   - [ ] [One task per additional platform target, e.g. `npm run build:prod`, `docker build .`]
   - [C] Final checkpoint: all builds green, all tests pass, acceptance criteria verified
   ```

3. **Review with the user.** Say `✓ Created specs/[feature]/tasks.md — [N] tasks across [M] phases, [X] parallel groups, [Y] checkpoints`. Ask only: "Anything to add, remove, or reorder?"

### Test-first task ordering

The constitution says test-first, and the task list must structurally enforce this. For every piece of functionality:

1. The test task comes **before** the implementation task — always. Not in a separate "Testing" phase at the end, but immediately before the code it validates.
2. For `[P]` parallel groups, each parallel task is a self-contained "test + implement" pair. The test is written first within that task, then the implementation. Don't split tests and implementation into separate parallel tracks.
3. Never create a standalone "Phase 4: Testing" section that comes after all implementation. Integration tests and edge case tests should appear at the boundary of the phase they're testing — e.g., after Phase 2 tasks are done, write integration tests for Phase 2's behavior before moving to Phase 3.

If you catch yourself writing tasks where implementation comes before its tests, reorder them. The task list is the source of truth for execution order.

### What makes a good task

- **Small enough to complete in one focused session.** If a task would take more than a couple of hours, break it down further.
- **Testable in isolation.** After completing the task, you should be able to verify it works without finishing the rest of the feature.
- **Clear on what "done" means.** The person reading the task list should know what the expected outcome is.
- **Dependencies are explicit.** If task B can't start until task A is done, say so.
- **Each task includes its verification.** A task like "implement login" is incomplete — it should be "implement login (test: valid credentials return JWT, invalid credentials return 401)".

### Parallelization — real concurrent execution

Tasks marked `[P]` aren't just a label — they flag genuinely independent work. This agent has no parallel-subagent API, so it executes them sequentially (one at a time) — but the independence guarantee still matters, because it means the order is free to choose and a `[C]` checkpoint can safely batch-verify the group. This means:

- Only mark tasks `[P]` when they are genuinely independent: no shared state mutations, no file conflicts, no ordering dependencies.
- Each `[P]` task must be fully self-contained: it includes its own test-writing and implementation steps, targeting a specific module or file set that won't conflict with other `[P]` tasks.
- A `[P]` group is always followed by a `[C]` checkpoint that runs the full test suite and verifies no conflicts arose from concurrent work.

### Checkpoints — catching drift

Checkpoints (`[C]`) are verification gates that prevent the task list from drifting out of sync with reality. At each checkpoint:

1. Run the full test suite (not just the tests written in the current phase)
2. Re-read `tasks.md` and verify the completion marks are accurate
3. Compare completed work against the relevant acceptance criteria from `spec.md`
4. If anything is out of sync — a test fails, a task was marked done but isn't actually working, or a criterion that should be met isn't — stop and fix it before continuing
5. Write a brief checkpoint entry in `progress.md` recording what passed and what didn't

Think of checkpoints as save points. Without them, small errors compound across phases until you're debugging a tangled mess at the end. With them, you catch problems within one phase of where they were introduced.

### Build Verification — the final group

Every task list ends with a **Build Verification** group. This group exists because tests passing doesn't guarantee the project actually builds — type errors, missing imports, and broken configurations can all hide behind a green test suite.

To generate this group:

1. Read `.junie/guidelines.md` and look for build commands (e.g., `npm run build`, `cargo build`, `go build ./...`), test commands (e.g., `npm test`, `pytest`), and any platform-specific targets (e.g., `npm run build:prod`, `docker build .`, `make release`).
2. Create one task per build/platform target. Each task runs the command and verifies it exits cleanly.
3. Create one task for the full test suite command.
4. End with a final `[C]` checkpoint that confirms everything is green.

If .junie/guidelines.md doesn't have build commands (maybe the project is new), ask the user what build and test commands to use, or infer from the project structure (look for `package.json`, `Cargo.toml`, `Makefile`, `pyproject.toml`, etc.) and confirm with the user.

---

## Phase 5 — Execute and Track

This phase is where code gets written. Every task follows the same rhythm: write a failing test, make it pass, mark the task done, verify at checkpoints.

### Starting execution

1. Read all inputs:
   - Check whether `graphify-out/GRAPH_REPORT.md` exists. If it does, read it — use it to navigate the codebase structurally rather than with open-ended Glob/Grep searches.
   - `specs/[feature]/spec.md` — what to build and why
   - `specs/[feature]/plan.md` — how to build it
   - `specs/[feature]/tasks.md` — what to do next
   - `.junie/guidelines.md` — build commands, test commands, and project conventions

   .junie/guidelines.md is where you find the actual commands to run tests and build the project. Without it, you'd have to guess — and guessing leads to running `npm test` on a Python project or missing a required build flag.

2. Scan the task list and identify the next work to do — either the first `[ ]` task or a `[P]` group

### Executing a sequential task (`[ ]`)

For each `[ ]` task:

1. Mark it `[~]` in `tasks.md` (in progress)
2. Write the test first — a test that will fail right now but will pass when the task is done. Run it to confirm it fails. This isn't ceremonial; it forces you to define "done" concretely before you start coding.
3. Write the implementation until the test passes
4. Run the test suite (not just the new test — the full suite) to check for regressions
5. Mark the task `[x]` in `tasks.md`
6. Move to the next task

### Executing a parallel group (`[P]`)

This agent has no parallel-subagent API, so a `[P]` group is executed **sequentially** — one task after another. The `[P]` marker is still meaningful: it certifies the tasks are independent (no shared state, no file conflicts, no ordering dependency), which means you may do them in any order and the closing `[C]` checkpoint can verify them as a batch.

For each task in the group, follow the same rhythm as a sequential `[ ]` task:

1. Mark it `[~]` in `tasks.md`
2. Write the test first; run it to confirm it fails
3. Implement until the test passes
4. Run the full test suite to check for regressions
5. Mark the task `[x]` in `tasks.md`

Because the tasks are independent, keep each one's edits confined to its own files/modules — if you notice two `[P]` tasks touching the same file, they were mis-marked: drop the `[P]` on one of them and treat it as ordered. Reference `specs/[feature]/spec.md`, `specs/[feature]/plan.md`, `specs/memory/constitution.md`, and `.junie/guidelines.md` while implementing. After the whole group is done, run the full test suite before the `[C]` checkpoint.

### Executing a checkpoint (`[C]`)

When you reach a `[C]` checkpoint:

1. **Run the full test suite.** Every test, not just recent ones. Use the test command from .junie/guidelines.md.
2. **Run the build.** Use the build command(s) from .junie/guidelines.md. A passing test suite with a broken build is still broken. This catches type errors, missing imports, and configuration problems that tests alone miss.
3. **Audit tasks.md.** Read the file and verify that every task marked `[x]` actually corresponds to working, tested code. If you find a task marked complete but its tests fail, unmark it (`[x]` → `[ ]`) and flag it.
4. **Check against spec.md.** Read the acceptance criteria and assess which ones are now satisfied by the completed work. Record this in the checkpoint entry.
5. **Write a checkpoint entry in progress.md** using this compact format:

   ```markdown
   ### CP: [Phase] — [Date]
   tests: X pass / Y fail / Z skip
   build: pass|fail [commands run]
   done: [task ids]
   rework: [task ids, if any]
   criteria_met: [AC ids from spec]
   issues: [one line per issue, or "none"]
   ```

6. **If issues were found, fix them before continuing.** Don't carry broken state into the next phase.
7. **Report to user** in one structured block — no narrative wrapping:

### Resuming

When the user says "resume" or "continue":

1. Read `specs/[feature-name]/progress.md` — look at the most recent checkpoint entry to understand the verified state of things
2. Read `tasks.md` to find the first incomplete task
3. Re-read `spec.md`, `plan.md`, and `.junie/guidelines.md` to refresh context and pick up build/test commands
4. **Run the test suite and build before writing any new code.** This confirms reality matches what progress.md claims. If tests fail or the build is broken at a point where the last checkpoint said everything was green, something changed — investigate before continuing.
5. Continue from the first `[ ]` task

If multiple features exist under `specs/`, ask the user which feature to resume unless it's obvious from context.

### Progress tracking

After each session, or when the user asks, write or update `specs/[feature-name]/progress.md`. Checkpoint entries accumulate in this file over time, giving a historical record:

```markdown
# [Feature Name] — Progress

updated: [Date]
status: [Phase N checkpoint passed | Phase N in progress]
blockers: [list or "none"]
next_session: [one line of context]

## Checkpoints

### CP: Phase 1 Foundation — [Date]
tests: 8/0/0
done: 1.1, 1.2, 1.3
criteria_met: AC-1, AC-2

### CP: Phase 2 Business Logic — [Date]
tests: 22/1/0
rework: 2.3 (race condition)
```

### Reviewing against the spec

When the user asks to review or check progress against the spec:

1. Read `spec.md`, specifically the acceptance criteria
2. Run the full test suite to get current reality (don't trust task marks alone)
3. For each criterion, check whether the current implementation satisfies it — both by reading the code and by checking test coverage
4. Report the results clearly: which criteria are met, which aren't, and what's needed to close the gaps

---

## Sprint Mode — Multi-Feature Team Workflow

Sprint Mode coordinates multiple features as one unit. Its multi-agent variant relies on Claude Code **Agent Teams** (independent peer sessions that self-coordinate via a shared task list) — a capability Junie does not provide. So in Junie, Sprint Mode runs **sequentially**: you play every role yourself, in phase order, without spawning teammates. The structure and artifacts are identical; only the concurrency is removed.

**When to use Sprint Mode:** the user has multiple features to build and wants them planned and executed together, or explicitly asks for "sprint mode" / "team mode".

### Sprint artifact

Sprint Mode introduces one new artifact:

- `specs/sprints/sprint-[N].md` — the sprint manifest: features, role roster, refinement log, and execution progress.

All other artifacts (`spec.md`, `plan.md`, `tasks.md`, `progress.md` per feature) are unchanged. Sprint Mode orchestrates them; it doesn't replace them.

### Starting a sprint

1. **Determine sprint number.** Check `specs/sprints/` — new sprint = max(N) + 1, or 1 if none exist.
2. **Collect features.** Ask the user which features go in this sprint. For each, check whether a spec already exists under `specs/[feature-name]/`; features without specs need Phase 2 during refinement.
3. **Agree a role set.** Even without live teammates, roles structure the work. Default roles: Product Manager, Solution Architect, Frontend Dev, Backend Dev, App Dev, UI Designer. Ask the user to confirm or trim the set (pure backend → Backend Dev + Solution Architect).
4. **Create the sprint file.** Write `specs/sprints/sprint-[N].md` listing every feature with its current status (spec/plan/tasks present?).
5. **Confirm.** `✓ Created specs/sprints/sprint-[N].md — [X] features, [Y] roles. Ready for refinement.`

### Sprint Refinement (sequential)

Refine each feature in priority order. For each feature you act as every role in turn — there are no teammates to message, so the review steps become self-review passes you perform inline:

1. **If no spec exists:** run Phase 2 (Specify) to create `spec.md`, then review it from a Product-Manager lens (user stories complete? acceptance criteria testable? scope concerns?).
2. **If no plan exists:** run Phase 3 (Plan) to create `plan.md`, then review it from an Architect lens (cross-feature integration, shared components) and a per-discipline lens (complexity estimates, performance concerns).
3. **Task generation with role annotations:** run Phase 4 (Task) to create `tasks.md`, and annotate every task with exactly one `@role` indicating which discipline owns it. Checkpoints are always `@tech-lead`. A task that spans two roles must be split.
4. **Log the refinement** in `sprint-[N].md`:

   ```markdown
   ### [feature-name] — [Date]
   roles: PM, SA, BE
   decisions: [key decisions from planning]
   task_count: [N] tasks, [X] parallel groups
   role_assignments: BE:[N], FE:[N], UI:[N]
   ```

5. **After all features are refined**, summarize: features refined, total tasks, role distribution. Ready for execution.

#### Role annotation rules

- `@frontend` — UI components, client-side logic, CSS, browser APIs
- `@backend` — server logic, APIs, database, infrastructure
- `@app` — mobile/native/platform-specific code
- `@ui-designer` — accessibility audits, design reviews, asset creation
- `@tech-lead` — checkpoints, integration tasks, cross-cutting concerns
- Custom roles use the same `@kebab-case` convention

Every task MUST have exactly one `@role`. Checkpoints are always `@tech-lead`.

### Sprint Execution (sequential, phase-gated)

Execution proceeds phase by phase **across all features at once**: complete every Phase 1 task (of every feature) before any Phase 2 task, and so on. You do the work of all roles yourself; the `@role` annotations simply document ownership and let you group related tasks.

For each phase M:

1. Work through every `@role` task in Phase M, across all features, using test-first for each (write → fail → implement → pass).
2. When all Phase M tasks are done, run the `[C]` checkpoint yourself: full test suite **and** build, using commands from `.junie/guidelines.md`. In Sprint Mode the checkpoint covers **all** features in the sprint, not just one — cross-feature regressions must be caught here.
3. Record the checkpoint in each feature's `progress.md` and update the gate status in `sprint-[N].md`:

   ```markdown
   ### Phase [M] Gate
   all_tasks_done: yes
   checkpoint: pass
   ```

4. Only advance to Phase M+1 once the gate is clear (all tasks done + checkpoint passes). If the checkpoint fails, fix the rework before advancing.

Watch for cross-feature concerns throughout: shared components touched by multiple features (keep edits coherent), API-contract conflicts (resolve before the gate clears), and duplicate code across features (flag for the Polish phase).

### Sprint completion

After all phases complete across all features:

1. Run Build Verification (the final group in each `tasks.md`) — full build, full test suite, and any platform targets.
2. Update `sprint-[N].md`: `status: done`, `completed: [Date]`, `features_delivered: [list]`, `total_tasks: [N] completed, [M] reworked`.
3. Report to user: `✓ Sprint [N] complete — [X] features delivered`.

### Single-feature fallback

If the user starts Sprint Mode with only one feature, it still works — refinement produces role-annotated tasks and execution runs them phase by phase. The overhead is minimal and the structure stays consistent; just run it.

---

## Behaviors that apply to all phases

- **Don't overwrite without asking.** If a spec file already exists, confirm with the user before replacing it. They may have made manual edits you'd lose.
- **Resolve open questions.** When you encounter `[NEEDS CLARIFICATION: ...]` markers, ask the user. Don't fill in answers based on assumptions.
- **Respect the constitution.** The principles in `specs/memory/constitution.md` apply to all decisions. If a user request conflicts with a constitutional principle, raise it — the user can override, but they should do so consciously.
- **Test-first is structural, not aspirational.** In the task list, the test task always precedes its implementation task. During execution, you write the test, run it to see it fail, then implement. If the project doesn't have a test framework set up, setting one up is the very first task. If you ever find yourself writing implementation code without a failing test already in place, stop and write the test first.
- **Non-goals are boundaries.** If something is listed in the spec's non-goals, do not build it, suggest building it, or plan for it — even if it would be "easy to add."
- **Specs say WHAT and WHY. Plans say HOW.** If you find yourself writing implementation details in a spec, move them to the plan. If you find yourself writing user stories in a plan, move them to the spec.
