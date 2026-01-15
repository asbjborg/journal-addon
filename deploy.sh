#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)/JournalingAddon"
TARGET_BASE="/Applications/World of Warcraft/_anniversary_/Interface/AddOns"
TARGET_DIR="${TARGET_BASE}/JournalingAddon"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Source addon folder not found: $SOURCE_DIR"
  exit 1
fi

if [[ ! -d "$TARGET_BASE" ]]; then
  echo "Target AddOns folder not found: $TARGET_BASE"
  exit 1
fi

echo "Deploying addon to: $TARGET_DIR"
/usr/bin/rsync -a --delete "$SOURCE_DIR/" "$TARGET_DIR/"
echo "Done."
