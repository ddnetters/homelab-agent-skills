---
name: invoking-codex-exec
description: Use when delegating a single coding task to `codex exec` ("hand off to codex", "run codex on this", "dispatch codex on this ticket", any one-shot invocation). Covers flags, sandbox traps, monitoring, and recovery. Not for multi-issue parallel batches — use codex-issue-waves for those.
---

# Invoking codex exec

Delegate a self-contained coding task to `codex exec` while you keep working in the main conversation. The codex subprocess edits files, runs builds, and reports back. You stay in command of the rest of the session.

## Required flags

```bash
codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  -C <worktree> \
  --skip-git-repo-check \
  "<prompt>"
```

- `--dangerously-bypass-approvals-and-sandbox`: required whenever codex needs to run gradle, maven, docker, npm scripts that bind sockets, or anything that touches privileged OS resources. The default `--full-auto` sandbox is `workspace-write`, which silently blocks daemon socket binding. Codex will spiral trying to bypass it instead of failing fast.
- `-C <worktree>`: pin codex to the working tree. Required for worktree-isolated work.
- `--skip-git-repo-check`: codex otherwise refuses to run in a worktree it considers ambiguous.

**Don't use `--full-auto`** for any task that runs builds or tests. The flag name is misleading — the sandbox actively breaks gradle/maven/docker. Pure source-editing tasks are the only safe `--full-auto` use case, and even then the bypass flag is fine.

## Sandbox-bypass spiral — KILL ON SIGHT

If codex starts doing any of these, you launched with the wrong flag. Kill the run, restart with `--dangerously-bypass-approvals-and-sandbox`:

- Writing into `/tmp/gradle-patch/`, `/tmp/gradle-home/`, `/tmp/maven-*`, `/tmp/docker-*`
- Recompiling daemon/launcher classes: `BuildActionsFactory`, `DefaultFileLockCommunicator`, similar
- `Expecting a stack map frame` JVM verifier errors
- Patching jars with `jar uf` / `jar xf`
- Re-pointing `GRADLE_USER_HOME`, `MAVEN_OPTS`, `DOCKER_HOST` to `/tmp` paths
- Iterating on `--no-daemon` / `--offline` workarounds for >2 minutes
- Recompiling toolchain-internal classes from decompiled bytecode

The cost of letting it run is real: in one observed case, ~8 minutes wall clock and tens of thousands of tokens trying to recompile gradle's CLI to bypass its daemon. Restart is faster than waiting it out.

For early detection, run `scripts/detect_sandbox_spiral.sh <logfile>` against the codex log. In follow mode it tails the log and emits one line per spiral signature — wire it through the Monitor tool so the harness surfaces a notification the moment the spiral starts (typically minute 1–2, well before the jar-patching phase). `--once <logfile>` does a one-shot scan and exits non-zero if any signature is present (use this in scripts or after-the-fact triage).

## Monitoring — wait by PID, not by log

Launch in background, redirect output, capture the PID:

```bash
codex exec --dangerously-bypass-approvals-and-sandbox -C <worktree> --skip-git-repo-check "..." > /tmp/codex-<id>.log 2>&1 &
CODEX_PID=$!
```

Wait by process exit:

```bash
until ! kill -0 $CODEX_PID 2>/dev/null; do sleep 30; done
```

Or use the harness's background-task mechanism (Bash with `run_in_background`, ScheduleWakeup, or Monitor). For long runs (>5 min) prefer ScheduleWakeup with a 10–30 min delay over busy-polling.

**Don't grep the log for "completion markers".** Codex emits bare-line section headers (`codex`, `exec`, `thinking`) interleaved with output. A regex like `^codex$` matches the section header and reports completion mid-run. The PID is authoritative; the log is for diagnosis only.

## Before killing a stuck run — check the diff

When you decide a codex run is wedged, do this in the worktree before killing:

```bash
git status --short
git diff
```

Codex commits or stages edits as it works. The actual code change may already be correct even when codex is stuck in an unrelated dead-end (sandbox-bypass spiral, looping test rerun, retry storm on a network call). If the diff matches the plan, kill codex and finish the verification yourself — don't relaunch from scratch.

This trust-but-verify check costs ~5 seconds and routinely saves a full re-run.

## Prompt shape

One prompt block, no nested instructions. Include:

- Path to a plan file (if one exists) and an instruction to read it first.
- A `## Scope` block with three required headings: `In scope`, `Out of scope`, `Open questions` (each with at least one bullet, or `none`). The wave skills (`codex-task-waves`, `codex-issue-waves`) require this; one-shot dispatches are strongly encouraged. See those skills for the canonical shape and rules.
- Concrete verification commands to run from the worktree root (`./gradlew formatKotlin && ./gradlew compileKotlin && ./gradlew test`, `pnpm tsc --noEmit && pnpm test`, etc.).
- Explicit boundaries: don't commit, don't push, don't edit CHANGELOG, don't bypass hooks.
- Reference to project rules: `CLAUDE.md`, `AGENTS.md`.

Brief codex like a smart engineer with zero session context. No "as we discussed" or "the file you saw earlier."

## Red flags — STOP and fix the launch

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Codex creates `/tmp/gradle-patch/` | Wrong sandbox flag | Kill, relaunch with `--dangerously-bypass-approvals-and-sandbox` |
| Codex log says `Expecting a stack map frame` | Sandbox-bypass spiral | Same |
| Wait loop exits but codex still running | Regex matched a section header | Wait by PID instead |
| Killed codex, planning to relaunch | Probably forgot to check diff | `git status` first |
| Used `--full-auto` for a build task | Default sandbox blocks daemons | Use bypass flag |
| Codex prompt references "the plan we agreed on" | Missing context — codex has none | Inline the plan or pass a path |

## When this skill applies

- "Hand this off to codex" / "run codex on this"
- "Dispatch codex on ticket X"
- One-shot delegation of an implementation plan that already exists
- Single-issue codex run, including inside a worktree

For wave-structured single-task delegation (plan → split → review per wave) see `codex-task-waves`. For multi-issue parallel waves see `codex-issue-waves`. Both build on this skill.
