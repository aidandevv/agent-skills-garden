#!/usr/bin/env bash
# hooks/pre-compact.sh
# Claude Code — PreCompact hook
#
# Fires immediately BEFORE a compaction (manual /compact or auto on context
# pressure). Writes a [CP-COMPACT-SNAPSHOT] entry capturing what's in
# progress so nothing is lost across the compaction boundary.
#
# CRITICAL: This hook MUST exit 0. If it exits 2 it BLOCKS the compaction,
# which can leave the session stuck at the context wall. Make it fast and
# resilient. Do work in a subshell; never let an error propagate upward.
#
# Install alongside session-end.sh in ~/.claude/settings.json:
# {
#   "hooks": {
#     "PreCompact": [{"hooks": [{"type": "command",
#       "command": "~/.claude/hooks/journaling/pre-compact.sh"}]}],
#     "PostCompact": [{"hooks": [{"type": "command",
#       "command": "~/.claude/hooks/journaling/post-compact.sh"}]}]
#   }
# }
#
# References:
#   https://hidekazu-konishi.com/entry/claude_code_compaction_and_long_session_guide.html
#   https://github.com/mvara-ai/precompact-hook
#   https://dev.to/mikeadolan/claude-code-compaction-kept-destroying-my-work-i-built-hooks-that-fixed-it-2dgp

set -euo pipefail

PAYLOAD=$(cat)
TRANSCRIPT_PATH=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || echo "")
SESSION_ID=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo "unknown")
CWD=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")

GIT_ROOT=$(git -C "${CWD:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${CWD:-.}")
DEV_JOURNAL="$GIT_ROOT/docs/dev_journal.md"
LOG_DIR="$GIT_ROOT/.claude/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG="$LOG_DIR/pre-compact.log"
stamp() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG" 2>/dev/null || true; }

# ── Run the snapshot in a subshell so any failure still exits 0 ──────────────
(
  if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    stamp "No transcript for $SESSION_ID — skipping snapshot."
    exit 0
  fi

  TRANSCRIPT_SIZE=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
  if [ "$TRANSCRIPT_SIZE" -lt 500 ]; then
    stamp "Transcript too short for snapshot — skipping."
    exit 0
  fi

  SNAPSHOT_PROMPT='A context compaction is about to occur. Read the tail of
this session transcript and produce a compact [CP-COMPACT-SNAPSHOT] entry:

### [CP-COMPACT-SNAPSHOT] | DATE: Pre-compaction state — [brief task label]

**Summary:** [What we are in the middle of building or fixing — 1-2 sentences.]

**Files in progress:** [Files actively being worked on.]

**Decisions made this context window:** [Key choices, max 3 bullets.]

**Immediate next step:** [Exactly what to do right after compaction resumes.]

**Open questions:** [Any unresolved risks or blockers.]

---

Be concrete. This entry is what the next context window wakes up to.
Use today'"'"'s date.'

  TRANSCRIPT_TAIL=$(tail -c 20000 "$TRANSCRIPT_PATH")

  SNAPSHOT=$(printf '%s\n\nTRANSCRIPT TAIL:\n%s' \
    "$SNAPSHOT_PROMPT" "$TRANSCRIPT_TAIL" | \
    claude --print --safe-mode --tools "" --model claude-haiku-4-5 2>/dev/null || echo "")

  if [ -z "$SNAPSHOT" ]; then
    stamp "Snapshot generation failed for $SESSION_ID — skipping."
    exit 0
  fi

  mkdir -p "$GIT_ROOT/docs" 2>/dev/null || true
  if [ ! -f "$DEV_JOURNAL" ]; then
    printf '# Engineering Development Journal\n> Chronological log.\n\n---\n' \
      > "$DEV_JOURNAL" 2>/dev/null || true
  fi

  DATE_NOW=$(date '+%Y-%m-%d %H:%M')
  {
    printf '\n<!-- COMPACT: %s | id:%s -->\n\n' "$DATE_NOW" "$SESSION_ID"
    echo "$SNAPSHOT"
  } >> "$DEV_JOURNAL" 2>/dev/null || true

  stamp "Compact snapshot appended for $SESSION_ID."
) || true  # Subshell failure is silently swallowed — compaction must not be blocked

# Always exit 0 — never block the compaction
exit 0
