# agent-skills-garden

A personal collection of reusable agent skills built on the Agent Skills open
standard. Each top-level folder is self-contained and droppable into any
project or global skill directory.

---

## Skills in This Garden

| Skill | Status | Description |
|---|---|---|
| [`journaling/`](./journaling/) | ✅ v2.0 | Dual-journal system for engineering decisions and product insights |
| `travel-agent/` | 🔲 Planned | — |

```mermaid
flowchart LR
  Garden["agent-skills-garden"] --> Journaling["journaling/"]
  Garden --> Travel["travel-agent/<br/>planned"]

  Journaling --> Skills["skills/<br/>procedures"]
  Journaling --> Hooks["hooks/<br/>lifecycle automation"]
  Journaling --> Adapters["adapters/<br/>tool config"]
  Journaling --> Evals["evals/<br/>quality checks"]
  Journaling --> Docs["docs/<br/>examples"]
```

---

## How to Use These Skills

**Drop into a project:**
Copy the folder (e.g. `journaling/`) to your project root or to
`~/.claude/skills/` / `~/.codex/skills/`. Run the `scripts/` init script.
Follow the `adapters/` instructions for your tool.

**Reference from this repo:**
Point your CLAUDE.md or AGENTS.md at the skill path in this repo. Useful
during active development of a skill before it's been promoted to your
global install.

**Tool compatibility:**
All SKILL.md files follow the Agent Skills open standard (released by
Anthropic December 18, 2025, subsequently adopted by OpenAI Codex CLI,
Google Gemini CLI, GitHub Copilot, and Cursor). They work without
modification across all compliant runtimes. Hooks and adapters are
tool-specific and live in separate files.

---

## Research Foundation

This repo engages with the following body of work. These sources informed
the design of every skill here — particularly the context engineering
constraints, the Agent Skills architecture, the hook-layer integration
patterns, and the eval methodology.

### Context Engineering

**Lost in the Middle: How Language Models Use Long Contexts**
Liu et al., 2023 — arXiv:2307.03172
The foundational paper documenting U-shaped positional attention bias in
LLMs. Information at the start and end of context is attended to far more
reliably than information in the middle. Core implication for skill design:
important triggers and output format instructions must appear near the top
of any protocol file. Informs why SKILL.md files are short and front-loaded.

**A Survey of Context Engineering for Large Language Models**
Mei et al., 2025 — arXiv:2507.13334
Coined "context engineering" as the systematic discipline of curating what
enters the context window. Distinguishes four operations: writing, selecting,
compressing, and isolating information. The framework this repo uses to
think about skill file design.

**Effective Context Engineering for AI Agents**
Anthropic, September 2025 — anthropic.com/engineering
Anthropic's formalization of context engineering as the primary design
discipline for reliable agents. Documented how agents processing large
codebases routinely exceed available context through sequential tool calls.

**Context Rot and Long-Context Degradation**
Chroma / StackOne, 2025 — stackone.com/blog/agent-suicide-by-context
A Chroma study tested 18 frontier models and found every one degrades as
context fills, through lost-in-the-middle effects, attention dilution, and
distractor interference. Model correctness starts dropping after 32K tokens.
Motivates keeping SKILL.md files under ~200 lines.

**Knowledge Activation: AI Skills as the Institutional Knowledge Primitive**
2026 — arXiv:2603.14805
Documents the three constraints defining the context window economy: token
budget (hard limit), attention decay (effective capacity is smaller than
nominal), and latency cost (inference cost scales with context). Informs the
strict separation between skill instructions (SKILL.md, always lean) and
design rationale (README, never loaded by agents).

**Externalization in LLM Agents: Memory, Skills, Protocols and Harness Engineering**
2026 — arXiv:2604.08224
"Agentic memory stores what the agent learned; skills store how the agent
should act. Both keep information outside the context window until needed."
The conceptual foundation for the skill/journal split in this repo.

**Less Context, Better Agents: Efficient Context Engineering**
2026 — arXiv:2606.10209
Shows that for tool-heavy single-session workflows, a lightweight recency
window plus a compact running summary is sufficient — no external store or
retriever required. Informs the journal-as-external-memory design.

### Agent Skills Open Standard

