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
