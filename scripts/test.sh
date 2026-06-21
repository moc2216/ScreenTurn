#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_CONFIG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/screenturn-test.XXXXXX")"

cleanup() {
  rm -rf "$TEST_CONFIG_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"
SCREENTURN_CONFIG_DIR="$TEST_CONFIG_DIR" swift run ScreenTurnSelfTest
