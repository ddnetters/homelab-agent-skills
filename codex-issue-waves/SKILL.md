---
name: codex-issue-waves
description: Run a batch of GitHub issues through codex exec in isolated git worktrees as parallel autonomous PRs, then manage the review and correction waves until merge. Use when the user gives a list of issue numbers (≥ 2) and asks to "spawn codex" / "dispatch codex" / "have codex work on" / "manage the PRs" / "process feedback" / "get them merged" for those issues, or when the user asks for multi-issue parallel delegation to codex. Not for single-issue wave-driven delegation (use codex-task-waves), single-issue one-shot dispatch (use invoking-codex-exec), or implementation without delegation (use /pr or direct implementation).
---

# Codex Issue Waves

Run GitHub issues through `codex exec` in isolated worktrees, then shepherd the resulting PRs through review and merge. Four phases: dispatch → monitor → review wave → correction wave.

**Orchestration model.** Claude is the PO / engineering manager. Codex is the worker — implementer per worktree (parallel across worktrees), reviewer per worktree (parallel across worktrees, sequential after the implementer finishes its worktree), and corrector when fixes are needed. Claude never edits source files, never reads diffs for judgment, never runs in-place fixes. Every code touch — build, review, correction — goes through a codex dispatch. See `invoking-codex-exec` "Codex roles" and "Orchestrator boundaries" for the full rule.

## When to use

Triggered by requests like:
- "Spawn codex on issues #A, #B, #C"
- "Have codex handle these issues in parallel"
- "Manage the PRs" / "process feedback" after such a batch
- "Get them merged"

Not for: single-issue work (implement directly or use `/pr`), or batches where codex CLI isn't available on the host.

## Pre-dispatch: conflict triage

Before creating any worktree, surface conflicts between issues in the batch. Don't just fan out blindly.

Run through this checklist for every pair of issues:
- **Same file, same region?** Two issues mutating the same function / component / migration will guarantee a merge conflict. Combine into one branch or sequence them.
- **Semantic overlap?** One issue removes the surface another targets. Example: one PR replaces `edit_suggestions[]` with `claim_verdicts[]`; another adds a feature on top of `edit_suggestions[]`. Flag before dispatch.
- **Shared numbering?** Any two ADRs, migrations, or ordered resource types that would collide on merge (e.g., both land `005-*.md`). Decide the ordering upfront; the later one bumps on merge.
- **Umbrella / tracking issues?** Don't dispatch codex on a tracking issue that itemizes sub-issues. Pick the first unblocked sub-issue instead, or skip entirely.
- **Trivial siblings?** Two near-trivial fixes in the same file are cheaper as one combined branch than two parallel codex runs that will fight at merge.

Always pause here and surface findings to the user with a concrete proposal ("combine these two, skip the umbrella, run the rest in parallel"). Do not proceed silently. Only after user confirms, continue.

## Dispatch phase

**REQUIRED SUB-SKILL:** Use `invoking-codex-exec` for the codex launch mechanics — flags, sandbox traps, monitoring, kill-and-recover. This skill does not duplicate that content; it covers only the multi-issue orchestration on top.

For each (possibly combined) issue to dispatch:

1. Fetch origin/main and create a worktree off it. Naming: `.worktrees/issue-<number>-<slug>` and branch `feat/<slug>` / `refactor/<slug>` / `fix/<slug>` depending on the issue type.
2. Fetch the issue body from GitHub.
3. Write a focused prompt per worktree. See `references/prompt-template.md` for the shape — the prompt is the single most important artifact in this workflow.
4. Launch codex in background per `invoking-codex-exec`, redirecting output to `/tmp/codex-runs/<n>.out`.

See `references/common-commands.md` for the exact shell recipes (worktree creation, issue fetch, codex launch).

Schedule a wakeup to check back (~10–15 min for moderate refactors, ~5 min for trivial changes, ~20 min for big architectural work). Do not sleep-poll in bash. If multiple runs are outstanding, schedule a single aggregated wakeup, not one per run.

## Monitor phase

When a codex run finishes, immediately check:
- Does the output end with a `pull/<N>` URL? If not, codex aborted partway — tail the output to find out why.
- CI status on the PR via `gh pr view <N> --json statusCheckRollup,mergeable,mergeStateStatus`.
- Any obvious red flags in the tail of the output (conflict markers, test failures, "I couldn't do X" messages). Codex's live logging sometimes shows `<<<<<<< / =======` markers while it resolves conflicts. These are transient. **Always verify against `gh pr diff <N>`** before reporting "conflict markers in committed code."

