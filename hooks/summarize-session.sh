#!/bin/bash
# summarize-session.sh — deterministic, detailed session summarizer for the vault.
#
# Reads a Claude Code transcript (.jsonl) and writes a rich markdown session file
# to the vault's raw/sessions/. Used by both the SessionEnd hook (live) and the
# backfill driver. No LLM required — everything is extracted directly from the
# transcript.
#
# Usage: summarize-session.sh <transcript_path> [session_id] [output_file]
#   - transcript_path : path to the .jsonl transcript (required)
#   - session_id      : session id override (optional; falls back to transcript field)
#   - output_file     : output .md path (optional; derived from transcript timestamp)

# No pipefail on purpose: extraction pipelines use `head`/`tail`, which SIGPIPE
# their jq producer (exit 141) — expected here, and pipefail+set -e would abort.
set -eu

SESSIONS_DIR="{{VAULT_DIR}}/raw/sessions"

TRANSCRIPT_PATH="${1:-}"
SESSION_ID_ARG="${2:-}"
OUTPUT_FILE_ARG="${3:-}"

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# --- Derive session id -------------------------------------------------------
SESSION_ID="$SESSION_ID_ARG"
if [ -z "$SESSION_ID" ]; then
  SESSION_ID=$(jq -r 'select(.sessionId // empty) | .sessionId' "$TRANSCRIPT_PATH" 2>/dev/null | head -1)
fi
[ -z "$SESSION_ID" ] && SESSION_ID=$(basename "$TRANSCRIPT_PATH" .jsonl)

# --- Derive timestamp / output filename --------------------------------------
# Prefer the first event timestamp in the transcript so backfilled files carry
# the real session date rather than "now".
FIRST_TS=$(jq -r 'select(.timestamp // empty) | .timestamp' "$TRANSCRIPT_PATH" 2>/dev/null | head -1)
if [ -n "$FIRST_TS" ]; then
  DATE=$(date -d "$FIRST_TS" +"%Y-%m-%d" 2>/dev/null || date +"%Y-%m-%d")
  TIME=$(date -d "$FIRST_TS" +"%H:%M" 2>/dev/null || date +"%H:%M")
  STAMP=$(date -d "$FIRST_TS" +"%Y-%m-%d-%H-%M" 2>/dev/null || date +"%Y-%m-%d-%H-%M")
else
  DATE=$(date +"%Y-%m-%d")
  TIME=$(date +"%H:%M")
  STAMP=$(date +"%Y-%m-%d-%H-%M")
fi

OUTPUT_FILE="$OUTPUT_FILE_ARG"
# Include a session-id fragment so two sessions ending in the same minute
# get distinct files (and re-runs stay idempotent).
[ -z "$OUTPUT_FILE" ] && OUTPUT_FILE="${SESSIONS_DIR}/${STAMP}-${SESSION_ID:0:8}-session.md"

mkdir -p "$SESSIONS_DIR"

# --- Context fields ----------------------------------------------------------
CWD=$(jq -r 'select(.cwd // empty) | .cwd' "$TRANSCRIPT_PATH" 2>/dev/null | head -1)
GIT_BRANCH=$(jq -r 'select(.gitBranch // empty) | .gitBranch' "$TRANSCRIPT_PATH" 2>/dev/null | grep -v '^HEAD$' | head -1)

