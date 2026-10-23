---
name: vault-learning
description: "Use when the user says 'save this learning', 'capture what you learned', 'remember this about the codebase', or wants to persist an insight discovered during the current chat. Writes the learning + details to the vault's raw/learnings/ and runs the vault ingest workflow."
---

# Codebase Learning Ingest

## When This Triggers
- User says "save this learning", "capture this", "remember what you learned"
- User asks to persist an insight discovered while exploring or working on the codebase in the current chat
- A non-obvious fact about how the code works, why something is the way it is, or how a problem was solved came up this session and is worth keeping

## What Counts as a Learning
Something discovered *in this conversation* that isn't obvious from reading the code cold:
- How a subsystem actually works (control flow, data flow, hidden coupling)
- Why something is the way it is (a constraint, a gotcha, a historical reason)
- How a bug was root-caused and fixed, and what the underlying cause was
- A pattern, convention, or invariant the codebase relies on
- A tricky reproduction or debugging technique that worked

Do NOT capture: things trivially readable from the code, generic language/library facts, or session logistics.

## Workflow

### Step 1: Extract the Learning from This Chat
Review the current conversation and identify the concrete learning(s). For each, gather:
- **The insight itself** — stated crisply in 1-2 sentences
- **The details** — the reasoning, evidence, and supporting context that back it up
- **Where in the code** — repo, files, functions, line references (`file_path:line`)
- **How it was discovered** — investigation, debugging, reading, asking
- **Why it matters** — what this unblocks or prevents next time

If anything is ambiguous, ask the user to confirm the phrasing before writing.

### Step 2: Format as Markdown
Create a markdown file with this frontmatter:

```yaml
---
type: learning
title: "{concise learning title}"
repo: {org/repo or local path, if applicable}
topics: [topic-slug]
projects: [project-slug]      # if it maps to a known project
discovered: YYYY-MM-DD
---
```

Sections:
- **Learning** — The insight, stated crisply (1-2 sentences)
- **Details** — Full reasoning, evidence, and supporting context
- **Code References** — Files/functions/lines involved (`file_path:line`)
- **How It Was Discovered** — Brief note on the path to this insight
- **Why It Matters** — What this saves or prevents next time
- **Related** — Any related PRs, designs, or topics

### Step 3: Save to raw/learnings/
Write to `{{VAULT_DIR}}/raw/learnings/YYYY-MM-DD-{descriptive-slug}.md` (lowercase, hyphens, ≤60 chars).
If multiple learnings share a date, add a numeric suffix: `2026-07-24-cache-eviction-2.md`.

Grouping subfolders are allowed for related learnings (e.g. `raw/learnings/ads-serving/`); the `raw_path` in the manifest and source page must include the full relative path.

### Step 4: Ingest
Follow the standard vault ingest workflow from the vault `CLAUDE.md`:
1. Create source summary in `{{VAULT_DIR}}/wiki/sources/` with `source_type: learning`
2. Create or update the relevant `{{VAULT_DIR}}/wiki/topics/` page — a learning almost always belongs to a topic; add the key facts there
3. Link to the relevant project hub if it maps to one
4. Update manifest, index, and log

### Step 5: Report
Tell the user:
- What file was saved to `raw/learnings/`
- What wiki pages were created or updated (topic page especially)
- The one-line learning as it will be remembered
