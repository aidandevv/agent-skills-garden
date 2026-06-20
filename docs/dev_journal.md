# Engineering Development Journal
> Chronological log of architecture decisions, implementation pivots,
> constraint discoveries, verification results, and engineering milestones.

---

### [CP-MILESTONE] | 2026-06-20: Transfer Artifact Removed From Repository History

**Summary:** Removed the Claude-to-Codex transfer handoff artifact from the repository and rewrote the single root commit so the public branch no longer carries it. Added Mermaid diagrams to the README surfaces without changing the existing explanatory copy.

**Files/Modules Affected:** `.gitignore`, `README.md`, `journaling/README.md`, `journaling/docs/example-entries.md`, Git refs/history.

**Key Trade-off:** Chose a history rewrite and force push because the artifact had been committed in the root commit; a normal deletion would have left it recoverable from branch history.

**Evidence:** `git log --all -- handoff.md` returned no commits, `git rev-list --objects --all | rg '(^| )handoff\.md$'` returned no reachable objects, and `git status --short --branch` showed `main...origin/main` clean.

**Follow-ups:** GitHub may retain server-side unreachable objects for a period after force-push; contact GitHub support if the artifact must be purged from provider backups or caches.

---

### [CP-MILESTONE] | 2026-06-20: README Research Section Reframed for GitHub

**Summary:** Reworked the root README presentation so the implemented skill is the only visible garden entry, the research foundation opens with an executive summary, and the detailed source list is collapsible with source titles carrying the links.

**Files/Modules Affected:** `README.md`, `docs/dev_journal.md`.

**Key Trade-off:** Kept the detailed research bibliography intact for credibility while moving it behind a GitHub-supported disclosure block so the README reads cleaner on first pass.

**Evidence:** Verified the markdown structure with `sed`, `git diff -- README.md`, and `rg` checks for `travel`, `Research Foundation`, `<details>`, and `</details>`.

**Follow-ups:** None identified.

---

### [CP-MILESTONE] | 2026-06-20: Journaling Skill Roles Made Visible in READMEs

**Summary:** Added a compact root README subtable for the engineering and product journal skills, then expanded `journaling/README.md` with a dedicated two-journal explanation, examples, and cross-log diagram.

**Files/Modules Affected:** `README.md`, `journaling/README.md`, `docs/dev_journal.md`, `docs/product_insights.md`.

**Key Trade-off:** Kept the root README concise for portfolio scanning while moving the fuller examples and operational nuance into the journaling README.

**Evidence:** Verified the markdown diff and Mermaid fences with `git diff -- README.md journaling/README.md` and `rg` checks for journal skill links, Mermaid blocks, and output-file references.

**Follow-ups:** None identified.

> **[CROSS-LOG]** Product-facing README clarity logged in `./docs/product_insights.md`
> — see [PI-POSITIONING] | 2026-06-20: Journal Roles Need to Be Visible Before Installation.

---

### [CP-MILESTONE] | 2026-06-20: README Skill Presentation Shifted to Abstract Blocks

**Summary:** Reworked the README skill presentation from catalog/table-first into block-style explanations, with `journaling/` framed as a live project-memory layer and the two subskills described as nested decision/insight logs.

**Files/Modules Affected:** `README.md`, `journaling/README.md`, `docs/dev_journal.md`, `docs/product_insights.md`.

**Key Trade-off:** Preserved scan-friendly metadata tables where useful, but moved the motivation and value proposition into prose blocks so the public README flows more like an authored portfolio artifact.

**Evidence:** Read back the top sections of both READMEs and reviewed `git diff -- README.md journaling/README.md`.

**Follow-ups:** None identified.

> **[CROSS-LOG]** Product-facing positioning change logged in `./docs/product_insights.md`
> — see [PI-POSITIONING] | 2026-06-20: Journaling Should Read Like a Live Memory Layer.

---
