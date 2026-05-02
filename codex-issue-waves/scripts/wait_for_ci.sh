#!/usr/bin/env bash
# Block until a PR's `test` check (or a named check) reports a final conclusion.
# Exits 0 on SUCCESS, 1 on failure/cancelled/timed_out, 2 on bad input.
#
# Usage:
#   wait_for_ci.sh <PR_NUMBER> [CHECK_NAME]
#
# CHECK_NAME defaults to "test". Poll interval is 20s; override via WAIT_FOR_CI_INTERVAL.
#
# Run this in the harness's background-command mechanism, not inline — the harness
# will notify when it exits so the agent isn't blocked.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <PR_NUMBER> [CHECK_NAME]" >&2
  exit 2
fi

pr="$1"
check_name="${2:-test}"
interval="${WAIT_FOR_CI_INTERVAL:-20}"

if ! [[ "$pr" =~ ^[0-9]+$ ]]; then
  echo "PR_NUMBER must be an integer, got: $pr" >&2
  exit 2
fi

while true; do
  raw="$(gh pr view "$pr" --json statusCheckRollup \
    --jq ".statusCheckRollup[] | select(.name==\"$check_name\") | \"\(.status)|\(.conclusion)\"")" || {
    echo "gh pr view failed for PR #$pr" >&2
    exit 1
  }

  if [[ -z "$raw" ]]; then
    echo "No check named '$check_name' found on PR #$pr (yet). Waiting ${interval}s..." >&2
    sleep "$interval"
    continue
  fi

  status="${raw%%|*}"
  conclusion="${raw##*|}"

  if [[ "$status" == "COMPLETED" ]]; then
    echo "PR #$pr check '$check_name': $conclusion"
    case "$conclusion" in
      SUCCESS|NEUTRAL|SKIPPED) exit 0 ;;
      *) exit 1 ;;
    esac
  fi

  sleep "$interval"
done