# --- User prompts (real ones: type user, string OR text[], not tool_result) --
# Strips command/caveat/stdout wrapper messages the CLI injects.
mapfile -t USER_PROMPTS < <(
  jq -r '
    select(.type=="user" and (.isMeta // false | not) and (.isSidechain // false | not))
    | .message.content
    | if type=="string" then .
      else ([.[]? | select(.type=="text") | .text] | join("\n"))
      end
    # Collapse each prompt to a single line so multi-line synthetic blocks
    # (task-notification, command wrappers) can be filtered as one unit.
    | gsub("\n"; " ") | gsub("  +"; " ") | sub("^ +";"") | sub(" +$";"")
    | select(. != "")
  ' "$TRANSCRIPT_PATH" 2>/dev/null \
    | grep -vE '^<(command-|local-command|bash-|user-prompt-submit|task-notification|task-id|tool-use-id|output-file|status|summary|note|result)' \
    | grep -vE '^Caveat: The messages below' \
    | grep -vE '^\[Request interrupted by user' \
    | grep -vE '^This session is being continued from a previous conversation'
)

FIRST_PROMPT="${USER_PROMPTS[0]:-}"

# --- Final wrap-up text (session's own summary) ------------------------------
# The last few assistant text blocks are almost always the session summary.
FINAL_TEXT=$(
  jq -r '
    select(.type=="assistant" and (.isSidechain // false | not))
    | .message.content[]? | select(.type=="text") | .text
  ' "$TRANSCRIPT_PATH" 2>/dev/null | tail -c 4000
)

# Skip empty/stub transcripts (no real prompt and no assistant output) — these
# are aborted or metadata-only sessions with nothing worth capturing.
if [ "${#USER_PROMPTS[@]}" -eq 0 ] && [ -z "$FINAL_TEXT" ]; then
  exit 0
fi

# --- Links: PRs and docs -----------------------------------------------------
ALL_URLS=$(jq -r '.. | .text? // empty' "$TRANSCRIPT_PATH" 2>/dev/null \
  | grep -oiE 'https?://[^ )"><|]+' | sed -E 's/[.,*]+$//' | sort -u || true)

PR_LINKS=$(echo "$ALL_URLS" | grep -iE 'github\.com/[^/]+/[^/]+/pull/[0-9]+' | sort -u || true)
DOC_LINKS=$(echo "$ALL_URLS" | grep -iE 'docs\.google\.com|confluence|\.atlassian\.|/browse/[A-Z]+-[0-9]+|/wiki/' | sort -u || true)

# --- Files touched (Edit / Write tool_use inputs) ----------------------------
FILES_TOUCHED=$(jq -r '
  select(.type=="assistant")
  | .message.content[]? | select(.type=="tool_use" and (.name=="Edit" or .name=="Write" or .name=="NotebookEdit"))
  | .input.file_path // empty
' "$TRANSCRIPT_PATH" 2>/dev/null | sort -u | head -40 || true)

# --- Tool activity counts ----------------------------------------------------
TOOL_COUNTS=$(jq -r '
  select(.type=="assistant")
  | .message.content[]? | select(.type=="tool_use") | .name
' "$TRANSCRIPT_PATH" 2>/dev/null | sort | uniq -c | sort -rn | head -12 || true)

# --- Projects: repo names from PRs + cwd basename ----------------------------
PROJECTS=""
if [ -n "$PR_LINKS" ]; then
  PROJECTS=$(echo "$PR_LINKS" | sed -E 's#.*github\.com/[^/]+/([^/]+)/pull.*#\1#' | sort -u | paste -sd, - || true)
fi
if [ -n "$CWD" ]; then
  CWD_PROJ=$(basename "$CWD")
  if [ -n "$CWD_PROJ" ]; then
    if [ -n "$PROJECTS" ]; then PROJECTS="${PROJECTS},${CWD_PROJ}"; else PROJECTS="$CWD_PROJ"; fi
  fi
fi
# dedupe
[ -n "$PROJECTS" ] && PROJECTS=$(echo "$PROJECTS" | tr ',' '\n' | grep -vE '^\s*$' | sort -u | paste -sd, - )

# --- YAML list helpers -------------------------------------------------------
prs_yaml() {
  local out=""
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    # e.g. org/repo#123
    local ref
    ref=$(echo "$url" | sed -E 's#.*github\.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\1/\2\#\3#')
    if [ -z "$out" ]; then out="$ref"; else out="${out}, ${ref}"; fi
  done <<< "$PR_LINKS"
  echo "$out"
}
PRS_INLINE=""
if [ -n "$PR_LINKS" ]; then
  PRS_INLINE=$(prs_yaml)
fi

# --- Write the file ----------------------------------------------------------
{
  echo "---"
  echo "type: session"
  echo "date: ${DATE}"
  echo "time: ${TIME}"
  echo "session_id: ${SESSION_ID}"
  echo "cwd: ${CWD}"
  [ -n "$GIT_BRANCH" ] && echo "git_branch: ${GIT_BRANCH}"
  echo "projects: [${PROJECTS}]"
  echo "prs: [${PRS_INLINE}]"
  echo "status: summarized"
  echo "---"
  echo
  echo "# Session: ${DATE} ${TIME}"
  echo

  echo "## Ask"
  if [ -n "$FIRST_PROMPT" ]; then
    # Quote the opening ask (truncate very long prompts)
    echo "$FIRST_PROMPT" | head -c 1500 | sed 's/^/> /'
  else
    echo "_No user prompt captured._"
  fi
  echo

  if [ "${#USER_PROMPTS[@]}" -gt 1 ]; then
    echo "## Follow-up Prompts"
    for ((i=1; i<${#USER_PROMPTS[@]} && i<12; i++)); do
      line=$(echo "${USER_PROMPTS[$i]}" | tr '\n' ' ' | head -c 240)
      echo "- ${line}"
    done
    echo
  fi

  echo "## What Was Done"
  if [ -n "$FINAL_TEXT" ]; then
    echo "$FINAL_TEXT"
  else
    echo "_No summary text captured from the transcript._"
  fi
  echo

  if [ -n "$PR_LINKS" ]; then
    echo "## PR Links"
    while IFS= read -r url; do
      [ -z "$url" ] && continue
      echo "- ${url}"
    done <<< "$PR_LINKS"
    echo
  fi

  if [ -n "$DOC_LINKS" ]; then
    echo "## Doc Links"
    while IFS= read -r url; do
      [ -z "$url" ] && continue
      echo "- ${url}"
    done <<< "$DOC_LINKS"
    echo
  fi

  if [ -n "$FILES_TOUCHED" ]; then
    echo "## Files Touched"
    while IFS= read -r fp; do
      [ -z "$fp" ] && continue
      echo "- \`${fp}\`"
    done <<< "$FILES_TOUCHED"
    echo
  fi

  if [ -n "$TOOL_COUNTS" ]; then
    echo "## Tool Activity"
    echo '```'
    echo "$TOOL_COUNTS" | sed -E 's/^ *//'
    echo '```'
    echo
  fi

  echo "## Raw Transcript Reference"
  echo "Transcript: ${TRANSCRIPT_PATH}"
} > "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
