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
| 20 | reduced_motion coverage | 6d5b8f1 | FIXED: boss light ignored Still Forest |
| 21 | world_scenery dead declaration | — | no code change; see below |
| 22 | high_contrast coverage | fd86185 | FIXED: contrast never reached the text |
| 23 | damage_taken / wisp_speed / rhythm_window | — | refuted; settings sweep closed |
| 24 | Bump softness slider direction | e6fb47d | FIXED: dragging right made it harder |
| 25 | Extra song time / lullaby beat window | — | refuted; settings controls closed |
| 26 | Charm swap evicts an unnamed charm | f0b4682 | FIXED: silent eviction, now named |
| 27 | Verse swap + free items claim ownership | — | FIXED: silent eviction and false ownership |

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

- reduced_motion, every animated channel (probes 68-70). One real defect and two
  probe bugs, and the probe bugs came first.
  - Propagation is correct: flipping the setting through _apply_settings reaches
    world, hero, ui and all 32 wisps.
  - FIXED (6d5b8f1): wisp.gd:300 breathed the boss light on a sine with no
    reduced_motion guard. 0.19-0.26 peak-to-peak light_energy with the setting
    ON. It was the only animated channel in the file without a guard -- the bob,
    the halo spin and the curious aura twinkle all had one.
  - Probe bug 1: I read ui._reduced_motion after mutating game.settings in
    place, never calling _apply_settings. It reported the UI as not receiving
    the setting. It was receiving it fine.
  - Probe bug 2: I sampled wisp.position.y, but the bob is written to
    _visual.position.y -- a child node. Both settings measured 0.0000.
  - Harness bug, worth remembering: the first regression sampled 150 tight-loop
    ticks. The breath is driven by Time.get_ticks_msec(), so that spans ~0ms of
    real time and measured a 0.00016 swing -- it would have "passed" a dead
    light. It now spans 1200ms of wall clock. Same for quit(1) inside a helper:
    it does not stop execution, so the suite printed its OK marker after
    declaring failure. Helpers return a bool now.
  - world_scenery.gd:25 declares _reduced_motion and nothing reads or writes
    it. Dead, not a missed feature: the scenery is static geometry with no
    _process and no sin() anywhere in the file.

- high_contrast (probes 71-73). Same shape as reduced_motion, and it had the
  same kind of hole, only quieter.
  - FIXED: the setting drove _overlay_scrim, _shop_scrim and the minimap, and
    nothing else. The scrims sit BEHIND the cards, and the cards carry their
    own near-opaque fill (shop 0.98 alpha), so every label a player reads sat at
    exactly the same ratio with the setting on or off.
      shop   13.65:1 -> 18.58:1   story 9.64:1 -> 14.56:1   overlay 10.02:1 -> 14.72:1
    The minimap half was already working (floor/bg 5.96 -> 9.00, floor/wall
    3.67 -> 5.51), which is why the feature read as working when tested
    casually.
  - The fill has to survive the card being refilled -- shop, journal and
    settings share one card -- so the base fill, border and border width are
    captured in meta on first apply and restored when the setting goes back
    off. Verified: the darker fill is identical after all three screens open.
  - Probe bug: I first computed the ratio against a composited forest colour,
    which is the right physics and the wrong question, because the card's own
    fill sits between them. Measuring text against what is actually behind it
    gave the real answer.
  - Godot 4.7.2 StyleBoxFlat has no get_border_width_all(); use
    border_width_top. Worth remembering, it cost a parse-error round trip.

