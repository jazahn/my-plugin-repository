#!/usr/bin/env bash
# SessionStart hook for the pr-assistant plugin: nudge, never block.
#
# Reads ~/.claude/.pr-assistant-rotation, a per-machine cache that
# /pr-assistant:install and /pr-assistant:rotate write, one line per auth
# mode holding the rotate-by date (mint date plus eleven months):
#
#   personal: 2027-10-25
#   team: 2027-10-25
#
# When a date is today or past, tell Claude through additionalContext so it
# can point at /pr-assistant:rotate once, at a natural pause. No file, or
# no overdue line: print nothing. The repo variables (PR_ASSISTANT_MINTED)
# are the source of truth; this file is only a cache so the hook stays
# offline. Fixed strings only reach the JSON. No jq. Always exits 0.
set -uo pipefail

# Drain stdin (hook input JSON) so the parent never blocks on a full pipe.
cat >/dev/null 2>&1 || true

file="${HOME}/.claude/.pr-assistant-rotation"
[ -r "$file" ] || exit 0

today=$(date +%F)
due=""
while IFS= read -r line || [ -n "$line" ]; do
  mode=""
  case "$line" in
    personal:*) mode="personal" ;;
    team:*)     mode="team" ;;
    *)          continue ;;
  esac
  d=$(printf '%s' "$line" | sed -E 's/^[a-z]+:[[:space:]]*//; s/[[:space:]]*$//')
  # ISO dates compare correctly as strings.
  case "$d" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) continue ;;
  esac
  if [[ "$d" < "$today" || "$d" == "$today" ]]; then
    due="${due:+$due and }$mode"
  fi
done < "$file"

[ -n "$due" ] || exit 0

emit() {
  # $1: one line of context for Claude. Fixed strings only.
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"pr-assistant plugin: %s"}}\n' "$1"
}

case "$due" in
  personal)
    emit "the personal credential (CLAUDE_CODE_OAUTH_TOKEN, a one-year subscription token) in enrolled repos is due for rotation according to the local cache. At a natural pause, mention it once in one line and point at /pr-assistant:rotate personal. Do not interrupt a task for it."
    ;;
  team)
    emit "the team credential (PR_ASSISTANT_API_KEY, the HUIT Bedrock proxy key) in enrolled repos is due for rotation according to the local cache. At a natural pause, mention it once in one line and point at /pr-assistant:rotate team. Do not interrupt a task for it."
    ;;
  *)
    emit "both the personal credential (CLAUDE_CODE_OAUTH_TOKEN) and the team credential (PR_ASSISTANT_API_KEY) in enrolled repos are due for rotation according to the local cache. At a natural pause, mention it once in one line and point at /pr-assistant:rotate. Do not interrupt a task for it."
    ;;
esac
exit 0
