This agent has no parallel-subagent API, so a `[P]` group is executed **sequentially** — one task after another. The `[P]` marker is still meaningful: it certifies the tasks are independent (no shared state, no file conflicts, no ordering dependency), which means you may do them in any order and the closing `[C]` checkpoint can verify them as a batch.

For each task in the group, follow the same rhythm as a sequential `[ ]` task:

1. Mark it `[~]` in `tasks.md`
2. Write the test first; run it to confirm it fails
3. Implement until the test passes
4. Run the full test suite to check for regressions
5. Mark the task `[x]` in `tasks.md`

Because the tasks are independent, keep each one's edits confined to its own files/modules — if you notice two `[P]` tasks touching the same file, they were mis-marked: drop the `[P]` on one of them and treat it as ordered. Reference `specs/[feature]/spec.md`, `specs/[feature]/plan.md`, `specs/memory/constitution.md`, and `.junie/guidelines.md` while implementing. After the whole group is done, run the full test suite before the `[C]` checkpoint.
