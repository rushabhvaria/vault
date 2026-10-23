#!/bin/bash
# backfill-sessions.sh — run summarize-session.sh over every Claude Code
# transcript on this machine, skipping sessions already captured (by session_id).
# One-off backfill driver; the SessionEnd hook handles new sessions going forward.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_DIR="{{VAULT_DIR}}/raw/sessions"
PROJECTS_DIR="${HOME}/.claude/projects"

mkdir -p "$SESSIONS_DIR"

# Collect session_ids already captured (from frontmatter) so we don't duplicate.
declare -A SEEN
while IFS= read -r sid; do
  [ -n "$sid" ] && SEEN["$sid"]=1
done < <(grep -rhE '^session_id:' "$SESSIONS_DIR" 2>/dev/null | sed -E 's/^session_id:\s*//')

written=0
skipped=0
for tp in "$PROJECTS_DIR"/*/*.jsonl; do
  [ -f "$tp" ] || continue
  base=$(basename "$tp" .jsonl)
  # Skip subagent sidechain transcripts (agent-*.jsonl) — not real sessions.
  case "$base" in
    agent-*) continue ;;
  esac
  sid="$base"
  if [ -n "${SEEN[$sid]:-}" ]; then
    skipped=$((skipped+1))
    continue
  fi
  # summarize-session.sh derives a collision-safe path (timestamp + session-id
  # fragment) itself, and is idempotent, so just let it choose the output file.
  out=$("$HOOK_DIR/summarize-session.sh" "$tp" "$sid" 2>/dev/null || true)
  if [ -n "$out" ]; then
    SEEN["$sid"]=1          # guard against duplicate transcripts for same session
    written=$((written+1))
    echo "wrote: $out"
  fi
done

echo "---"
echo "backfill complete: ${written} written, ${skipped} skipped (already captured)"
