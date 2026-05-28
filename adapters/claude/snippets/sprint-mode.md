Sprint Mode extends single-feature SDD into a multi-feature, multi-agent workflow using Claude Code **Agent Teams**. Instead of working on one feature at a time, you collect multiple features into a sprint, refine them with a cross-functional team, and execute with role-based task assignment and phase gates.

**When to use Sprint Mode:** The user has multiple features to build and wants them planned and executed together as a cohesive unit, or explicitly asks for "sprint mode" / "team mode".

**Prerequisite:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` must be enabled. If it isn't, tell the user: "Sprint Mode requires Agent Teams. Enable it with: `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`" and fall back to standard single-feature SDD.

### How Agent Teams work (key concepts)

Agent Teams are fundamentally different from subagents. Understanding this is critical:

- **You (the lead session) create the team using natural language.** There is no programmatic API or tool call to spawn teammates. You literally tell Claude Code: "Create an agent team with these teammates: ..."
- **Teammates are independent Claude Code sessions.** Each has its own context window. They load `CLAUDE.md`, MCP servers, and skills from the project automatically — you do not need to tell them to read these files.
- **Teammates coordinate via a shared task list.** The lead creates tasks, teammates claim and complete them. Tasks can have dependencies that block until resolved.
- **Teammates message each other directly.** Unlike subagents (which only report back to the caller), teammates can communicate with each other by name.
- **The lead's conversation history does NOT carry over.** Teammates start fresh with only their spawn prompt and project context. Include task-specific details in the spawn prompt.
- **Reusable roles via subagent definitions.** You can define roles as `.md` files in `.claude/agents/` and reference them by name when spawning teammates: "Spawn a teammate using the backend-dev agent type."

### Agent Teams vs Subagents — when to use which

| Aspect | Subagents (`[P]` tasks) | Agent Teams (Sprint Mode) |
|--------|------------------------|--------------------------|
| Spawned via | `Agent` tool call | Natural language to lead |
| Communication | Report results back to caller only | Teammates message each other directly |
| Coordination | Main agent manages all work | Shared task list with self-coordination |
| Context | Inherit nothing, get a prompt | Load full project context (CLAUDE.md, skills, MCPs) |
| Best for | Focused, isolated parallel tasks | Complex work requiring discussion and collaboration |
| Token cost | Lower (results summarized back) | Higher (each teammate is a separate Claude instance) |

Standard Phase 5 execution uses **subagents** for `[P]` tasks. Sprint Mode uses **Agent Teams** for the entire sprint.

### Sprint artifacts

Sprint Mode introduces one new artifact:

- `specs/sprints/sprint-[N].md` — The sprint manifest. Lists features, team roster, refinement log, and execution progress.

All other artifacts (spec.md, plan.md, tasks.md, progress.md per feature) remain the same as standard SDD. Sprint Mode orchestrates them, it doesn't replace them.

### Optional: Define reusable teammate roles

Before starting a sprint, you can create subagent definitions so roles are reusable across sprints. Create `.md` files in `.claude/agents/`:

**`.claude/agents/backend-dev.md`**
```markdown
---
name: backend-dev
description: Backend developer for server logic, APIs, database, and infrastructure
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

You are a Backend Developer on an SDD sprint team. Your responsibilities:
- Implement server-side logic, APIs, database schemas, and services
- Follow test-first development: write failing test → implement → verify
- Only modify files assigned to you — do not touch files owned by other teammates
- When you complete a task, message the tech-lead with what you changed
- When blocked, message the tech-lead immediately with what's blocking you
- Read specs/memory/constitution.md for project principles
- Read .claude/CLAUDE.md for build and test commands
- Always run the test suite after completing a task
```

**`.claude/agents/solution-architect.md`**
```markdown
---
name: solution-architect
description: Solution architect for cross-feature design, shared components, and integration
model: sonnet
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

