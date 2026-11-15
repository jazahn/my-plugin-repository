#!/usr/bin/env bash
# SessionStart hook for the trello plugin: nudge, never block.
#
# Reads the project's CLAUDE.local.md (per-machine, never committed) for a
# `card-first:` setting and tells Claude, through additionalContext, whether
# to run the /trello:card-first skill when a new work item starts.
#
#   card-first: off   -> prints nothing
#   card-first: on    -> "card-first is on here"
#   no setting        -> "card-first is not configured here; the skill asks once"
#
# Fixed strings only reach the JSON, so no escaping is needed. No network
# calls, no jq. Always exits 0.
set -uo pipefail

# Drain stdin (hook input JSON) so the parent never blocks on a full pipe.
input=$(cat 2>/dev/null || true)

# Project root: Claude Code exports CLAUDE_PROJECT_DIR to hook processes.
# Fall back to the cwd in the hook input, then to the shell's cwd.
root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi
root="${root:-$PWD}"

setting=""
if [ -r "$root/CLAUDE.local.md" ]; then
  setting=$(grep -E '^[[:space:]]*card-first:[[:space:]]*(on|off)[[:space:]]*$' "$root/CLAUDE.local.md" \
    | tail -n 1 | sed -E 's/.*card-first:[[:space:]]*//; s/[[:space:]]*$//')
fi

emit() {
  # $1: one line of context for Claude. Fixed strings only.
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"trello plugin: %s"}}\n' "$1"
}

case "$setting" in
  off)
    ;;
  on)
    emit "card-first is on for this project (card-first: on in CLAUDE.local.md). Before starting a new work item here (a request that will change files or produce a deliverable, not a question or a read-only look), and again when the conversation shifts to a different task, invoke the /trello:card-first skill. It finds the matching Trello card or offers to create one with at most one question, then keeps the card updated when the work lands. Check once per item, never for questions."
    ;;
  *)
    emit "card-first is not configured for this project (no card-first line in CLAUDE.local.md). The first time a new work item starts here (a request that will change files or produce a deliverable, not a question), invoke the /trello:card-first skill once; it asks whether to use the Trello card check in this project and records the answer in CLAUDE.local.md. Do not run it for questions or read-only tasks."
    ;;
esac
exit 0
