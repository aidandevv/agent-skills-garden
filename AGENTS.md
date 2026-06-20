# AGENTS.md

This file provides guidance to Codex CLI when working with code in this repository.

## What this repo is

`agent-skills-garden` is a personal portfolio repo of reusable agent skills built on
the Agent Skills open standard (name+description at discovery, full file on
activation, referenced files only during execution). Each top-level folder is a
self-contained, droppable skill — not a single application. There is no build,
lint, or test toolchain; the "code" is markdown skill definitions, shell-script
hooks, and small bash utilities.

`journaling/` is the only fully implemented skill (a dual-journal system for
engineering decisions and product insights). `travel-agent/` is planned but not
yet started. New skills should follow the same top-level-folder pattern.

`handoff.md` is a point-in-time state-transfer document written for session
continuity — useful for history, but the actual repo state (this file, the
READMEs, and the code) is authoritative if they ever disagree.

## Three-layer architecture (applies to every skill in this garden)

1. **Skill files** (`<skill>/skills/*/SKILL.md`) — procedure only, what the
   agent reads when performing the task. **No citations, no design rationale.**
   If you want to explain *why* an instruction exists, put it in a README, not
   here. Keep SKILL.md files under ~300 lines — attention to late-file
   instructions degrades past that (see "lost in the middle" research in the
   root README).
2. **Adapters** (`<skill>/adapters/*.md`) — short blocks (~15 lines of actual
   instructions) meant to be pasted into a project or global `CLAUDE.md`/
   `AGENTS.md`. They only tell the model where to find the skill and the
   cross-cutting rules (e.g. when to write to two logs); they load on every
   session start, so keep them lean.
3. **Hooks** (`<skill>/hooks/*.sh`) — deterministic shell scripts wired into
   the host tool's lifecycle events (Claude Code `SessionEnd`/`PreCompact`/
   `PostCompact`, Codex CLI `Stop`/`TaskCompleted`). Hooks exist because
   model-driven journaling is probabilistic and degrades near context limits;
   hooks fire regardless of model attention.

Research and rationale for all of the above lives in `README.md` (repo-level
bibliography) and `journaling/README.md` (skill-level design decisions) —
agents never load these; they're for humans evaluating the design.

## Hard constraints — do not violate

- **PreCompact hooks must always exit 0.** A non-zero exit blocks compaction
  and can strand a session at the context wall. `journaling/hooks/pre-compact.sh`
  does its work in a subshell with `|| true` specifically to guarantee this —
  preserve that pattern in any hook touching `PreCompact`.
- **Journals are append-only.** Never overwrite or delete prior entries. If a
  decision changes, append a new entry describing the revision.
- **Eval scripts pin their judge model version** (currently `claude-haiku-4-5`
  in `journaling/evals/eval-score.sh`, and `gpt-5.4-mini` for the Codex Level 1
  gate in `journaling/hooks/codex-stop.sh`). Don't swap to a different/more
  expensive model without explicit instruction, and re-baseline scores if a
  pinned model string ever changes — silent model drift invalidates score
  comparisons.

## Common commands

These are skill-installation and smoke-test commands, not a build pipeline —
run them when installing or verifying the `journaling` skill in a target
project (not in this repo itself):

```bash
# Initialize the two journal files in a target project
bash journaling/scripts/journal-init   # creates ./docs/dev_journal.md and ./docs/product_insights.md

# Score the last N journal entries against the rubric (Level 2 eval)
bash journaling/evals/eval-score.sh [N|--all]   # default N=10; requires python3 and `claude --print` on PATH

# Install Claude Code hooks/skills globally — see journaling/adapters/claude-code.md
# Install Codex hooks/skills globally       — see journaling/adapters/codex.md
```

Full install/smoke-test steps (hook registration JSON, expected log output,
compaction test) are in `journaling/README.md` under "Installation Quickstart"
and in `handoff.md` under "P0 — Must do to make this usable".
