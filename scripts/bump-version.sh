#!/usr/bin/env bash
#
# bump-version.sh — single source of truth for the plugin version.
#
# Bumps every version field declared in .version-bump.json in lockstep, with
# drift detection and a repo-wide audit for missed files.
#
# Source: adapted from the superpowers project by Jesse Vincent (obra),
#   https://github.com/obra/superpowers/blob/main/scripts/bump-version.sh
# Used and modified under its MIT license. Requires: jq.
#
# Usage:
#   bump-version.sh <new-version>   Bump all declared files to new version
#   bump-version.sh --check         Report current versions (detect drift)
#   bump-version.sh --audit         Check + grep repo for old version strings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT
readonly CONFIG="${REPO_ROOT}/.version-bump.json"

#######################################
# Prints an error message to STDERR.
# Arguments:
#   $*: message
#######################################
err() {
  echo "error: $*" >&2
}

#######################################
# Converts a dotted field path ("plugins.0.version") to a jq path
# (".plugins[0].version").
# Arguments:
#   $1: dotted field path
# Outputs:
#   jq path expression on STDOUT.
#######################################
to_jq_path() {
  echo "$1" | sed -E 's/\.([0-9]+)/[\1]/g' | sed 's/^/./' | sed 's/\.\././g'
}

#######################################
# Reads a field from a JSON file.
# Arguments:
#   $1: file path
#   $2: dotted field path
# Outputs:
#   Field value on STDOUT.
#######################################
read_json_field() {
  local file="$1" field="$2"
  jq -r "$(to_jq_path "${field}")" "${file}"
}

#######################################
# Writes a string value to a field in a JSON file (in place).
# Arguments:
#   $1: file path
#   $2: dotted field path
#   $3: value
#######################################
write_json_field() {
  local file="$1" field="$2" value="$3"
  local tmp="${file}.tmp"
  jq "$(to_jq_path "${field}") = \"${value}\"" "${file}" >"${tmp}" \
    && mv "${tmp}" "${file}"
}

#######################################
# Lists the declared version-bearing files.
# Globals:
#   CONFIG
# Outputs:
#   Lines of "path<TAB>field" on STDOUT.
#######################################
declared_files() {
  jq -r '.files[] | "\(.path)\t\(.field)"' "${CONFIG}"
}

#######################################
# Lists audit exclude patterns from the config, if any.
# Globals:
#   CONFIG
# Outputs:
#   One pattern per line on STDOUT.
#######################################
audit_excludes() {
  jq -r '.audit.exclude[]' "${CONFIG}" 2>/dev/null
}

#######################################
# Shows the version in every declared file and detects drift.
# Globals:
#   REPO_ROOT
# Returns:
#   0 if all declared files agree, 1 on drift or missing files.
#######################################
cmd_check() {
  local has_drift=0
  local versions=()
  local path field fullpath ver unique

  echo "Version check:"
  echo ""

  while IFS=$'\t' read -r path field; do
    fullpath="${REPO_ROOT}/${path}"
    if [[ ! -f "${fullpath}" ]]; then
      printf "  %-45s  MISSING\n" "${path} (${field})"
      has_drift=1
      continue
    fi
    ver="$(read_json_field "${fullpath}" "${field}")"
    printf "  %-45s  %s\n" "${path} (${field})" "${ver}"
    versions+=("${ver}")
  done < <(declared_files)

  echo ""

  unique="$(printf '%s\n' "${versions[@]}" | sort -u | wc -l | tr -d ' ')"
  if [[ "${unique}" -gt 1 ]]; then
    echo "DRIFT DETECTED — versions are not in sync:"
    printf '%s\n' "${versions[@]}" | sort | uniq -c | sort -rn \
      | while read -r count ver; do
          echo "  ${ver} (${count} files)"
        done
    has_drift=1
  else
    echo "All declared files are in sync at ${versions[0]}"
  fi

  return "${has_drift}"
}

