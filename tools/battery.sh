#!/usr/bin/env bash
## The full regression battery, twice over.
##
## Pass 1 runs every headless suite in the machine's current .godot state.
## Pass 2 empties .godot/global_script_class_cache.cfg first and restores it
## afterwards -- the state of any machine that pulled new classes but has not
## opened the editor since. A suite may only call itself green if it passes
## both ways, because the stale state is exactly what a player's machine
## carries, and the shop once read as empty on it with zero script errors:
## the shared harness asked find_children for "CozyCard", a type string that
## resolves through ClassDB only while the editor's cache is warm.
##
## Skipped here: regression_luminance.gd and regression_scrims.gd need a
## display (see docs/TESTING.md). Per-suite logs land in .godot/battery_logs/.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
CACHE=".godot/global_script_class_cache.cfg"
BACKUP=".godot/global_script_class_cache.battery.bak"
LOGS=".godot/battery_logs"
HAD_CACHE=0
if [ -f "$CACHE" ]; then HAD_CACHE=1; fi

restore() {
	if [ "$HAD_CACHE" = 1 ]; then
		mv -f "$BACKUP" "$CACHE" 2>/dev/null || true
	else
		rm -f "$BACKUP" "$CACHE" 2>/dev/null || true
	fi
}
trap restore EXIT

run_all() {
	local label="$1" failures=0 test log
	mkdir -p "$LOGS"
	for test in tests/regression_*.gd; do
		case "$test" in *luminance*|*scrims*) continue ;; esac
		log="$LOGS/${label}_$(basename "$test" .gd).log"
		if "$GODOT" --headless --path . --script "res://$test" > "$log" 2>&1; then
			echo "ok   [$label] $test"
		else
			echo "FAIL [$label] $test  (log: $log)"
			failures=$((failures + 1))
		fi
	done
	return $failures
}

echo "== pass 1: the machine's current .godot state =="
if ! run_all current; then
	echo "battery: pass 1 red"
	exit 1
fi

echo "== pass 2: emptied global-class cache (a player's stale machine) =="
if [ "$HAD_CACHE" = 1 ]; then
	cp "$CACHE" "$BACKUP"
else
	mkdir -p .godot
fi
: > "$CACHE"
if ! run_all stale; then
	echo "battery: pass 2 red"
	exit 1
fi

echo "battery: both passes green"
