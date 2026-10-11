#!/usr/bin/env bash
# Parse-check every script, and fail on mixed indentation.
#
# This repo's GDScript is one-space-or-tab per FILE, and a patch written with
# the wrong one fails the whole project at load with a cascade of "Could not
# resolve super class" errors that name the wrong file. Checking each script
# on its own turns that into one line naming the real culprit.
#
# Usage: scripts/check_indent.sh   (run from the repo root)
set -uo pipefail
cd "$(dirname "$0")/.."

status=0

for f in scripts/*.gd tests/*.gd tests/support/*.gd _audit/*.gd; do
    [ -e "$f" ] || continue
    tabs=$(grep -cP '^\t' "$f" || true)
    spaces=$(grep -cP '^    ' "$f" || true)
    if [ "$tabs" -gt 0 ] && [ "$spaces" -gt 0 ]; then
        echo "MIXED INDENT: $f (tabs=$tabs spaces=$spaces) -- pick one for the whole file" >&2
        status=1
    fi
done

if [ "$status" -ne 0 ]; then
    exit 1
fi

echo "indentation: clean"
