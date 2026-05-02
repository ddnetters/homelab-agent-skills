# Scope-block prompt upgrade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a mandatory `## Scope` block (In scope / Out of scope / Open questions) to every codex dispatch prompt across the three codex skills, paired with a one-line reviewer cue that gives it enforcement teeth via the existing review wave.

**Architecture:** Doc-only edits. No new files, no new scripts, no new agents. Same artifact (Scope block) lives in different carriers per skill: a recommendation in `invoking-codex-exec/SKILL.md`, a first-class section in `codex-issue-waves/references/prompt-template.md`, and an inline requirement in `codex-task-waves/SKILL.md`. Reviewer cues live in SKILL.md (orchestrator-facing) for both wave skills.

**Tech Stack:** Markdown only.

**Spec:** `docs/superpowers/specs/2026-05-02-scope-block-prompt-upgrade-design.md`

---

## File map

- Modify: `invoking-codex-exec/SKILL.md` (Prompt shape recommendation)
- Modify: `codex-issue-waves/references/prompt-template.md` (dispatch + correction skeletons)
- Modify: `codex-task-waves/SKILL.md` (per-wave dispatch requirement + reviewer cue)
- Modify: `codex-issue-waves/SKILL.md` (Review wave reviewer cue)

Order is primitive-up: 1 (`invoking-codex-exec`) → 2 (`codex-issue-waves` template) → 3 (`codex-task-waves`) → 4 (`codex-issue-waves` SKILL).

`CODEX_WAVES.md` is **not** modified — flowchart shapes survive.

---

## Task 1: Add Scope to invoking-codex-exec "Prompt shape"

**Files:**
- Modify: `invoking-codex-exec/SKILL.md`

- [ ] **Step 1: Read current "Prompt shape" section**

Run: `grep -n "## Prompt shape" invoking-codex-exec/SKILL.md`
Expected: One match around line 75. Open the file and read the section to confirm exact bullet list.

- [ ] **Step 2: Insert Scope bullet between "plan file" bullet and "verification commands" bullet**

Edit `invoking-codex-exec/SKILL.md`. Locate the bullet list under `## Prompt shape`. Replace this exact text:

```
- Path to a plan file (if one exists) and an instruction to read it first.
- Concrete verification commands to run from the worktree root (`./gradlew formatKotlin && ./gradlew compileKotlin && ./gradlew test`, `pnpm tsc --noEmit && pnpm test`, etc.).
```

with:

```
- Path to a plan file (if one exists) and an instruction to read it first.
- A `## Scope` block with three required headings: `In scope`, `Out of scope`, `Open questions` (each with at least one bullet, or `none`). The wave skills (`codex-task-waves`, `codex-issue-waves`) require this; one-shot dispatches are strongly encouraged. See those skills for the canonical shape and rules.
- Concrete verification commands to run from the worktree root (`./gradlew formatKotlin && ./gradlew compileKotlin && ./gradlew test`, `pnpm tsc --noEmit && pnpm test`, etc.).
```

- [ ] **Step 3: Verify the insertion**

Run: `grep -n "Scope.*block with three required headings" invoking-codex-exec/SKILL.md`
Expected: One match in the "Prompt shape" section.

Run: `grep -c "^- " invoking-codex-exec/SKILL.md`
Expected: Bullet count grew by exactly 1 vs. before (was 4 bullets in Prompt shape, now 5).

- [ ] **Step 4: Commit**

```bash
git add invoking-codex-exec/SKILL.md
git commit -m "Recommend Scope block in invoking-codex-exec Prompt shape"
```

---

## Task 2: Add Scope section to codex-issue-waves prompt template (dispatch + correction)

**Files:**
- Modify: `codex-issue-waves/references/prompt-template.md`

- [ ] **Step 1: Read both template skeletons**

Run: `grep -n "^## " codex-issue-waves/references/prompt-template.md`
Expected: Section list including `## Canonical shape (dispatch prompt)`, `## Correction prompt shape`, `## Do not do`. Open file and locate the dispatch skeleton's `## Issue #<N> specification` and `## Execution steps` markers, plus the correction skeleton's `## Why it needs rework` and `## What you need to do` markers.

- [ ] **Step 2: Insert `## Scope` into the dispatch skeleton**

In the dispatch skeleton's fenced code block, locate the segment between the issue spec and the execution steps:

```
[Paste the full issue body here. Do not truncate. Do not link to the issue — inline it. Codex should not need to run `gh issue view`.]

## Execution steps
```

Replace with:

```
[Paste the full issue body here. Do not truncate. Do not link to the issue — inline it. Codex should not need to run `gh issue view`.]

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

## Execution steps
```

- [ ] **Step 3: Insert `## Scope` into the correction skeleton**

In the correction skeleton's fenced code block, locate the segment between the rework reason and the action list:

```
## Why it needs rework

[State the blocker from the review. Be specific — include the file and line where possible.]

## What you need to do
```

Replace with:

