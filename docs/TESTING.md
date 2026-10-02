# Testing

How to run the suites that guard this game. For what the game *is*, see the
project `README.md`.

Run everything from the project root.

## Regressions

Every suite below is headless-safe. Run them all:

```bash
for test in tests/regression_*.gd; do
  case "$test" in *luminance*|*scrims*) continue;; esac
  godot --headless --path . --script "res://$test" || exit 1
done
```

The `case` skips the two suites that need a display (below). One suite:

```bash
godot --headless --path . --script res://tests/regression_player.gd
```

A passing suite prints `<TOKEN>_OK (N checks)` and exits 0. Anything else is a
failure — `tests/support/test_case.gd` collects checks and owns the exit code,
because Godot's own `assert()` only logs a `SCRIPT ERROR` and keeps going, which
let suites print their OK line with the game broken.

## Integration smoke

Boots `scenes/main.tscn` and drives a whole run: menu → floor → rewards → shop →
journal → settings → dragon and Big Feeling floors.

```bash
godot --headless --path . --script res://tests/runtime_smoke.gd
```

Prints `BEAUTY_FOREST_SMOKE_OK`.

## The two suites that need a display

`regression_luminance.gd` and `regression_scrims.gd` render real frames and
measure them. A headless build has no rasterizer, so
`RenderingServer.frame_post_draw` never fires and the run hangs to the timeout
and exits 124 — not a test failure. Run them windowed:

```bash
godot --path . --resolution 640x360  --script tests/regression_luminance.gd
godot --path . --resolution 1280x720 --script tests/regression_scrims.gd
```

Both defend the "bright, cozy, never dark" brief from opposite sides:

- `regression_luminance.gd` catches a screen that renders too dark to be
  cheerful. It caught the title menu inheriting the pause card's scrim: menu
  measured 99 against gameplay's 176.
- `regression_scrims.gd` catches the reverse — a card that dims the world too
  far — and checks that High Contrast still darkens *more* than the normal case,
  so the accessibility setting cannot quietly become a no-op.

## Art gates

Both are dev tools, not shipped. Worth running after any art change: every
glyph is drawn pixel by pixel into an `Image` at runtime, so nothing about
legibility shows up in a screenshot review.

```bash
godot --headless --path . --script res://tests/capture_glyphs_check.gd
godot --headless --path . --script res://tests/capture_text_census.gd
```

- `capture_glyphs_check.gd` rejects any glyph too dark, desaturated, solid or
  thin to read against sunlit grass. Currently 57 glyphs, 0 needing attention.
- `capture_text_census.gd` counts the text a player can actually see per screen
  and **exits non-zero if the walking screen paints any** — it is a gate, not a
  report, per the project's icon-not-instructions rule. It starts a real run
  first and fails if the HUD is off screen, so that zero is measured rather than
  vacuous, and it reads hand-painted `draw_string` captions as well as Labels:
  a caption the minimap used to carry would otherwise be invisible to the count.

## Saves

Save data lives in Godot's per-user `user://` directory, separate from the
gentler-forest settings. Suites redirect it to a throwaway profile via
`TestProfile`, so they never touch a real save — without it, a test run inflated
the player's Visits, stickers and dragons (a real profile reached
`dragons_sung = 143` purely from test runs). Profiles older than an hour are
swept on the next run, which reclaims the directories left by suites that died
through an early failure path.

## Other checks

```bash
godot --headless --path . --import                                   # import/check
godot --headless --path . --check-only --script res://path/to/file.gd # parse one script
```