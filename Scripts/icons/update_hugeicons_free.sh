#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

FETCH_SCRIPT="${SCRIPT_DIR}/fetch_hugeicons_free.sh"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify_hugeicons_xcassets.swift"
NAME_MAP_SCRIPT="${SCRIPT_DIR}/generate_hugeicons_name_map.swift"
SWIFT_API_SCRIPT="${SCRIPT_DIR}/generate_hugeicons_swift_api.sh"
SUMMARY_SCRIPT="${SCRIPT_DIR}/summarize_hugeicons_name_map.swift"

DEFAULT_VERSION_LOCK="${REPO_ROOT}/version.lock"
DEFAULT_OUTPUT_DIR="${REPO_ROOT}/Sources/Hugeicons/Resources/Hugeicons/Hugeicons.xcassets"
DEFAULT_NAME_MAP_PATH="${REPO_ROOT}/Sources/Hugeicons/Resources/Hugeicons/name-map.json"

VERSION_LOCK="${DEFAULT_VERSION_LOCK}"
OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"
NAME_MAP_PATH="${DEFAULT_NAME_MAP_PATH}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--version-lock <path>] [--output-dir <path>] [--name-map-path <path>]

Refresh pipeline:
1) fetch
2) verify generated asset catalog
3) regenerate name map + SwiftGen/wrapper API
4) output summary (added/removed/renamed)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version-lock)
      VERSION_LOCK="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --name-map-path)
      NAME_MAP_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for required in "${FETCH_SCRIPT}" "${VERIFY_SCRIPT}" "${NAME_MAP_SCRIPT}" "${SWIFT_API_SCRIPT}" "${SUMMARY_SCRIPT}"; do
  if [[ ! -f "${required}" ]]; then
    echo "Required script not found: ${required}" >&2
    exit 1
  fi
done

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

OLD_NAME_MAP_PATH="${TMP_DIR}/old-name-map.json"
HAS_OLD_NAME_MAP=0
if [[ -f "${NAME_MAP_PATH}" ]]; then
  cp "${NAME_MAP_PATH}" "${OLD_NAME_MAP_PATH}"
  HAS_OLD_NAME_MAP=1
fi

echo "[1/4] Fetching pinned Hugeicons free payload..."
"${FETCH_SCRIPT}" --version-lock "${VERSION_LOCK}" --output-dir "${OUTPUT_DIR}"

echo "[2/4] Verifying asset catalog consistency..."
"${VERIFY_SCRIPT}" "${OUTPUT_DIR}"

echo "[3/4] Regenerating name map + SwiftGen wrapper API..."
"${NAME_MAP_SCRIPT}" "${OUTPUT_DIR}" "${NAME_MAP_PATH}"
"${SWIFT_API_SCRIPT}" --name-map "${NAME_MAP_PATH}"

echo "[4/4] Computing icon delta summary..."
if [[ "${HAS_OLD_NAME_MAP}" -eq 1 ]]; then
  "${SUMMARY_SCRIPT}" "${OLD_NAME_MAP_PATH}" "${NAME_MAP_PATH}"
else
  "${SUMMARY_SCRIPT}" "${TMP_DIR}/missing-old-name-map.json" "${NAME_MAP_PATH}"
fi
