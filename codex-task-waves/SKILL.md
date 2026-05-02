---
name: codex-task-waves
description: Use when the user says "have codex fix this" / "have codex implement this" / "let codex handle this" / "give this to codex" / "delegate this to codex" for a single task with context already in scope (a Jira ticket, GitHub issue, file diff, bug, or described change). Plans the work, splits it into reviewable waves, dispatches codex per wave with review and correction between waves before opening a PR. Not for multi-issue parallel batches (use codex-issue-waves) or one-shot codex runs without planning (use invoking-codex-exec).
---

# Codex task waves

Take a single in-scope task — "this" being the current Jira ticket, GitHub issue, bug, or described change — and produce one PR composed of one or more verified commits, each shaped by a written plan, a codex dispatch, and a review+correction round.

**REQUIRED SUB-SKILLS:**
- `invoking-codex-exec` — every wave's dispatch (flags, sandbox traps, monitoring)
- `superpowers:writing-plans` — the plan file that drives every wave
- `superpowers:requesting-code-review` — between every wave
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

1. **Dispatch** via `invoking-codex-exec`. The codex prompt must include:
   - The plan file path and an instruction to read it first.
   - The current wave's specific instructions and exit condition.
   - The verification commands for this wave (compile, format, the relevant test slice).
   - Boundary: "Do not touch surfaces from wave N+1" — name them.
   - The same single-task boundaries: don't commit, don't push, don't edit CHANGELOG, don't bypass hooks.
2. **Verify** — `git status` and `git diff` first (per `invoking-codex-exec` trust-but-verify). Run the wave's verification commands yourself if codex didn't, or if codex was killed mid-run.
3. **Review** — see "Review delegation" below. Default is an in-harness claude subagent via `superpowers:requesting-code-review` / `superpowers:code-reviewer`. Brief it with the plan file, the wave's exit condition, and the wave's diff (`git diff <last-wave-commit>..HEAD`). **Never use codex for review** — it's a wrong-tool match for read+reason work, and the sandbox traps in `invoking-codex-exec` apply. Categorize findings:
   - **Blocking** — must fix before next wave.
   - **Should-fix** — fix in this wave unless explicitly out of scope.
   - **Nit / follow-up** — annotate, defer to PR comment.
4. **Correction round**:
   - Small blockers (< ~5 files, < ~50 lines): fix in place yourself in the worktree. Faster than respawning codex.
   - Large blockers (multi-file rework, design change, rebase conflicts): respawn codex on the same worktree with a focused correction prompt naming exactly what to fix and what not to touch.
5. **Commit the wave** as a single commit. Conventional prefix matching the wave's nature (`fix:`, `feat:`, `refactor:`, `test:`). One commit per wave keeps the PR diff history reviewable.
6. **Re-run the full project verification** (not just this wave's slice) before moving to the next wave. A wave that breaks an upstream test fails fast here, before downstream waves pile on.

Move to the next wave only when the current wave is clean.

## Review delegation

Three review delegation targets exist. Pick by stakes, not by habit.

| Target | When | Cost | Notes |
|--------|------|------|-------|
| **In-harness claude subagent** (default) | Most waves | ~10–30k tokens, ~10–30s | Use `superpowers:requesting-code-review` / `superpowers:code-reviewer` agent type. Inherits skills + project rules; structured findings wire straight back to the main session. Brief it with diff + plan + exit condition only — don't paste the full conversation. |
| **Fresh `claude -p`** (escalation) | High-stakes waves: production-critical, security-sensitive, or when you suspect the *plan itself* may be wrong (clean-room second opinion) | ~30–80k tokens, ~30–60s | New process, no main-session bias, rediscovers skills/rules from disk. Symmetric mental model to dispatching codex but with no sandbox baggage. |
| **`codex exec`** | **Never for review.** | — | Codex's value is autonomous execution; review is read+reason. Same sandbox traps as `invoking-codex-exec` apply for zero benefit. |

### Fresh `claude -p` invocation

```bash
claude -p \
  --dangerously-skip-permissions \
  --add-dir <worktree> \
  --output-format json \
  --model opus \
  "$(cat <<'PROMPT'
You are reviewing wave <N> of the implementation plan at <worktree>/PLAN_<ID>.md.
Read the plan first. Then review this diff against the plan and the project's
CLAUDE.md / AGENTS.md rules:

git diff <last-wave-commit>..HEAD

Categorize findings as Blocking / Should-fix / Nit. Output JSON:
{ "blocking": [...], "should_fix": [...], "nits": [...] }

Don't suggest scope expansions. Don't run tests — assume they pass. Focus on
correctness, race conditions, missed cases, project-rule compliance, and parity
with the plan's exit condition.
PROMPT
)"
```

Use `--dangerously-skip-permissions` only inside an isolated worktree. The flag bypasses *all* permission checks for the spawned process — fine in a worktree under your control, dangerous elsewhere.

Don't use `ultrareview` here — it's user-triggered and billed; you can't launch it autonomously.

## Finalize

After the last wave:
- Stage the plan file's deletion (don't ship it).
- Run the full verification: format + compile + unitTest + integrationTest, or `pnpm tsc --noEmit && pnpm test`, etc.
- Push the branch.
- Open the PR. Body must include:
  - Link to the source ticket / issue.
  - One-paragraph root-cause summary.
  - Wave-by-wave summary: what each commit does, what was reviewed, what corrections happened.
  - PR template checklist if the repo has one.

## Red flags — STOP

| Symptom | Meaning | Fix |
|---------|---------|-----|
| Trying to plan and dispatch in the same turn | Skipped the wave-splitting decision | Stop, write plan first |
| Wave 1 dispatch already touches wave 2's surface | Boundaries wrong | Re-split or merge waves |
| No verify step between waves | Errors cascade silently | Always verify before next dispatch |
| Reviewer flags "scope change" | Wave boundary may be wrong | Cross-check plan; re-scope if needed |
| Codex commits across the boundary you set | Boundary not enforced in prompt | Respawn with explicit "don't touch X" |
| Considering a 5+-wave split | Over-decomposed | Combine until ≤ 3 unless each wave earns its review cycle |
| Considering `codex exec` for review | Wrong tool — codex is for autonomous exec, review is read+reason | Use `superpowers:requesting-code-review` (default) or fresh `claude -p` (escalation) per "Review delegation" |
| About to fan out review across many waves | Each wave's review is per-PR-single, not parallel — that's `codex-issue-waves` | Single-task waves run sequentially; reviews don't parallelize within one task |
| Single-wave task, but you wrote 100 lines of plan | Plan is over-engineered for the task | Trim plan, dispatch, move on |
| User said "just have codex fix it" but you start lecturing about waves | Single-wave answer was correct; just proceed | State "1 wave, here's why," then go |

## When this skill applies

- "Have codex fix this" / "have codex implement this" / "have codex handle this"
- "Let codex do this" / "let codex take this ticket"
- "Give this to codex" / "delegate this to codex"
- Any single-task delegation where the user expects a PR they will review

For multi-issue parallel waves see `codex-issue-waves`. For a one-shot codex dispatch with no plan and no wave structure see `invoking-codex-exec` directly.
