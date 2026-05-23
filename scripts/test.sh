#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DERIVED_DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lexi-derived.XXXXXX")"

cleanup() {
  if [[ -n "${DERIVED_DATA_DIR:-}" && -d "$DERIVED_DATA_DIR" ]]; then
    rm -rf "$DERIVED_DATA_DIR"
  fi
}

trap cleanup EXIT INT TERM HUP

cd "$REPO_ROOT"

echo "Using temporary DerivedData: $DERIVED_DATA_DIR" >&2

xcodebuild \
  -project lexi.xcodeproj \
  -scheme lexi \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  test \
  "$@"
