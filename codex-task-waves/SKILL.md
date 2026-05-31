---
name: codex-task-waves
description: Use when the user says "have codex fix this" / "have codex implement this" / "let codex handle this" / "give this to codex" / "delegate this to codex" for a single task with context already in scope (a Jira ticket, GitHub issue, file diff, bug, or described change). Plans the work, splits it into reviewable waves, opens a draft PR before review, dispatches codex review/correction through durable GitHub PR review threads, and marks the converged draft PR ready for review. Not for multi-issue parallel batches (use codex-issue-waves) or one-shot codex runs without planning (use invoking-codex-exec).
---

# Codex task waves

Take a single in-scope task — "this" being the current Jira ticket, GitHub issue, bug, or described change — and produce one draft-then-ready PR composed of verified commits, each shaped by a written plan, a codex implementer dispatch, a codex reviewer dispatch that posts GitHub PR review threads, and (when needed) a codex corrector dispatch that resolves those threads.

**Orchestration model.** Claude is the PO / engineering manager. Codex is the worker — implementer, reviewer, or corrector. Claude never edits source files, never reviews code, never makes inline fixes. Every code touch goes through a codex dispatch. See `invoking-codex-exec` "Codex roles" and "Orchestrator boundaries" for the full rule.

**REQUIRED SUB-SKILLS:**
- `invoking-codex-exec` — every wave's dispatches (implementer, reviewer, corrector); flags, sandbox traps, read-only enforcement, monitoring
- `superpowers:writing-plans` — the plan file that drives every wave
- `superpowers:using-git-worktrees` — worktree setup before wave 1

## Phases

1. **Identify "this"** — the task in scope. If ambiguous (multiple recent items, no recent context, fresh session), ask the user before proceeding. Don't guess.
2. **Plan** — write a plan file in the worktree (`PLAN_<TICKET-ID>.md` or `PLAN.md`). Per `superpowers:writing-plans`: spec, root cause, proposed change, tests, verification commands, out-of-scope. The plan file is the artifact every wave reads.
3. **Split into waves** — see "Wave splitting" below. Output: an ordered list of waves, each with a one-line goal and an "exit when..." condition.
4. **Per-wave loop**: dispatch → verify → commit → push/update draft PR → review threads → correct/resolve → next.
5. **Finalize** — strip the plan file, run full verification, push, update the draft PR body, confirm review-thread convergence, and mark ready for review.

## Wave splitting

The number of waves depends on the task's shape, not its size in lines:

- **1 wave** — atomic changes. One-line fixes, single-function bugs, mechanical renames, isolated test additions, small refactors with a self-contained blast radius. Default to 1 wave unless a boundary earns its own review cycle.
- **2 waves** — "set up the surface, then use it". E.g., add a domain field then wire it through; write a helper then call it; introduce a feature flag then ramp.
- **3 waves** — changes that span a layered stack. Schema migration → repository/service → controller/UI. Or producer → wire format → consumer.
- **4+ waves** — only when each wave verifies independently AND a later wave's design genuinely depends on the prior wave's actual landed code. Rare. Prefer 2–3.

**Boundaries that work:**
- Layer boundaries (domain / service / controller / UI)
- Data-flow direction (producer → wire → consumer)
- Feature flag stages (introduce gated → wire usage → flip → remove flag)
- Tests-first as wave 1 if the user asked for strict TDD

**Don't split when:**
- The task is genuinely atomic (single rename, one-line bug, isolated type fix)
- The user explicitly says "one-shot" / "don't split"
- Each potential wave's diff is <~50 lines (review overhead exceeds the gain)

**Don't merge waves when:**
- A verification step (compile / test / lint) must pass before the next wave's design is final
- The reviewer needs to see a clean diff per concern
- A wave's correction round might invalidate a later wave's design

State the wave count and rationale to the user before starting wave 1. Single-wave is a valid answer — say so explicitly so the user isn't surprised by a flat dispatch.

## Per-wave loop

For each wave, in order:

