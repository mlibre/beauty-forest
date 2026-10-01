# Endless bug hunt — iteration log

Skill: `.agents/skills/endless-bug-hunt/SKILL.md`
Target: 100 skill invocations (each one = one complete hunt→trace→fix→verify→commit
iteration, or one full pass that legitimately finds nothing new).

Godot 4.7.2 · branch master · never push.

## Progress

Completed iterations: 1-6 (see below)

## Iterations

| # | Cause | Commit | Status |
|---|-------|--------|--------|
| 1 | `_clean_meta` inverted guard wiped save file | 4985359 | done |
| 2 | Dragon spawned on player (sorted rooms re-scan no-op) | 2c4ed12 | done |
| 3 | Song-note aim height != connect-test height | 2c4ed12 | done |
| 4 | Ambience never re-armed after non-finale dragon | 2c4ed12 | done |
| 5 | Stairwell + Peddle shared a clearing | 2c4ed12 | done |
| 6 | Dream chime landed on stairwell glow disc | 2c4ed12 | done |

## Backlog (ranked, from the three delegated audits — all need independent verification)

Tier 8 (UI):
- B1. Mote's log label painted over the status card + hint bar, 71px off-screen bottom
- B2. Story card overflows window bottom by up to 307px (show_story never refits)
- B3. apply_settings never refits layout; _compact_hud is stale after text_scale change
- B4. COZY button / C key silently no-op in SHOP and JOURNAL modes

Tier 6 (feel/audio):
- B5. play_chord envelope never decays -> ~40% end discontinuity (click) on every hit/step
- B6. CozyVFX.burst allocates mesh+2 materials per call; ~75 bursts/sec

Tier 7 (rendering):
- B7. sunbeam.gdshader: capless cylinder means v_radial==1.0 always -> EMISSION==0
- B8. Invisible 1.7m wall cells ringing clearings (collider where no tree drawn)

Tier 2/3 (progression/logic):
- B9. `_open_settings()` twice corrupts previous_mode (NOT player-reachable — scrim blocks input)
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
