---
name: codex-task-waves
description: Use when the user says "have codex fix this" / "have codex implement this" / "let codex handle this" / "give this to codex" / "delegate this to codex" for a single task with context already in scope (a Jira ticket, GitHub issue, file diff, bug, or described change). Plans the work, splits it into reviewable waves, dispatches codex per wave with review and correction between waves before opening a PR. Not for multi-issue parallel batches (use codex-issue-waves) or one-shot codex runs without planning (use invoking-codex-exec).
---

# Codex task waves

Take a single in-scope task — "this" being the current Jira ticket, GitHub issue, bug, or described change — and produce one PR composed of one or more verified commits, each shaped by a written plan, a codex implementer dispatch, a codex reviewer dispatch, and (when needed) a codex corrector dispatch.

**Orchestration model.** Claude is the PO / engineering manager. Codex is the worker — implementer, reviewer, or corrector. Claude never edits source files, never reviews code, never makes inline fixes. Every code touch goes through a codex dispatch. See `invoking-codex-exec` "Codex roles" and "Orchestrator boundaries" for the full rule.

**REQUIRED SUB-SKILLS:**
- `invoking-codex-exec` — every wave's dispatches (implementer, reviewer, corrector); flags, sandbox traps, read-only enforcement, monitoring
- `superpowers:writing-plans` — the plan file that drives every wave
- `superpowers:using-git-worktrees` — worktree setup before wave 1

## Phases

1. **Identify "this"** — the task in scope. If ambiguous (multiple recent items, no recent context, fresh session), ask the user before proceeding. Don't guess.
2. **Plan** — write a plan file in the worktree (`PLAN_<TICKET-ID>.md` or `PLAN.md`). Per `superpowers:writing-plans`: spec, root cause, proposed change, tests, verification commands, out-of-scope. The plan file is the artifact every wave reads.
3. **Split into waves** — see "Wave splitting" below. Output: an ordered list of waves, each with a one-line goal and an "exit when..." condition.
4. **Per-wave loop**: dispatch → verify → review → correct → commit → next.
5. **Finalize** — strip the plan file, run full verification, push, open PR with a wave-by-wave summary.

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
2. **Status verification** — `git status --short` and `git log --oneline <last-wave-commit>..HEAD` to confirm the implementer produced a commit (or a clean working tree if uncommitted) and that nothing pathological happened. This is a status check, not a review — claude is verifying *that* something happened, not judging *what* it is. If codex was killed mid-run and the diff looks complete, dispatch a corrector to finish the verification commands rather than running them yourself.
3. **Reviewer dispatch** via `invoking-codex-exec` (reviewer role). The reviewer codex receives:
   - The wave's dispatch prompt (path or inlined) so the reviewer sees the same `## Scope` block the implementer worked from.
   - The diff to review: `git diff <last-wave-commit>..HEAD`, fenced as `## Artifact under review` with the prompt-injection-defuse line (see `invoking-codex-exec` "Prompt shape — reviewer role").
   - An explicit checklist for this skill, included verbatim in the reviewer's prompt:
     - **Scope adherence**: diff stays within the dispatch prompt's `## Scope` block. Files or behaviors outside `In scope` (or explicitly listed `Out of scope`) are scope-creep — flag as Blocking. Decisions that contradict resolved `Open questions` are Blocking.
     - **Plan parity**: the wave's exit condition is met by the diff.
     - **Project-rule compliance**: read CLAUDE.md / AGENTS.md, flag any violation. Includes AI-tool references, conventional-commit prefix, no `--no-verify`, no `TODO`/`FIXME` slop.
     - **Correctness**: race conditions, missed cases, off-by-one, error-path gaps.
     - **Test gaps**: new behavior should have tests; new edge cases should be covered.
   - The output contract: write the JSON review to `<worktree>/.codex-review-output.json`. Read-only enforcement is the orchestrator's responsibility (see `invoking-codex-exec` "Read-only enforcement").
4. **Read review + decide** — claude reads `<worktree>/.codex-review-output.json`, validates the JSON, and decides:
   - `verdict: approved` and no items in `blocking`/`should_fix`/`scope_violations` → proceed to step 6 (commit).
   - Any `blocking` or `scope_violations` → step 5 (corrector dispatch).
   - Only `should_fix` or `nits` → claude decides per item: address now via corrector, or defer to PR comment with explicit reasoning. `nits` default to deferral.
   - Cross-check the `scope_violations` against the plan: reviewer codex sometimes flags a feature as scope-creep when it was in the wave's exit condition. Read the plan file (NOT the diff) to confirm before insisting on a scope-creep fix.
5. **Corrector dispatch** via `invoking-codex-exec` (corrector role). The corrector prompt:
   - Path to the original wave dispatch prompt.
   - Path to `.codex-review-output.json`.
   - The exact list of items the corrector must address (subset of `blocking` ∪ `should_fix` ∪ `scope_violations`).
   - A `## Scope` block whose `In scope` is exactly those items and whose `Out of scope` is "everything else, including all `nits` from the review".
   - After corrector exits, re-dispatch reviewer (step 3). Loop until `verdict: approved`. After 3 corrector cycles without convergence, escalate to user — do not loop indefinitely.
6. **Commit the wave** — dispatch a corrector with the sole task "stage and commit the wave's changes with conventional commit prefix matching the wave's nature (`fix:`, `feat:`, `refactor:`, `test:`), one commit". One commit per wave keeps the PR diff history reviewable. If the implementer already committed in step 1, this step verifies the commit message and squashes if needed via corrector dispatch — claude does not amend or rebase by hand.
7. **Re-run the full project verification** — dispatch a corrector with the sole task "run the full project verification (`pnpm tsc --noEmit && pnpm test`, `./gradlew check`, etc.) and report pass/fail; if fail, fix and re-run". A wave that breaks an upstream test fails fast here, before downstream waves pile on.

