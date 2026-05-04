#!/usr/bin/env bash
set -euo pipefail

CURRENT_TAG="${1:-}"

if [[ -z "${CURRENT_TAG}" ]]; then
  CURRENT_TAG="$(git tag --list 'v*' --sort=-version:refname | head -n 1)"
fi

if [[ -z "${CURRENT_TAG}" ]]; then
  printf 'v0.1.0\n'
  exit 0
fi

if [[ ! "${CURRENT_TAG}" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "Unsupported repository tag format: ${CURRENT_TAG}" >&2
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
NEXT_PATCH=$((PATCH + 1))

printf 'v%s.%s.%s\n' "${MAJOR}" "${MINOR}" "${NEXT_PATCH}"