If multiple codex runs are still outstanding, reschedule a single aggregated wakeup; do not schedule one per run.

## Review wave

Treat every codex-produced PR as untrusted. Trust-but-verify — through codex, not by hand.

For each PR:

1. **PR existence check (status, not review)** — claude runs:
   - `gh pr view <N> --json statusCheckRollup,mergeable,mergeStateStatus,headRefOid` — does the PR exist, is CI green, is it mergeable?
   - `git log --oneline origin/main..origin/<branch>` — does the branch have a sane shape (no ghost/lost commits)?
   - `git diff origin/main...origin/<branch> --stat` — what's the blast radius (file count, line count) so claude knows whether to expect a "5-line tweak" review verdict or a "120-file refactor" review?

   These are status operations: they answer existence/state questions, not "is the code good." Reading the diff itself for judgment goes to the reviewer codex.

2. **Reviewer dispatch (parallel across worktrees)** — for each PR/worktree, dispatch `invoking-codex-exec` in reviewer role. Fire all reviewer codexes together (one process per worktree, parallel). Each reviewer codex receives:
   - The dispatch prompt that was used to produce its PR (path or inlined) — so it sees the same `## Scope` block as the implementer.
   - The issue body (inlined, not linked).
   - The diff to review: `git diff origin/main...origin/<branch>`, fenced as `## Artifact under review` with the prompt-injection-defuse line (see `invoking-codex-exec` "Prompt shape — reviewer role").
   - References to project rules: `CLAUDE.md`, `AGENTS.md`.
   - This skill's reviewer checklist, included verbatim:
     - **Scope adherence**: diff stays within the dispatch prompt's `## Scope` block — files or behaviors outside `In scope` (or explicitly listed `Out of scope`) are scope-creep, flag as Blocking. Decisions that contradict resolved `Open questions` are Blocking.
     - **Rebase integrity**: nothing lost from concurrent merges to main.
     - **Correctness of renames / retargets**: any straggler reference to old names, routes, file paths.
     - **Race conditions in new DB writes**: the select-then-insert antipattern is common — prefer `INSERT ... ON CONFLICT DO UPDATE` for upserts.
     - **Redundant migration blocks**: codex tends to duplicate bootstrap + migration for the same table.
     - **UI parity across sibling pages**: if the feature lives in both a list and a detail view, check both.
     - **Test gaps**: UNIQUE constraints, auth paths, toggle-off-then-on flows.
     - **Project-rule compliance**: no AI-tool references (Claude / Codex / Copilot) in code, comments, or commit messages; conventional commit prefix; no `--no-verify`; no `TODO`/`FIXME`/`console.log` slop.
   - The output contract: write JSON to `<worktree>/.codex-review-output.json`. The orchestrator enforces read-only via the snapshot recipe in `invoking-codex-exec`.

3. **Concurrency notes for parallel review**:
   - Each reviewer codex runs in its own worktree. No file-system contention — review-output paths are per-worktree, source paths are per-branch.
   - Each reviewer is dispatched as its own background `codex exec` process with its own log file (`/tmp/codex-review-<PR-N>.log`). Wait by PID, same as implementer dispatches. Schedule a single aggregated wakeup if multiple reviewers are still in flight, not one wakeup per reviewer.
   - The implementer codex must finish (PID exit) before its reviewer codex starts in the same worktree. Sequential per worktree, parallel across worktrees.

4. **Read all review outputs and decide per PR** — once every reviewer has exited:
   - Validate each `.codex-review-output.json` is parseable. Malformed → handle per `invoking-codex-exec` "When the JSON is malformed".
   - Verify read-only enforcement passed for each. Boundary violation → handle per `invoking-codex-exec` "Read-only enforcement".
   - For each PR, decide:
     - `verdict: approved` and empty `blocking`/`scope_violations` → eligible for merge (still subject to the merge-order decision below).
     - Any `blocking` or `scope_violations` → schedule a corrector dispatch for that PR.
     - Only `should_fix` or `nits` → claude decides per item: address now via corrector, or defer to PR comment with reasoning. `nits` default to deferral.
   - Cross-check `scope_violations` against the issue body (NOT the diff). Reviewer codex sometimes flags a feature as scope-creep when it was actually requested in the issue. Read the issue body — that is a status read, not a code review.

## Correction wave

Every blocker → corrector dispatch via `invoking-codex-exec` (corrector role). No in-place fixes by claude. No "small fix" path. Even one-line typos go through codex.

