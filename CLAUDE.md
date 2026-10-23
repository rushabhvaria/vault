# Vault Wiki — Claude Code Instructions

You are maintaining a personal knowledge base ("second brain"). This vault follows the "LLM Wiki" pattern: raw sources arrive in `raw/`, you process them into structured, interlinked wiki pages in `wiki/`.

Your job is to keep the wiki accurate, current, cross-referenced, and useful as a persistent memory system.

## Architecture

```
vault/
├── raw/                    # IMMUTABLE inputs — user adds, you read
│   ├── slack/              # Slack thread exports
│   ├── meetings/           # Meeting notes & transcripts
│   ├── designs/            # Technical design docs, RFCs (may contain subfolders for grouping)
│   ├── sessions/           # Auto-captured Claude Code session summaries
│   ├── prs/                # GitHub PR snapshots
│   ├── web/                # Web articles / clippings
│   ├── mcp/                # MCP server docs & configs
│   └── learnings/          # Codebase insights captured mid-chat
│
├── wiki/                   # YOU maintain this — structured knowledge base
│   ├── projects/           # One page per project (hub pages)
│   ├── designs/            # Processed design doc summaries + status
│   ├── topics/             # Concept/technology pages (grown organically)
│   ├── sources/            # One summary page per ingested raw source
│   ├── index.md            # Master index of all wiki pages
│   ├── action-items.md     # Aggregated open action items
│   ├── overview.md         # High-level "state of my world"
│   ├── manifest.md         # Ingestion status of all raw files
│   └── log.md              # Chronological record of all operations
│
├── templates/              # Page templates (reference, do not modify)
└── CLAUDE.md               # THIS FILE — your instructions
```

## Golden Rules

1. **Never modify files in `raw/`.** Raw sources are immutable inputs.
2. **Every wiki change must update `wiki/log.md`.** No silent modifications.
3. **Every ingested source must be tracked in `wiki/manifest.md`.**
4. **Cross-reference aggressively.** Use `[[wiki-links]]` between all related pages.
5. **Frontmatter is mandatory.** Every wiki page must have valid YAML frontmatter matching its type schema.
6. **`last_touched` must be updated** on every page you modify. Format: `YYYY-MM-DD`.
7. **Idempotent operations.** Re-ingesting a source updates existing pages; it does not create duplicates.
8. **Preserve user content.** If the user has manually edited a wiki page, preserve their additions. Merge, do not overwrite.

## Page Types & Frontmatter Schemas

### Project Hub (`wiki/projects/*.md`)

```yaml
---
type: project
status: active | paused | completed
last_touched: YYYY-MM-DD
created: YYYY-MM-DD
tags: [team-name, domain-name]
---
```

**Purpose:** The canonical "re-orient" page for a project. Contains everything needed to regain context after time away.

**Required sections:**
- **Status** — Current state in 2-3 sentences
- **Open Action Items** — Checkbox list with backlinks: `- [ ] item — @assignee — due: YYYY-MM-DD — [[source-page]]`
- **Recent Activity** — Reverse-chronological, last 10 items: `- YYYY-MM-DD: description — [[source-page]]`
- **Key Decisions** — Numbered list: `1. YYYY-MM-DD: Decision text — [[source-page]]`
- **Design Docs** — Links to `wiki/designs/` pages
- **Related** — Links to `wiki/topics/` and other `wiki/projects/` pages

**File naming:** `wiki/projects/{project-slug}.md` — lowercase, hyphens, no spaces.

### Source Summary (`wiki/sources/*.md`)

```yaml
---
type: source
source_type: slack | meeting | design | session | pr | mcp | web | learning
raw_path: raw/path/to/file.md
ingested: YYYY-MM-DD
projects: [project-slug]
expires: YYYY-MM-DD  # optional — for time-sensitive sources
---
```

**Purpose:** Structured summary of one ingested raw source.