- The remaining three settings (probes 74-77). All correct, and it took three
  probes to find that out because each one first produced a convincing lie.
  - Probe 74 said wisp_speed "saturates above 1.0" -- identical velocity at 1.0
    and 3.0. False: it passed kindling_speed=1.0 by hand, and main.gd computes
    it as wisp_speed/0.85. It also compared wisps[0] across separate
    _start_run calls, which reseeds the wisp mix, so it was comparing a
    Shambler against a Crawler.
  - Probe 75 said damage_taken was "0.0000 warmth" at every setting. False: the
    1.0s post-load invulnerability swallowed every hit. It also restarted the
    run per setting, reseeding the mix again.
  - Probe 76, on ONE fixed run with the guards opened, shows damage_taken is
    correctly linear: at x0.357 a 10-point hit deals 4; at x4.286 it deals 43.
    No clamping, no floor, no ceiling anywhere in 0.25-3.0.
  - The one interesting edge: amount is an int, so a 1-point hit rounds to 0 at
    the bottom of the slider. probe77 shows the smallest contact_damage the
    game can deal is 4 (floor 1) rising to 9 (floor 13), and the 1.5x feeling
    path only makes it bigger. So no real hit is ever swallowed. Not a defect.
  - wisp_speed, damage_taken and rhythm_window all verified. The settings sweep
    is closed: reduced_motion (fixed 6d5b8f1), high_contrast (fixed fd86185),
    text_scale (fixed in run_state.gd), muted, volume, and these three. Two of
    six had a silent hole, both found by measuring behaviour rather than
    grepping for the setting name.

- Bump softness (probes 78-80). The one remaining readability defect, and it
  was a control-direction bug rather than a math bug.
  - FIXED: "Bump softness" stores damage_taken, a damage MULTIPLIER, so the
    slider ran softest-on-the-left. A player reaching for gentler bumps dragged
    right and landed on x3.00 -- four times the damage they were trying to
    avoid. Every other slider in the panel increases with a rightward drag;
    this was the only one that decreased.
  - The obvious fix does not work: HSlider in Godot 4.7.2 silently clamps
    min_value=3.0, max_value=0.25 to min=max=3.0, every read returns 3.0, and
    value_changed never fires again. probe79 measured exactly that before any
    code was written. So _inverted_slider_row keeps a normal 0..1 track and maps
    the position to the stored value itself.
  - Verified both directions with real damage numbers: drag right -> stored
    0.25, a 10-point hit deals 4 warmth; drag left -> stored 3.00, 43 warmth.
    The handle also sits where the stored value belongs, so the default x0.70
    rests near the soft end.
  - Reverting to the plain slider makes regression_ui exit 1 with right=1.00
    and left=0.25 -- exactly backwards, which is the clearest possible proof.
  - One thing the probes caught in my own test: a print with a %s verb and two
    arguments printed its format string literally. It would have hidden the
    numbers on the one line that reports this invariant.

- Extra song time, and the beat window behind it (probes 81-84). The hit test
  looked like it might be an exact-frame flag rather than a window, which would
  have made the slider a lie. It is not.
  - _judge_lullaby_beat reads _lullaby_gold, a bool, so it LOOKS like an exact
    frame test. But _tick_lullaby only raises it on a tick and
    _judge_lullaby_beat clears it on a successful hit, so the flag stays up for
    the whole beat interval -- 8 frames even at the tightest setting. That is a
    real window, and it is what "extra song time" widens.
  - At the tightest setting a press 0.30s after the gold beat scored 6/6 while
    one 0.15s after scored 0/6, which looked backwards. Frame-by-frame
    (probe82) shows why: the 0.30s press lands on the NEXT gold beat, which is
    legitimately countable. Not a defect.
  - The beat freezes while paused (_auto_combat early-returns unless mode is
    PLAYING) and resumes with the timer still positive -- 0.7667s of time owed,
    so the player is never handed a beat that came due during a pause.
  - A long frame advances the step by one, not by the delta. A huge delta is
    absorbed into the timer rather than skipped, so the song runs slow rather
    than fast. That is the forgiving direction, and it means no beat is ever
    offered without warning.
  - Gold beats offered matches the ideal at real frame rates (0.016s: 0 of 0,
    0.25s: 3 of 3). Only an absurd delta falls behind.
  - The ceremony opens with 1.18s and a spoken count-in from Mote.
  - Probe bug: probe83 printed "the step saturates at 30" for delta 2.0 and
    10.0. It was counting 30 ITERATIONS, not measuring a clamp. probe84 shows
    one call at delta=10.0 advances the step by exactly 1. No clamp exists.
  - Settings controls are now fully closed: 3 toggles, 5 sliders, 1 reset, all
    verified. Two had defects (high_contrast fd86185, bump softness e6fb47d),
    both found by asking what the player sees rather than whether the math is
    right.