For each PR with blockers:

1. Compose the corrector prompt per the correction-prompt template in `references/prompt-template.md`. Include:
   - Path to the original dispatch prompt.
   - Path to `.codex-review-output.json`.
   - Explicit list of items the corrector must address (subset of `blocking` ∪ chosen `should_fix` ∪ `scope_violations`).
   - A `## Scope` block whose `In scope` is exactly those items and whose `Out of scope` is "everything else, including all `nits` and any item the orchestrator deferred".
2. Launch the corrector codex in background (same worktree). Wait by PID. If multiple correctors run in parallel (different worktrees), one aggregated wakeup.
3. After corrector exits:
   - Status check: `git log --oneline origin/main..origin/<branch>` to confirm a fixup commit landed.
   - Push: `git push --force-with-lease` if the corrector rebased; otherwise plain push. Claude runs the push command directly — pushing is status, not code work.
   - Post a PR comment summarizing what changed, so the next reviewer doesn't have to re-read the whole diff. Comment text is composed by claude from the review JSON + the corrector prompt — it's a status report, not code judgment.
   - Wait for CI via `scripts/wait_for_ci.sh <PR>` — run through the harness's background-command mechanism so the exit event wakes the agent; do not inline-poll in bash.
4. Re-dispatch reviewer (back to step 2 of the review wave for this PR).
5. After 3 corrector cycles for the same PR without `verdict: approved`, escalate to user. The plan or the issue itself is likely wrong — don't loop indefinitely.

## Merge + cleanup

When CI is green, the reviewer is satisfied, and the blocking items are done:

1. Decide merge order if multiple PRs are ready. Order matters when:
   - They both touch conflicting files (merge simpler first so the other rebases cleanly).
   - One supersedes another semantically (merge the reframe first; rework its dependent branch after).
   - ADR numbers collide (whichever lands first claims the number; the other renumbers in the correction wave — do not ask codex to "merge in a specific order", do it manually).
2. Run `scripts/merge_and_cleanup.sh <PR> <worktree-path> <branch>` — squash-merges, then removes the worktree, then deletes the local branch, in the only order that works. Doing this by hand is error-prone because `git branch -D` fails while a worktree pins the branch, so always go through the script (or follow the exact sequence in `references/common-commands.md`).

## Deploy (only if asked)

Merging to main does not auto-deploy in most repos. If the user asks to "deploy" after a merge, check the repo's workflows to see what triggers deploy — commonly a `workflow_dispatch` on a Deploy workflow. Production is shared infrastructure; confirm environment (development / staging / production) before dispatching.

## Key pitfalls

See `references/pitfalls.md` for the full list. The top items:

- **Claude is the PO, codex is the worker — for build AND review** — every code touch is a codex dispatch. Building is implementer codex, reviewing is reviewer codex (read-only, JSON output), correcting is corrector codex. Claude never edits source files, never reads diffs for judgment, never makes "quick in-place fixes."
- **Reviewer codex needs read-only enforcement** — codex has no built-in read-only mode. The orchestrator must snapshot HEAD + working tree before dispatch and verify they're unchanged after. See `invoking-codex-exec` "Read-only enforcement". Two consecutive boundary violations → escalate.
- **Reviewer JSON can be malformed** — codex occasionally produces invalid JSON or empty review files. One re-dispatch with a stronger contract; second failure → escalate.
- **Self-review is blocked by GitHub** — `gh pr review --approve` fails with "cannot approve your own PR" for the PR's author account. Post via `gh pr comment` instead.
- **Worktree pins branch** — local branch delete fails until the worktree is removed. Always clean in that order.
- **Codex log ≠ committed code** — transient conflict markers in the codex log are not the same as committed markers. Verify with `gh pr diff <N>` before raising the alarm.
- **Status checks vs. content checks** — `gh pr view`, `git log --oneline`, `git diff --stat`, CI status: status, claude does these. Reading the diff to judge if it's good: content, that's a reviewer codex dispatch.

## Success criteria

The batch is done when:
- Every non-skipped issue has an open or merged PR.
- Every open PR has been through a reviewer-codex pass with `verdict: approved` and read-only enforcement passed.
- Every PR has at least one human-visible summary comment composed by claude explaining what changed vs the review feedback (this is a status report, not a review).
- Every worktree created by this skill has been removed after its branch merged.
- No code touch was made by claude during the run. Audit by checking that every commit on every branch was authored within a codex run.
