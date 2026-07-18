#!/usr/bin/env bash
# PostToolUse hook: runs gdlint on any .gd file that was just edited/written.
# Reads Claude Code tool-result JSON from stdin, returns additionalContext with lint output.
# Non-blocking — Claude sees errors as context but is not stopped.

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" || "${FILE_PATH##*.}" != "gd" ]]; then
  echo '{"hookSpecificOutput":{"additionalContext":""}}'
  exit 0
fi

if ! command -v gdlint &>/dev/null; then
  echo '{"hookSpecificOutput":{"additionalContext":"[lint-hook] gdlint not found — skipping."}}'
  exit 0
fi

LINT_OUTPUT=$(gdlint "$FILE_PATH" 2>&1 || true)

if [[ -z "$LINT_OUTPUT" ]]; then
  MSG="[gdlint] $FILE_PATH — OK"
else
  MSG="[gdlint] $FILE_PATH ERRORS:\n$LINT_OUTPUT"
fi

ESCAPED=$(printf '%s' "$MSG" | jq -Rs .)
echo "{\"hookSpecificOutput\":{\"additionalContext\":$ESCAPED}}"
