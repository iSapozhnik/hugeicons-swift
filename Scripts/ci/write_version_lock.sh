#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <version-lock-path> <version>" >&2
  exit 1
fi

VERSION_LOCK_PATH="$1"
VERSION="$2"

if [[ -z "${VERSION}" ]]; then
  echo "Version must not be empty." >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
cleanup() {
  rm -f "${TMP_FILE}"
}
trap cleanup EXIT

if [[ -f "${VERSION_LOCK_PATH}" ]]; then
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { print; next }
    { exit }
  ' "${VERSION_LOCK_PATH}" > "${TMP_FILE}"
else
  cat <<'EOF' > "${TMP_FILE}"
# Pinned npm version for @hugeicons/core-free-icons
# Set an explicit semver before running fetch script.
EOF
fi

printf '%s\n' "${VERSION}" >> "${TMP_FILE}"
mv "${TMP_FILE}" "${VERSION_LOCK_PATH}"
