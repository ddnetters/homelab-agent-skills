# Pitfalls

Specific failure modes encountered running this workflow. Read before your first dispatch of a session; you'll save real time.

## Dispatch-time mistakes

### Blindly parallelizing issues that touch the same file
Two "tiny" issues editing adjacent lines of the same component will conflict at merge. Combine them on one branch.

### Running codex on an umbrella tracking issue
Codex will try to do all sub-issues at once. Result: one giant PR with everything half-done. Dispatch on the first unblocked sub-issue instead.

### Not inlining the issue spec in the prompt
Codex may skip `gh issue view`, re-read it mid-flight and lose context, or guess. Paste the body verbatim.

### Forgetting to fence scope
Codex is eager to clean up adjacent code. Without explicit "do NOT touch X", it will refactor things outside the issue's scope and your PR doubles in size.

## Monitoring mistakes

### Reading codex's live output as if it were the committed diff
When codex is mid-conflict-resolution, its stdout logging can contain `<<<<<<<`, `=======`, `>>>>>>>` markers. These are transient. Always verify against `gh pr diff <N>` — what got committed is often clean.

### Polling codex with `ps aux | grep`
Unreliable across shells and environments. The only trustworthy signal is the harness's background-command completion event.

### Scheduling a wakeup per run
If three runs are outstanding, one aggregated wakeup that checks all three is cheaper than three wakeups.

## Review-time mistakes

### Treating a green CI as "ready to merge"
Vitest doesn't always type-check what it imports — a prop-name typo can pass tests and still break `tsc --noEmit`. Run the type-checker manually before merge if the repo separates them.

### Assuming the reviewer agent is correct about scope
Reviewer agents sometimes flag a deliberate-per-issue-spec behavior as "out of scope". Re-read the issue before asking for it to be stripped.

### Self-approving via `gh pr review --approve`
GitHub API blocks self-review. Use `gh pr comment` instead. The PR can still be merged (unless branch protection requires a reviewer from someone else, in which case you need another human).

### Missing UI parity checks
If a feature renders in both a list and detail view (Review + ResultDetail is the canonical example), codex often only adds it to one. Check both before merge.

### Accepting select-then-insert upsert code
Race condition by default. Push back and request `INSERT ... ON CONFLICT DO UPDATE` or a transaction.

### Missing tests for
- UNIQUE constraints (direct insert-insert test that asserts the constraint fires)
- Unauthenticated/forbidden paths if the route handler still has inline 401/403 checks
- Toggle-off-then-on paths (ID reuse, row recreation)

### Forgetting to audit straggler renames
Codex renames `X` to `Y` but leaves `X` in a test file, a comment, or an unused import. Always grep the diff for the old name.

## Correction-wave mistakes

### Rebasing without resetting
If codex force-pushed while you were mid-review, `git reset --hard origin/<branch>` the worktree before you start editing or your fixes apply to a stale tree.

### Using `--force` instead of `--force-with-lease`
`--force` will stomp codex's concurrent push. `--force-with-lease` will refuse and tell you.

### Pushing without bumping the PR description
If the PR body still describes the pre-fix behavior, reviewers get confused. Update via `gh pr edit <N>` or at least post a clear comment.

### Asking codex to re-do a 3-line fix
Respawning codex for small corrections wastes 5–10 minutes and hundreds of thousands of tokens. If you can make the fix in two edits, just do it.

## Merge-time mistakes

### Merging without considering order
When two PRs both touch the same file or share an ADR number, merge the one with fewer downstream effects first. The second one rebases cleanly then.

### Running `git branch -D` before `git worktree remove`
Silently fails — the branch is pinned. Remove the worktree first.

### Merging an obsolete feature
If a superseding PR merged while a dependent PR was open, the dependent may now target a deleted surface. Don't merge just because CI is green; verify the surface still exists.

## Deploy-time mistakes

### Assuming merge triggers deploy
Usually doesn't. Most repos require a `workflow_dispatch` to deploy. Check `.github/workflows/` before claiming "deployed".

### Dispatching to production without confirmation
Deploy is shared infrastructure. Even if user says "deploy", ask which environment unless they said "production" explicitly.

### Choosing an environment codex-style
Never pick production for "Build and deploy (default)" — that's an undocumented choice. Make the environment selection explicit.