#######################################
# Runs cmd_check, then scans the repo for the current version string in files
# not declared in the config.
# Globals:
#   REPO_ROOT
# Returns:
#   0 on success, 1 if the current version cannot be determined.
#######################################
cmd_audit() {
  local current_version
  local path field fullpath match match_file rel_path dp is_declared
  local found_undeclared=0
  local -a exclude_args=() declared_paths=()
  local pattern

  cmd_check || true
  echo ""

  current_version="$(
    while IFS=$'\t' read -r path field; do
      fullpath="${REPO_ROOT}/${path}"
      [[ -f "${fullpath}" ]] && read_json_field "${fullpath}" "${field}"
    done < <(declared_files) | sort | uniq -c | sort -rn | head -1 \
      | awk '{print $2}'
  )"

  if [[ -z "${current_version}" ]]; then
    err "could not determine current version"
    return 1
  fi

  echo "Audit: scanning repo for version string '${current_version}'..."
  echo ""

  while IFS= read -r pattern; do
    exclude_args+=("--exclude=${pattern}" "--exclude-dir=${pattern}")
  done < <(audit_excludes)
  exclude_args+=(
    "--exclude-dir=.git"
    "--exclude-dir=node_modules"
    "--binary-files=without-match"
  )

  while IFS=$'\t' read -r path _; do
    declared_paths+=("${path}")
  done < <(declared_files)

  while IFS= read -r match; do
    match_file="${match%%:*}"
    rel_path="${match_file#"${REPO_ROOT}"/}"

    is_declared=0
    for dp in "${declared_paths[@]}"; do
      if [[ "${rel_path}" == "${dp}" ]]; then
        is_declared=1
        break
      fi
    done

    if [[ "${is_declared}" -eq 0 ]]; then
      if [[ "${found_undeclared}" -eq 0 ]]; then
        echo "UNDECLARED files containing '${current_version}':"
        found_undeclared=1
      fi
      echo "  ${match}"
    fi
  done < <(grep -rn "${exclude_args[@]}" -F "${current_version}" \
    "${REPO_ROOT}" 2>/dev/null || true)

  if [[ "${found_undeclared}" -eq 0 ]]; then
    echo "No undeclared files contain the version string. All clear."
  else
    echo ""
    echo "Review the above files — if they should be bumped, add them to"
    echo ".version-bump.json. If they should be skipped, add them to the"
    echo "audit.exclude list."
  fi
}

#######################################
# Bumps every declared file to the given version, then audits.
# Globals:
#   REPO_ROOT
# Arguments:
#   $1: new semver version (X.Y.Z)
#######################################
cmd_bump() {
  local new_version="$1"
  local path field fullpath old_ver

  if ! echo "${new_version}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    err "'${new_version}' doesn't look like a version (expected X.Y.Z)"
    exit 1
  fi

  echo "Bumping all declared files to ${new_version}..."
  echo ""

  while IFS=$'\t' read -r path field; do
    fullpath="${REPO_ROOT}/${path}"
    if [[ ! -f "${fullpath}" ]]; then
      echo "  SKIP (missing): ${path}"
      continue
    fi
    old_ver="$(read_json_field "${fullpath}" "${field}")"
    write_json_field "${fullpath}" "${field}" "${new_version}"
    printf "  %-45s  %s -> %s\n" "${path} (${field})" "${old_ver}" \
      "${new_version}"
  done < <(declared_files)

  echo ""
  echo "Done. Running audit to check for missed files..."
  echo ""
  cmd_audit
}

#######################################
# Prints usage information.
#######################################
usage() {
  echo "Usage: bump-version.sh <new-version> | --check | --audit"
  echo ""
  echo "  <new-version>  Bump all declared files to the given version"
  echo "  --check        Show current versions, detect drift"
  echo "  --audit        Check + scan repo for undeclared version references"
}

main() {
  if [[ ! -f "${CONFIG}" ]]; then
    err ".version-bump.json not found at ${CONFIG}"
    exit 1
  fi

  case "${1:-}" in
    --check)
      cmd_check
      ;;
    --audit)
      cmd_audit
      ;;
    --help | -h | "")
      usage
      exit 0
      ;;
    --*)
      err "unknown flag '$1'"
      exit 1
      ;;
    *)
      cmd_bump "$1"
      ;;
  esac
}

main "$@"