**Equipping Agents for the Real World with Agent Skills**
Anthropic Engineering, December 2025 — anthropic.com/engineering
The announcement and design rationale for Agent Skills. Introduced progressive
disclosure: name + description (~30–50 tokens) at discovery, full SKILL.md
on activation, referenced files and scripts only during execution.

**Agent Skills Open Standard**
agentskills.io — Released December 18, 2025
The official specification. Three-stage loading: Discovery → Activation →
Execution. The format this repo's SKILL.md files follow.

**Progressive Disclosure as a System Design Pattern**
SwirlAI Newsletter, March 2026
"The SKILL.md file organizes information into three layers. The platform
implements the loading logic, deciding when to promote from one layer to the
next." Explains why the open standard achieved immediate cross-platform
adoption.

**Configuration Smells in AGENTS.md Files**
2026 — arXiv:2606.15828
Documents anti-patterns in agent configuration: context bloat, skill leakage,
conflicting instructions. Referenced in the skill authoring guidelines.

**How to Build Your AGENTS.md**
Augment Code, June 2026 — augmentcode.com/guides/how-to-build-agents-md
An ETH Zurich study found LLM-generated context files reduced task success
rates ~3% and increased inference cost >20%. Human-curated files provided
a marginal 4% gain but still incurred token overhead. Justifies keeping
CLAUDE.md / AGENTS.md adapters under 15 lines.

### Hook-Layer Integration

**Claude Code Hooks — Complete Guide**
Konishi, June 2026 — hidekazu-konishi.com
Comprehensive reference for all Claude Code hook events, exit-code protocol,
tool matchers, and settings.json hierarchy.

**All 30 Claude Code Hook Events**
MorphLLM, June 2026 — morphllm.com/claude-code-hooks
Documents the full event list including `SessionEnd` (receives `transcript_path`),
`PreCompact`, `PostCompact`, `TaskCreated`, and `TaskCompleted`.

**SessionEnd vs Stop**
luongnv89/claude-howto, 2026 — GitHub
"Stop fires after every Claude response. SessionEnd fires once when the
session terminates — exactly what you want for an end-of-session diary entry."
Informs the choice of `SessionEnd` (not `Stop`) for Claude Code journaling.

**PreCompact and PostCompact Hooks**
Developers Digest, April 2026 — developersdigest.tech
"PreCompact fires just before Claude summarizes older turns. It can block the
compaction, customize the summary strategy, or persist important context before
it gets condensed." Core hook used for compaction-boundary journal capture.

**Claude Code Compaction and Long-Session Operations Guide**
Konishi, June 2026 — hidekazu-konishi.com
"The PreCompact hook fires immediately before a compaction, with a matcher
that distinguishes manual (/compact) from automatic triggers." Documents
the exact integration pattern used in `pre-compact.sh`.

**Claude Code Compaction Kept Destroying My Work**
Adolan, DEV Community, April 2026
Documents PreCompact + PostCompact as the production pattern for persistent
memory across compaction events, including the subshell pattern for making
PreCompact hooks crash-safe.

**precompact-hook by mvara-ai**
GitHub — mvara-ai/precompact-hook
"The hook fires at the death boundary — the moment between full context and
compaction. A subagent called from the hook has an empty context window,
meaning it can dedicate full attention to interpreting the session." Informed
the snapshot prompt design in `pre-compact.sh`.

**Codex CLI Hooks Reference**
OpenAI Developers, April 2026 — developers.openai.com/codex/hooks
Codex supports the same hook event schema as Claude Code via `hooks.json`
or inline `config.toml`. `TaskCompleted` is a supported event alongside
`Stop`, `SessionStart`, `PreCompact`, and `PostCompact`.

**Codex CLI v0.124.0 — Hooks Engine Stable**
Blake Crosley, June 2026 — blakecrosley.com/guides/codex
As of v0.124.0 (April 23, 2026) the Codex CLI hooks engine is marked stable.
New hook events continue to ship in releases.

**Codex CLI Issue #17532**
GitHub openai/codex, April 2026
Project-local `.codex/config.toml` hook config does not fire in interactive
sessions as of v0.120. Recommends global `~/.codex/hooks.json` until resolved.
Informs the adapter's installation note.

