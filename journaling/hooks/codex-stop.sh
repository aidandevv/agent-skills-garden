#!/usr/bin/env bash
# hooks/codex-stop.sh
# Codex CLI — Stop + TaskCompleted hook
#
# Handles two distinct Codex usage patterns:
#
#   MODE A — Small focused sessions (transcript growth < 3K chars since last
#             run): Write a lightweight entry immediately on Stop. These
#             sessions are self-contained; capture on exit.
#
#   MODE B — Chained dispatch sessions (multiple tasks, large transcript):
#             The Stop hook also receives TaskCompleted events via the
#             hook_event_name field. When event=TaskCompleted, write one
#             entry per completed task rather than waiting for session end.
#             This gives natural mid-chain checkpoints without any prompt-
#             level instruction to the model.
#
# Deduplication: a size-cache file at /tmp prevents re-processing the
# same transcript bytes if Stop fires multiple times in one session.
#
# Install in ~/.codex/hooks.json (global — prefer this over project-local
# until GitHub issue #17532 is resolved for Codex v0.120):
# {
#   "hooks": [
#     {"event": "Stop",
#      "hooks": [{"type":"command","command":"~/.codex/hooks/journaling/codex-stop.sh"}]},
#     {"event": "TaskCompleted",
#      "hooks": [{"type":"command","command":"~/.codex/hooks/journaling/codex-stop.sh"}]}
#   ]
# }
#
# Note: async hooks are not yet supported in Codex CLI as of June 2026
# (parsed but skipped). Use synchronous commands only.

set -euo pipefail

# `codex` is not guaranteed to be on PATH in a hook's minimal shell
# environment. Resolve a working binary, preferring PATH, falling back to
# the desktop app's bundled CLI.
CODEX_BIN=$(command -v codex 2>/dev/null || echo "/Applications/Codex.app/Contents/Resources/codex")

PAYLOAD=$(cat)
HOOK_EVENT=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name','Stop'))" 2>/dev/null || echo "Stop")
TRANSCRIPT_PATH=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || echo "")
SESSION_ID=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo "unknown")
CWD=$(echo "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")

GIT_ROOT=$(git -C "${CWD:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${CWD:-.}")
DEV_JOURNAL="$GIT_ROOT/docs/dev_journal.md"
LOG_DIR="$GIT_ROOT/.codex/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/codex-stop.log"
stamp() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$HOOK_EVENT] $*" >> "$LOG"; }

# ── Guards ───────────────────────────────────────────────────────────────────
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  stamp "No transcript for $SESSION_ID — skipping."
  exit 0
fi

