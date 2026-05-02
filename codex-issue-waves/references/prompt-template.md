# Codex Exec Prompt Template

The single most leveraged artifact in this workflow. The whole point of running codex autonomously is that it actually ships a PR without a babysitter — which only happens if the prompt is focused, self-contained, and explicit about non-negotiables.

## Canonical shape (dispatch prompt)

Every dispatch prompt should follow this skeleton. Inline everything codex needs; do not rely on it reading chat context.

```
You are an autonomous engineering agent working inside a git worktree on branch `<branch>`. The task is to fully implement GitHub issue **<org>/<repo>#<N>** and open a pull request.

## Project rules (read first)

Read these before writing any code:
- <absolute/path/to/repo/CLAUDE.md>
- <absolute/path/to/worktree/CLAUDE.md>

[Inline the two or three rules that matter most for this task, verbatim:]
- Never mention Claude, Codex, or any AI tool in code or commit messages.
- Use conventional commit prefixes (`feat:`, `fix:`, `refactor:`, ...).
- <e.g. "ADR required for structural DB changes in docs/adr/NNN-*.md">
- <e.g. "inline migrations via PRAGMA table_info in db.ts">
- Run `npm test` per workspace before committing. All must pass.

## Issue #<N> specification

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

Numbered, concrete, starting with `cd` into the worktree and reading CLAUDE.md. Include:
1. cd + CLAUDE.md read
2. Exploration of the specific files that will change (give absolute paths or `packages/.../file.ts` references so codex doesn't grep aimlessly)
3. Concrete implementation steps in the order they should be done
4. Tests — both new tests to write and existing suites to run
5. Commit (conventional, no --no-verify)
6. Push (`git push -u origin <branch>`, or `--force-with-lease` for rebased branches)
7. Open PR via `gh pr create --title "..." --body "..."`. Spell out the title explicitly; for the body, say what must be in it (closes #<N>, summary, test plan).
8. Return the PR URL

## Non-negotiables

- All tests must pass locally before commit.
- No `--no-verify` on git commits.
- No references to AI tools in code or messages.
- If something is ambiguous, make a reasonable decision and note it in the PR description; do not block.
- Return the PR URL when done.
```

## Rules that make prompts work

- **Inline, don't link.** Codex reads what you give it. If you write `see issue #143 for details`, it will either do an extra tool call or just guess. Paste the issue body.
- **Absolute paths for project-level rules.** `/Users/name/code/project/CLAUDE.md` is unambiguous; `CLAUDE.md` is ambiguous across worktrees.
- **Concrete file pointers.** Instead of "update the repository", write "update `packages/core/src/repositories/sqlite/adapters/X.repository.ts`".
- **Explicit scope fences.** "Do NOT touch Y — that is step #N's scope, not this PR." Codex is eager to clean up adjacent code; fence it.
- **The `## Scope` block is the canonical scope fence.** All three sub-headings (`In scope`, `Out of scope`, `Open questions`) must be present and non-empty (use `none` when truly empty). `Open questions` documents decisions the orchestrator already resolved — codex must not revisit them. If a question is genuinely open at dispatch time, the orchestrator resolves it before dispatch; codex never sees an unresolved question.
- **No hedging.** Write "switch to `INSERT ... ON CONFLICT DO UPDATE`". Don't write "consider using upsert semantics". Codex does exactly what you say.
- **Return the PR URL.** State this as a non-negotiable so codex definitely surfaces it at the end.
- **Don't babysit test commands.** Say "run `npm test` per workspace, all green." Don't list every command; codex knows `npm test`.

## Correction prompt shape

When respawning codex to address review feedback, the prompt looks similar but starts differently:

```
You are an autonomous engineering agent picking up an existing PR that needs to be reworked. The PR is <org>/<repo>#<N> on branch `<branch>`. Worktree is at `<absolute path>`. The branch may be behind `main` — rebase first.

## What the PR does today

[One paragraph summary so codex can orient without reading the whole diff.]

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

### 1. Rebase on origin/main
`git fetch origin && git rebase origin/main`. Resolve conflicts cleanly in <list of expected files>.

### 2. <concrete fix #1>
<exact changes required, including file paths, old and new names, API shapes>

### 3. <concrete fix #2>
...

### 4. Run tests + push + update PR

- `npm test` per workspace.
- `git push --force-with-lease` (because you rebased).
- Update the PR description via `gh pr edit <N> --body-file -` or temp-file to reflect the rework.
- Post a reply comment via `gh pr comment <N>` summarizing what you changed so the reviewer doesn't have to re-read the whole diff.

## Non-negotiables

[Same as dispatch prompt, plus any rework-specific rules.]
```

## Do not do

- Don't tell codex to "be creative" or "make tradeoffs as you see fit" — it then invents scope. If a tradeoff has a right answer, say which one.
- Don't let codex pick the commit message — give it the conventional-commits prefix and a one-line description.
- Don't forget to say "rebase first" on correction prompts — codex happily stacks fix commits on a stale branch otherwise.
- Don't include environment-specific hacks in the prompt (e.g. "if npm install fails, try yarn"). Let codex hit and report the real error.
- Don't mix two issues into a single dispatch prompt unless you have explicitly combined them on one branch; otherwise codex does half of each.
