When you hit a group of consecutive `[P]` tasks, launch them all concurrently using the **Agent tool**. This is actual parallel execution, not a suggestion — spawn one subagent per `[P]` task in a single message so they run simultaneously.

Each subagent gets a **minimal** prompt — no narrative, just structured fields:

```
TASK: [exact task line from tasks.md]
FEATURE: [feature-name]
READ: specs/[feature]/spec.md, specs/[feature]/plan.md, specs/memory/constitution.md, .claude/CLAUDE.md
OWN_FILES: [files/modules this task touches — nothing else]
RULES: test-first (write→fail→implement→pass), no shared config edits, no files outside OWN_FILES
REPORT_WHEN_DONE: STATUS: done | TASK: [id] | FILES: [changed] | RESULT: [one line]
```

This prompt is ~100 tokens vs ~200+ for a prose version. Over a sprint with 20+ parallel tasks, this halves the context overhead.

After all subagents complete:

1. Integrate their work (merge files, resolve any conflicts)
2. Run the full test suite
3. Mark all `[P]` tasks `[x]` in `tasks.md`
4. If any subagent's tests fail after integration, fix the conflicts before moving on
