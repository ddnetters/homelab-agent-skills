# Codex delegation flow

Single chart showing how `invoking-codex-exec`, `codex-task-waves`, and `codex-issue-waves` relate. Pick the entry by task shape; the lower skills layer on the primitive.

```mermaid
flowchart TD
    Start([User asks to delegate to codex]) --> Shape{Task shape?}

    Shape -->|"1 issue, no plan needed<br/>(one-shot dispatch)"| Exec
    Shape -->|"1 task, needs plan<br/>+ review checkpoints"| Task
    Shape -->|"≥2 issues<br/>parallel batch"| Issue

    %% ── invoking-codex-exec (primitive) ──
    subgraph Exec["invoking-codex-exec — primitive"]
        direction TB
        E1[Set required flags:<br/>--dangerously-bypass-approvals-and-sandbox<br/>-C worktree --skip-git-repo-check] --> E2[Launch codex in background<br/>capture PID + log file]
        E2 --> E3[Wait by PID, not log regex]
        E3 --> E4{Sandbox spiral<br/>detected?}
        E4 -->|yes| E5[KILL → relaunch with bypass flag]
        E5 --> E2
        E4 -->|no| E6[git status + git diff<br/>trust-but-verify]
        E6 --> E7([Done / handoff])
    end

    %% ── codex-task-waves ──
    subgraph Task["codex-task-waves — single task, planned"]
        direction TB
        T1[Identify 'this'] --> T2[Write PLAN_TICKET.md<br/>in worktree]
        T2 --> T3{Wave count?<br/>1 / 2 / 3 / 4+}
        T3 --> T4[State count + rationale<br/>to user]
        T4 --> T5[Wave loop start]
        T5 --> T6[Dispatch wave via<br/>invoking-codex-exec]
        T6 --> T7[Verify diff +<br/>run wave verification]
        T7 --> T8[Review:<br/>claude subagent default<br/>fresh claude -p escalation<br/>NEVER codex]
        T8 --> T9{Findings?}
        T9 -->|blocking small| T10[Fix in place]
        T9 -->|blocking large| T11[Respawn codex<br/>focused correction prompt]
        T9 -->|none / nits| T12[Commit wave<br/>conventional prefix]
        T10 --> T12
        T11 --> T7
        T12 --> T13[Full project verification]
        T13 --> T14{More waves?}
        T14 -->|yes| T5
        T14 -->|no| T15[Strip plan file<br/>push + open PR<br/>wave-by-wave summary]
    end

    %% ── codex-issue-waves ──
    subgraph Issue["codex-issue-waves — multi-issue parallel"]
        direction TB
        I1[Pre-dispatch:<br/>conflict triage between issues] --> I2{Conflicts?}
        I2 -->|yes| I3[Combine / sequence /<br/>skip umbrella issues]
        I2 -->|no| I4[Per-issue worktree<br/>.worktrees/issue-N-slug]
        I3 --> I4
        I4 --> I5[Fetch issue body<br/>write focused prompt]
        I5 --> I6[Launch all codex runs<br/>in parallel via invoking-codex-exec]
        I6 --> I7[Schedule single<br/>aggregated wakeup]
        I7 --> I8[Monitor: PR URL +<br/>gh pr view CI status]
        I8 --> I9[Review wave:<br/>parallel claude subagents<br/>one per PR]
        I9 --> I10[Spot-checks:<br/>git log/diff/grep<br/>conflict markers/TODO/AI refs]
        I10 --> I11{Blockers?}
        I11 -->|small| I12[Fix in worktree<br/>force-with-lease push]
        I11 -->|large| I13[Respawn codex<br/>correction prompt]
        I12 --> I14[Wait for CI via<br/>scripts/wait_for_ci.sh]
        I13 --> I14
        I11 -->|none| I14
        I14 --> I15[Decide merge order<br/>conflict-aware]
        I15 --> I16[scripts/merge_and_cleanup.sh<br/>squash → rm worktree → del branch]
    end

    %% Layering: task-waves and issue-waves call back into invoking-codex-exec
    T6 -.uses.-> Exec
    T11 -.uses.-> Exec
    I6 -.uses.-> Exec
    I13 -.uses.-> Exec

    E7 --> Done([Task delegated])
    T15 --> Done
    I16 --> Done

    classDef primitive fill:#1f3a5f,stroke:#4a90e2,color:#fff
    classDef single fill:#2d5016,stroke:#7cb342,color:#fff
    classDef multi fill:#5d2f8f,stroke:#ab47bc,color:#fff
    class Exec primitive
    class Task single
    class Issue multi
```

## Reading the chart

- **Entry decision** is `Task shape?` — pick exactly one path.
- **Dotted arrows** = layering. `codex-task-waves` and `codex-issue-waves` both *call* `invoking-codex-exec` for the actual codex launch; they don't reimplement flag handling or PID waits.
- **Reviewer is never codex.** All three paths use claude (in-harness subagent default, fresh `claude -p` for high-stakes). Codex = autonomous execution. Review = read+reason.
- **Worktree isolation** is universal. All three skills run codex pinned to a worktree via `-C <worktree>`.
- **Trust-but-verify** is universal. Always `git status` + `git diff` before declaring success or killing a stuck run.

## Skill picker — quick

| Trigger | Skill |
|---------|-------|
| "Run codex on this" / one-shot | `invoking-codex-exec` |
| "Have codex fix this ticket" / planned single task | `codex-task-waves` |
| "Spawn codex on issues #A #B #C" / parallel batch | `codex-issue-waves` |
