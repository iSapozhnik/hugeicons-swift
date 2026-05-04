#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <version-lock-path>" >&2
  exit 1
fi

VERSION_LOCK_PATH="$1"

if [[ ! -f "${VERSION_LOCK_PATH}" ]]; then
  echo "Version lock file not found: ${VERSION_LOCK_PATH}" >&2
  exit 1
fi

VERSION="$(awk '!/^[[:space:]]*#/ && NF { print $1; exit }' "${VERSION_LOCK_PATH}")"

if [[ -z "${VERSION:-}" ]]; then
  echo "Failed to read pinned version from ${VERSION_LOCK_PATH}" >&2
  exit 1
fi

printf '%s\n' "${VERSION}"
