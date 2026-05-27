Sprint Mode coordinates multiple features as one unit. Its multi-agent variant relies on Claude Code **Agent Teams** (independent peer sessions that self-coordinate via a shared task list) — a capability Augment does not provide. So in Augment, Sprint Mode runs **sequentially**: you play every role yourself, in phase order, without spawning teammates. The structure and artifacts are identical; only the concurrency is removed.

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
2. When all Phase M tasks are done, run the `[C]` checkpoint yourself: full test suite **and** build, using commands from `AGENTS.md`. In Sprint Mode the checkpoint covers **all** features in the sprint, not just one — cross-feature regressions must be caught here.
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
