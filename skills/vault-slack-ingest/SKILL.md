---
name: vault-slack-ingest
description: "Use when the user pastes a Slack link or asks to ingest a Slack thread. Fetches the thread via a Slack MCP server, saves to the vault's raw/slack/, and runs the vault ingest workflow."
---

# Slack Thread Ingest

## When This Triggers
- User pastes a Slack URL (e.g., `https://your-workspace.slack.com/archives/C.../p...`)
- User says "ingest this slack thread" or similar

## Prerequisites
- A Slack MCP server must be connected to Claude Code (any MCP server that exposes tools to read channel info and thread replies). Without one, this skill cannot fetch thread contents — tell the user to connect a Slack MCP server first. Tool names below are illustrative; adapt to whatever the connected server exposes.

## Workflow

### Step 1: Parse the Slack Link
Extract the channel ID and thread timestamp from the URL.

Slack URLs follow this pattern:
- `https://{workspace}.slack.com/archives/{channel_id}/p{timestamp}`
- The timestamp in the URL has no dot — insert a dot before the last 6 digits to get the API timestamp
- Example: `p1712345678901234` → `1712345678.901234`

### Step 2: Authenticate with the Slack MCP Server
If the Slack MCP tools are not available or require auth, run the server's authenticate flow first. Share any auth URL with the user and wait for them to complete it.

### Step 3: Fetch the Thread
Use the Slack MCP tools to:
1. Get channel info (channel name) using the channel ID
2. Fetch the thread replies using the channel ID and thread timestamp
3. Collect all messages in the thread

### Step 4: Format as Markdown
Create a markdown file with:
- YAML frontmatter: `type: slack`, `channel: {channel-name}`, `channel_id: {id}`, `thread_ts: {timestamp}`, `date: YYYY-MM-DD`, `participants: []`
- Thread title (first message summary or first line)
- Each message formatted as: `**@username** (YYYY-MM-DD HH:MM):` followed by the message text
- Preserve any links, code blocks, and formatting

### Step 5: Save to raw/slack/
Write the file to `{{VAULT_DIR}}/raw/slack/YYYY-MM-DD-{channel-name}-{topic-slug}.md`
- `topic-slug` is derived from the first message (first few meaningful words, lowercased, hyphenated)
- Max 60 chars for filename

### Step 6: Ingest
Follow the standard vault ingest workflow from the vault `CLAUDE.md`:
1. Read & extract decisions, action items, people, projects, PRs
2. Create source summary in `{{VAULT_DIR}}/wiki/sources/`
3. Update project hubs, action-items.md, topics, manifest, index, log
4. Report what was created/updated

### Step 7: Report
Tell the user:
- What file was saved to raw/
- What wiki pages were created or updated
- Any action items extracted
- Any new projects or topics created