**Claude Code vs Codex CLI 2026 Decision Reference**
Blake Crosley — blakecrosley.com/blog/claude-code-vs-codex
Documents `TaskCreated` and `TaskCompleted` as confirmed Claude Code lifecycle
events (v2.1.141+), also available in Codex's hook schema. Confirms the
technical basis for `TaskCompleted`-based per-task checkpointing.

### Eval Methodology

**LLM Agent Evaluation Metrics in 2026**
Confident AI, June 2026 — confident-ai.com
Distinguishes agent tracing (what happened) from agent evaluation (whether
the right decisions were made). Covers tool calling, planning effectiveness,
task completion, and trajectory-level evaluation. Basis for the Level 4
behavioral eval design.

**Rubric-Based Evals & LLM-as-a-Judge**
Medium / Masood, April 2026
"Analytic rubrics score criterion-by-criterion. This is the cornerstone of
modern Eval Ops; it allows for regression root-cause analysis that a single
holistic score cannot provide." Basis for the five-dimension rubric in
`evals/rubric.md`.

**LLM as a Judge — Primer and Pre-Built Evaluators**
Arize AI, 2026 — arize.com/llm-as-a-judge
"A judge model applies a written rubric to outputs and returns structured
scores. You define what 'good' looks like once; the judge applies it
consistently across thousands of traces." The pattern used in `eval-score.sh`.

**LLM-as-judge for Multi-Step Agent Evaluation**
Vinod Rane, Medium, May 2026
"Locking judge model versions is now a standard engineering requirement, not
optional. A model provider quietly updating the underlying LLM can change
scoring without any alert." Informs the judge model pinning requirement in
the Level 4 plan.

**MCP-Bench: Benchmarking Tool-Using LLM Agents**
arXiv:2508.20453
Uses an LLM-as-judge framework scoring across task completion quality, tool
selection rationale, and planning effectiveness. The judge is provided task
description, final solution, and summarized execution trace. Informs the
Level 4 behavioral eval methodology.

**A Comprehensive Survey of Self-Evolving AI Agents**
arXiv:2508.07407
Documents LLM-as-a-Judge in pointwise mode (scoring each output independently
against a rubric) as the standard for scalable evaluation. Notes that LLM
judges can correlate with human judgments, reaching inter-annotator agreement
levels in some domains.

### Product Discovery and Product Strategy

*(Informing the product-insight-journal skill)*

**Continuous Discovery Habits**
Teresa Torres / Product Talk — producttalk.org
Product insight should be tied to recurring user touchpoints and desired
product outcomes, not one-off feature ideas.

**Opportunity Solution Trees**
Teresa Torres / Product Talk — producttalk.org
Product notes should connect outcomes, opportunities, solutions, and
experiments. Informs the hypothesis and decision fields in the full schema.

**Jobs to Be Done**
Christensen Institute — christenseninstitute.org
Product observations should capture the functional, social, and emotional
context behind user behavior. Informs the JTBD lens in the full entry schema.

**Four Big Risks**
Silicon Valley Product Group — svpg.com
Product observations should help de-risk value, usability, feasibility, and
business viability. Informs the Product Risk Lens field.

**Feature Documentation Research**
arXiv:2208.01317
Product-feature knowledge in GitHub projects is often fragmented and weakly
linked to implementation context. Motivates the dual-journal system with
explicit cross-referencing rather than a single mixed-concern log.

---

## Repo Philosophy

**Skills are procedures, not documents.** SKILL.md files contain only what
the agent needs to act. Design rationale and research live in READMEs that
agents never load.

**Hooks make reliability deterministic.** Model-driven journaling is
probabilistic. Hooks fire on every qualifying lifecycle event regardless of
model attention. The combination produces reliable coverage.

**Evals close the loop.** A skill without evals is a guess. Even a simple
Level 1 gate tells you whether the system is working session by session.
Level 2 rubric scoring tells you where it's weakest. The eval stack is part
of the skill, not an afterthought.

**Progressive disclosure keeps everything lean.** ~30–50 tokens at discovery,
full skill on activation, referenced files only during execution. This is
the Agent Skills contract and this repo honors it in every file.