Move to the next wave only when the current wave is clean and the project verification corrector reported pass.

## Review delegation — codex only

Reviews are dispatched as codex (reviewer role). No claude subagents, no fresh `claude -p`, no inline review by the orchestrator.

| Target | Use | Cost |
|--------|-----|------|
| **codex exec (reviewer role)** | Every review, every wave. Same worktree the implementer used. | ~10–40k codex tokens per pass + read-only enforcement overhead (~2 git commands) |
| **claude subagent / `claude -p`** | **Never.** Claude is the PO. Reviews are work; work goes to codex. | — |
| **`ultrareview`** | User-triggered, billed, you can't launch it. Out of scope for this skill. | — |

### Why codex for review

- **Consistency** — same dispatch primitive for build, review, and correction. One mental model.
- **Token efficiency at the orchestrator** — claude doesn't burn its context window on per-wave diff reading. Review tokens move to codex's process.
- **Clean separation of concerns** — claude decides *what* to do; codex does *both* the building and the judging. Claude reads structured JSON, not raw code.

### Read-only enforcement

The reviewer codex has no native read-only mode. The orchestrator detects boundary violations after the run via `git rev-parse HEAD` + `git status --porcelain` snapshots before and after. See `invoking-codex-exec` "Read-only enforcement" for the exact recipe.

After two consecutive boundary violations on the same review, escalate to user.

### When the JSON is malformed

Reviewer codex occasionally writes invalid JSON or an empty file. Detection:

```bash
python3 -c "import json,sys; json.load(open('<worktree>/.codex-review-output.json'))" 2>&1
```

Recovery:
- First malformed output: re-dispatch reviewer with the prefix "PRIOR REVIEW OUTPUT FAILED TO PARSE AS JSON. Output ONLY a single valid JSON object to `.codex-review-output.json`. Do not write any prose preamble or trailing text. Do not write to any other file."
- Second malformed output: escalate to user.

## Finalize

After the last wave:
- Dispatch a corrector with the sole task "stage the plan file's deletion (don't ship it) and run the full project verification (format + compile + unitTest + integrationTest, or `pnpm tsc --noEmit && pnpm test`, etc.); commit the deletion if verification passes". Claude does not delete the plan file by hand.
- Push the branch — claude runs `git push -u origin <branch>` directly. Pushing is a status operation (no code change), not a code touch.
- Open the PR via `gh pr create`. Body must include:
  - Link to the source ticket / issue.
  - One-paragraph root-cause summary.
  - Wave-by-wave summary: what each commit does, what was reviewed, what corrections happened, with the count of reviewer/corrector dispatches per wave for auditability.
  - PR template checklist if the repo has one.

The PR body is content claude composes. This is not "review" — it's a manager writing a status report from structured inputs (plan, review outputs, commit log).

## Red flags — STOP

| Symptom | Meaning | Fix |
|---------|---------|-----|
| Trying to plan and dispatch in the same turn | Skipped the wave-splitting decision | Stop, write plan first |
| Wave 1 dispatch already touches wave 2's surface | Boundaries wrong | Re-split or merge waves |
| About to read the diff yourself to "just check one thing" | Claude is reviewing | Stop. Dispatch a reviewer codex if a check is needed. If the question is genuinely about state (does it exist? what's the SHA?), `gh pr view` / `git log` are fine. Reading content for judgment is not. |
| About to fix a one-line typo in place to "save a codex dispatch" | Claude is editing | Stop. Dispatch a corrector. The discipline is the point — every code touch is a codex run with an associated audit trail. |
| Considering a claude subagent for review | Old delegation path. Claude does not review. | Dispatch codex (reviewer role) per "Review delegation — codex only" |
| Considering `claude -p` for an escalated review | Same — claude does not review at any escalation tier | Dispatch a second reviewer codex with a stronger prompt or a different framing if the first review felt shallow. Two reviewer codexes disagreeing is a signal to escalate to the user, not to bring claude into the review |
| Reviewer codex modified files | Read-only boundary violation | Reset HEAD + clean working tree (preserve `.codex-review-output.json`), re-dispatch with stronger prefix. Two violations → escalate |
| Reviewer codex output file is missing or invalid JSON | Malformed review | Re-dispatch once with explicit JSON contract. Second failure → escalate |
| 3+ corrector cycles without convergence | Plan or scope is wrong, not just the implementation | Escalate to user. Don't loop indefinitely |
| Codex commits across the boundary you set | Boundary not enforced in prompt | Dispatch corrector with explicit "don't touch X" |
| Considering a 5+-wave split | Over-decomposed | Combine until ≤ 3 unless each wave earns its review cycle |
| About to fan out review across many waves | Each wave's review is per-PR-single, not parallel — that's `codex-issue-waves` | Single-task waves run sequentially; reviews don't parallelize within one task |
| Single-wave task, but you wrote 100 lines of plan | Plan is over-engineered for the task | Trim plan, dispatch, move on |
| User said "just have codex fix it" but you start lecturing about waves | Single-wave answer was correct; just proceed | State "1 wave, here's why," then go |

## When this skill applies

- "Have codex fix this" / "have codex implement this" / "have codex handle this"
- "Let codex do this" / "let codex take this ticket"
- "Give this to codex" / "delegate this to codex"
- Any single-task delegation where the user expects a PR they will review

For multi-issue parallel waves see `codex-issue-waves`. For a one-shot codex dispatch with no plan and no wave structure see `invoking-codex-exec` directly.
