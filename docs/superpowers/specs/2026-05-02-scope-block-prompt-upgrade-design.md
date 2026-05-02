# Scope-block prompt upgrade

**Date:** 2026-05-02
**Status:** Design approved, ready for implementation plan
**Affects:** `invoking-codex-exec`, `codex-task-waves`, `codex-issue-waves`

## Problem

Across the three codex delegation skills, the dispatch prompt fed to `codex exec` has no first-class section for the orchestrator's *scope interpretation*. The issue body / ticket fills the spec slot. The orchestrator's read on what is in vs. out of scope — and what decisions it has already made — lives only in the orchestrator's head and leaks into the prompt as ad-hoc fences.

This is preventive, not reactive: no concrete drift incident has been observed yet. The bet is that a small upgrade to existing prompt shape catches the drift modes that real teams document via scoping practice (added features, adjacent edits, unsanctioned design decisions) before they show up.

## Non-goals

- No new skill, no new agent role, no new orchestration step.
- No automated diff-vs-scope verification script.
- No "Stop conditions" axis for ambiguous tickets — promote later if ambiguous-ticket drift becomes a real failure mode.
- No change to `CODEX_WAVES.md` flowchart shapes.

## Approach

**Approach 2 from brainstorm:** prompt-shape upgrade across all three skills, paired with a one-line reviewer cue that gives the new section enforcement teeth via the existing reviewer wave.

Asymmetric bet: ~25 minutes of doc edits, zero new tooling, immediate enforcement via mechanism that already exists.

## The Scope block

Mandatory three-heading section in every codex dispatch prompt, sitting between the issue specification and the execution steps (so the reader sees the spec first, then the orchestrator's interpretation, before execution):

```markdown
## Scope

### In scope
- <thing 1 the orchestrator deliberately authorized — file/feature/decision>
- <thing 2>

### Out of scope
- <adjacent thing codex might be tempted to touch — name it>
- <refactor codex might suggest — pre-emptively rule it out>

### Open questions
- <decision orchestrator made and codex must NOT revisit, format: "Q: ... → resolved: <pick>, because <reason>">
- (or `none`)
```

### Rules

- All three headings required even when short. Write `none` rather than omitting — explicit beats implicit.
- `Open questions` at dispatch time documents **resolved** decisions, not unresolved ones. The orchestrator resolves any genuinely-open question before dispatch (asks user, reads code, picks one). Codex never sees an unresolved question.
- Section title is `Scope`, not `Spec`. The issue body is the spec; this section is the orchestrator's interpretation.
- `Out of scope` items must be **named adjacent things** ("don't touch `AuthContext`"), not vague rules ("stay focused"). Codex obeys specific fences far better than vague ones.

### Example (illustrative, "fix login redirect bug")

```markdown
## Scope

### In scope
- Fix the redirect logic in `src/auth/redirect.ts:handleLoginSuccess`
- Add a regression test in `src/auth/__tests__/redirect.test.ts`

### Out of scope
- The TODO in `redirect.ts` about consolidating with logout flow — separate ticket
- Refactoring the `AuthContext` provider — not part of this fix
- Updating the auth library version — out of scope even if a newer version would fix this differently

### Open questions
- Q: should the redirect respect query-param `next` or always go to `/dashboard`? → resolved: respect `next` if present and same-origin, else `/dashboard`. Matches existing pattern in `logout.ts`.
```

## Reviewer cue

One line added to the reviewer brief in `codex-issue-waves` "Review wave" and `codex-task-waves` per-wave review:

> Verify the diff stays within the dispatch prompt's `## Scope` block. Files or behaviors outside `In scope` (or explicitly listed `Out of scope`) are scope-creep — flag as **Blocking**. Decisions that contradict resolved `Open questions` are also Blocking.

This gives the new section enforcement teeth through the existing reviewer wave. No new agent, no new tool — just one extra item in the brief the reviewer is already given.

## File-by-file rollout

Implementation order is primitive-up so the foundation lands first.

1. **`invoking-codex-exec/SKILL.md`** — Add `Scope (in scope / out of scope / open questions)` to "Prompt shape" recommended-items bullet list. Mention that wave skills require it; one-shot users are encouraged.
2. **`codex-issue-waves/references/prompt-template.md`** — Add `## Scope` section to the canonical dispatch skeleton, positioned **between "Issue specification" and "Execution steps"** (so the reader sees the spec first, then the orchestrator's interpretation, before execution). Add the same section to the correction prompt skeleton in the equivalent position (between "Why it needs rework" and "What you need to do").
3. **`codex-task-waves/SKILL.md`** — Add scope-block requirement to "Per-wave loop" step 1 (Dispatch). Add reviewer-cue line to step 3 (Review). Note that the plan file's spec section feeds the per-wave Scope blocks but doesn't replace them — each wave gets its own.
4. **`codex-issue-waves/SKILL.md`** — Append reviewer-cue line to "Review wave" → step 3 → reviewer brief items list.

## Carriers per skill

The same artifact lives in different carriers because each skill's existing structure differs:

| Skill | Carrier | Why |
|-------|---------|-----|
| `invoking-codex-exec` | "Prompt shape" recommendation in SKILL.md | No template — primitive consumers compose their own prompts |
| `codex-task-waves` | Inline requirement in SKILL.md per-wave loop | Prompts are written ad-hoc per wave, not from a template |
| `codex-issue-waves` | First-class section in `references/prompt-template.md` | Prompts are reusable and produced from the template |

Reviewer-cue lines live in SKILL.md (not prompt template) in both wave skills because the reviewer is dispatched by the orchestrator (claude), not codex — the instruction belongs in the orchestrator-facing skill text.

## Success criteria

- Every codex dispatch prompt produced by an orchestrator following any of the three skills includes a `## Scope` block with all three headings.
- Reviewers (claude subagent or fresh `claude -p`) explicitly check diffs against the dispatch prompt's Scope block and flag scope-creep as Blocking.
- No new scripts, agents, or workflow steps introduced.
- `CODEX_WAVES.md` flowchart unchanged.

## Out of scope for this design

- Stop-conditions / halt-and-ask axis (would be heading #4) — promote only if ambiguous-ticket drift becomes a real failure mode.
- Automated `git diff --name-only` vs scope verifier script — reviewer agent already does this in one breath.
- Per-role artifact convention (`.codex-roles/<role>.md`) — separate brainstorm, separate spec.
- Security advisor pre-pickup gate — separate brainstorm, separate spec.
- Feature-branch / epic workflow for ≥3 related tickets — separate brainstorm, separate spec.
