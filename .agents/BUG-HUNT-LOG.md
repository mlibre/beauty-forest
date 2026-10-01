# Endless bug hunt — iteration log

Skill: `.agents/skills/endless-bug-hunt/SKILL.md`
Target: 100 skill invocations (each one = one complete hunt→trace→fix→verify→commit
iteration, or one full pass that legitimately finds nothing new).

Godot 4.7.2 · branch master · never push.

## Progress

Completed iterations: 15 (see below)

## Iterations

| # | Cause | Commit | Status |
|---|-------|--------|--------|
| 1 | `_clean_meta` inverted guard wiped save file | 4985359 | done |
| 2 | Dragon spawned on player (sorted rooms re-scan no-op) | 2c4ed12 | done |
| 3 | Song-note aim height != connect-test height | 2c4ed12 | done |
| 4 | Ambience never re-armed after non-finale dragon | 2c4ed12 | done |
| 5 | Stairwell + Peddle shared a clearing | 2c4ed12 | done |
| 6 | Dream chime landed on stairwell glow disc | 2c4ed12 | done |
| 7 | play_chord flat envelope -> click on every hit/step | c333127 | done |
| 8 | sunbeam shader emitted exactly 0.0 (open cone) | 5a25404 | done |
| 9 | Invisible 1.70m walls ringing 11/13 clearings | 2d0b4c9 | done |
| 10 | Boss/feeling spawn omit `occupied` -> wisp interpenetration | — | dropped, see below |
| 11 | COZY button did nothing while shop/journal open | a7b9df3 | done |
| 12 | Raising text scale never refit the HUD (card over hint bar) | 5c73fd9 | done |
| 13 | Script runs wrote the player's real profile (text_scale=2.0) | eb2d145 | done |
| 14 | CozyVFX per-burst allocation | — | refuted, see below |
| 15 | Peddle promised a capped charm would be worn | b4788a7 | done |
| 16 | Feeling ceremony at high rhythm_window; heart pickups | — | refuted, see below |
| 17 | Quit path / save atomicity / sticker cap | — | refuted, see below |
| 18 | Region ranges / ambient beds | — | refuted, see below |
| 19 | _separate_wisps at maximum density | — | refuted, see below |

Refuted (audit's claim did not survive measurement):
- B1. Log label over status card / off-screen -- NO. Label is text-clipped at
  165px, never hits the hint bar, never leaves the window. Audit's numbers came
  from measuring custom_minimum_size instead of the real rect.
- B2. Story card overflows by up to 307px -- NO at every size with real text.
  Only clips below 260px tall, which is below any sane window.

## Backlog (ranked, from the three delegated audits — all need independent verification)

Tier 8 (UI):
- B3. DONE (5c73fd9)
- B4. DONE (a7b9df3)
- B10. DROPPED. Un-aware spawn picks land on an occupied cell 0.2% of the
  time (9/4000). _separate_wisps() pushes overlapping pairs apart every frame,
  so the worst case is a one-frame cosmetic pop. Below the fix bar.
- B11. COZY button / C key silently no-op in SHOP and JOURNAL modes

Harness (found by the hunt, not by an audit):
- H1. TestProfile.begin() was opt-in and 11 of 14 suites skipped it, so a test
  run could write the player's real save/settings. Fixed in BeautyData (a
  --script run gets a throwaway dir by default). All 14 suites in sequence now
  leave the player profile with 0 files.
- H2. Existing 200%-text check called _fit_layout() by hand, masking B3.
- H3. A regression must not damage real state to prove itself.

Tier 6 (feel/audio):
- B5. DONE (c333127)  - B6. CozyVFX.burst allocates mesh+2 materials per call; ~75 bursts/sec

Tier 7 (rendering):
- B7. DONE (5a25404)  - B8. DONE (2d0b4c9)

Tier 2/3 (progression/logic):
- B9. `_open_settings()` twice corrupts previous_mode -- CONFIRMED dynamically
  but NOT player-reachable (the modal scrim covers the pause card on both the
  keyboard and touch routes). Backlog only.

- Lullaby ceremony at rhythm_window 0.25/1.4/3.0 x gentle/standard/bold. The
  player CAN die mid-ceremony (standard and bold, standing in a 15-wisp swarm,
  HP 100 -> 0 at ~10-12s) but that is legitimate combat, not a defect: the same
  ceremony with the hero out of the swarm completes in every style and HP RISES
  (100 -> 135/130/150). Dying mid-ceremony leaves `_lullaby_active` true, but
  the death screen is clean -- beat ring hidden, only the two nap buttons, E
  inert -- and `_start_run` resets step/timer/flag, so nothing leaks into the
  next run. A ceremony is also bounded: at the loosest window it is 21.8s.