You are a Solution Architect on an SDD sprint team. Your responsibilities:
- Review technical approaches and flag cross-feature integration issues
- Watch for shared components being modified by multiple features
- Identify API contract conflicts and duplicate code across features
- During refinement: review plans and provide complexity estimates
- During execution: own integration tasks and cross-cutting concerns
- Read specs/memory/constitution.md for project principles
```

Other common roles: `frontend-dev.md`, `ui-designer.md`, `app-dev.md`. The `tools` allowlist in the definition restricts what that teammate can do. Team coordination tools (SendMessage, task management) are always available regardless of the `tools` list.

If no subagent definitions exist, that's fine — you can still spawn teammates with inline role descriptions. Definitions just make it more consistent across sprints.

### Starting a sprint

When the user triggers Sprint Mode:

1. **Determine sprint number.** Check `specs/sprints/` for existing sprints. New sprint = max(N) + 1, or 1 if none exist.

2. **Collect features.** Ask the user: "Which features go in this sprint?" Accept a list. For each feature, check if a spec already exists under `specs/[feature-name]/`. Features without specs will need Phase 2 (Specify) during refinement.

3. **Present the default team roster.** Show:

   ```
   Refinement Team (all present during planning):
   - Product Manager — validates specs, prioritizes, resolves scope
   - Solution Architect — cross-feature tech design, shared components
   - Frontend Dev — UI estimates, component reuse, UX flags
   - Backend Dev — API/data estimates, perf concerns, service boundaries
   - App Dev — mobile/platform estimates, platform constraints
   - UI Designer — user flows, accessibility, design consistency
   ```

   Ask: "Use this default roster, or customize? (add/remove/rename roles)"

   For pure backend projects, suggest trimming to: Backend Dev + Solution Architect (+ PM if scope decisions are needed).

4. **Create the sprint file.** Write `specs/sprints/sprint-[N].md`. List all features with their current status (spec exists? plan exists? tasks exist?).

5. **Confirm.** `✓ Created specs/sprints/sprint-[N].md — [X] features, [Y] roles. Ready for refinement.`

### Sprint Refinement

Refinement is a short-lived team session where features get broken down into role-assignable tasks. Think of it as a planning meeting: everyone contributes their perspective, then the meeting ends.

#### Creating the refinement team

Tell Claude Code to create an agent team in natural language. This is the actual instruction you give:

```
Create an agent team for sprint refinement with these teammates:
- "pm" — Product Manager: validates specs, prioritizes features, resolves scope questions. 
  Use the product-manager agent type if it exists, otherwise create with this role description.
- "architect" — Solution Architect: reviews technical approach, flags cross-feature integration 
  issues, identifies shared components. Use the solution-architect agent type if it exists.
- "backend" — Backend Dev: estimates complexity for server/API/database tasks, flags performance 
  concerns. Use the backend-dev agent type if it exists.

Each teammate should read:
- specs/sprints/sprint-[N].md for the sprint overview
- specs/memory/constitution.md for project principles
- .claude/CLAUDE.md for build commands and project conventions