**Required sections:**
- **Summary** — 2-5 sentences capturing the essence
- **Key Points** — Bullet list of important information extracted
- **Decisions** — Any decisions made (with who decided and context)
- **Action Items** — `- [ ] action — @person — due: YYYY-MM-DD` (due date optional)
- **Open Questions** — Unresolved questions
- **Links** — Backlinks to project hubs, related sources, topics

**File naming:** `wiki/sources/YYYY-MM-DD-{descriptive-slug}.md`. If multiple sources share a date, add a numeric suffix: `2026-04-10-standup-2.md`

### Design Doc (`wiki/designs/*.md`)

```yaml
---
type: design
status: draft | in-review | approved | superseded
project: project-slug
raw_path: raw/designs/original-file.md
last_touched: YYYY-MM-DD
superseded_by: design-slug  # only if status is superseded
---
```

**Required sections:**
- **Summary** — 1 paragraph
- **Status** — Current review/approval status
- **Key Decisions** — Extracted from the design
- **Open Questions** — Unresolved design questions
- **Related** — Links to project hub, other designs, topics

**File naming:** `wiki/designs/{descriptive-slug}.md`

### Topic (`wiki/topics/*.md`)

```yaml
---
type: topic
last_touched: YYYY-MM-DD
created: YYYY-MM-DD
tags: [category]
---
```

**Purpose:** Concept, technology, or domain knowledge page. Grown organically as topics emerge from sources.

**Required sections:**
- **Overview** — What this is
- **Context** — How it relates to our work
- **Key Facts** — Important details
- **Sources** — Backlinks to `wiki/sources/` pages
- **Related** — Links to other pages

**File naming:** `wiki/topics/{topic-slug}.md`

**When to create:** When a concept, technology, team, or system is referenced in 2+ sources and warrants its own persistent reference page. Do not create topic pages for trivially simple concepts.

## Ingest Workflow

When asked to ingest raw sources (or when detecting un-ingested files in `raw/`), follow this procedure exactly:

### Step 1: Scan

Recursively scan all subdirectories of `raw/` for files. Subdirectories within `raw/` categories are allowed for grouping related sources (e.g., `raw/designs/my-project/`). The `raw_path` in the manifest and source pages must include the full relative path from the vault root.

Read `wiki/manifest.md` and compare against actual files to identify:
- **New files:** present in `raw/` but not in manifest
- **Stale files:** present in manifest but `raw_modified` < actual file modification date (file was updated since last ingest)
- **Already ingested:** present in manifest and current

Report what you found before proceeding.

### Step 2: Read & Extract

For each file to ingest, read the raw source and extract:
- **Decisions** made or recorded
- **Action items** with assignee and due date where available
- **People** mentioned (use @name format)
- **Projects** referenced (map to existing `wiki/projects/` slugs or propose new ones)
- **PRs** created, reviewed, or referenced (format: `org/repo#number`)
- **Open questions** that remain unresolved
- **Key facts** worth persisting as knowledge
- **Topics** that could warrant their own page

### Step 3: Create/Update Source Page

Create `wiki/sources/YYYY-MM-DD-{slug}.md` using the source summary template.

If re-ingesting (stale file), update the existing source page. Add a note at the top:
```
> Re-ingested on YYYY-MM-DD. Changes from previous version noted below.
```

### Step 4: Update Dependent Pages

For each source ingested, update ALL relevant pages:

1. **Project hub pages** (`wiki/projects/`):
   - Add to Recent Activity
   - Merge new action items into Open Action Items
   - Update Status if the source changes project state
   - Add new decisions to Key Decisions
   - Add new design doc links if applicable

2. **Design doc pages** (`wiki/designs/`):
   - Update status if the source mentions review/approval
   - Add new decisions or open questions

3. **Action items** (`wiki/action-items.md`):
   - Add new action items with backlinks to source page
   - Check off completed items if source indicates completion
   - Group by project, then by assignee

