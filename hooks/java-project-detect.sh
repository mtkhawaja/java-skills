#!/usr/bin/env bash
#
# SessionStart hook for the java-skills plugin.
#
# If the working directory looks like a Java project (Maven/Gradle), emits the
# plugin's skill list as additional session context; emits nothing otherwise,
# so non-Java sessions are unaffected. The list is derived from
# skills/*/SKILL.md frontmatter at runtime so it cannot drift from the skills
# that actually ship.
#
# Portability: bash builtins only — no awk/sed/find/grep/python/jq — so it
# runs anywhere bash does, including Git Bash on Windows.
# (Deliberate deviation from the Google style guide's `#!/bin/bash` shebang:
# `env` finds bash on systems where it is not in /bin, e.g. NixOS.)
#
# Globals (input):
#   CLAUDE_PROJECT_DIR  Session working directory (default: $PWD).
#   CLAUDE_PLUGIN_ROOT  Installed plugin root (default: this script's parent).
# Outputs:
#   SessionStart hook JSON on STDOUT, or nothing for non-Java projects.

set -euo pipefail

readonly PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
readonly PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "${0%/*}/.." && pwd)}"

#######################################
# Checks whether the session directory is a Maven/Gradle project, looking at
# the root and one level down (multi-module / monorepo layouts).
# Globals:
#   PROJECT_DIR
# Returns:
#   0 if a build file is found, 1 otherwise.
#######################################
is_java_project() {
  local f
  for f in pom.xml build.gradle build.gradle.kts settings.gradle \
    settings.gradle.kts; do
    [[ -e "${PROJECT_DIR}/${f}" ]] && return 0
  done
  # An unmatched glob stays literal and fails the -e test.
  for f in "${PROJECT_DIR}"/*/pom.xml "${PROJECT_DIR}"/*/build.gradle \
    "${PROJECT_DIR}"/*/build.gradle.kts; do
    [[ -e "${f}" ]] && return 0
  done
  return 1
}

#######################################
# Prints the value of a top-of-file YAML frontmatter field from a SKILL.md.
# Arguments:
#   $1: path to the SKILL.md file
#   $2: field key ("name" or "description")
# Outputs:
#   The field value on STDOUT; nothing if the field is absent.
#######################################
frontmatter_field() {
  local file="$1" key="$2" line
  while IFS= read -r line; do
    line="${line%$'\r'}"  # tolerate CRLF checkouts (Windows autocrlf)
    case "${line}" in
      "${key}: "*)
        printf '%s' "${line#"${key}": }"
        return 0
        ;;
    esac
  done <"${file}"
  return 0
}

#######################################
# Builds the skill list: one markdown bullet per skill, showing its name and
# the trigger clause of its description (everything before the first " — ").
# Globals:
#   PLUGIN_ROOT
# Outputs:
#   Bullet list on STDOUT; empty if no skills are found.
#######################################
skill_list() {
  local skill_md name desc
  for skill_md in "${PLUGIN_ROOT}"/skills/*/SKILL.md; do
    [[ -e "${skill_md}" ]] || continue
    name="$(frontmatter_field "${skill_md}" name)"
    desc="$(frontmatter_field "${skill_md}" description)"
    [[ -n "${name}" ]] || continue
    # shellcheck disable=SC2016  # backticks are literal markdown, not expansion
    printf -- '- `%s` — %s\n' "${name}" "${desc%% — *}"
  done
}

#######################################
# JSON-encodes a string using parameter expansion only.
# Arguments:
#   $1: raw string
# Outputs:
#   Double-quoted JSON string on STDOUT.
#######################################
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "${s}"
}

main() {
  is_java_project || return 0

  local skills header context
  skills="$(skill_list)"
  [[ -n "${skills}" ]] || return 0

  header='This is a Java project. The java-skills plugin is available — '
  header+='load the relevant skill before writing or reviewing Java:'
  context="${header}"$'\n'"${skills}"

  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart",'
  printf '"additionalContext":%s}}\n' "$(json_escape "${context}")"
}

main "$@"
