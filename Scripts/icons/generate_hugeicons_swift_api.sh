#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEFAULT_SWIFTGEN_CONFIG="${REPO_ROOT}/swiftgen.yml"
DEFAULT_NAME_MAP="${REPO_ROOT}/Sources/Hugeicons/Resources/Hugeicons/name-map.json"
DEFAULT_SWIFTGEN_OUTPUT="${REPO_ROOT}/Sources/Hugeicons/Generated/HugeiconsGenerated.swift"
DEFAULT_WRAPPER_OUTPUT="${REPO_ROOT}/Sources/Hugeicons/Generated/Hugeicons+Catalog.generated.swift"
WRAPPER_SCRIPT="${SCRIPT_DIR}/generate_hugeicons_wrapper.swift"

SWIFTGEN_CONFIG="${DEFAULT_SWIFTGEN_CONFIG}"
NAME_MAP="${DEFAULT_NAME_MAP}"
SWIFTGEN_OUTPUT="${DEFAULT_SWIFTGEN_OUTPUT}"
WRAPPER_OUTPUT="${DEFAULT_WRAPPER_OUTPUT}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--swiftgen-config <path>] [--name-map <path>] [--swiftgen-output <path>] [--wrapper-output <path>]

Runs:
1) swiftgen config lint
2) swiftgen config run
3) Hugeicons wrapper generation
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --swiftgen-config)
      SWIFTGEN_CONFIG="$2"
      shift 2
      ;;
    --name-map)
      NAME_MAP="$2"
      shift 2
      ;;
    --swiftgen-output)
      SWIFTGEN_OUTPUT="$2"
      shift 2
      ;;
    --wrapper-output)
      WRAPPER_OUTPUT="$2"
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

if [[ ! -f "${SWIFTGEN_CONFIG}" ]]; then
  echo "SwiftGen config not found: ${SWIFTGEN_CONFIG}" >&2
  exit 1
fi

if [[ ! -f "${NAME_MAP}" ]]; then
  echo "Name-map not found: ${NAME_MAP}" >&2
  exit 1
fi

if [[ ! -f "${WRAPPER_SCRIPT}" ]]; then
  echo "Wrapper generator script not found: ${WRAPPER_SCRIPT}" >&2
  exit 1
fi

swiftgen config lint --config "${SWIFTGEN_CONFIG}"
swiftgen config run --config "${SWIFTGEN_CONFIG}"

"${WRAPPER_SCRIPT}" "${NAME_MAP}" "${SWIFTGEN_OUTPUT}" "${WRAPPER_OUTPUT}"

generated_count="$(rg -c '^[[:space:]]*static var ' "${WRAPPER_OUTPUT}" | tr -d '[:space:]')"
echo "Hugeicons Swift API generated successfully."
echo "SwiftGen output: ${SWIFTGEN_OUTPUT}"
echo "Wrapper output: ${WRAPPER_OUTPUT}"
echo "Public icon properties: ${generated_count}"
