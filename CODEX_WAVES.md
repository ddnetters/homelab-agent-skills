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
        T1[Identify 'this'] --> T2[Write PLAN_TICKET.md<br/>claude is PO]
        T2 --> T3{Wave count?<br/>1 / 2 / 3 / 4+}
        T3 --> T4[State count + rationale<br/>to user]
        T4 --> T5[Wave loop start]
        T5 --> T6[Dispatch implementer codex<br/>via invoking-codex-exec]
        T6 --> T7[Status check:<br/>git status + git log<br/>NOT review]
        T7 --> T8[Dispatch reviewer codex<br/>read-only, JSON output]
        T8 --> T8a[Verify read-only boundary<br/>+ JSON parses]
        T8a --> T9{Review verdict?}
        T9 -->|approved| T12[Dispatch corrector codex<br/>commit wave<br/>conventional prefix]
        T9 -->|blocking / scope_violations| T11[Dispatch corrector codex<br/>focused fix prompt]
        T9 -->|should_fix / nits| T9b{Address now<br/>or defer?}
        T9b -->|address| T11
        T9b -->|defer| T12
        T11 --> T7
        T12 --> T13[Dispatch corrector codex<br/>full project verification]
        T13 --> T14{More waves?}
        T14 -->|yes| T5
        T14 -->|no| T15[Push + open PR<br/>wave-by-wave summary<br/>claude composes status report]
    end

    %% ── codex-issue-waves ──
    subgraph Issue["codex-issue-waves — multi-issue parallel"]
        direction TB
        I1[Pre-dispatch:<br/>conflict triage between issues<br/>claude as PO] --> I2{Conflicts?}
        I2 -->|yes| I3[Combine / sequence /<br/>skip umbrella issues]
        I2 -->|no| I4[Per-issue worktree<br/>.worktrees/issue-N-slug]
        I3 --> I4
        I4 --> I5[Fetch issue body<br/>write implementer prompt]
        I5 --> I6[Launch all implementer codex<br/>runs in parallel<br/>via invoking-codex-exec]
        I6 --> I7[Schedule single<br/>aggregated wakeup]
        I7 --> I8[PR existence check:<br/>gh pr view + git log<br/>status, not review]
        I8 --> I9[Dispatch reviewer codex<br/>per worktree, parallel<br/>read-only, JSON output]
        I9 --> I9a[Verify read-only boundary<br/>+ JSON parses per PR]
        I9a --> I11{Per-PR verdict?}
        I11 -->|blocking / scope_violations| I13[Dispatch corrector codex<br/>focused fix prompt]
        I11 -->|should_fix / nits| I11b{Address now<br/>or defer?}
        I11b -->|address| I13
        I11b -->|defer| I14
        I11 -->|approved| I14[Wait for CI via<br/>scripts/wait_for_ci.sh]
        I13 --> I9
        I14 --> I15[Decide merge order<br/>conflict-aware]
        I15 --> I16[scripts/merge_and_cleanup.sh<br/>squash → rm worktree → del branch]
    end

    %% Layering: task-waves and issue-waves call back into invoking-codex-exec
    %% for every codex dispatch — implementer, reviewer, corrector
    T6 -.implementer.-> Exec
    T8 -.reviewer.-> Exec
    T11 -.corrector.-> Exec
    T12 -.corrector.-> Exec
    T13 -.corrector.-> Exec
    I6 -.implementer.-> Exec
    I9 -.reviewer.-> Exec
    I13 -.corrector.-> Exec

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
- **Dotted arrows** = layering, labeled with the codex role being dispatched. Every dispatch (implementer, reviewer, corrector) goes through `invoking-codex-exec`.
- **Claude is the PO; codex is the worker.** Claude plans, dispatches, reads structured outputs (JSON reviews), decides next dispatch, opens PRs (mechanical). Claude does not edit source files, does not read diffs for judgment, does not make in-place fixes. Every code touch — build, review, correction — is a codex dispatch.
- **Reviewer codex is read-only.** No native enforcement; the orchestrator checks `git rev-parse HEAD` + `git status --porcelain` snapshots before/after each reviewer run. Two consecutive boundary violations → escalate to user.
- **Status vs. review** distinction matters. `gh pr view`, `git log --oneline`, `git diff --stat`, CI rollups → status, claude does these. Reading the diff to judge content quality → review, dispatched to reviewer codex.
- **Worktree isolation** is universal. All three skills run codex pinned to a worktree via `-C <worktree>`. Reviewer codex runs in the same worktree as the implementer that produced the PR.
- **Trust-but-verify** is universal. After each dispatch, claude runs status checks (`git status`, `git log`); after each reviewer dispatch, claude additionally verifies the read-only boundary held.

## Skill picker — quick

| Trigger | Skill |
|---------|-------|
| "Run codex on this" / one-shot | `invoking-codex-exec` |
| "Have codex fix this ticket" / planned single task | `codex-task-waves` |
| "Spawn codex on issues #A #B #C" / parallel batch | `codex-issue-waves` |