4. **Topic pages** (`wiki/topics/`):
   - Add the new source to the Sources section of related topic pages
   - Add relevant key facts

5. **Overview** (`wiki/overview.md`):
   - Update if the source materially changes project status or introduces new work

6. **Create new pages** as needed:
   - New project hub if a previously-unknown project is referenced
   - New topic page if a concept crosses the 2-source threshold
   - New design page if a raw design doc was ingested

### Step 5: Update Manifest

Add or update the row in `wiki/manifest.md`:

```
| raw/slack/2026-04-10-thread.md | ingested | [[2026-04-10-thread-summary]] | 2026-04-10 | 2026-04-10 |
```

The `raw_modified` column should reflect the file's actual last-modified date. The `ingested` column should reflect today's date. When a file is re-ingested, update BOTH columns.

### Step 6: Update Index

Rebuild the sections of `wiki/index.md`:
- Add new pages to their category
- Keep alphabetical within each section
- Update the "Recent Sources" section (most recent 10)

### Step 7: Log the Operation

Append to `wiki/log.md`:

```
| 2026-04-10 14:30 | ingest | Ingested raw/slack/2026-04-10-thread.md → [[2026-04-10-thread-summary]]. Updated [[project-slug]], [[action-items]]. |
```

## Cross-Referencing Rules

Use Obsidian wiki-link syntax: `[[page-name]]` (without path prefix — Obsidian resolves these).

### Mandatory Links

- Source pages MUST link to: their project hub(s), any referenced topics, any related source pages
- Project hubs MUST link to: all their source pages, design docs, related topics
- Design docs MUST link to: their project hub, related topics
- Action items page MUST link to: the source page where each item originated
- Topic pages MUST link to: all source pages that discuss the topic

### Bidirectional Linking

When you add a link from page A to page B, verify that page B also links back to page A. Obsidian shows backlinks automatically, but explicit links in the "Related" or "Sources" section improve readability.

## Action Item Tracking

### Format

Action items use this format everywhere they appear:

```markdown
- [ ] Description of the action — @assignee — due: YYYY-MM-DD — [[source-page]]
```

`@assignee` and `due:` are optional but preferred when available from the source.

### Lifecycle

1. **Created:** Extracted from a source during ingest
2. **Open:** Default state. Lives on the source page AND mirrored in `wiki/action-items.md` AND on the project hub
3. **Completed:** Check the box `- [x]` on all three locations. Add completion date: `(completed YYYY-MM-DD)`
4. **Expired:** Source had an `expires` date that has passed. Move to "Recently Completed" section of `action-items.md`
5. **Auto-expired:** PR-linked items auto-expire when the PR is merged/closed

### Staleness Detection

An action item is **stale** if:
- The source page's `last_touched` is more than 90 days ago AND the item is still open
- Flag stale items in `wiki/action-items.md` under a "Stale" section

### PR-Linked Items

When an action item references a PR (e.g., "Review PR org/repo#1234"):
- If subsequent sources indicate the PR was merged/closed, mark the item complete
- Add note: `(PR merged YYYY-MM-DD)`

## Staleness & Expiration Rules

### Page Staleness

A page is **stale** if:
- `type: project` with `status: active` and `last_touched` > 90 days ago
- `type: design` with `status: draft | in-review` and `last_touched` > 90 days ago

### Source Expiration

A source expires when:
- Its `expires` frontmatter date has passed
- The source discussed a time-sensitive event (standup, sprint review) and is > 30 days old

When a source expires:
- Do NOT delete it
- Add `expired: true` to frontmatter
- Remove its action items from active sections of `action-items.md` (move to "Recently Completed")
- Keep links intact for historical reference

### Manifest Staleness

A manifest entry is stale when the raw file's actual modification time is newer than the `raw_modified` date recorded in the manifest. This means the raw source was updated and needs re-ingestion.

## Lint & Maintenance

When asked to "lint", "maintain", or "health-check" the vault, check ALL of the following:

### 1. Stale Pages
Scan `wiki/projects/*.md` and `wiki/designs/*.md` for staleness.
**Output:** List of stale pages with days since last touched.

### 2. Expired Sources
Scan `wiki/sources/*.md` for expired sources.
**Output:** List of expired sources and recommended actions.

### 3. Orphan Pages
Find pages in `wiki/` with zero inbound links from other wiki pages.
**Output:** List of orphans with recommendation to link or archive.

### 4. Overdue Action Items
Scan `wiki/action-items.md` for items past due date.
**Output:** List grouped by project.

### 5. Manifest Drift
Compare `raw/` contents against `wiki/manifest.md`.
**Output:** Un-ingested files, stale entries, missing raw files.

### 6. Frontmatter Validation
Check every `wiki/**/*.md` for: missing frontmatter, missing required fields, invalid dates, invalid status enums.
**Output:** List of validation errors.

### 7. Broken Links
Find `[[wiki-links]]` that point to non-existent pages.
**Output:** List with source file.

### 8. Index Drift
Verify `wiki/index.md` lists all pages in `wiki/`.
**Output:** Missing or phantom entries.

### Report Format

```markdown
## Vault Lint Report — YYYY-MM-DD

### Stale Pages (X found)
...
### Expired Sources (X found)
...
### Orphan Pages (X found)
...
### Overdue Action Items (X found)
...
### Manifest Drift (X issues)
...
### Frontmatter Errors (X found)
...
### Broken Links (X found)
...
### Index Drift (X issues)
...

### Summary
- Total issues: N
- Critical: N
- Warnings: N
```

## Query Handling

When the user asks a question about their work, projects, or knowledge:

1. **Search wiki first.** Check relevant project hubs, recent sources, topic pages, action items.
2. **Search raw if needed.** If wiki doesn't have the answer, grep `raw/`.
3. **Synthesize an answer** from multiple sources. Always cite which pages informed the answer.
4. **Offer to persist.** If the answer is reusable, offer to file it into the wiki.

### Project Briefings

When asked for a "briefing" on a project:
1. Read the project hub page
2. Read the 5 most recent source pages linked to that project
3. Read relevant action items
4. Synthesize: status, recent changes, open items, blockers, next steps
5. Offer to update the hub if the briefing revealed stale info

### Morning Briefings

When asked for a general status or "morning briefing":
1. Read `wiki/overview.md`
2. Read `wiki/action-items.md`
3. Scan project hubs with `status: active`
4. Synthesize: what happened recently, what needs attention, upcoming deadlines
5. Update `wiki/overview.md` with the briefing content

## Conventions

### Dates
- Frontmatter: `YYYY-MM-DD`
- Log entries: `YYYY-MM-DD HH:MM`
- Prose: spell out month (`April 10, 2026`)

### File Naming
- All lowercase, hyphens between words (no spaces, no underscores)
- Source pages prefixed with date: `YYYY-MM-DD-slug.md`
- Maximum 60 characters for filename (excluding `.md`)

### Markdown Style
- H1 for page title (matches filename slug, expanded to title case)
- H2 for major sections
- H3 for subsections
- Bullet lists for unordered items
- Numbered lists only for sequences or ranked items
- `>` blockquotes for direct quotes from sources
- `---` horizontal rules between major sections

### Tags
- Use frontmatter `tags` array, not inline `#tags`
- Tags are lowercase, hyphenated: `ads-team`, `ml-platform`, `agent-framework`

## What NOT To Do

- Do NOT modify files in `raw/` — ever
- Do NOT modify `CLAUDE.md` (this file) or `.obsidian/` config
- Do NOT create files outside `wiki/`, `raw/sessions/`, or `templates/`
- Do NOT create deeply nested subdirectories in `wiki/`
- Do NOT duplicate information across pages — link instead
- Do NOT leave placeholder text from templates — fill in or remove sections
- Do NOT commit changes — the user handles version control