- The charm swap (probes 85-90). Found by asking what the player SEES, again.
  - Dead code first: run_state.gd:147 had an elif that returned after the
    sparkles were spent and ownership recorded. Unreachable -- it needs
    charms_owned[key] false AND charms_equipped[key] true. Verified across 960
    purchases in 60 random orders: 0 divergences, equipped was always a subset
    of owned. Not a defect.
  - FIXED: with all three slots full, tapping a pocketed charm built the
    replacement loadout by walking charms_owned.keys() and keeping the first
    MAX-1, so whichever worn charm fell last in insertion order was evicted --
    never the weakest, never the one the player would choose -- and nothing in
    the UI said a swap had happened at all. The button read "in pocket -- tap
    to wear" and the tooltip promised "tap to swap it in", with no unequip
    control anywhere in the shop.
  - Now _loadout_replacing() walks the WORN set (matching what the stanza swap
    already did correctly), so the evicted charm is a stable choice, and Peddle
    names it: "Ember Mitten on. Echo Chime rests in your pocket -- tap it any
    time to swap back."
  - Verified: the evicted charm stays owned so it can be swapped back; a second
    swap evicts the next worn charm (scarf, not echo again); 12 swaps lose no
    ownership.
  - Regression bug worth keeping: both charm checks read "the newest log line",
    which is racy -- a wisp drifting home during the test pushes a line above
    the purchase. The first revert attempt failed on the WRONG check for exactly
    that reason. Both now search upward for the newest line mentioning the
    charm they caused (_newest_line_mentioning).
  - Operational note: a revert-check run inside execute_code hit the 300s cell
    timeout and left the revert APPLIED to run_state.gd. Always re-read the file
    after a timeout before trusting it, and prefer doing the revert in a single
    foreground terminal call with a bounded `timeout`.

- The verse swap, and everything the shop claims about free things (probes
  91-98). The sibling of iteration 26, and it had the same defect plus a second
  one underneath.
  - FIXED, part 1: with both verse slots full the swap evicted one and the log
    did not change AT ALL -- probe91 measured `did the log change at all? false`.
    Mote now says what steps back: "Verse of Hearth it is. Verse of Echoes
    steps back for now -- tap it again any time."
  - FIXED, part 2: the shop listed every unworn verse AND every unchosen
    counter-melody as "in pocket -- tap to wear" with the tooltip "already
    yours. Tap to wear it." Both are free gifts nobody owns; there is no
    purchase and no pocket, so that copy described a transaction that never
    happened. They now read "swap it in for a verse you're humming" and "hum
    this instead", with tooltips that say what a tap actually does. 17 of 17
    free rows verified.
  - Five probes were needed because I could not find the shop rows. They live
    inside a ScrollContainer -> VBoxContainer under _shop_frame, and
    _shop_content is only the settings list. Probes 94, 95 and 96 all reported
    "0 buttons", and probe92's "0 lies" was VACUOUS rather than a pass -- it had
    been reading an empty tree. Only probe98, which dumped the shape first,
    found the 26 rows. Lesson: when a search returns zero results in a codebase
    that should have some, dump the structure before concluding anything.
  - probe93 asserted in its own print that the mote swap was "Currently
    silent" without having checked; the very next lines showed the log DID
    change. An unverified claim in a probe's own output is still a claim.
  - First revert attempt produced unbalanced parentheses in game_ui_screens.gd
    and the suite failed to even parse. Reverted each half separately with
    exact-match edits instead: the log half fails with "a full-slot verse swap
    said nothing about what it displaced", the copy half with "a free item
    claimed ownership: ... -- already yours".

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