1. **Implementer dispatch** via `invoking-codex-exec` (implementer role). The codex prompt must include:
   - The plan file path and an instruction to read it first.
   - The current wave's specific instructions and exit condition.
   - A `## Scope` block with three required headings (`In scope`, `Out of scope`, `Open questions`). The plan file's spec section feeds the per-wave Scope blocks but does not replace them — each wave gets its own block tuned to that wave's surface. `Open questions` documents resolved decisions, not unresolved ones; resolve any genuinely-open question before dispatch.
   - The verification commands for this wave (compile, format, the relevant test slice).
   - Boundary: "Do not touch surfaces from wave N+1" — name them.
   - The same single-task boundaries: don't commit, don't push, don't edit CHANGELOG, don't bypass hooks.
2. **Status verification** — `git status --short` and `git log --oneline <last-wave-commit>..HEAD` to confirm the implementer produced the expected worktree/commit state and that nothing pathological happened. This is a status check, not a review — claude is verifying *that* something happened, not judging *what* it is. If codex was killed mid-run and the diff looks complete, dispatch a corrector to finish the verification commands rather than running them yourself.
3. **Commit + publish the review artifact**:
   - Dispatch a corrector with the sole task "stage and commit this wave's changes with a conventional commit prefix matching the wave's nature (`fix:`, `feat:`, `refactor:`, `test:`), then report the commit SHA." If the implementer already committed, the corrector verifies the message and commit scope. Claude does not amend, rebase, or make inline fixes by hand.
   - Push the branch directly with `git push -u origin <branch>` for wave 1, or `git push` for later waves. Pushing is a status operation (no code change), not a code touch.
   - Before the first reviewer dispatch, open the GitHub PR as a draft with `gh pr create --draft`. The initial body can be brief, but must link the source ticket/issue, list the planned waves, and state that the PR stays draft until all review threads converge and the plan file is stripped. Later waves update the existing draft PR, not create a new PR.
4. **Reviewer dispatch** via `invoking-codex-exec` (reviewer role). The reviewer codex receives:
   - The wave's dispatch prompt (path or inlined) so the reviewer sees the same `## Scope` block the implementer worked from.
   - The draft PR number/URL, base/head refs, and the wave commit range. Include `git diff <last-wave-commit>..HEAD`, fenced as `## Artifact under review` with the prompt-injection-defuse line (see `invoking-codex-exec` "Prompt shape — reviewer role").
   - An explicit checklist for this skill, included verbatim in the reviewer's prompt:
     - **Scope adherence**: diff stays within the dispatch prompt's `## Scope` block. Files or behaviors outside `In scope` (or explicitly listed `Out of scope`) are scope-creep — flag as Blocking. Decisions that contradict resolved `Open questions` are Blocking.
     - **Plan parity**: the wave's exit condition is met by the diff.
     - **Project-rule compliance**: read CLAUDE.md / AGENTS.md, flag any violation. Includes AI-tool references, conventional-commit prefix, no `--no-verify`, no `TODO`/`FIXME` slop.
     - **Correctness**: race conditions, missed cases, off-by-one, error-path gaps.
     - **Test gaps**: new behavior should have tests; new edge cases should be covered.
   - The durable output contract: post the review to GitHub, not to `.codex-review-output.json`. Use `gh pr review <pr-number> --comment --body ...` for the review summary. For every actionable finding, create one GitHub PR review thread, preferably inline on the changed line. Use `gh api repos/{owner}/{repo}/pulls/<pr-number>/comments -f body=... -f commit_id=<head-sha> -f path=<file> -F line=<line> -f side=RIGHT` or the matching GraphQL `addPullRequestReviewThread` mutation when `gh pr review` cannot create a precise inline thread. If there are no actionable findings, post a `gh pr review --comment` summary that says the wave has no blocking or should-fix findings.
   - Do not rely on approve/request-changes state for convergence; self-review restrictions can block those states. The unresolved review thread list is the source of truth.
