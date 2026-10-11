---
name: endless-bug-hunt
description: Use when asked to find/fix bugs thoroughly, run a sustained bug-hunting session, root-cause defects one at a time with verified commits, or audit this Godot game for real bugs before shipping.
---

# Endless Bug Hunt

## Operating rules

- Handle one underlying cause per iteration, even when several symptoms share it.
- Prioritize player-visible and correctness failures.
- Keep changes focused and report uncertainty honestly.

## Establish the baseline

1. Read `AGENTS.md`, `project.godot`, and the relevant scenes, scripts.
2. Run `git status --short`. Preserve all existing changes; never reset, discard, or overwrite them.
3. Choose an end condition: fixed iteration budget, queue drained, or endless.
4. Build a candidate queue across tiers 1–9. Record evidence, affected flow, severity, reproduction status, and next action; re-rank as evidence changes. Inventory authored source files against those rules rather than limiting review to today’s changes.

## One-defect iteration

1. **HUNT** — Identify a concrete failure and its affected flow. State the invariant or branch that should hold but does not.
2. **REPRODUCE**
3. **TRACE ROOT CAUSE** — Follow ownership, signals, state transitions, physics/process timing, scene loading, and cleanup. Explain why the failure exists rather than stopping at the first suspicious line.
4. **ADD RED COVERAGE** — Add or tighten a focused regression when practical. Confirm it fails for the intended reason before production edits.
5. **FIX** — Make the smallest coherent change for the diagnosed cause, matching repository style and the game’s design rules. Do not bundle unrelated cleanup.
6. **VERIFY** — Run the focused reproduction, relevant regressions, import. Add an interactive or visual check when headless execution cannot prove the behavior. Results from before the final production edit are stale; rerun affected layers afterward.
7. **REVIEW** — Inspect the exact diff for scope, cause resolution, generated files, valid Godot APIs, and those rules.
8. **COMMIT** — Stage only the files or hunks belonging to this cause and use `fix(<area>): <plain-language cause>`.

If verification is blocked, report the blocker and evidence. Do not weaken a valid assertion to make a test pass. If the failure cannot be reproduced or explained, return it to the queue as unconfirmed.

## Code-health policy

Apply these rules to every authored source file. Other sections refer to this policy instead of repeating it.

- **500-line limit:** No source file may exceed 500 lines, including blank lines and comments. Split by cohesive responsibility before adding functionality. Use `wc -l` as objective evidence; never waive a pre-existing violation.
- **No dead code:** Remove unreachable, unused, superseded, behavior-free functions, variables, branches, resources, scenes, orphaned files, duplicate paths, commented-out code, code after `return`, never-executing flags, pass-through wrappers with no contract value, empty handlers, and debug output. Verify dynamic access through signals, scenes, strings, annotations, exports, and Godot lifecycle hooks first.
- **No dead or useless comments:** Delete stale, contradictory, redundant, empty, copied, obvious, or obsolete comments, including narration of the next line. Remove TODO/FIXME/HACK notes without a concrete action, owner, or tracking context. Keep only current rationale, constraints, non-obvious lifecycle behavior, and warning-worthy workarounds.

A violation is a confirmed finding. Keep any necessary refactor separate from a bug-fix commit when practical.

## Defect tiers

Use this order and group shared causes into one iteration.

### 1. Crashes, hangs, and availability

- Parse, import, or runtime errors on boot or common paths
- Unhandled script errors, null or invalid-instance access, rejected coroutines
- Hangs, frozen frames, unresponsive input, or blocking main-thread work
- Headless-safe failures that become crashes or blank screens in the editor or export

### 2. Broken flows, softlocks, and progression

- Start → play → reward → descend → finale → restart dead ends
- Modes that disagree with visible UI or active input/physics
- Stale state, pending timers, or callbacks leaking across floor/run changes
- Save/load failures, invalid migration, or progress loss in `user://`
- Unreachable objectives, unusable stairs/shops/ceremonies, unwinnable or trivially won states
- Rewards granted twice or never, or HUD values disagreeing with authoritative state
- Balance drift after scaling changes
- Invalid generated floors, navigation, collisions, or spawn placement

