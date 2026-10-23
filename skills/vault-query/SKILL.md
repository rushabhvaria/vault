---
name: vault-query
description: "Use when the user asks a question about their work, projects, decisions, or knowledge that could be answered by the vault wiki. Searches the wiki and synthesizes an answer."
---

# Vault Query

## When This Triggers
- User asks about past decisions: "why did we choose X?", "what was decided about Y?"
- User asks about project state: "what PRs are open for X?", "who's working on Y?"
- User asks about action items: "what do I need to do for X?", "what's blocking Y?"
- User asks about designs: "what's the design for X?", "how does Y work?"
- User asks about people: "what did @alice say about X?"
- Any question that could be answered by information in the vault

## Workflow

### Step 1: Search Wiki

Check relevant pages in this order:
1. **Project hubs** (`{{VAULT_DIR}}/wiki/projects/`) — for project-level questions
2. **Design docs** (`{{VAULT_DIR}}/wiki/designs/`) — for architecture/design questions
3. **Source pages** (`{{VAULT_DIR}}/wiki/sources/`) — for specific meeting/thread/session details
4. **Topic pages** (`{{VAULT_DIR}}/wiki/topics/`) — for concept/technology questions
5. **Action items** (`{{VAULT_DIR}}/wiki/action-items.md`) — for task tracking questions
6. **Overview** (`{{VAULT_DIR}}/wiki/overview.md`) — for general status questions

Use the index at `{{VAULT_DIR}}/wiki/index.md` to find relevant pages by name.

### Step 2: Search Raw (if wiki doesn't have the answer)

If the wiki pages don't fully answer the question, search `{{VAULT_DIR}}/raw/` for relevant raw sources. Use grep to search across raw files.

### Step 3: Synthesize Answer

- Draw from multiple pages to give a complete answer
- Always cite which pages informed the answer: "per [[page-name]]..."
- If information conflicts between sources, note the discrepancy and which is more recent

### Step 4: Offer to Persist

If the answer is valuable and reusable (a new synthesis, a connection not previously captured):
- Offer to file it into the wiki as a new topic page or update to an existing page
- Example: "This comparison isn't captured anywhere — want me to add it to the wiki?"
