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

Graphify is a knowledge-graph tool that can be installed per repository inside <!-- ADAPTER: agent-name -->. When active, it maintains `graphify-out/GRAPH_REPORT.md` — a one-page structural summary of the codebase covering "god nodes" (highly-connected files), community clusters, and surprising cross-cutting connections. It may also install a pre-search hook and a `<!-- ADAPTER: context-file -->` directive asking the agent to consult the graph before architecture questions.

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

3. **Set up <!-- ADAPTER: context-file -->.** Add a development methodology section to `<!-- ADAPTER: context-file -->` (create the file if needed). This section tells future <!-- ADAPTER: agent-name --> sessions how to work within the SDD framework. Use the content in `references/context-file-template.md`.

4. **Confirm completion.** One-line per file created (`✓ [path]`), then: "Ready. Name a feature to start Phase 2."

### Important

- If `specs/` already exists, don't overwrite anything. Ask the user if they want to reinitialize.
- If `<!-- ADAPTER: context-file -->` already exists, append the SDD section rather than replacing the file.

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
   - `<!-- ADAPTER: context-file -->` (for build commands, test commands, and platform targets)

   <!-- ADAPTER: context-file --> is the source of truth for how to build and test this project. The build commands defined there become the verification steps in the task list.

2. **Generate the task list.** Write `specs/[feature-name]/tasks.md`:

   ```markdown
   # [Feature Name] — Tasks

   ## Status Legend
   - `[ ]` Not started
   - `[x]` Complete
   - `[~]` In progress
   - `[P]` Parallelizable — <!-- ADAPTER: parallel-legend -->
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
   - [ ] Full build: [build command from <!-- ADAPTER: context-file -->, e.g. `npm run build`]
   - [ ] Full test suite: [test command from <!-- ADAPTER: context-file -->, e.g. `npm test`]
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

Tasks marked `[P]` aren't just a label — <!-- ADAPTER: parallel-tasks -->. This means:

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

1. Read `<!-- ADAPTER: context-file -->` and look for build commands (e.g., `npm run build`, `cargo build`, `go build ./...`), test commands (e.g., `npm test`, `pytest`), and any platform-specific targets (e.g., `npm run build:prod`, `docker build .`, `make release`).
2. Create one task per build/platform target. Each task runs the command and verifies it exits cleanly.
3. Create one task for the full test suite command.
4. End with a final `[C]` checkpoint that confirms everything is green.

If <!-- ADAPTER: context-file --> doesn't have build commands (maybe the project is new), ask the user what build and test commands to use, or infer from the project structure (look for `package.json`, `Cargo.toml`, `Makefile`, `pyproject.toml`, etc.) and confirm with the user.

---

## Phase 5 — Execute and Track

This phase is where code gets written. Every task follows the same rhythm: write a failing test, make it pass, mark the task done, verify at checkpoints.

### Starting execution

1. Read all inputs:
   - Check whether `graphify-out/GRAPH_REPORT.md` exists. If it does, read it — use it to navigate the codebase structurally rather than with open-ended Glob/Grep searches.
   - `specs/[feature]/spec.md` — what to build and why
   - `specs/[feature]/plan.md` — how to build it
   - `specs/[feature]/tasks.md` — what to do next
   - `<!-- ADAPTER: context-file -->` — build commands, test commands, and project conventions

   <!-- ADAPTER: context-file --> is where you find the actual commands to run tests and build the project. Without it, you'd have to guess — and guessing leads to running `npm test` on a Python project or missing a required build flag.

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

<!-- ADAPTER: parallel-exec -->

### Executing a checkpoint (`[C]`)

When you reach a `[C]` checkpoint:

1. **Run the full test suite.** Every test, not just recent ones. Use the test command from <!-- ADAPTER: context-file -->.
2. **Run the build.** Use the build command(s) from <!-- ADAPTER: context-file -->. A passing test suite with a broken build is still broken. This catches type errors, missing imports, and configuration problems that tests alone miss.
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
3. Re-read `spec.md`, `plan.md`, and `<!-- ADAPTER: context-file -->` to refresh context and pick up build/test commands
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

<!-- ADAPTER: sprint-mode -->

---

## Behaviors that apply to all phases

- **Don't overwrite without asking.** If a spec file already exists, confirm with the user before replacing it. They may have made manual edits you'd lose.
- **Resolve open questions.** When you encounter `[NEEDS CLARIFICATION: ...]` markers, ask the user. Don't fill in answers based on assumptions.
- **Respect the constitution.** The principles in `specs/memory/constitution.md` apply to all decisions. If a user request conflicts with a constitutional principle, raise it — the user can override, but they should do so consciously.
- **Test-first is structural, not aspirational.** In the task list, the test task always precedes its implementation task. During execution, you write the test, run it to see it fail, then implement. If the project doesn't have a test framework set up, setting one up is the very first task. If you ever find yourself writing implementation code without a failing test already in place, stop and write the test first.
- **Non-goals are boundaries.** If something is listed in the spec's non-goals, do not build it, suggest building it, or plan for it — even if it would be "easy to add."
- **Specs say WHAT and WHY. Plans say HOW.** If you find yourself writing implementation details in a spec, move them to the plan. If you find yourself writing user stories in a plan, move them to the spec.
