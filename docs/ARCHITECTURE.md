# Architecture

The vault implements the **LLM Wiki** pattern: a strict separation between immutable raw inputs and a Claude-maintained structured wiki, governed by a rulebook (`CLAUDE.md`) and driven by skills.

## Two-zone model

```
raw/   →   Claude (skills + CLAUDE.md)   →   wiki/
(inputs, immutable)                          (structured, cross-linked)
```

- **`raw/`** is append-only from your side and read-only for Claude. Sources are grouped by kind: `slack/`, `meetings/`, `designs/`, `sessions/`, `prs/`, `web/`, `mcp/`, `learnings/`. Grouping subfolders are allowed (e.g. `raw/designs/project-x/`).
- **`wiki/`** is written only by Claude, following the rules in [`CLAUDE.md`](../CLAUDE.md).

## Wiki page types

| Type | Folder | Purpose |
|------|--------|---------|
| **Project hub** | `wiki/projects/` | Canonical "re-orient" page per project: status, open action items, recent activity, key decisions, design links. |
| **Source summary** | `wiki/sources/` | One structured summary per ingested raw source. |
| **Design doc** | `wiki/designs/` | Processed design/RFC with status, decisions, open questions. |
| **Topic** | `wiki/topics/` | Concept/technology page, grown when a topic appears in 2+ sources. |

Plus five singletons at the wiki root:

| File | Role |
|------|------|
| `index.md` | Master index of every page, by category, + recent sources. |
| `overview.md` | "State of my world" — one-liner status per active project. |
| `action-items.md` | Aggregated open action items with backlinks and lifecycle state. |
| `manifest.md` | Ingestion status of every file in `raw/`. |
| `log.md` | Chronological record of every wiki operation. |

Every page carries YAML frontmatter with a `type` and a `last_touched` date. Schemas and required sections are defined in `CLAUDE.md`.

## The skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `vault-ingest` | "ingest", drops a file in `raw/` | Scans `raw/` vs manifest, runs the 7-step ingest workflow. |
| `vault-pr-ingest` | pastes a GitHub PR link | Fetches PR via `gh`, saves to `raw/prs/`, ingests. |
| `vault-slack-ingest` | pastes a Slack link | Fetches thread via Slack MCP, saves to `raw/slack/`, ingests. |
| `vault-learning` | "save this learning" | Captures a codebase insight from the current chat into `raw/learnings/`, ingests as a topic. |
| `vault-query` | asks a question about their work | Searches wiki (then raw), synthesizes a cited answer. |
| `vault-briefing` | "catch me up", "briefing on X" | Reads hubs/overview/action-items, synthesizes a briefing. |

All ingest-family skills converge on the **same 7-step workflow** in `CLAUDE.md` (read & extract → source page → update dependents → manifest → index → log).

## The ingest workflow

```
1. Scan       raw/ vs manifest  →  new / stale / already-ingested
2. Extract    decisions, action items, people, projects, PRs, questions, topics
3. Source     write wiki/sources/YYYY-MM-DD-slug.md
4. Dependents update project hubs, designs, topics, action-items, overview
5. Manifest   record raw_modified + ingested dates
6. Index      add pages, refresh Recent Sources
7. Log        append the operation
```

Re-ingesting a **stale** source (raw file modified after last ingest) updates existing pages in place — operations are idempotent, never duplicating.

## Session capture (hooks)

```
Claude Code session ends
        │
        ▼
SessionEnd hook → hooks/vault/session-capture.sh
        │  (reads transcript_path + session_id from stdin)
        ▼
summarize-session.sh  (pure bash + jq, no LLM)
        │  extracts: ask, follow-ups, final summary, PR/doc links,
        │            files touched, tool activity, projects, git branch
        ▼
raw/sessions/YYYY-MM-DD-HH-MM-<id>-session.md
```

- Deterministic: everything is pulled straight from the transcript with `jq` — no model call, so it's fast and free.
- Idempotent: the filename embeds the timestamp + a session-id fragment; re-running overwrites the same file.
- `backfill-sessions.sh` replays the summarizer over every historical transcript in `~/.claude/projects/`, skipping sessions already captured.

Captured sessions are just another raw source — say "ingest" to fold them into project hubs and the timeline.

## Portability

Skills and hooks ship with a `{{VAULT_DIR}}` placeholder. `install.sh` substitutes the real clone path at install time and writes resolved copies into `~/.claude/`. That's why the tools work from any working directory and why moving the repo just means re-running the installer.

## Maintenance / lint

`lint the vault` runs eight checks defined in `CLAUDE.md`: stale pages, expired sources, orphan pages, overdue action items, manifest drift, frontmatter validation, broken `[[links]]`, and index drift — with a summarized report.