TRANSCRIPT_SIZE=$(wc -c < "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)

# ── Size-cache deduplication ─────────────────────────────────────────────────
SIZE_CACHE="/tmp/codex-journal-size-${SESSION_ID}.cache"
LAST_SIZE=$(cat "$SIZE_CACHE" 2>/dev/null || echo 0)
GROWTH=$((TRANSCRIPT_SIZE - LAST_SIZE))

# ── Mode detection ───────────────────────────────────────────────────────────
if [ "$HOOK_EVENT" = "TaskCompleted" ]; then
  # MODE B: task boundary — write if meaningful work happened since last entry
  MIN_GROWTH=1000
  MODE_LABEL="task-boundary"
else
  # MODE A: session stop — write if this is a small focused session or end
  if [ "$TRANSCRIPT_SIZE" -lt 800 ]; then
    stamp "Session too short (${TRANSCRIPT_SIZE}B) — skipping."
    exit 0
  fi
  MIN_GROWTH=2000
  MODE_LABEL="session-stop"
fi

if [ "$GROWTH" -lt "$MIN_GROWTH" ]; then
  stamp "Insufficient growth (${GROWTH}B < ${MIN_GROWTH}B) — skipping."
  exit 0
fi

echo "$TRANSCRIPT_SIZE" > "$SIZE_CACHE"

# ── Prompt varies by mode ────────────────────────────────────────────────────
if [ "$HOOK_EVENT" = "TaskCompleted" ]; then
  JOURNAL_PROMPT='A Codex task just completed. Review the new portion of this
session transcript and write ONE Lightweight Entry for the task that just
finished:

### [TAG] | DATE: [Title — name the specific task completed]
**Summary:** [What the task accomplished, 1-2 sentences.]
**Files/Modules Affected:** [List or None identified.]
**Key Trade-off:** [What was accepted or rejected.]
**Evidence:** [Test output, build result, or Not yet verified.]
**Follow-ups:** [Open questions, or None identified.]

---

Tags: [CP-ARCHITECTURE] [CP-PIVOT] [CP-REFACTOR] [CP-MILESTONE]
      [CP-CONSTRAINT] [CP-DEBUG] [CP-TESTING] [CP-INTEGRATION]

If the task was trivial (config tweak, minor fix), output: NO_CHECKPOINT
Use today'"'"'s date.'
else
  JOURNAL_PROMPT='Review this Codex session transcript. Identify engineering
checkpoint moments worth logging. For each, write a Lightweight Entry:

### [TAG] | DATE: [Title]
**Summary:** [Decision and why, 1-2 sentences.]
**Files/Modules Affected:** [List or None identified.]
**Key Trade-off:** [What was accepted or rejected.]
**Evidence:** [How we know it worked, or Not yet verified.]
**Follow-ups:** [Open questions, or None identified.]

---

Tags: [CP-ARCHITECTURE] [CP-PIVOT] [CP-REFACTOR] [CP-MILESTONE]
      [CP-CONSTRAINT] [CP-DEBUG] [CP-TESTING] [CP-INTEGRATION]

If no checkpoint-worthy moments exist, output: NO_CHECKPOINT
Do not fabricate. Use today'"'"'s date.'
fi

TRANSCRIPT_EXCERPT=$(tail -c 28000 "$TRANSCRIPT_PATH")

# `codex exec` has no --quiet flag; -o writes just the final agent message
# to a file, which is the only way to get parseable output from this CLI.
JOURNAL_OUT_FILE="/tmp/codex-journal-out-${SESSION_ID}.txt"
printf '%s\n\nTRANSCRIPT:\n%s' "$JOURNAL_PROMPT" "$TRANSCRIPT_EXCERPT" | \
  "$CODEX_BIN" exec --sandbox read-only --skip-git-repo-check \
    -c model_reasoning_effort=low --model gpt-5.4-mini \
    -o "$JOURNAL_OUT_FILE" >/dev/null 2>&1 || true
JOURNAL_OUTPUT=$(cat "$JOURNAL_OUT_FILE" 2>/dev/null || echo "")
rm -f "$JOURNAL_OUT_FILE"

if [ -z "$JOURNAL_OUTPUT" ] || echo "$JOURNAL_OUTPUT" | grep -qx "NO_CHECKPOINT"; then
  stamp "No checkpoints for $SESSION_ID ($MODE_LABEL)."
  exit 0
fi

# ── Ensure journal exists ────────────────────────────────────────────────────
mkdir -p "$GIT_ROOT/docs"
if [ ! -f "$DEV_JOURNAL" ]; then
  printf '# Engineering Development Journal\n> Chronological log.\n\n---\n' \
    > "$DEV_JOURNAL"
fi

# ── Append ───────────────────────────────────────────────────────────────────
DATE_NOW=$(date '+%Y-%m-%d %H:%M')
{
  printf '\n<!-- SESSION: %s | id:%s (%s) -->\n\n' \
    "$DATE_NOW" "$SESSION_ID" "$MODE_LABEL"
  echo "$JOURNAL_OUTPUT"
} >> "$DEV_JOURNAL"

stamp "Appended entries for $SESSION_ID ($MODE_LABEL, growth: ${GROWTH}B)."

# ── Level 1 eval gate ────────────────────────────────────────────────────────
EVAL_PROMPT='Quality gate: do these journal entries answer at least 4 of 8?
1.Decision made 2.Why 3.What rejected 4.Constraint 5.What changed
6.Evidence 7.Files affected 8.What to revisit

Reply YES or NO on line 1. One sentence of reasoning on line 2.

ENTRIES:
'"$JOURNAL_OUTPUT"

EVAL_OUT_FILE="/tmp/codex-eval-out-${SESSION_ID}.txt"
echo "$EVAL_PROMPT" | \
  "$CODEX_BIN" exec --sandbox read-only --skip-git-repo-check \
    -c model_reasoning_effort=low --model gpt-5.4-mini \
    -o "$EVAL_OUT_FILE" >/dev/null 2>&1 || true
EVAL_RESULT=$(cat "$EVAL_OUT_FILE" 2>/dev/null || echo "YES")
rm -f "$EVAL_OUT_FILE"

EVAL_PASS=$(echo "$EVAL_RESULT" | head -1 | tr -d '[:space:]')

if [ "$EVAL_PASS" != "YES" ]; then
  EVAL_REASON=$(echo "$EVAL_RESULT" | tail -1)
  {
    printf '\n> ⚠ **EVAL-FAIL** (codex gate) — %s\n' "$EVAL_REASON"
    printf '> Run `./evals/eval-score.sh` for a full rubric review.\n\n'
  } >> "$DEV_JOURNAL"
  stamp "EVAL-FAIL for $SESSION_ID: $EVAL_REASON"
else
  stamp "EVAL-PASS for $SESSION_ID."
fi

exit 0
