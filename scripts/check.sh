#!/usr/bin/env bash
#
# check.sh — repository checks, runnable locally and in CI (same entry point).
#
# Usage:
#   check.sh          Run everything
#   check.sh lint     shellcheck + markdownlint + static (needs shellcheck,
#                     npx, jq)
#   check.sh static   bash syntax, JSON, evals, version lockstep (jq only;
#                     CI runs shellcheck/markdownlint via dedicated actions)
#   check.sh hooks    Behavioral tests for the plugin hooks (requires jq;
#                     cross-platform — runs under Git Bash on Windows)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT

cd "${REPO_ROOT}"

#######################################
# Prints a check header / error line.
#######################################
say() {
  echo "==> $*"
}

err() {
  echo "FAIL: $*" >&2
}

#######################################
# Asserts a required tool is installed.
# Arguments:
#   $1: command name
#######################################
require() {
  command -v "$1" >/dev/null 2>&1 || { err "$1 is required"; exit 1; }
}

# --- lint checks ---

check_shellcheck() {
  say "shellcheck on all tracked shell scripts"
  git ls-files '*.sh' | xargs shellcheck
}

check_bash_syntax() {
  say "bash -n syntax check"
  git ls-files '*.sh' | xargs -n1 bash -n
}

check_json() {
  say "all tracked JSON files parse"
  git ls-files '*.json' | xargs -n1 jq -e . >/dev/null
}

check_evals() {
  say "eval scenario files are well-formed (3 scenarios each)"
  local f
  for f in evals/*.json; do
    jq -e 'length == 3 and all(.[];
        (.skills | length > 0) and
        (.query | length > 0) and
        (.expected_behavior | length > 0))' "${f}" >/dev/null \
      || { err "malformed eval file: ${f}"; exit 1; }
  done
}

check_version_lockstep() {
  say "version fields in lockstep"
  "${SCRIPT_DIR}/bump-version.sh" --check
}

check_markdown() {
  say "markdownlint on all markdown files"
  # Same cli2 version the CI action bundles, config from .markdownlint-cli2.jsonc.
  npx --yes markdownlint-cli2@0.22.1 "**/*.md"
}

# --- hook behavioral tests ---

#######################################
# Runs the SessionStart hook against a directory and prints its stdout.
# Arguments:
#   $1: directory to use as CLAUDE_PROJECT_DIR
#######################################
run_session_hook() {
  CLAUDE_PROJECT_DIR="$1" CLAUDE_PLUGIN_ROOT="${REPO_ROOT}" \
    bash hooks/java-project-detect.sh
}

test_hook_lists_all_skills() {
  say "session hook: lists every skill for a Java project"
  local tmp out ctx skill_md name
  tmp="$(mktemp -d)"
  touch "${tmp}/pom.xml"
  out="$(run_session_hook "${tmp}")"
  ctx="$(printf '%s' "${out}" \
    | jq -er '.hookSpecificOutput.additionalContext')" \
    || { err "hook output is not the expected JSON: ${out}"; exit 1; }
  for skill_md in skills/*/SKILL.md; do
    name="$(basename "$(dirname "${skill_md}")")"
    case "${ctx}" in
      *"\`${name}\`"*) ;;
      *) err "hook output missing skill: ${name}"; exit 1 ;;
    esac
  done
  rm -rf "${tmp}"
}

test_hook_detects_nested_build() {
  say "session hook: detects nested build files (monorepo layout)"
  local tmp
  tmp="$(mktemp -d)"
  mkdir "${tmp}/svc"
  touch "${tmp}/svc/build.gradle.kts"
  run_session_hook "${tmp}" | jq -e . >/dev/null \
    || { err "no valid JSON for nested build file"; exit 1; }
  rm -rf "${tmp}"
}

test_hook_silent_for_non_java() {
  say "session hook: silent for non-Java projects"
  local tmp out
  tmp="$(mktemp -d)"
  out="$(run_session_hook "${tmp}")"
  [[ -z "${out}" ]] || { err "expected no output, got: ${out}"; exit 1; }
  rm -rf "${tmp}"
}

test_hook_tolerates_crlf() {
  say "session hook: tolerates CRLF line endings (Windows checkout)"
  local root tmp ctx
  root="$(mktemp -d)"
  mkdir -p "${root}/skills/demo-skill"
  printf -- '---\r\nname: demo-skill\r\ndescription: Use when demoing — detail.\r\n---\r\n' \
    >"${root}/skills/demo-skill/SKILL.md"
  tmp="$(mktemp -d)"
  touch "${tmp}/pom.xml"
  ctx="$(CLAUDE_PROJECT_DIR="${tmp}" CLAUDE_PLUGIN_ROOT="${root}" \
    bash hooks/java-project-detect.sh \
    | jq -er '.hookSpecificOutput.additionalContext')" \
    || { err "CRLF hook output is not the expected JSON"; exit 1; }
  case "${ctx}" in
    *"\`demo-skill\`"*) ;;
    *) err "hook leaked carriage return into skill name on CRLF input"; exit 1 ;;
  esac
  rm -rf "${root}" "${tmp}"
}

test_shellcheck_hook() {
  if ! command -v shellcheck >/dev/null 2>&1; then
    say "shellcheck hook: SKIPPED (shellcheck not installed)"
    return 0
  fi
  say "shellcheck hook: passes clean files, exit 2 on findings"
  printf '{"tool_input":{"file_path":"%s"}}' \
    "${REPO_ROOT}/hooks/java-project-detect.sh" \
    | bash .claude/hooks/shellcheck-edited-file.sh \
    || { err "clean file should exit 0"; exit 1; }

  local tmp rc=0
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2016  # the unexpanded $var IS the planted violation
  printf '#!/bin/bash\necho $unquoted_undefined\n' >"${tmp}/bad.sh"
  printf '{"tool_input":{"file_path":"%s"}}' "${tmp}/bad.sh" \
    | bash .claude/hooks/shellcheck-edited-file.sh 2>/dev/null || rc=$?
  [[ "${rc}" -eq 2 ]] || { err "bad file should exit 2, got ${rc}"; exit 1; }
  rm -rf "${tmp}"
}

# --- entrypoints ---

run_static() {
  require jq
  check_bash_syntax
  check_json
  check_evals
  check_version_lockstep
}

run_lint() {
  require shellcheck
  require npx
  check_shellcheck
  check_markdown
  run_static
}

run_hooks() {
  require jq
  test_hook_lists_all_skills
  test_hook_detects_nested_build
  test_hook_silent_for_non_java
  test_hook_tolerates_crlf
  test_shellcheck_hook
}

main() {
  case "${1:-all}" in
    lint) run_lint ;;
    static) run_static ;;
    hooks) run_hooks ;;
    all)
      run_lint
      run_hooks
      ;;
    *)
      err "unknown check group '$1' (expected: lint, static, hooks, all)"
      exit 1
      ;;
  esac
  echo "All checks passed."
}

main "$@"
