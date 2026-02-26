#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

FETCH_SCRIPT="${SCRIPT_DIR}/fetch_hugeicons_free.sh"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify_hugeicons_free.swift"
NAME_MAP_SCRIPT="${SCRIPT_DIR}/generate_hugeicons_name_map.swift"
SWIFT_API_SCRIPT="${SCRIPT_DIR}/generate_hugeicons_swift_api.sh"

DEFAULT_VERSION_LOCK="${REPO_ROOT}/version.lock"
DEFAULT_OUTPUT_DIR="${REPO_ROOT}/Sources/Hugeicons/Resources/Hugeicons/raw"
DEFAULT_MANIFEST_PATH="${REPO_ROOT}/Sources/Hugeicons/Resources/Hugeicons/manifest.json"
DEFAULT_NAME_MAP_PATH="${REPO_ROOT}/Sources/Hugeicons/Resources/Hugeicons/name-map.json"

VERSION_LOCK="${DEFAULT_VERSION_LOCK}"
OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"
MANIFEST_PATH="${DEFAULT_MANIFEST_PATH}"
NAME_MAP_PATH="${DEFAULT_NAME_MAP_PATH}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--version-lock <path>] [--output-dir <path>] [--manifest-path <path>] [--name-map-path <path>]

Phase 5 refresh pipeline:
1) fetch
2) verify
3) regenerate SwiftGen/wrapper API
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
    --manifest-path)
      MANIFEST_PATH="$2"
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

for required in "${FETCH_SCRIPT}" "${VERIFY_SCRIPT}" "${NAME_MAP_SCRIPT}" "${SWIFT_API_SCRIPT}"; do
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

echo "[2/4] Verifying SVG payload + writing manifest..."
"${VERIFY_SCRIPT}" "${OUTPUT_DIR}" "${MANIFEST_PATH}"

echo "[3/4] Regenerating name map + SwiftGen wrapper API..."
"${NAME_MAP_SCRIPT}" "${OUTPUT_DIR}" "${NAME_MAP_PATH}"
"${SWIFT_API_SCRIPT}" --name-map "${NAME_MAP_PATH}"

echo "[4/4] Computing icon delta summary..."
swift - "${HAS_OLD_NAME_MAP}" "${OLD_NAME_MAP_PATH}" "${NAME_MAP_PATH}" <<'SWIFT'
import Foundation

struct NameMapPayload: Decodable {
    struct Entry: Decodable {
        let sourceName: String
        let swiftIdentifier: String
    }

    let entries: [Entry]
}

func loadNameMap(at path: String) throws -> NameMapPayload {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(NameMapPayload.self, from: data)
}

let args = CommandLine.arguments
guard args.count == 4 else {
    fputs("Internal error: expected 3 arguments.\n", stderr)
    exit(1)
}

let hasOldNameMap = args[1] == "1"
let oldPath = args[2]
let newPath = args[3]

do {
    let newEntries = try loadNameMap(at: newPath).entries
    let oldEntries = hasOldNameMap ? try loadNameMap(at: oldPath).entries : []

    let oldByIdentifier = Dictionary(uniqueKeysWithValues: oldEntries.map { ($0.swiftIdentifier, $0.sourceName) })
    let newByIdentifier = Dictionary(uniqueKeysWithValues: newEntries.map { ($0.swiftIdentifier, $0.sourceName) })

    let oldSources = Set(oldByIdentifier.values)
    let newSources = Set(newByIdentifier.values)

    var renamedCount = 0
    var renamedOldSources = Set<String>()
    var renamedNewSources = Set<String>()

    for (identifier, oldSource) in oldByIdentifier {
        guard let newSource = newByIdentifier[identifier], newSource != oldSource else {
            continue
        }
        renamedCount += 1
        renamedOldSources.insert(oldSource)
        renamedNewSources.insert(newSource)
    }

    var addedCount = newSources.subtracting(oldSources).count
    var removedCount = oldSources.subtracting(newSources).count

    let renamedAddedOverlap = newSources.subtracting(oldSources).intersection(renamedNewSources).count
    let renamedRemovedOverlap = oldSources.subtracting(newSources).intersection(renamedOldSources).count
    addedCount = max(0, addedCount - renamedAddedOverlap)
    removedCount = max(0, removedCount - renamedRemovedOverlap)

    print("Hugeicons refresh summary:")
    print("  old count: \(oldSources.count)")
    print("  new count: \(newSources.count)")
    print("  added: \(addedCount)")
    print("  removed: \(removedCount)")
    print("  renamed: \(renamedCount)")
} catch {
    fputs("Failed to compute icon delta summary: \(error)\n", stderr)
    exit(1)
}
SWIFT
