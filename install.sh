#!/bin/bash
# install.sh — set up the Claude Code Vault ("LLM Wiki" second brain).
#
# What it does:
#   1. Treats this repo directory as your live vault (raw/ + wiki/ live here).
#   2. Installs the six vault skills into ~/.claude/skills/, with the vault path
#      baked in so they work from any Claude Code session.
#   3. Installs resolved copies of the session-capture hooks into
#      ~/.claude/hooks/vault/.
#   4. Registers the SessionEnd hook in ~/.claude/settings.json (merged with jq,
#      original backed up first).
#
# Re-running is safe and idempotent.
#
# Usage:
#   ./install.sh                 # use this repo dir as the vault
#   ./install.sh --skills-only   # install skills only, skip the session hook

set -euo pipefail

# --- Resolve paths -----------------------------------------------------------
VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SKILLS_DEST="${CLAUDE_DIR}/skills"
HOOKS_DEST="${CLAUDE_DIR}/hooks/vault"
SETTINGS="${CLAUDE_DIR}/settings.json"

SKILLS_ONLY=0
[ "${1:-}" = "--skills-only" ] && SKILLS_ONLY=1

echo "Claude Code Vault installer"
echo "  vault dir      : ${VAULT_DIR}"
echo "  claude config  : ${CLAUDE_DIR}"
echo

# --- Preflight ---------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (used to read Claude transcripts and merge settings)." >&2
  echo "  macOS:  brew install jq" >&2
  echo "  Debian: sudo apt-get install jq" >&2
  exit 1
fi

# subst <src> <dest> : copy a file replacing the {{VAULT_DIR}} placeholder.
subst() {
  sed "s|{{VAULT_DIR}}|${VAULT_DIR}|g" "$1" > "$2"
}

# --- 1. Install skills -------------------------------------------------------
echo "Installing skills → ${SKILLS_DEST}/"
mkdir -p "$SKILLS_DEST"
for skill_dir in "${VAULT_DIR}"/skills/*/; do
  name="$(basename "$skill_dir")"
  mkdir -p "${SKILLS_DEST}/${name}"
  subst "${skill_dir}SKILL.md" "${SKILLS_DEST}/${name}/SKILL.md"
  echo "  ✓ ${name}"
done

if [ "$SKILLS_ONLY" -eq 1 ]; then
  echo
  echo "Done (skills only)."
  exit 0
fi

# --- 2. Install resolved hooks ----------------------------------------------
echo "Installing hooks → ${HOOKS_DEST}/"
mkdir -p "$HOOKS_DEST"
for hook in session-capture.sh summarize-session.sh backfill-sessions.sh; do
  subst "${VAULT_DIR}/hooks/${hook}" "${HOOKS_DEST}/${hook}"
  chmod +x "${HOOKS_DEST}/${hook}"
  echo "  ✓ ${hook}"
done

# --- 3. Register the SessionEnd hook ----------------------------------------
HOOK_CMD="${HOOKS_DEST}/session-capture.sh"
echo "Registering SessionEnd hook in ${SETTINGS}"

mkdir -p "$CLAUDE_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# Back up before touching, then merge idempotently: only add our hook command
# if it is not already present under hooks.SessionEnd.
cp "$SETTINGS" "${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"

tmp="$(mktemp)"
jq --arg cmd "$HOOK_CMD" '
  .hooks //= {} |
  .hooks.SessionEnd //= [] |
  if any(.hooks.SessionEnd[]?; (.hooks // [])[]?.command == $cmd)
  then .
  else .hooks.SessionEnd += [ { "hooks": [ { "type": "command", "command": $cmd } ] } ]
  end
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
echo "  ✓ SessionEnd → ${HOOK_CMD}"

# --- Done --------------------------------------------------------------------
cat <<EOF

Done. Your vault is live at:
  ${VAULT_DIR}

Try it:
  • Drop a design doc into  ${VAULT_DIR}/raw/designs/  then ask Claude to "ingest"
  • Paste a GitHub PR link and say "track this PR"
  • Ask "catch me up" for a morning briefing
  • (optional) Backfill past sessions:  ${HOOKS_DEST}/backfill-sessions.sh

New Claude Code sessions will auto-capture summaries into raw/sessions/.
EOF
