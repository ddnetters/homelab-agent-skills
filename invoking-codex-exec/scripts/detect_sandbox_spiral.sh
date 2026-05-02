#!/usr/bin/env bash
# Detect codex-exec sandbox-bypass spirals from a codex log.
#
# Usage:
#   detect_sandbox_spiral.sh <logfile>             # tail -f, emit one line per hit, run forever
#   detect_sandbox_spiral.sh --once <logfile>      # scan existing content, exit 0 (clean) or 1 (spiral)
#
# Designed for use with the Monitor tool: each match becomes a stdout line, which
# the harness surfaces as a notification. The agent decides whether to kill codex,
# usually after a `git status` / `git diff` check (see SKILL.md "Before killing").
#
# Signatures are derived from a real spiral observed 2026-04-28: codex used
# `--full-auto` (workspace-write sandbox), gradle daemon socket bind was blocked,
# codex tried GRADLE_USER_HOME=/tmp, then patched the gradle CLI jar.

set -euo pipefail

mode="follow"
if [[ "${1:-}" == "--once" ]]; then
  mode="once"
  shift
fi

logfile="${1:-}"
if [[ -z "$logfile" ]]; then
  echo "usage: $(basename "$0") [--once] <logfile>" >&2
  exit 2
fi
if [[ ! -r "$logfile" ]]; then
  echo "error: cannot read $logfile" >&2
  exit 2
fi

# Earliest-to-latest signal order. Order does not matter for matching, but the
# earlier signals (sandbox-policy rejections, GRADLE_USER_HOME=/tmp) tend to fire
# minutes before the JVM-verifier and jar-patching ones.
pattern='blocked by policy|rejected by policy|GRADLE_USER_HOME=/tmp|MAVEN_OPTS=.*-Duser\.home=/tmp|/tmp/gradle-(patch|home)|/tmp/maven-(patch|home)|Expecting a stack( |-)?map frame|BuildActionsFactory|DefaultFileLockCommunicator|PatchBuildActionsFactory|jar (uf|xf|cf) /tmp|--no-daemon.*--no-daemon|Net\.bind0|DatagramSocket.*bind'

if [[ "$mode" == "once" ]]; then
  hits=$(grep -nE "$pattern" "$logfile" 2>/dev/null || true)
  if [[ -n "$hits" ]]; then
    printf '%s\n' "$hits" | awk 'NR<=5'
    exit 1
  fi
  exit 0
fi

# follow mode — line-buffered grep so events surface immediately
exec tail -n0 -F "$logfile" 2>/dev/null \
  | grep -E --line-buffered "$pattern" \
  | awk '{ print "[sandbox-spiral] " $0; fflush(); }'