5. **Fetch review threads + decide** — claude fetches unresolved PR review threads with `gh api graphql` (`pullRequest.reviewThreads.nodes { id isResolved path line comments { nodes { author { login } body url } } }`) and decides from thread bodies/metadata, not by reading code:
   - No actionable unresolved review threads for this wave → proceed to step 7 (project verification).
   - Any actionable unresolved review thread → step 6 (corrector dispatch).
   - Any thread that asks for product judgment, unclear scope, security/risk acceptance, or another decision codex cannot make → stop with `needs-human`. Reply in that thread with `requires human input: <specific question or decision needed>`, leave the PR draft, and report the blocked thread URLs to the user.
   - Cross-check scope-violation review threads against the plan: reviewer codex sometimes flags a feature as scope-creep when it was in the wave's exit condition. Read the plan file (NOT the diff) to confirm before insisting on a scope-creep fix.
6. **Corrector dispatch** via `invoking-codex-exec` (corrector role). The corrector prompt:
   - Path to the original wave dispatch prompt.
   - The draft PR number/URL.
   - The exact unresolved review thread IDs, URLs, and reviewer comments the corrector must address.
   - A `## Scope` block whose `In scope` is exactly those review threads and whose `Out of scope` is "everything else, including unrelated nits or new refactors".
   - Instructions to fetch unresolved review threads first, make the smallest fixes needed, run the relevant verification, commit and push the correction, then resolve each fixed thread with the GraphQL `resolveReviewThread` mutation. Example:

   ```bash
   gh api graphql -F thread="$THREAD_ID" -f query='
   mutation($thread:ID!) {
     resolveReviewThread(input:{threadId:$thread}) {
       thread { id isResolved }
     }
   }'
   ```

   - If a thread cannot be corrected without human judgment, reply to that GitHub review thread with `requires human input: <specific question or decision needed>`, leave it unresolved, and exit so claude can stop with `needs-human`.
   - After corrector exits, re-fetch unresolved review threads and re-dispatch reviewer (step 4). Loop until no actionable unresolved threads remain. After 3 corrector cycles or 4 reviewer passes for the same wave without convergence, stop with `needs-human`; leave the PR draft and post a PR comment summarizing the unresolved thread URLs.
7. **Re-run the full project verification** — dispatch a corrector with the sole task "run the full project verification (`pnpm tsc --noEmit && pnpm test`, `./gradlew check`, etc.) and report pass/fail; if fail, fix, commit, push, and re-run". A wave that breaks an upstream test fails fast here, before downstream waves pile on.

Move to the next wave only when the current wave is pushed to the draft PR, no actionable unresolved review threads remain for that wave, and the project verification corrector reported pass.

## Review delegation — codex only

Reviews are dispatched as codex (reviewer role). No claude subagents, no fresh `claude -p`, no inline review by the orchestrator. Reviewer codex posts durable GitHub review state: one `gh pr review --comment` summary per pass and one unresolved PR review thread per actionable finding.

| Target | Use | Cost |
|--------|-----|------|
| **codex exec (reviewer role)** | Every review, every wave. Same worktree the implementer used, with GitHub PR review comments/threads as the durable output. | ~10–40k codex tokens per pass + read-only enforcement overhead (~2 git commands) |
| **claude subagent / `claude -p`** | **Never.** Claude is the PO. Reviews are work; work goes to codex. | — |
| **`ultrareview`** | User-triggered, billed, you can't launch it. Out of scope for this skill. | — |

### Why codex for review

- **Consistency** — same dispatch primitive for build, review, and correction. One mental model.
- **Token efficiency at the orchestrator** — claude doesn't burn its context window on per-wave diff reading. Review tokens move to codex's process.
- **Clean separation of concerns** — claude decides *what* to do; codex does *both* the building and the judging. Claude reads GitHub review-thread metadata and codex summaries, not raw code.

### Read-only enforcement

The reviewer codex has no native read-only mode. It may mutate GitHub review state via `gh pr review` / `gh api`, but it must not mutate the worktree. The orchestrator detects worktree boundary violations after the run via `git rev-parse HEAD` + `git status --porcelain` snapshots before and after. See `invoking-codex-exec` "Read-only enforcement" for the exact recipe.

After two consecutive boundary violations on the same review, escalate to user.

### When review threads are missing

Reviewer codex occasionally exits with only terminal prose or a local file. Detection:

```bash
gh pr view <pr-number> --comments
gh api graphql -F owner=OWNER -F name=REPO -F number=NUMBER -f query='
query($owner:String!, $name:String!, $number:Int!) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      reviewThreads(first:100) { totalCount nodes { id isResolved } }
    }
  }
}'
```

Recovery:
- First missing durable review: re-dispatch reviewer with the prefix "PRIOR REVIEW DID NOT POST DURABLE GITHUB REVIEW STATE. Use `gh pr review --comment` for the pass summary and `gh api` to create inline PR review threads for every actionable finding. Do not write local JSON as the source of truth."
- Second missing durable review: stop with `needs-human`.

## Finalize

After the last wave:
- Dispatch a corrector with the sole task "stage the plan file's deletion (don't ship it) and run the full project verification (format + compile + unitTest + integrationTest, or `pnpm tsc --noEmit && pnpm test`, etc.); commit the deletion if verification passes". Claude does not delete the plan file by hand.
- Push the branch — claude runs `git push` directly. Pushing is a status operation (no code change), not a code touch.
- Update the existing draft PR body via `gh pr edit`. Body must include:
  - Link to the source ticket / issue.
  - One-paragraph root-cause summary.
  - Wave-by-wave summary: what each commit does, what was reviewed, what correction commits happened, and the count of reviewer/corrector dispatches per wave for auditability.
  - Review-thread summary: resolved thread count, any `requires human input` replies, and confirmation that no actionable unresolved review threads remain.
  - PR template checklist if the repo has one.
- Fetch unresolved review threads one final time. If any actionable thread remains unresolved, or any thread contains a `requires human input` reply that has not been answered, stop with `needs-human` and leave the PR draft.
- When full verification passes, the plan file has been stripped/deleted, and no actionable unresolved review threads remain, mark the PR ready for review with `gh pr ready <pr-number>`.

The PR body is content claude composes. This is not "review" — it's a manager writing a status report from structured inputs (plan, GitHub review threads, commit log).

## Red flags — STOP

