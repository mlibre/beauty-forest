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
failure. Every `regression_*` suite but one extends the shared `TestCase`
harness (`tests/support/test_case.gd`): `ok()` collects checks, `finish()` owns
the exit code, and a 600-frame stall watchdog quits a suite that has failed and
stopped moving rather than let it hang. The harness exists because Godot's own
`assert()` only logs a `SCRIPT ERROR` and keeps going, which let suites print
their OK line with the game broken.

The one standalone suite is `regression_quit.gd`: it asserts that the process
exits by itself through the production quit path, and a harness `finish()` would
quit first and preempt the graceful quit it is testing.

Note that `finish()` always prints its `_OK (N checks)` line, even on a failed
run — the `BEAUTY_FOREST_*_FAILED` errors above it and the exit code are the
truth. Trust the exit code when piping output through `tail`.

## The cold-boot invariant

A fresh clone ships no `.godot/` (it is gitignored), and a plain `godot .` never
builds the global-class cache — only the editor does. Every bare global class
name (`extends RunWorld`, `BeautyData.x`) therefore fails to *parse* on a
player's first boot, and it fails at `main.gd:1`, naming a file that is fine.
That is how the game once shipped a boot that only broke on machines that had
never opened the editor.

Two suites hold the line:

```bash
godot --headless --path . --script res://tests/regression_architecture.gd
godot --headless --path . --script res://tests/regression_cold_boot.gd
```

- `regression_architecture.gd` reads every script under `scripts/` and `tests/`
  and enforces the rules that make parsing cache-independent: `extends` names an
  engine class or quotes a res:// path; a bare class reference in real code
  (comments and string literals stripped, multi-line verses included) must sit
  under a `const <Name> := preload("res://...")` in its own file or in a chain
  ancestor — inherited consts are members, so a child may use them; and every
  preload const must point at the file that actually declares the class it is
  named after. It runs in under a second.
- `regression_cold_boot.gd` replays the player's exact situation once per run:
  it copies the project into a throwaway `user://coldboot_copy` (no `.godot`,
  no tests, no VCS noise), launches a second headless engine process against
  the copy, and requires it to reach `main.gd`'s `BEAUTY_FOREST_BOOT_OK`
  marker with zero parse errors and quit by itself.

The dependency direction between the two content modules is load-bearing too:
`beauty_content.gd` may ask `BeautyEndless` questions, never the reverse — a
const borrowed back the other way is a cycle no loader can resolve. That is why
`CAMPAIGN_LENGTH` lives in `BeautyEndless`, with `BeautyContent` re-exporting
it for existing readers.

When you add a script, keep the invariant by hand: quote your `extends` path,
and pin every external class the file uses under one dependency block of
preload consts. `tools/cache_free_sweep.py` does the same mechanically across
the tree (dry-run by default, `--apply` to write), and both suites will reject
the bare reference either way.

## Indentation

GDScript in this project is one indentation style per *file*, and a file that
mixes tabs and spaces fails to parse — the whole project then fails to load with
a cascade of `Could not resolve super class` errors that name the wrong file.

```bash
./scripts/check_indent.sh
```

Run this before blaming a parse error on the script it names.

## Integration smoke

Boots `scenes/main.tscn` and drives a whole run: menu → floor → rewards → shop →
journal → settings → dragon and Big Feeling floors.

```bash
godot --headless --path . --script res://tests/runtime_smoke.gd
```

