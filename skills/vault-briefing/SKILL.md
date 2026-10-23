---
name: vault-briefing
description: "Use when the user asks for a briefing, status update, or 'catch me up' on a project or their work in general. Reads the vault wiki and synthesizes a briefing."
---

# Vault Briefing

## When This Triggers
- User says "briefing", "catch me up", "what's the status of X", "morning briefing"
- User asks about open action items or recent activity
- User is switching context to a project and needs to re-orient

## Workflow

### Project Briefing (user asks about a specific project)

1. Read the project hub: `{{VAULT_DIR}}/wiki/projects/{project-slug}.md`
2. Read the 5 most recent source pages linked to that project (check Recent Activity section for links)
3. Read relevant action items from `{{VAULT_DIR}}/wiki/action-items.md` (filter to that project's section)
4. Synthesize a briefing covering:
   - **Current status** — what's happening now
   - **Recent activity** — what happened in the last few days/weeks
   - **Open action items** — what needs to be done, grouped by priority
   - **Blockers** — anything stalling progress
   - **Next steps** — what should happen next
5. Cite wiki pages as sources: "per [[page-name]]..."
6. If the briefing reveals stale info in the hub, offer to update it

### Morning Briefing (general "catch me up")

1. Read `{{VAULT_DIR}}/wiki/overview.md`
2. Read `{{VAULT_DIR}}/wiki/action-items.md`
3. Scan all project hubs with `status: active` in `{{VAULT_DIR}}/wiki/projects/`
4. Synthesize:
   - **Across all projects** — 1-2 sentence status per active project
   - **Needs attention** — overdue items, blockers, stale pages
   - **This week** — what happened, what's upcoming
5. Offer to update `{{VAULT_DIR}}/wiki/overview.md` with the briefing content

### Project Slug Lookup

If the user mentions a project by name, map it to its slug. Check `{{VAULT_DIR}}/wiki/index.md` for the full list of projects and their slugs. If a name is ambiguous, ask the user which project they mean rather than guessing.