| Symptom | Meaning | Fix |
|---------|---------|-----|
| Trying to plan and dispatch in the same turn | Skipped the wave-splitting decision | Stop, write plan first |
| Wave 1 dispatch already touches wave 2's surface | Boundaries wrong | Re-split or merge waves |
| About to start reviewer dispatch before a draft PR exists | Review state would be local/session-only | Commit, push, and create `gh pr create --draft` first |
| About to read the diff yourself to "just check one thing" | Claude is reviewing | Stop. Dispatch a reviewer codex if a check is needed. If the question is genuinely about state (does it exist? what's the SHA?), `gh pr view` / `git log` are fine. Reading content for judgment is not. |
| About to fix a one-line typo in place to "save a codex dispatch" | Claude is editing | Stop. Dispatch a corrector. The discipline is the point — every code touch is a codex run with an associated audit trail. |
| Considering a claude subagent for review | Old delegation path. Claude does not review. | Dispatch codex (reviewer role) per "Review delegation — codex only" |
| Considering `claude -p` for an escalated review | Same — claude does not review at any escalation tier | Dispatch a second reviewer codex with a stronger prompt or a different framing if the first review felt shallow. Two reviewer codexes disagreeing is a signal to escalate to the user, not to bring claude into the review |
| Reviewer codex modified files | Read-only boundary violation | Reset HEAD + clean working tree, preserve GitHub review threads/comments, re-dispatch with stronger prefix. Two violations → escalate |
| Reviewer codex wrote only local JSON or prose | Review state is not durable | Re-dispatch once with explicit `gh pr review` / `gh api` thread contract. Second failure → stop with `needs-human` |
| A review thread needs a product/scope/security decision | Codex cannot safely decide | Reply `requires human input: ...`, leave the thread unresolved, stop with `needs-human` |
| 3+ corrector cycles without convergence | Plan or scope is wrong, not just the implementation | Stop with `needs-human`. Don't loop indefinitely |
| Codex commits across the boundary you set | Boundary not enforced in prompt | Dispatch corrector with explicit "don't touch X" |
| About to mark ready while plan files remain or threads are unresolved | The PR is not converged | Keep the PR draft; strip the plan file and resolve or escalate every actionable thread first |
| Considering a 5+-wave split | Over-decomposed | Combine until ≤ 3 unless each wave earns its review cycle |
| About to fan out review across many waves | Each wave's review is per-PR-single, not parallel — that's `codex-issue-waves` | Single-task waves run sequentially; reviews don't parallelize within one task |
| Single-wave task, but you wrote 100 lines of plan | Plan is over-engineered for the task | Trim plan, dispatch, move on |
| User said "just have codex fix it" but you start lecturing about waves | Single-wave answer was correct; just proceed | State "1 wave, here's why," then go |

## Phase logging (WAVE_PHASE)

Emit structured phase-marker lines around every codex dispatch. This feeds the weekly performance report (`~/scripts/codex-waves-perf-report.sh`).

**Log file**: `${CODEX_WAVE_LOG:-$HOME/tasks/logs/codex-waves-manual.log}` — append, never overwrite.

**Wave ID**: `${CODEX_WAVE_ID}` if that env var is set (orchestrator sets it); otherwise generate once at session start as `$(date +%Y%m%dT%H%M%S)-<issue-number>` and reuse across all phases.

**Line format**:
```
[ISO8601Z] WAVE_PHASE wave=<id> repo=<owner/repo> issue=<n> phase=<implement|review|correct|merge> event=<start|end> exit=<code> duration_s=<s> tokens=<n>
```
For `event=start`: leave `exit=`, `duration_s=`, `tokens=` empty. For `event=end`: fill all fields.

**Token extraction**: run `~/scripts/parse-codex-log.sh <codex-outfile>` after the codex process exits; grep for `^tokens=` in the output.

**When to emit**:
- `implement start/end` — before/after each implementer codex dispatch per wave.
- `review start/end` — before/after each reviewer codex dispatch.
- `correct start/end` — before/after each corrector codex dispatch (one pair per cycle).
- `merge start/end` — before/after the draft PR create/update, final PR body update, and ready-for-review step.

**Shell pattern** (adapt repo, issue, outfile):
```bash
WAVE_LOG="${CODEX_WAVE_LOG:-$HOME/tasks/logs/codex-waves-manual.log}"
WAVE_ID="${CODEX_WAVE_ID:-$(date +%Y%m%dT%H%M%S)-<issue>}"
mkdir -p "$(dirname "$WAVE_LOG")"

wave_log() {
    local phase="$1" event="$2" exit_code="${3:-}" duration="${4:-}" logfile="${5:-}"
    local tokens=""
    if [[ "$event" == "end" && -n "$logfile" && -f "$logfile" ]]; then
        tokens=$(~/scripts/parse-codex-log.sh "$logfile" 2>/dev/null | grep '^tokens=' | cut -d= -f2 || true)
    fi
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WAVE_PHASE wave=${WAVE_ID} repo=<owner/repo> issue=<n> phase=${phase} event=${event} exit=${exit_code} duration_s=${duration} tokens=${tokens}" >> "$WAVE_LOG"
}

# Usage:
T0=$(date +%s); wave_log implement start
codex exec ... > /tmp/codex-runs/${WAVE_ID}-impl.out 2>&1; EC=$?
wave_log implement end "$EC" "$(($(date +%s) - T0))" "/tmp/codex-runs/${WAVE_ID}-impl.out"

# After each phase end, archive the codex output:
mkdir -p "$HOME/tasks/logs/codex-runs/${WAVE_ID}"
cp "/tmp/codex-runs/${WAVE_ID}-impl.out" "$HOME/tasks/logs/codex-runs/${WAVE_ID}/implement-1.out"
```

## When this skill applies

- "Have codex fix this" / "have codex implement this" / "have codex handle this"
- "Let codex do this" / "let codex take this ticket"
- "Give this to codex" / "delegate this to codex"
- Any single-task delegation where the user expects a PR they will review

For multi-issue parallel waves see `codex-issue-waves`. For a one-shot codex dispatch with no plan and no wave structure see `invoking-codex-exec` directly.
