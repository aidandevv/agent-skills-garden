# journaling — Codex CLI Adapter
# Part 1: paste the AGENTS.md block into ~/.codex/AGENTS.md or ./AGENTS.md
# Part 2: copy the hooks.json config to ~/.codex/hooks.json
#
# NOTE: Use global ~/.codex/hooks.json until GitHub issue #17532 is resolved
# (project-local hook config may not fire in interactive sessions as of v0.120).
# Hooks engine is stable as of Codex CLI v0.124.0 (April 2026).
# Async hooks not yet supported — use synchronous commands only.
#
# NOTE: Codex requires interactive hook trust on first run. The first time
# Stop or TaskCompleted fires after installing hooks.json, Codex will prompt
# to trust codex-stop.sh before executing it — approve once per machine.
#
# NOTE: codex-stop.sh resolves a working `codex` binary at runtime (PATH,
# falling back to the desktop app's bundled CLI) since `codex` is not always
# on PATH inside a hook's minimal shell. It also captures model output via
# `-o <file>` rather than stdout — `codex exec` has no `--quiet` flag, and
# raw stdout includes banner/log noise that breaks downstream parsing.

---

## Active Skills — Journaling

**Engineering Journal:**
Follow skill at `~/.codex/skills/journaling/engineering-journal/SKILL.md`.
Maintain `./docs/dev_journal.md`. At the end of meaningful engineering work,
evaluate whether a checkpoint should be logged. Prefer Lightweight schema in
long or compressed sessions. Never overwrite. Never fabricate.

**Product Insight Journal:**
Follow skill at `~/.codex/skills/journaling/product-insight-journal/SKILL.md`.
Maintain `./docs/product_insights.md`. At the end of meaningful product, UX,
growth, onboarding, retention, or roadmap work, evaluate whether a product
insight should be logged. Never overwrite. Never fabricate.

**Cross-Log Rule:**
When an observation has both an engineering dimension and a product dimension
worth preserving independently, write separate entries in both files and add a
`[CROSS-LOG]` marker in each entry linking to the other.

---

# ~/.codex/hooks.json
{
  "hooks": [
    {
      "event": "Stop",
      "hooks": [
        {
          "type": "command",
          "command": "~/.codex/hooks/journaling/codex-stop.sh"
        }
      ]
    },
    {
      "event": "TaskCompleted",
      "hooks": [
        {
          "type": "command",
          "command": "~/.codex/hooks/journaling/codex-stop.sh"
        }
      ]
    }
  ]
}