### 3. Logic and state errors

- Wrong arithmetic, inverted conditions, or off-by-one errors
- Wrong enum, group, collision-layer/mask, or node-path selection
- State flags, counters, or timers not reset at the correct lifecycle boundary
- Charm, stanza, counter-melody, progression, or NG+ stacking drift
- Diverged duplicate logic; fix the shared invariant instead of copying it again

### 4. Edge cases, races, and async work

- Empty, zero, maximum, rapid repeated, and conflicting inputs
- Keyboard, gamepad, and touch parity failures
- `await`, signals, timers, or callbacks resuming into a replaced world
- Ticks touching queued-free or cleared nodes
- Stuck animation or state-machine flags
- Physics-order differences between process and `_physics_process`

### 5. Swallowed failures

- Empty or overly broad `catch` blocks
- Failed `load`, `FileAccess`, `DirAccess`, audio, rendering, or scene operations hidden behind defaults
- Failures invisible to logs, tests, and players
- Optional failures that incorrectly disable a core promised feature

### 6. Gameplay feel: input, physics, camera, audio

- Inverted input, dead bindings, duplicate listeners, or focus stealing
- Screen-relative movement mistakes, analog dead zones, or diagonal normalization drift
- Collision tunneling, wall clipping, corner snags, snapping, or movement while disabled
- Frame-rate-dependent movement, attacks, cooldowns, or ceremony timing
- Wrong hit areas or automatic-combat resolution through invalid targets
- Camera drift, shake, recoil, mouse-driven movement, first-person or distant-angle regressions, or seeing voids
- Audio after source destruction, overlapping volume stacks, or missing first-gesture unlock

### 7. Rendering and entity visibility

- Nodes never entering the tree, wrong owner, detached parent, or accidental free
- Invisible-but-solid or visible-but-nonfunctional entities
- Wrong coordinates, scale zero, or invalid material/resource paths
- Animation folding a model out of view, or opacity/scale tweens left at zero
- Frustum-culling mistakes, broken AABBs, or interpolation/visibility pop-in
- Instanced meshes left at an instance count of zero after a failed fill
- Depth fights, bad transparency, wrong cull/material settings, or flicker
- Missing required lights, shadows, glow, particles, shaders, or post effects
- Square halos, black/unlit surfaces, half-culled billboards, wrong-color-space washes, broken color, or a black void

**Held or attached items** (staff, tool, prop) reading as "not in the hand" — floating, detached, orphaned; disconnected limb; misalignment. Three causes, most common first:

- **Wrong pivot** — origin is not at the grip, so it slides or spins out as the arm animates. Set the origin at the grip, not the sprite center.
- **Bad anchoring** — transform is not driven from the hand bone/node each frame, so it lags or drifts. Drive it from the hand's global transform, or parent it to the hand node.
- **Misaligned depth** — draw order puts the prop behind the arm or in front of the fingers, so nothing occludes it into a grip. Fix `z_index`/y-sort between body, prop, and hand.

“Renders without errors” is not proof of correct rendering. Fix nonsense graphics rather than deleting beauty.

### 8. UI, HUD, input focus, and layout

- HUD values disagreeing with game state
- Dead buttons, unavailable prompts, or swallowed clicks
- Overlap, clipping, unreadable scaling, bad wrapping, orphan lines, or z-index conflicts
- Panels or UI elements swallowing gameplay clicks
- Modal or pause state still advancing gameplay or accepting gameplay input
- Menus not animated or joyful enough to satisfy the project design rules
- Touch controls visible or active in the wrong state

Test real viewport sizes, text expansion, keyboard, controller, and touch where relevant.

### 9. Performance, memory, and leaks

