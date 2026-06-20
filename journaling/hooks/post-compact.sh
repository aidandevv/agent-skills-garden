#!/usr/bin/env bash
# hooks/post-compact.sh
# Claude Code — PostCompact hook
#
# Fires immediately AFTER a compaction completes. Appends a resume marker
# to the journal so the new context window has a clear "here is where we
# were" anchor to read on next SessionStart.
#
# This hook is lightweight by design — the heavy capture already happened
# in pre-compact.sh. This one just writes the boundary marker.
#
# Must also exit 0. Do not block post-compaction startup.

set -euo pipefail

PAYLOAD=$(cat)
SESSION_ID=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo "unknown")
CWD=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")

GIT_ROOT=$(git -C "${CWD:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${CWD:-.}")
DEV_JOURNAL="$GIT_ROOT/docs/dev_journal.md"
LOG_DIR="$GIT_ROOT/.claude/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true

(
  if [ ! -f "$DEV_JOURNAL" ]; then
    exit 0
  fi

  DATE_NOW=$(date '+%Y-%m-%d %H:%M')
  {
    printf '\n<!-- POST-COMPACT RESUME: %s | id:%s -->\n' "$DATE_NOW" "$SESSION_ID"
    printf '<!-- Read the CP-COMPACT-SNAPSHOT above to restore context. -->\n\n'
  } >> "$DEV_JOURNAL" 2>/dev/null || true

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Post-compact resume marker written for $SESSION_ID." \
    >> "$LOG_DIR/post-compact.log" 2>/dev/null || true
) || true

exit 0
