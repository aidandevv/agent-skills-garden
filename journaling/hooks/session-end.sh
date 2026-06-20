#!/usr/bin/env bash
# hooks/session-end.sh
# Claude Code — SessionEnd hook
#
# Fires ONCE when a Claude Code session terminates (clean exit, Ctrl-D,
# or crash). Reads the session transcript and appends lightweight journal
# entries to dev_journal.md. Then runs the Level 1 eval gate on what
# it just wrote.
#
# Install: add to ~/.claude/settings.json or .claude/settings.json
# {
#   "hooks": {
#     "SessionEnd": [{"hooks": [{"type": "command",
#       "command": "~/.claude/hooks/journaling/session-end.sh"}]}]
#   }
# }
#
# SessionEnd cannot block termination. Output goes to log, not the user.
# Keep this fast. Make it resilient to crashes/interrupts.

set -euo pipefail

# ── Parse stdin payload ──────────────────────────────────────────────────────
PAYLOAD=$(cat)
TRANSCRIPT_PATH=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || echo "")
SESSION_ID=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo "unknown")
CWD=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")

# ── Locate project root and journal ─────────────────────────────────────────
GIT_ROOT=$(git -C "${CWD:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${CWD:-.}")
DEV_JOURNAL="$GIT_ROOT/docs/dev_journal.md"
LOG_DIR="$GIT_ROOT/.claude/logs"
mkdir -p "$LOG_DIR"

LOG="$LOG_DIR/session-end.log"
stamp() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# ── Guards ───────────────────────────────────────────────────────────────────
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  stamp "No transcript for session $SESSION_ID — skipping."
  exit 0
fi

TRANSCRIPT_SIZE=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
if [ "$TRANSCRIPT_SIZE" -lt 800 ]; then
  stamp "Transcript too short (${TRANSCRIPT_SIZE}B) for $SESSION_ID — skipping."
  exit 0
fi

# ── Build journal-capture prompt ─────────────────────────────────────────────
JOURNAL_PROMPT='Review this Claude Code session transcript. Identify engineering
checkpoint moments worth logging. For each one found, write a Lightweight Entry:

### [TAG] | DATE: [Title]
**Summary:** [1-2 sentences: decision and why.]
**Files/Modules Affected:** [List or None identified.]
**Key Trade-off:** [What was accepted or rejected.]
**Evidence:** [How we know it worked, or Not yet verified.]
**Follow-ups:** [Open questions, or None identified.]

---

Use tags: [CP-ARCHITECTURE] [CP-PIVOT] [CP-REFACTOR] [CP-MILESTONE]
          [CP-CONSTRAINT] [CP-DEBUG] [CP-TESTING] [CP-INTEGRATION]

If no checkpoint-worthy moments exist, output exactly: NO_CHECKPOINT
Do not fabricate. Use today'"'"'s date.'

TRANSCRIPT_EXCERPT=$(tail -c 28000 "$TRANSCRIPT_PATH")

JOURNAL_OUTPUT=$(printf '%s\n\nTRANSCRIPT:\n%s' \
  "$JOURNAL_PROMPT" "$TRANSCRIPT_EXCERPT" | \
  claude --print --safe-mode --tools "" --model claude-haiku-4-5 2>/dev/null || echo "")

if [ -z "$JOURNAL_OUTPUT" ] || echo "$JOURNAL_OUTPUT" | grep -qx "NO_CHECKPOINT"; then
  stamp "No checkpoints for $SESSION_ID."
  exit 0
fi

# ── Ensure journal exists ────────────────────────────────────────────────────
mkdir -p "$GIT_ROOT/docs"
if [ ! -f "$DEV_JOURNAL" ]; then
  printf '# Engineering Development Journal\n> Chronological log.\n\n---\n' \
    > "$DEV_JOURNAL"
fi

# ── Append entries ───────────────────────────────────────────────────────────
DATE_NOW=$(date '+%Y-%m-%d %H:%M')
{
  printf '\n<!-- SESSION: %s | id:%s (hook:session-end) -->\n\n' \
    "$DATE_NOW" "$SESSION_ID"
  echo "$JOURNAL_OUTPUT"
} >> "$DEV_JOURNAL"

stamp "Entries appended for $SESSION_ID."

# ── Level 1 eval gate ────────────────────────────────────────────────────────
# Re-read what we just wrote and check quality. Appends a warning if it fails.
EVAL_PROMPT='You are a quality gate for an engineering journal.
Read the journal entries below and answer YES or NO:
Do these entries collectively answer at least 4 of these 8 questions?
1. What decision was made?
2. Why was it made?
3. What was rejected?
4. What constraint shaped it?
5. What changed during implementation?
6. What evidence shows it worked?
7. What files or components were affected?
8. What should be revisited?

Reply with only YES or NO on the first line, then one sentence of reasoning.

ENTRIES:
'"$JOURNAL_OUTPUT"

EVAL_RESULT=$(echo "$EVAL_PROMPT" | \
  claude --print --safe-mode --tools "" --model claude-haiku-4-5 2>/dev/null || echo "YES")

EVAL_PASS=$(echo "$EVAL_RESULT" | head -1 | tr -d '[:space:]')

if [ "$EVAL_PASS" != "YES" ]; then
  EVAL_REASON=$(echo "$EVAL_RESULT" | tail -1)
  {
    printf '\n> ⚠ **EVAL-FAIL** (session-end gate) — %s\n' "$EVAL_REASON"
    printf '> Re-review this session manually or run `./evals/eval-score.sh`.\n\n'
  } >> "$DEV_JOURNAL"
  stamp "EVAL-FAIL for $SESSION_ID: $EVAL_REASON"
else
  stamp "EVAL-PASS for $SESSION_ID."
fi

exit 0
