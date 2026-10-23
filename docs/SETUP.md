# Setup Guide

## Prerequisites

- **Claude Code** installed and working.
- **`jq`** — used to parse Claude transcripts and merge `settings.json`.
  - macOS: `brew install jq`
  - Debian/Ubuntu: `sudo apt-get install jq`
- **`gh` CLI** (optional) — authenticated, for `vault-pr-ingest`. Check with `gh auth status`.
- **A Slack MCP server** (optional) — connected to Claude Code, for `vault-slack-ingest`.
- **Obsidian** (optional) — open the repo folder as a vault to browse `[[wiki-links]]` and backlinks visually.

## Install

```bash
git clone https://github.com/rushabhvaria/vault.git
cd vault
./install.sh
```

### What the installer changes

| Location | Change |
|----------|--------|
| `~/.claude/skills/vault-*` | Installs the six skills, with `{{VAULT_DIR}}` resolved to your clone path. |
| `~/.claude/hooks/vault/` | Installs `session-capture.sh`, `summarize-session.sh`, `backfill-sessions.sh` (resolved + executable). |
| `~/.claude/settings.json` | Adds a `SessionEnd` hook pointing at `session-capture.sh`. Backs up the original to `settings.json.bak.<timestamp>` first. |

The installer is **idempotent** — re-running updates skills/hooks in place and won't add a duplicate hook entry.

Custom Claude config dir? Set `CLAUDE_CONFIG_DIR` before running.

## The vault lives in the repo

Your `raw/` and `wiki/` folders are **inside this cloned repo**. That keeps everything in one place and version-controllable. The skills and hooks reference this exact path (baked in at install time), so they work from any Claude Code session regardless of your current working directory.

If you move the repo, just re-run `./install.sh` to re-point everything.

## Recommended: public template, private vault

This repo is safe to share as a **template**. But once you start ingesting, your `raw/` and `wiki/` will hold private notes. Two good options:

1. **Private clone (simplest).** Clone, then either don't push, or point `origin` at a private repo of your own:
   ```bash
   git remote set-url origin git@github.com:<you>/my-vault.git   # a PRIVATE repo
   ```
   `.gitignore` already excludes session captures and OS cruft; commit your `wiki/` if you want history, or add `raw/` and `wiki/` to `.gitignore` to keep them purely local.

2. **Template + separate vault.** Keep this repo read-only for updates, and copy `skills/`, `hooks/`, `templates/`, `CLAUDE.md`, and the empty `raw/`+`wiki/` into a private repo you own; run `install.sh` from there.

## Verify it works

```bash
# Skills installed?
ls ~/.claude/skills | grep vault

# Hook registered?
jq '.hooks.SessionEnd' ~/.claude/settings.json

# End a Claude Code session, then check for a capture:
ls raw/sessions/
```

Then in Claude Code: drop any markdown file into `raw/designs/` and say **"ingest"**. You should get a new `wiki/sources/…` page plus manifest/index/log updates.

## Backfilling past sessions

To summarize Claude Code sessions that predate the install:

```bash
~/.claude/hooks/vault/backfill-sessions.sh
```

It scans `~/.claude/projects/*/*.jsonl`, skips sessions already captured (by `session_id`), and writes summaries into `raw/sessions/`. Then say "ingest" to fold them into the wiki.

## Uninstall

```bash
rm -rf ~/.claude/skills/vault-ingest ~/.claude/skills/vault-query \
       ~/.claude/skills/vault-briefing ~/.claude/skills/vault-learning \
       ~/.claude/skills/vault-pr-ingest ~/.claude/skills/vault-slack-ingest
rm -rf ~/.claude/hooks/vault
# then remove the SessionEnd entry from ~/.claude/settings.json
# (or restore one of the settings.json.bak.* files the installer created)
```

## Troubleshooting

- **`jq: command not found`** — install jq (see prerequisites).
- **No session file after ending a session** — the transcript may have been empty (aborted/metadata-only sessions are skipped by design). Confirm the hook exists with the `jq` check above.
- **PR ingest fails** — run `gh auth status`; authenticate with `gh auth login`.
- **Slack ingest fails** — ensure a Slack MCP server is connected in Claude Code and authenticated.