```
## Why it needs rework

[State the blocker from the review. Be specific — include the file and line where possible.]

## Scope

### In scope
- <fix items required by the review>
- <files the rework is allowed to touch>

### Out of scope
- <files / behaviors the original PR touched that the rework must NOT modify>
- <refactors the reviewer did not ask for>

### Open questions
- <reviewer decisions documented as resolved, format: "Q: ... → resolved: <pick>, because <reason>">
- (or `none`)

## What you need to do
```

- [ ] **Step 4: Add a "Rules" cross-reference under "Rules that make prompts work"**

Locate the bullet list under `## Rules that make prompts work`. After the existing bullet beginning with `- **Explicit scope fences.**`, insert this new bullet on a new line directly below:

```
- **The `## Scope` block is the canonical scope fence.** All three sub-headings (`In scope`, `Out of scope`, `Open questions`) must be present and non-empty (use `none` when truly empty). `Open questions` documents decisions the orchestrator already resolved — codex must not revisit them. If a question is genuinely open at dispatch time, the orchestrator resolves it before dispatch; codex never sees an unresolved question.
```

- [ ] **Step 5: Verify the insertions**

Run: `grep -c "^### In scope$" codex-issue-waves/references/prompt-template.md`
Expected: `2` (one in dispatch skeleton, one in correction skeleton).

Run: `grep -c "^### Out of scope$" codex-issue-waves/references/prompt-template.md`
Expected: `2`.

Run: `grep -c "^### Open questions$" codex-issue-waves/references/prompt-template.md`
Expected: `2`.

Run: `grep -n "canonical scope fence" codex-issue-waves/references/prompt-template.md`
Expected: One match in the "Rules that make prompts work" section.

- [ ] **Step 6: Commit**

```bash
git add codex-issue-waves/references/prompt-template.md
git commit -m "Add Scope section to codex-issue-waves dispatch and correction templates"
```

---

## Task 3: Add Scope requirement and reviewer cue to codex-task-waves

**Files:**
- Modify: `codex-task-waves/SKILL.md`

- [ ] **Step 1: Read the per-wave loop section**

Run: `grep -n "## Per-wave loop" codex-task-waves/SKILL.md`
Expected: One match. Read the full section to locate step 1 (Dispatch) and step 3 (Review).

- [ ] **Step 2: Add Scope-block requirement to step 1 (Dispatch)**

Locate the bullet list under step 1 of the per-wave loop:

```
1. **Dispatch** via `invoking-codex-exec`. The codex prompt must include:
   - The plan file path and an instruction to read it first.
   - The current wave's specific instructions and exit condition.
   - The verification commands for this wave (compile, format, the relevant test slice).
   - Boundary: "Do not touch surfaces from wave N+1" — name them.
   - The same single-task boundaries: don't commit, don't push, don't edit CHANGELOG, don't bypass hooks.
```

Replace with:

```
1. **Dispatch** via `invoking-codex-exec`. The codex prompt must include:
   - The plan file path and an instruction to read it first.
   - The current wave's specific instructions and exit condition.
   - A `## Scope` block with three required headings (`In scope`, `Out of scope`, `Open questions`). The plan file's spec section feeds the per-wave Scope blocks but does not replace them — each wave gets its own block tuned to that wave's surface. `Open questions` documents resolved decisions, not unresolved ones; resolve any genuinely-open question before dispatch.
   - The verification commands for this wave (compile, format, the relevant test slice).
   - Boundary: "Do not touch surfaces from wave N+1" — name them.
   - The same single-task boundaries: don't commit, don't push, don't edit CHANGELOG, don't bypass hooks.
```

- [ ] **Step 3: Add reviewer cue to step 3 (Review)**

Locate step 3 of the per-wave loop (the paragraph beginning `3. **Review** — see "Review delegation" below.`). Find the categorize-findings bullet list at the end of that step:

```
   - **Blocking** — must fix before next wave.
   - **Should-fix** — fix in this wave unless explicitly out of scope.
   - **Nit / follow-up** — annotate, defer to PR comment.
```

Insert a new instruction sentence immediately *before* that bullet list. The current text reads:

```
**Never use codex for review** — it's a wrong-tool match for read+reason work, and the sandbox traps in `invoking-codex-exec` apply. Categorize findings:
   - **Blocking** — must fix before next wave.
```

Replace with:

```
**Never use codex for review** — it's a wrong-tool match for read+reason work, and the sandbox traps in `invoking-codex-exec` apply. Brief the reviewer to verify the diff stays within the dispatch prompt's `## Scope` block — files or behaviors outside `In scope` (or explicitly listed `Out of scope`) are scope-creep, flag as Blocking; decisions that contradict resolved `Open questions` are also Blocking. Categorize findings:
   - **Blocking** — must fix before next wave.
