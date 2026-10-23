---
name: vault-ingest
description: "Use when the user says 'ingest', asks to process raw files, or drops content into the vault's raw/ folder. Scans for new/stale files in raw/ and runs the vault ingest workflow from the vault CLAUDE.md."
---

# Vault Ingest

## When This Triggers
- User says "ingest", "process", "scan raw", or similar
- User drops a file into the vault's `raw/` and asks to process it
- User specifies a file path to ingest

## Workflow

### Step 1: Determine What to Ingest

**If a specific file path is given:**
- Ingest just that file

**If no path given:**
- Read `{{VAULT_DIR}}/wiki/manifest.md` to get current ingestion state
- Recursively scan all subdirectories of `{{VAULT_DIR}}/raw/` for files (including nested grouping folders like `raw/designs/my-project/`)
- Compare against manifest to identify:
  - **New files:** in raw/ but not in manifest
  - **Stale files:** in manifest but raw file modified since last ingest (`raw_modified` is older than actual file modification date)
- Report findings and ask user which to ingest (or ingest all if they say so)

### Step 2: For Each File to Ingest

Follow the 7-step ingest workflow from the vault `CLAUDE.md` exactly:

1. **Read & Extract** — Read the raw file. Extract: decisions, action items, people, projects, PRs, open questions, key facts, topics.

2. **Create/Update Source Page** — Write `{{VAULT_DIR}}/wiki/sources/YYYY-MM-DD-{slug}.md` with frontmatter and structured summary. If re-ingesting, update existing page with change note.

3. **Update Dependent Pages:**
   - Project hubs → Recent Activity, Action Items, Decisions, Status
   - Design docs → Status, decisions, questions
   - Action items → Add new, check off completed
   - Topic pages → Add source reference, key facts
   - Overview → Update if material changes
   - Create new project/topic/design pages as needed

4. **Update Manifest** — Add/update row with current `raw_modified` and `ingested` dates.

5. **Update Index** — Add new pages to categories, keep alphabetical, update Recent Sources (last 10).

6. **Log** — Append operation to `{{VAULT_DIR}}/wiki/log.md`.

### Step 3: Report

After all files are processed, provide a summary:
- Number of files ingested
- Wiki pages created (with links)
- Wiki pages updated (with links)
- Action items extracted
- New projects or topics created
- Any issues or conflicts found

### Notes
- For session files (`raw/sessions/`): Read the transcript path referenced in the file to generate a proper summary. Replace the placeholder content with actual session details.
- For learning files (`raw/learnings/`): These capture insights discovered about the codebase in a chat (see the `vault-learning` skill). Ingest with `source_type: learning`. A learning almost always belongs to a topic — create or update the relevant `wiki/topics/` page with its key facts, and link to the mapped project hub if applicable.
- For re-ingestion: Update existing source pages rather than creating duplicates. Note changes from previous version.
- Always verify cross-references are bidirectional after ingest.
