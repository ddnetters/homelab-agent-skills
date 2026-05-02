#!/usr/bin/env bash
# Squash-merge a PR and clean up its worktree + local branch in the correct order.
#
# The hard-won rule: `git branch -D` fails while a worktree pins the branch, and
# `gh pr merge --delete-branch` only deletes the remote branch. This script
# enforces the sequence:
#   1. gh pr merge --squash --delete-branch  (merges + deletes remote branch)
#   2. git worktree remove <path>            (unpins the local branch)
#   3. git branch -D <branch>                (deletes the local branch)
#
# Usage:
#   merge_and_cleanup.sh <PR_NUMBER> <WORKTREE_PATH> <BRANCH>
#
# Environment:
#   MERGE_STRATEGY=squash|merge|rebase  (default: squash)

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <PR_NUMBER> <WORKTREE_PATH> <BRANCH>" >&2
  exit 2
fi

pr="$1"
worktree="$2"
branch="$3"
strategy="${MERGE_STRATEGY:-squash}"

if ! [[ "$pr" =~ ^[0-9]+$ ]]; then
  echo "PR_NUMBER must be an integer, got: $pr" >&2
  exit 2
fi

case "$strategy" in
  squash|merge|rebase) ;;
  *) echo "MERGE_STRATEGY must be squash|merge|rebase, got: $strategy" >&2; exit 2 ;;
esac

# 1. Confirm PR is mergeable first (fail fast instead of mid-sequence).
state="$(gh pr view "$pr" --json state,mergeable,mergeStateStatus \
  --jq '{state, mergeable, mergeStateStatus} | "\(.state)|\(.mergeable)|\(.mergeStateStatus)"')"
if [[ "${state%%|*}" != "OPEN" ]]; then
  echo "PR #$pr is not OPEN (state: ${state%%|*}); aborting." >&2
  exit 1
fi

# 2. Merge. `gh` may print "failed to delete local branch" — that is expected when
#    a worktree is pinning the branch and is not fatal for us; we handle it next.
echo "Merging PR #$pr (--$strategy)..."
gh pr merge "$pr" "--$strategy" --delete-branch || {
  echo "gh pr merge reported an error. Inspecting..." >&2
  gh pr view "$pr" --json state,mergedAt --jq '.'
  merged="$(gh pr view "$pr" --json state --jq '.state')"
  if [[ "$merged" != "MERGED" ]]; then
    echo "PR #$pr did not merge. Aborting cleanup." >&2
    exit 1
  fi
  echo "PR #$pr is MERGED; the error was only about local-branch cleanup. Continuing." >&2
}

# 3. Remove the worktree (this releases the branch lock).
if [[ -d "$worktree" ]]; then
  echo "Removing worktree at $worktree..."
  git worktree remove "$worktree"
else
  echo "Worktree $worktree not present; skipping." >&2
fi

# 4. Delete the local branch if it still exists.
if git show-ref --quiet "refs/heads/$branch"; then
  echo "Deleting local branch $branch..."
  git branch -D "$branch"
else
  echo "Local branch $branch already gone; skipping." >&2
fi

echo "Done. PR #$pr merged, worktree + branch cleaned up."