Prints `BEAUTY_FOREST_SMOKE_OK (N checks)`.

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
  and **exits non-zero if any screen goes over its budget** — it is a gate, not a
  report, per the project's icon-not-instructions rule. It starts a real run
  first and fails if the HUD is off screen, so that zero is measured rather than
  vacuous, and it reads hand-painted `draw_string` captions as well as Labels:
  a caption the minimap used to carry would otherwise be invisible to the count.
  It also counts what a `CozyCard` paints with `draw_string(item_name())`, which
  is not a source literal at all — the minimap's "GROVE MAP" was the precedent
  for looking past Labels, and a ware name is the same class of blind spot.

  Current budgets, set just above the measured count so an ordinary short row
  passes and a paragraph does not:

  | Screen | Budget | Now | What it counts |
  | --- | --- | --- | --- |
  | `PLAYING` | 0 | 0 | nothing at all, by rule |
  | `MENU` | 360 | 298 | title, subtitle, 3 promise captions, 6 buttons, record |
  | `PAUSE` | 820 | 673–705 | glyph-and-number rows, 4 buttons, keys, the floor's mood line |
  | `SHOP` | 700 | 601 | 34 ware names, 4 shelf headings, sparkle count |
  | `NAP` | 250 | 200 | the cozy-nap card: two floor rows, one warm line |
  | `ENDING` | 240 | 176 | the dragons-are-snuggled card: dragon, heart, chime |
  | `JOURNAL` | 380 | 294 | two facts, two stickers; grows with the collection |
  | `SETTINGS` | 320 | 250 | checkboxes and slider rows |
  | `DRAFT` | 420 | ~345 | the level-up draft: heading, 3 one-word cards, one line, plus the log strip beneath (like every `_root` screen) |
  | `WALK-CUE` | 32 | 31 | the longest thing the toast can say mid-walk |

  `PLAYING` is 0 because the HUD genuinely paints no text, but that zero used to
  hide the one voice that *does* speak during a walk: the toast. A cue such as
  "Almost! Wait for the GOLD halo" or "−7 warmth" is transient, and transient is
  not free — a run where Mote narrates every swing is exactly the future this
  project does not want. So the longest cue the source can produce is measured
  separately, and it has a smaller budget than any screen's, because a cue has to
  be read at a glance while moving. It is found by reading every `add_cue` call
  site rather than by triggering the fights, so a cue cannot escape the check by
  being rare; `%d` is measured as `999`, since a cue that is readable at seven
  digits is not readable at three.

  Four of these numbers were wrong before this pass, and the errors were not
  rounding:

  - **Buttons were invisible.** The census swept `Label` only, so every `Button`
    and `CheckButton` in the game went uncounted — the cozy panel claimed 102
    chars while its four checkboxes held more than that between them. It now
    sweeps `BaseButton` and `LineEdit` too. This is the same class of blind spot
    as the `draw_string` fix above: the tool was measuring the absence of its own
    gaps.
  - **The on-screen touch buttons were counted on the walk screen.** A headless
    run reports `is_touchscreen_available()` as `true` (there is no display for it
    to be truthful about), so `PLAYING` picked up six phantom buttons and failed
    its own zero budget. They are now excluded by name.
  - **Four screens were never measured.** The nap card, the ending, the memory
    book and the cozy panel had no budget at all — a gate covering only the
    screens somebody remembered to point it at is half a gate.
  - **`MENU` and `PAUSE` each said the same thing twice.** The menu welded the
    whole control scheme onto its record line while the pause card painted a
    longer version of it; the walk screen carried a third, shorter copy. Both
    duplicates are gone — the controls live in the pause card's
    `_keys_reference()`, once.

  The shop started this work at **1500 chars / 103 labels** — the single biggest
  wall of text in the game. It is a shelf of picture cards now.

  `PAUSE` is the one budget that is not a fixed measurement: the pause card shows
  the floor's mood, and `random_modifier` draws a different `FLOOR_MODIFIERS`
  line each run, so its count moves by up to 60 characters (673–705 observed).
  The budget sits above the longest line on purpose — a budget gate that fails on
  a coin flip is not a gate.

  `JOURNAL` has the most room on purpose. Its length is a player's collection
  rather than an author's paragraph: every fact found and every sticker earned is
  one more line, so a rising count there means the player got more, not that
  someone wrote more.

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

## Dev probes

Not tests — they measure and print, and assert nothing, so they cannot fail a
run. They exist so the numbers in `README.md` are claims you can re-check
instead of take on faith.

| Probe | Question it answers |
| --- | --- |
| `_audit/probe_growth.gd` | Does the hero keep pace with creatures that scale without bound? Walks the real `RunState` to floor 400. |
| `_audit/probe_frame_cost.gd` | What does a floor cost per frame, and how does it scale with depth? |

The growth probe is the one that guards the central promise of the game. It
prints the level, the song-to-creature ratio and the worst ratio on the walk; the
hero reaches level 538 by floor 400 with the ratio held in a 1.4–1.6 band. If a
change to the level curve, soul income or creature scaling ever reintroduces the
runaway, the ratio falls off a cliff and the probe shows it immediately.

Read the frame-cost column as **microseconds**. It sums the six phases that
`_physics_process` runs once each, so ~750 µs at floor 40 is under a millisecond
against a 16 667 µs frame — not the 750 ms a "ms/frame" label once implied.