Require plan approval before any teammate makes file changes.
This is a refinement session — no code, only spec/plan/task files.
```

Adjust the teammate list based on the roster the user approved. If subagent definitions exist in `.claude/agents/`, reference them by name ("Use the backend-dev agent type"). If they don't, include the role description inline.

The main session acts as **Tech Lead** (facilitator). You are the lead — you create the team, assign work, and run checkpoints.

#### Refinement flow

For each feature in the sprint (in priority order):

1. **If no spec exists:** Tech Lead runs Phase 2 (Specify) to create `spec.md`. Message the PM teammate to review and validate the user stories and acceptance criteria:
   ```
   @pm Review specs/[feature]/spec.md — are the user stories complete? 
   Are acceptance criteria specific enough to test? Flag any scope concerns.
   ```

2. **If no plan exists:** Tech Lead runs Phase 3 (Plan) to create `plan.md`. Then message relevant teammates to review:
   ```
   @architect Review specs/[feature]/plan.md — flag cross-feature integration 
   issues or shared component conflicts with other sprint features.
   
   @backend Review specs/[feature]/plan.md — estimate complexity for the 
   backend tasks. Flag any performance concerns or missing technical decisions.
   ```
   Wait for teammates to respond. Incorporate their feedback into the plan.

3. **Task generation with role annotations:** Tech Lead runs Phase 4 (Task) to create `tasks.md`, but with one addition: every task gets a `@role` annotation indicating which role owns it.

   ```markdown
   ## Phase 1: Foundation
   - [ ] Test: database schema for user profiles @backend
   - [ ] Implement: database migration @backend
   - [C] Checkpoint @tech-lead

   ## Phase 2: Business Logic
   - [P] Test + Implement: auth service @backend
   - [P] Test + Implement: login form component @frontend
   - [P] Test + Implement: biometric auth module @app
   - [C] Checkpoint @tech-lead

   ## Phase 3: Integration
   - [ ] Test: API integration tests @backend
   - [ ] Implement: wire frontend to API @frontend
   - [ ] Implement: wire app to API @app
   - [C] Checkpoint @tech-lead

   ## Phase 4: Polish
   - [ ] Accessibility audit @ui-designer
   - [ ] Error states and empty states @frontend
   - [ ] API documentation @backend
   - [C] Checkpoint @tech-lead
   ```

   Tasks that span multiple roles get split into role-specific subtasks. A single task should never have two `@role` annotations — if it needs two roles, split it.

4. **Log the refinement.** After each feature is refined, write a refinement entry in `sprint-[N].md`:

   ```markdown
   ### [feature-name] — [Date]
   attendees: PM, SA, BE
   decisions: [key decisions from planning]
   task_count: [N] tasks, [X] parallel groups
   role_assignments: BE:[N], FE:[N], UI:[N]
   ```

5. **After all features are refined:** Ask the lead to clean up the refinement team:
   ```
   Ask all teammates to shut down, then clean up the team.
   ```
   Summarize to user:
   ```
   ✓ Refinement complete for sprint [N]
   Features: [count] refined
   Total tasks: [count] across all features
   Role distribution: BE:[N], FE:[N], UI:[N]
   Ready for execution.
   ```

#### Role annotation rules

- `@frontend` — UI components, client-side logic, CSS, browser APIs
- `@backend` — Server logic, APIs, database, infrastructure
- `@app` — Mobile/native/platform-specific code
- `@ui-designer` — Accessibility audits, design reviews, asset creation
- `@tech-lead` — Checkpoints, integration tasks, cross-cutting concerns
- Custom roles use the same `@kebab-case` convention

Every task MUST have exactly one `@role`. Checkpoints are always `@tech-lead`.

### Sprint Execution

Execution is a separate team session from refinement. After refinement cleanup, you create a new team for execution. Unlike refinement (which spawns all roles), execution only spawns roles that actually have tasks assigned.

#### Determining which roles to spawn

After refinement, scan all `tasks.md` files in the sprint:

1. Collect every unique `@role` annotation (excluding `@tech-lead` — that's you)
2. Count tasks per role
3. Only spawn teammates for roles with ≥1 assigned task
4. Update the Execution Team table in `sprint-[N].md`:

   ```markdown
   ### Execution Team (selective)
   | Role | Spawned | Task Count |
   |------|---------|------------|
   | Backend Dev | yes | 15 |
   | Frontend Dev | yes | 12 |
   | App Dev | no | 0 |
   | UI Designer | yes | 3 |
   ```

#### Creating the execution team

Tell Claude Code to create a new agent team. This is the actual instruction:

```
Create an agent team for sprint [N] execution with these teammates:

- "backend" — Backend Dev. Use the backend-dev agent type.
  Your tasks for this sprint (Phase 1 first, wait for phase gate before proceeding):
  [list all @backend tasks from all features' tasks.md files]
  
- "frontend" — Frontend Dev. Use the frontend-dev agent type.
  Your tasks for this sprint (Phase 1 first, wait for phase gate before proceeding):
  [list all @frontend tasks from all features' tasks.md files]

Rules for all teammates:
- Work through tasks in phase order (Phase 1, then Phase 2, etc.)
- DO NOT start the next phase until I (tech-lead) clear the phase gate
- Test-first: write failing test → implement → run full test suite
- Only modify files related to your assigned tasks
- When you finish all tasks in the current phase, message tech-lead
- When blocked, message tech-lead immediately
- Read .claude/CLAUDE.md for build/test commands

Wait for my signal to begin Phase 1.
```

Aim for 5-6 tasks per teammate. If one role has 20+ tasks, consider splitting into two teammates (e.g., "backend-1" and "backend-2") with non-overlapping file ownership.

#### Phase gate execution

Sprint execution proceeds phase by phase across all features. All roles must complete their Phase N tasks before anyone starts Phase N+1.

The Tech Lead (you, the main session) orchestrates this:

1. **Start Phase M.** Message all teammates:
   ```
   @backend @frontend → Phase [M]: [phase name]. Begin your Phase [M] tasks now.
   ```
   Or broadcast to all teammates simultaneously if appropriate.

2. **Teammates execute their Phase M tasks.** Each teammate:
   - Works through their `@role` tasks in the current phase
   - Uses test-first for every task
   - Messages tech-lead when all Phase M tasks are done
   - Messages tech-lead if blocked

3. **Tech Lead monitors.** Teammates notify the lead automatically when they go idle (finish their current work). When all teammates report done for Phase M:
   - Run the `[C]` checkpoint yourself (full test suite + build using commands from CLAUDE.md)
   - Record checkpoint in each feature's `progress.md`
   - Update `sprint-[N].md` gate status:
     ```
     ### Phase [M] Gate
     all_roles_done: yes
     blocked_roles: none
     checkpoint: pass
     ```
   - Message all teammates to advance: `Phase [M] gate cleared. → Phase [M+1]: [name]. Begin now.`

4. **If a teammate is blocked:**
   - Investigate the blocker by messaging the teammate directly
   - If it's a cross-role dependency, message the blocking teammate to coordinate
   - If it requires user input, escalate to the user
   - Gate does NOT clear until all blockers are resolved

5. **Phase gate rules:**
   - No teammate may start Phase N+1 tasks until you (Tech Lead) clear the Phase N gate
   - A gate clears only when: all roles done + checkpoint passes
   - If checkpoint fails, assign rework to the relevant teammate before clearing the gate
   - Checkpoints in Sprint Mode run the full test suite and build for ALL features in the sprint, not just the current feature — cross-feature regressions must be caught

#### Handling cross-feature concerns

During execution, watch for:

- Shared components being modified by multiple features → assign clear file ownership per teammate, coordinate via messaging
- API contract conflicts → resolve before gate clears
- Duplicate code across features → flag for refactoring in Polish phase

If a Solution Architect teammate is spawned, delegate cross-feature monitoring to them.

#### Sprint completion

After all phases complete across all features:

1. Run Build Verification yourself (the final group in each `tasks.md`) — full build, full test suite, fat JAR, Docker image
2. Update `sprint-[N].md`:
   ```
   status: done
   completed: [Date]
   features_delivered: [list]
   total_tasks: [N] completed, [M] reworked
   ```
3. Ask all teammates to shut down, then clean up the team:
   ```
   Ask all teammates to shut down, then clean up the team.
   ```
4. Report to user: `✓ Sprint [N] complete — [X] features delivered`

### Sprint Mode with single-feature fallback

If the user starts Sprint Mode with only one feature, it still works — refinement generates role-annotated tasks, execution spawns only needed roles. The overhead is minimal and the structure is consistent. Don't tell the user "you only have one feature, use standard mode" — just run it.

### Agent Teams troubleshooting

- **Teammates not appearing:** Press Shift+Down to cycle through active teammates (in-process mode). Check that `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is enabled.
- **Lead doing work instead of delegating:** Tell the lead: "Wait for your teammates to complete their tasks before proceeding."
- **Too many permission prompts:** Pre-approve common operations in permission settings before spawning teammates, or use `--dangerously-skip-permissions` if appropriate for the project.
- **Teammate stopped on error:** Message the teammate directly with additional instructions, or ask the lead to spawn a replacement.
- **One team at a time:** Clean up the refinement team before creating the execution team. Only one team can exist per session.