```

- [ ] **Step 4: Verify the insertions**

Run: `grep -n "Scope.*block with three required headings" codex-task-waves/SKILL.md`
Expected: One match in step 1.

Run: `grep -n "verify the diff stays within the dispatch prompt" codex-task-waves/SKILL.md`
Expected: One match in step 3.

- [ ] **Step 5: Commit**

```bash
git add codex-task-waves/SKILL.md
git commit -m "Require Scope block per wave and brief reviewer to enforce it"
```

---

## Task 4: Add reviewer cue to codex-issue-waves Review wave

**Files:**
- Modify: `codex-issue-waves/SKILL.md`

- [ ] **Step 1: Read the Review wave section**

Run: `grep -n "## Review wave" codex-issue-waves/SKILL.md`
Expected: One match. Read the full section to locate step 3 (Independent code review) and the "the reviewer should look at:" bullet list at the end of step 3.

- [ ] **Step 2: Append reviewer cue to the "look at" list**

Locate the bullet list at the end of step 3:

```
   Whichever target is used, the reviewer should look at:
   - Rebase integrity (nothing lost from concurrent merges to main)
   - Correctness of renames / retargets
   - Race conditions in new DB writes (the select-then-insert antipattern is common — prefer `INSERT ... ON CONFLICT DO UPDATE` for upserts)
   - Redundant migration blocks (codex tends to duplicate bootstrap + migration for the same table)
   - UI parity across sibling pages (if the feature lives in both a list and a detail view, check both)
   - Test gaps (UNIQUE constraints, auth paths, toggle-off-then-on flows)
   - Project-rule compliance (no AI references, conventional commits, no skipped hooks)
```

Replace with:

```
   Whichever target is used, the reviewer should look at:
   - Scope adherence: the diff stays within the dispatch prompt's `## Scope` block — files or behaviors outside `In scope` (or explicitly listed `Out of scope`) are scope-creep, flag as Blocking; decisions that contradict resolved `Open questions` are also Blocking
   - Rebase integrity (nothing lost from concurrent merges to main)
   - Correctness of renames / retargets
   - Race conditions in new DB writes (the select-then-insert antipattern is common — prefer `INSERT ... ON CONFLICT DO UPDATE` for upserts)
   - Redundant migration blocks (codex tends to duplicate bootstrap + migration for the same table)
   - UI parity across sibling pages (if the feature lives in both a list and a detail view, check both)
   - Test gaps (UNIQUE constraints, auth paths, toggle-off-then-on flows)
   - Project-rule compliance (no AI references, conventional commits, no skipped hooks)
```

(Scope adherence goes first — it's the most leveraged check and frames the rest.)

- [ ] **Step 3: Verify the insertion**

Run: `grep -n "Scope adherence" codex-issue-waves/SKILL.md`
Expected: One match in the Review wave reviewer-brief list.

- [ ] **Step 4: Commit**

```bash
git add codex-issue-waves/SKILL.md
git commit -m "Brief codex-issue-waves reviewers to enforce Scope block"
```

---

## Task 5: Cross-skill verification

**Files:** none modified.

- [ ] **Step 1: Verify all four skill files reference the Scope block**

Run:
```bash
grep -l "## Scope" invoking-codex-exec/SKILL.md \
  codex-issue-waves/references/prompt-template.md \
  codex-task-waves/SKILL.md \
  codex-issue-waves/SKILL.md
```

Expected: All four paths returned.

- [ ] **Step 2: Verify the three required headings appear in both prompt-template skeletons**

Run:
```bash
grep -c "^### In scope$" codex-issue-waves/references/prompt-template.md
grep -c "^### Out of scope$" codex-issue-waves/references/prompt-template.md
grep -c "^### Open questions$" codex-issue-waves/references/prompt-template.md
```

Expected: Each command outputs `2` (one occurrence in dispatch skeleton, one in correction skeleton).

- [ ] **Step 3: Verify reviewer cue is present in both wave skills**

Run:
```bash
grep -n "Scope" codex-task-waves/SKILL.md | grep -i "reviewer\|verify the diff"
grep -n "Scope adherence" codex-issue-waves/SKILL.md
```

Expected: At least one hit in `codex-task-waves/SKILL.md` (step 3 reviewer brief) and one hit in `codex-issue-waves/SKILL.md` (Review wave bullet list).

- [ ] **Step 4: Confirm CODEX_WAVES.md flowchart unchanged**

Run: `git diff main -- CODEX_WAVES.md`
Expected: No output (file untouched on this branch).

- [ ] **Step 5: Eyeball — re-read each modified file's affected section**

For each of the four modified files, open it and re-read the changed section in full. Check:
- Heading hierarchy still consistent.
- No accidental whitespace mangling around the inserted blocks.
- The example fences (`<thing 1>`, `<thing 2>`) read sensibly to a fresh reader.

This step is a `Read` per file, not a command — you are validating prose quality, not just syntax.

- [ ] **Step 6: Final commit (if step 5 turned up small fixes)**

If step 5 surfaced cosmetic fixes (whitespace, heading levels), apply them and commit:

```bash
git add invoking-codex-exec/SKILL.md \
  codex-issue-waves/references/prompt-template.md \
  codex-task-waves/SKILL.md \
  codex-issue-waves/SKILL.md
git commit -m "Polish Scope block prose after eyeball review"
```

If step 5 was clean, skip this step.
