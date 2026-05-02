# Common Commands

Exact shell recipes for each phase. Copy-adapt, don't rewrite from memory.

## Worktree + issue body setup

```bash
# From the repo root
git fetch origin
mkdir -p .worktrees /tmp/codex-runs

# Per issue
git worktree add -b <branch-name> .worktrees/issue-<N>-<slug> origin/main
gh issue view <N> --json title,body > /tmp/codex-runs/issue-<N>.json
```

Branch naming by type: `feat/<slug>` for new features, `fix/<slug>` for bug fixes, `refactor/<slug>` for refactors, `chore/<slug>` for chores.

## Launching codex

Always background it, always redirect output:

```bash
codex exec \
  --dangerously-bypass-approvals-and-sandbox \
  --cd /absolute/path/to/.worktrees/issue-<N>-<slug> \
  --skip-git-repo-check \
  "$(cat /tmp/codex-runs/prompt-<N>.md)" \
  > /tmp/codex-runs/<N>.out 2>&1
```

Put this inside your harness's `run_in_background: true`-equivalent call so the agent isn't blocked.

Flags explained:
- `--dangerously-bypass-approvals-and-sandbox` — codex runs fully autonomously. Required for this skill.
- `--cd <worktree>` — codex treats the worktree as its root. Without this it picks up the main worktree's HEAD.
- `--skip-git-repo-check` — silences a warning; harmless either way.

## Monitoring without polling

Do not use `while sleep` in bash — sleep loops are often blocked by the harness. Two options:

**Option A — schedule a wakeup.** Set a delay (~10–15 min for moderate refactors) and come back to tail the output file.

**Option B — until-loop with a single condition.** When you truly need to block until a specific event, use the bundled script:

```bash
# Blocks until the `test` check (or a named check) reports final SUCCESS/FAILURE.
# Run via the harness's background-command mechanism so the exit notification wakes the agent.
bash "$SKILL_DIR/scripts/wait_for_ci.sh" <PR>               # waits on check "test"
bash "$SKILL_DIR/scripts/wait_for_ci.sh" <PR> build-deploy  # waits on a different check
WAIT_FOR_CI_INTERVAL=30 bash "$SKILL_DIR/scripts/wait_for_ci.sh" <PR>  # override poll interval
```

Exit codes: `0` = SUCCESS/NEUTRAL/SKIPPED, `1` = FAILURE/CANCELLED/TIMED_OUT, `2` = bad input.

Raw equivalent if you don't want to call the script:

```bash
until [ "$(gh pr view <N> --json statusCheckRollup --jq '.statusCheckRollup[] | select(.name=="test") | .status')" = "COMPLETED" ]; do
  sleep 20
done
```

Run this via the harness's background-command mechanism, not inline. The harness will notify when it exits.

Never poll for a codex run's completion with `ps aux | grep` — rely on the run-in-background exit notification.

## Reviewing a finished codex run

```bash
# Did it open a PR?
tail -30 /tmp/codex-runs/<N>.out

# PR state
gh pr view <N> --json state,mergeable,mergeStateStatus,statusCheckRollup | \
  jq '{state, mergeable, mergeStateStatus, checks: [.statusCheckRollup[] | {name, conclusion}]}'

# Commits on branch
git log --oneline origin/main..origin/<branch>

# Full diff (big, pipe to grep)
gh pr diff <N>

# File-shape audit
git diff origin/main...origin/<branch> --stat

# Straggler hunt for a rename (example)
git diff origin/main...origin/<branch> | grep -nE "old_name|OldName|/old/"

# Conflict marker hunt in committed code (not codex log)
gh pr diff <N> | grep -nE "^(<<<<<<<|=======|>>>>>>>)"
```

## Fix-in-place workflow

```bash
cd /absolute/path/to/.worktrees/issue-<N>-<slug>

# Sync with what's on origin (codex may have force-pushed)
git fetch origin
git reset --hard origin/<branch>

# Rebase on main if needed
git rebase origin/main

# Make edits ... then:
npm test --workspaces --if-present
npx tsc --noEmit -p packages/web/tsconfig.json   # if repo type-checks separately

git add <specific files>
git commit -m "fix: <summary>"
git push --force-with-lease
```

Always `--force-with-lease`, never `--force` — protects against racing with codex if it pushed something meanwhile.

## PR comments and reviews

```bash
# Leave a summary comment (can approve your own work via comment, but not via review)
gh pr comment <N> --body "$(cat <<'EOF'
Addressed the review findings in <sha>:
- <blocker 1>: <fix summary>
- <blocker 2>: <fix summary>
- <nit>: <fix summary>

Tests: <core>/<api>/<web> green.
EOF
)"
```

GitHub blocks you from approving your own PR (`addPullRequestReview` → "Review Can not approve your own pull request"). Post as a regular comment instead; merge button doesn't require approval unless the branch protection enforces it.

## Merge + cleanup (in this exact order)

Prefer the bundled script — it encodes the order:

```bash
bash "$SKILL_DIR/scripts/merge_and_cleanup.sh" <PR> <worktree-path> <branch>
# e.g.
bash "$SKILL_DIR/scripts/merge_and_cleanup.sh" 143 .worktrees/issue-131-suggestion-feedback feat/suggestion-feedback
# MERGE_STRATEGY=rebase bash "$SKILL_DIR/scripts/merge_and_cleanup.sh" <PR> <path> <branch>  # to override squash
```

Raw equivalent (in this exact order — swap and it breaks):

```bash
# 1. Merge (may print "failed to delete local branch" — expected, see below)
gh pr merge <N> --squash --delete-branch

# 2. Confirm it actually merged
gh pr view <N> --json state,mergedAt

# 3. Remove the worktree — until this runs, the local branch is pinned
git worktree remove .worktrees/issue-<N>-<slug>

# 4. Delete the local branch if gh didn't manage to
git branch -D <branch>
```

If step 1 reports `failed to delete local branch ... used by worktree`, that's expected — `gh` has already merged + deleted on the remote; just run steps 3 and 4.

## Deploy (only when asked)

```bash
# See what workflows exist
ls .github/workflows/

# Look at the triggers in the deploy workflow
grep -A5 "^on:" .github/workflows/deploy.yml

# Dispatch (replace env as needed)
gh workflow run "Deploy" --ref main -f environment=development
```

Never deploy to production without explicit user confirmation for the target environment.
