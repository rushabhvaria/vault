#!/bin/bash
# Session capture hook for the vault wiki.
# Triggered on SessionEnd — reads the transcript and writes a DETAILED session
# summary (ask, follow-ups, outcomes, PR/doc links, files touched, tool activity)
# to the vault's raw/sessions/ by delegating to summarize-session.sh.

set -euo pipefail

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Nothing to do without a transcript.
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Delegate to the shared summarizer. Let it derive the output path from the
# transcript's own first-event timestamp so the filename matches the session
# date. It is idempotent on content and cheap to re-run.
"${HOOK_DIR}/summarize-session.sh" "$TRANSCRIPT_PATH" "$SESSION_ID" >/dev/null 2>&1 || true

exit 0