- Heart pickups: 60s lifetime with a visible `heart_expired` log line, collect
  emits once (a `_collected` guard blocks the deferred double-free heal), and a
  real soothe drops one that heals on contact (40 -> 140, capped at hp_max).
  Verified through the game's own spawn path, not a hand-built fixture.
  (Probes 54/55 both "failed" first; both were probe bugs -- `setup()` takes
  four args, and lifetime runs on processed frames not physics frames.)

- Quit path (probe 57/58). quit_gracefully() never saves, but it does not need
  to: every `meta[...]` write in the codebase is immediately followed by
  `save_meta` (7 call sites, checked). Measured RAM-vs-disk diffs = [] after a
  run start, after a soothe, and after a cherry-picked sticker award. `runs`,
  `sparkles`, `level`, `xp` are deliberately run-only -- a fresh walk is
  supposed to start over. Three rapid quits collapse into one pending quit
  (the `_quitting` guard holds), and the drain window leaves the audio tree
  consistent.
- Write atomicity (probe 59). 200 back-to-back settings writes and 100 meta
  writes, the shape a slider drag produces: 0 failures, final read valid, no
  partial reads, no `.tmp` leftovers. The stage-then-rename in save_settings
  and save_meta holds under repetition.
- `stickers.slice(-40)` (run_state.gd:337) is unreachable: STICKERS has 11
  entries and _award_sticker refuses duplicates. Harmless, but it is dead
  defensive code -- flagged, not removed, because it is a guard on persisted
  data that a hand-edited save could exceed.

- Region + ambient system (probes 60/61/62). Ranges are contiguous 1-4, 5-8,
  9-12, 13-13: no gap, no overlap, no inverted range, no region no floor
  reaches, and the last range ends exactly on CAMPAIGN_LENGTH. All four regions
  get a DISTINCT cached ambient (4 streams for 4 regions), every one playing,
  and `_ambient_should_play` is re-armed across a floor change including
  13 -> 12. Ambient peak decoded properly is 0.1972 of full scale against
  0.1889 predicted by the generating math -- it is as loud as intended.
  (Probe 61 read byte PAIRS as single samples and reported a bogus 0.008 peak;
  62 decoded little-endian s16 by hand and got the real number. That is the
  same class of mistake as reading custom_minimum_size instead of a real rect.)

- _separate_wisps (probes 63-67). This took four probes to settle, and three of
  them first reported a defect that did not exist.
  - At spawn: 0 overlapping pairs on floor 1 (8 wisps) and floor 13 (32 wisps).
    The `occupied` dict in the seeder already prevents overlap.
  - Forced 32 wisps onto ONE point: resolved into a 19.5m x 0.00m LINE. Real,
    but unreachable: identical coordinates give every pair a zero offset, so
    the `distance < 0.001` fallback hands them all the same direction. The
    generator cannot produce that state.
  - Scattered in a 1m ball -> 4.7m x 5.2m disc. Two clumps 4m apart -> 7.3m x
    3.4m. The solver converges to a proper 2D spread; the line was my setup.
  - Under REAL tick_behavior + move_and_slide with the hero parked: 0
    overlapping pairs in every one of 1500 frames, never more than 1 wisp
    inside the 2.25m bump radius, HP untouched at 120/120. Physics resolves
    convergence; _separate_wisps is a safety net that never fires.
  - Cost at n=32: 0.002 ms/frame. Not a performance issue either.
  Lesson worth keeping: an O(n^2) relaxation solver looks pathological until you
  check whether the engine's own physics already prevents the pathological
  input. Two of the four probes were convincing-looking lies.

Audit backlog is now exhausted: every item is done, refuted, or unreachable.
Future iterations hunt fresh ground rather than re-reading the audits. (NOT player-reachable — scrim blocks input)
- B10. `_spawn_boss`/`_spawn_feeling` omit the `occupied` dict -> 0.75% two wisps interpenetrate
- B11. HeroRig staff rotation.x written by both hero_rig.gd:398 and an anim track

Tier 9 (perf/dead code):
- B12. `CozyMinimap._map_revision` bumps every set_map -> texture cache can never hit
- B13. `_prune_disconnected_floor` never triggers (0/120 maps disconnected)
- B14. `random_floor_cell` Vector2i(2,2) fallback unreachable

Code-health violations:
- V1. dungeon_generator.gd:7-9 doc claims "looped topology"; 116/120 maps are >90% open
- V2. world_scenery.gd:264-276 long comment guarding dead code (B7)
- V3. forest_world.gd:134-140 two paragraphs contradict each other
- V4. dungeon_generator.gd:239-240 dead fallback (same as B14)
- V5. `_settings` in game_ui_state.gd:66 written but never read by game code

## Rules I am holding to

- Every reported defect needs observable evidence or a violated invariant.
- A defect reachable only by direct method call is NOT player-reachable -> backlog only.
- Treat every probe FAIL as suspect test code first. Five "bugs" were probe bugs.
- Revert each fix and confirm the new regression FAILS before trusting it.
- Delete probes before committing; convert to shipped regressions.