- Unbounded arrays, timer growth, retained nodes, signal connections, or resources
- Leaked audio playbacks, threads, `RefCounted` cycles, or scene-owned resources
- Undisposed geometries, materials, listeners, or other resources on teardown
- Per-frame allocations, full scans, O(n²) hot loops, or avoidable physics/render work
- Boot, export, import stalls, or shipped-resource bloat

Run the performance skill when measured impact—not suspicion—is the primary goal.

## Proving a check actually proves something

- **Sample layout-dependent behaviour broadly.** Randomly-seeded generation (floor
  layouts, prop spread) makes any narrow sample a lucky one. Sweep a contiguous
  band wide enough to cover dozens of instances of the case under test.
- **Confirm every new check with a mutation that must fail.** A check that no
  plausible mutation can trip is not evidence, and the mutation's failure message
  must name the defect -- not merely exit non-zero. Watch for a mutant that
  breaks the parse instead of the logic; that proves nothing. Watch too for a
  mutant that is semantically identical to the fix: if removing a guard changes
  nothing, first ask whether that guard was load-bearing at all.
- **Do not loosen an assertion to make a suite green.** When a new check exposes a
  genuine second defect, fix that defect as its own iteration and say so.
- **Assert on the deterministic cause, never on wall-clock time.** A timing budget
  measures the machine, not the code: one here passed 12 consecutive runs and then
  flaked at 91ms against an 80ms budget under deliberate CPU contention. Guard the
  quantity that actually determines cost -- sample count, loop iterations, byte
  size -- which is reproducible, and keep wall-clock figures in the commit message
  as evidence rather than in the suite as an assertion.
- **Run any new check under deliberate load before trusting it.** A single green run
  of a timing-sensitive or contention-sensitive check proves nothing; one pass each
  way, then re-run the suite twice.
- **Sweep for unawaited async checks after adding one — and distrust a green that
  follows a new `await`.** An async test called without `await` never runs its body,
  so the suite passes while proving nothing. This has now bitten three separate times
  in this repo, so treat any new `await` in a test as suspect until a mutation
  confirms the check fails. The cheap detector: list `func` bodies that contain
  `await`, then check every call site in the runner for a matching `await`.
- **A loose substring over screen text passes on the wrong label.** Searching every
  `Label` for "save" matched the menu subtitle ("no hurry, no losing ♥"); searching
  for run-ish words matched "Visits 0 · Deepest floor 0". Match the specific string
  the fix introduces, and print the offending labels on failure so a false pass is
  visible.

## Queue discipline

Do not count formatting, naming preferences, unrequested test/docs cleanup, “cleaner” refactors, or unmeasured optimizations as functional bug iterations. Record stale tests, broken fixtures, contradictory documentation, orphaned or misplaced files, and circular dependencies as separate `test:`, `docs:`, `refactor:`, or `chore:` findings.

Require observable evidence or a violated invariant before calling a candidate a defect; return unconfirmed candidates to the queue. Fix crashes before progression, progression before lower-tier logic, and correctness before appearance. Do not cherry-pick a low-tier issue while a reproducible higher-tier issue waits. Keep unrelated discoveries in the backlog. If a pass is empty, report the inspected scope and checks rather than inventing findings. There is no fixed quota.

## Completion

Stop when the user asks, the chosen end condition is reached, further work is blocked by missing access, hardware, data, or a user decision, or:

- An endless request has no unresolved work in the agreed scope.
- A bounded request has two complete, varied passes with no confirmed functional defect and a clear inspected scope.

If stopped mid-iteration, finish only an already-safe or already-verified fix; otherwise report the working tree rather than forcing completion.

Always report:

- Confirmed fixes with cause and local commit hash
- Exact verification commands and outcomes
- Remaining functional backlog
- File-quality results and unresolved violations
- Separate test, documentation, structure, and hygiene findings
- Unverified areas or blockers
- An honest health assessment without exaggerating certainty
