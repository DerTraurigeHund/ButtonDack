#!/bin/bash
# Run script for ButtonDack Desktop App
# Usage: ./run.sh [--debug]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR/build/linux/x64/release/bundle"

if [ "$1" = "--debug" ]; then
  BUNDLE_DIR="$SCRIPT_DIR/build/linux/x64/debug/bundle"
fi

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: Build not found at $BUNDLE_DIR"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

export LD_LIBRARY_PATH="$BUNDLE_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$BUNDLE_DIR/buttondack_settings"
