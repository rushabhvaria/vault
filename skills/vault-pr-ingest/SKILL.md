---
name: vault-pr-ingest
description: "Use when the user pastes a GitHub PR link or asks to track/ingest a PR. Fetches PR details via gh CLI, saves to the vault's raw/prs/, and runs the vault ingest workflow."
---

# GitHub PR Ingest

## When This Triggers
- User pastes a GitHub PR URL (e.g., `https://github.com/org/repo/pull/123`)
- User references a PR like `org/repo#123` and asks to track it
- User says "track this PR" or "ingest this PR"

## Prerequisites
- The `gh` CLI must be installed and authenticated (`gh auth status`). If it is not, tell the user how to authenticate rather than guessing at PR contents.

## Workflow

### Step 1: Parse the PR Reference
Extract owner, repo, and PR number from:
- URL: `https://github.com/{owner}/{repo}/pull/{number}`
- Short ref: `{owner}/{repo}#{number}` or just `#{number}` (infer repo from context)

### Step 2: Fetch PR Data
Use the `gh` CLI to fetch comprehensive PR data:

```bash
gh pr view {owner}/{repo}#{number} --json title,body,state,author,reviewers,comments,files,mergedAt,createdAt,closedAt,labels,milestone,additions,deletions,baseRefName,headRefName
```

Also fetch review comments:
```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews --jq '.[] | {user: .user.login, state: .state, body: .body}'
```

### Step 3: Format as Markdown
Create a markdown file with:

```yaml
---
type: pr
repo: {owner}/{repo}
pr_number: {number}
title: "{title}"
author: "@{author}"
state: {open|closed|merged}
created: YYYY-MM-DD
merged: YYYY-MM-DD  # if merged
labels: []
files_changed: N
additions: N
deletions: N
---
```

Sections:
- **Summary** — PR title and description
- **Files Changed** — List of files with change counts
- **Reviews** — Each review with reviewer, state (approved/changes_requested/commented), and comments
- **Discussion** — Key comment threads (summarize if many)
- **Status** — Current state, merge status

### Step 4: Save to raw/prs/
Write to `{{VAULT_DIR}}/raw/prs/YYYY-MM-DD-{repo}-pr-{number}.md`

### Step 5: Ingest
Follow the standard vault ingest workflow from the vault `CLAUDE.md`:
1. Create source summary in `{{VAULT_DIR}}/wiki/sources/`
2. Link to relevant project hub (map repo to project)
3. If the PR resolves action items in action-items.md, mark them complete
4. Update manifest, index, log

### Step 6: Report
Tell the user:
- What file was saved to raw/
- What wiki pages were created or updated
- If any action items were resolved by this PR
