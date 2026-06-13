#!/usr/bin/env bash
#
# PostToolUse hook: run shellcheck on an edited/written shell script.
#
# Reads the Claude Code hook payload JSON on STDIN and shellchecks the file it
# names. Exits 2 on findings so they are fed back to Claude to fix in-turn.
# No-ops when jq/shellcheck are not installed or the file no longer exists,
# so the hook never breaks machines without the tooling.
#
# Wired in .claude/settings.json under hooks.PostToolUse with
# if-filters Edit(**/*.sh) / Write(**/*.sh), so it is only spawned for
# shell-script edits in the first place.

set -euo pipefail

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  command -v shellcheck >/dev/null 2>&1 || exit 0

  local file
  file="$(jq -r '.tool_input.file_path // empty')"
  [[ -n "${file}" && -f "${file}" ]] || exit 0

  shellcheck "${file}" >&2 || exit 2
}

main "$@"
