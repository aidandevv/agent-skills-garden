# journaling — Claude Code Adapter
# Paste the block below into your project CLAUDE.md or ~/.claude/CLAUDE.md.
# Keep it under 15 lines. Full skill protocols load on activation only.

---

## Active Skills — Journaling

**Engineering Journal:**
Follow skill at `~/.claude/skills/journaling/engineering-journal/SKILL.md`.
Maintain `./docs/dev_journal.md`. At the end of meaningful engineering work,
evaluate whether a checkpoint should be logged. Prefer Lightweight schema in
long or compressed sessions. Never overwrite. Never fabricate.

**Product Insight Journal:**
Follow skill at `~/.claude/skills/journaling/product-insight-journal/SKILL.md`.
Maintain `./docs/product_insights.md`. At the end of meaningful product, UX,
growth, onboarding, retention, or roadmap work, evaluate whether a product
insight should be logged. Never overwrite. Never fabricate.

**Cross-Log Rule:**
When an observation has both an engineering dimension and a product dimension
worth preserving independently, write separate entries in both files and add a
`[CROSS-LOG]` marker in each entry linking to the other.

**Compaction:**
The PreCompact and PostCompact hooks handle journal capture automatically
before context compaction. You do not need to manually log before /compact.

---

# Hook registration (add to ~/.claude/settings.json or .claude/settings.json):
#
# {
#   "hooks": {
#     "SessionEnd":  [{"hooks":[{"type":"command","command":"~/.claude/hooks/journaling/session-end.sh"}]}],
#     "PreCompact":  [{"hooks":[{"type":"command","command":"~/.claude/hooks/journaling/pre-compact.sh"}]}],
#     "PostCompact": [{"hooks":[{"type":"command","command":"~/.claude/hooks/journaling/post-compact.sh"}]}]
#   }
# }
