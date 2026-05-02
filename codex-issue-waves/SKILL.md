---
name: codex-issue-waves
description: Run a batch of GitHub issues through codex exec in isolated git worktrees as parallel autonomous PRs, then manage the review and correction waves until merge. Use when the user gives a list of issue numbers (≥ 2) and asks to "spawn codex" / "dispatch codex" / "have codex work on" / "manage the PRs" / "process feedback" / "get them merged" for those issues, or when the user asks for multi-issue parallel delegation to codex. Not for single-issue wave-driven delegation (use codex-task-waves), single-issue one-shot dispatch (use invoking-codex-exec), or implementation without delegation (use /pr or direct implementation).
---

# Codex Issue Waves

Run GitHub issues through `codex exec` in isolated worktrees, then shepherd the resulting PRs through review and merge. Four phases: dispatch → monitor → review wave → correction wave.

**Orchestration model.** Claude code is the orchestrator. Codex is the implementer (one process per worktree, parallel). Reviewers are claude — either in-harness subagents (default, parallel one-per-PR via `superpowers:dispatching-parallel-agents`) or fresh `claude -p` (escalation for high-stakes PRs). Codex is never used for review.

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

Treat every codex-produced PR as untrusted. Trust-but-verify.

For each PR:

1. **State check** — CI green, mergeable, not just "running". A green `test` check is necessary but not sufficient: `tsc --noEmit` is sometimes not part of CI even when tests pass. If the repo type-checks separately, run it manually.

2. **Manual spot-checks** — always:
   - `git log --oneline origin/main..origin/<branch>` to confirm a sane rebase shape (no ghost/lost commits)
   - `git diff origin/main...origin/<branch> --stat` to sanity-check blast radius
   - `grep` the diff for any stragglers from renames codex was asked to perform (old names / routes / file paths)
   - Skim the diff for conflict markers, `TODO`, `FIXME`, `console.log`, AI-tool references (Claude / Codex / Copilot), and any `--no-verify` in commit messages

3. **Independent code review** — claude code is the orchestrator; reviewers are claude. Two delegation targets, never codex:

   - **Default (parallel)** — dispatch one in-harness `superpowers:code-reviewer` subagent per PR/worktree, fired together via `superpowers:dispatching-parallel-agents`. Each subagent reads its own worktree's diff (`git diff origin/main...origin/<branch>`), the issue spec, the spot-check notes, and CLAUDE.md / AGENTS.md. Results return as structured findings ready to merge into the orchestrator's working state.
   - **Escalation (per PR, sequential)** — fresh `claude -p --dangerously-skip-permissions --add-dir <worktree> --output-format json --model opus "<review prompt>"` for high-stakes PRs (production-critical, security-sensitive, or where the issue spec itself may be wrong). Clean-room context, no main-session bias. See `codex-task-waves`'s "Review delegation" section for the full invocation template.
   - **Never codex** — codex's value is autonomous execution; review is read+reason. Same sandbox traps as `invoking-codex-exec` apply for zero benefit.

   Whichever target is used, the reviewer should look at:
   - Rebase integrity (nothing lost from concurrent merges to main)
   - Correctness of renames / retargets
   - Race conditions in new DB writes (the select-then-insert antipattern is common — prefer `INSERT ... ON CONFLICT DO UPDATE` for upserts)
   - Redundant migration blocks (codex tends to duplicate bootstrap + migration for the same table)
   - UI parity across sibling pages (if the feature lives in both a list and a detail view, check both)
   - Test gaps (UNIQUE constraints, auth paths, toggle-off-then-on flows)
   - Project-rule compliance (no AI references, conventional commits, no skipped hooks)

4. **Categorize findings**:
   - **Blocking**: TS errors, missing parity with ADR/issue spec, real data-integrity bugs, security. These must be fixed before merge.
   - **Should-fix**: performance, race conditions, test gaps, small regressions. Fix now unless explicitly scoped out.
   - **Nit/follow-up**: style, future extractions, documentation. Post as comment; don't block.

5. **Cross-check reviewer against the issue spec.** Code-reviewer agents sometimes flag a feature as "scope change" when it was in fact asked for in the issue. Read the issue body yourself before insisting on a "scope change" fix.

## Correction wave

Two paths for blockers:

**Path A — fix in-place**: If the blockers are small (< ~5 files, < ~100 lines) and you understand them, just fix them yourself in the worktree. Faster than respawning codex. Run tests, commit, `git push --force-with-lease` (rebased branches only — use `--force-with-lease` not `--force`).

**Path B — respawn codex**: If the corrections are large (rebase conflicts, renames across 10+ files, new subsystem) OR require exploring the codebase to understand, write a focused correction prompt and respawn codex on the same worktree. See `references/prompt-template.md` for the correction-prompt shape.

After either path:
- Post a PR comment summarizing what changed (so the reviewer agent doesn't have to re-read the whole diff).
- Wait for CI via `scripts/wait_for_ci.sh <PR>` — run it through the harness's background-command mechanism so the exit event wakes the agent; do not inline-poll in bash.
- If still blocked, another review round; otherwise merge.

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

See `references/pitfalls.md` for the full list. The top three are:

- **Codex builds, claude reviews** — claude code is the orchestrator; codex is for implementation only. Reviewers are always claude (in-harness subagent or fresh `claude -p`). Never dispatch codex for the review wave.
- **Self-review is blocked by GitHub** — `gh pr review --approve` fails with "cannot approve your own PR". Post via `gh pr comment` instead.
- **Worktree pins branch** — local branch delete fails until the worktree is removed. Always clean in that order.
- **Codex output ≠ committed code** — transient conflict markers in the codex log are not the same as committed markers. Verify with `gh pr diff` before raising the alarm.

## Success criteria

The batch is done when:
- Every non-skipped issue has an open or merged PR.
- Every open PR has been through both the spot-check and the reviewer-agent pass.
- No PR has been merged without at least one human-visible summary comment explaining what was changed vs the review feedback.
- Every worktree created by this skill has been removed after its branch merged.
