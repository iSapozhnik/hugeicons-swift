#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="@hugeicons/core-free-icons"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_VERSION_LOCK="${REPO_ROOT}/version.lock"
DEFAULT_OUTPUT_DIR="${REPO_ROOT}/Sources/Hugeicons/Resources/Hugeicons/raw"
CONVERTER_SCRIPT="${SCRIPT_DIR}/convert_hugeicons_core_to_svg.mjs"

VERSION_LOCK="${DEFAULT_VERSION_LOCK}"
OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--version-lock <path>] [--output-dir <path>]

Fetches pinned free Hugeicons icon modules from npm, converts to SVG, and writes to OUTPUT_DIR.
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

if [[ ! -f "${VERSION_LOCK}" ]]; then
  echo "Version lock file not found: ${VERSION_LOCK}" >&2
  exit 1
fi

VERSION="$(awk '!/^[[:space:]]*#/ && NF {print $1; exit}' "${VERSION_LOCK}")"
if [[ -z "${VERSION:-}" || "${VERSION}" == "0.0.0" ]]; then
  echo "Set a valid pinned version in ${VERSION_LOCK} before fetching." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

pushd "${TMP_DIR}" >/dev/null
TARBALL="$(npm pack "${PACKAGE_NAME}@${VERSION}" | tail -n 1)"
tar -xzf "${TARBALL}"
popd >/dev/null

if [[ ! -f "${CONVERTER_SCRIPT}" ]]; then
  echo "Converter script not found: ${CONVERTER_SCRIPT}" >&2
  exit 1
fi

ESM_DIR="${TMP_DIR}/package/dist/esm"
if [[ ! -d "${ESM_DIR}" ]]; then
  echo "Expected ESM icon directory not found in package payload: ${ESM_DIR}" >&2
  exit 1
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

REPORT_PATH="${OUTPUT_DIR}/conversion-report.json"
node "${CONVERTER_SCRIPT}" \
  --esm-dir "${ESM_DIR}" \
  --output-dir "${OUTPUT_DIR}" \
  --source-package "${PACKAGE_NAME}" \
  --source-version "${VERSION}" \
  --report-path "${REPORT_PATH}"

if [[ ! -f "${REPORT_PATH}" ]]; then
  echo "Conversion completed without report output: ${REPORT_PATH}" >&2
  exit 1
fi

module_count="$(node -e 'const fs=require("node:fs");const r=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(r.moduleCount ?? ""));' "${REPORT_PATH}")"
converted_count="$(node -e 'const fs=require("node:fs");const r=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(r.convertedCount ?? ""));' "${REPORT_PATH}")"
skipped_count="$(node -e 'const fs=require("node:fs");const r=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(r.skippedCount ?? ""));' "${REPORT_PATH}")"

if [[ ! "${converted_count}" =~ ^[0-9]+$ ]]; then
  echo "Invalid convertedCount in report: ${converted_count}" >&2
  exit 1
fi

if [[ "${converted_count}" -eq 0 ]]; then
  echo "Conversion completed but converted icon count is zero." >&2
  exit 1
fi

icon_count="$(rg --files "${OUTPUT_DIR}" -g '*.svg' | wc -l | tr -d '[:space:]')"
if [[ "${icon_count}" -eq 0 ]]; then
  echo "No SVG files written to output directory: ${OUTPUT_DIR}" >&2
  exit 1
fi

echo "Fetched and converted ${icon_count} SVG icons from ${PACKAGE_NAME}@${VERSION} into ${OUTPUT_DIR}."
echo "Conversion report: ${REPORT_PATH} (modules=${module_count}, converted=${converted_count}, skipped=${skipped_count})"

if [[ "${skipped_count}" =~ ^[0-9]+$ ]] && [[ "${skipped_count}" -gt 0 ]]; then
  echo "Warning: ${skipped_count} icon modules were skipped during conversion. See ${REPORT_PATH}." >&2
fi
