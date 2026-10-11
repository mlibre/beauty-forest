---
name: endless-perf-hunt
description: Use when asked to improve this Godot game's performance, reduce frame time/FPS jank/memory growth, run a sustained profiling session, root-cause measured costs one at a time with verified commits, or audit performance before shipping.
---

# Endless Performance Hunt

## Goal

Run a strict **baseline → measure → root-cause → optimize → compare → verify → local commit** loop. Work sequentially in the current context. Do the complete engineering job yourself; do not delegate or fan out.

Hunt measured player-visible costs, not theoretical micro-optimizations. Preserve correctness and the Beauty Forest presentation. Every claimed win needs comparable before/after evidence.

## Establish the baseline

Before changing code:

1. Read `AGENTS.md`, `project.godot`, and the relevant scenes/scripts/shaders.
2. Run `godot --version` and confirm the project targets Godot 4.7, Jolt Physics, and the configured renderer.
3. Run `git status --short`. Preserve all pre-existing work; never reset, discard, or overwrite user changes.
4. Use `docs/TESTING.md` for the project checks and commands.
5. Build a candidate queue across tiers P1–P8 below and rank it by measured or strongly evidenced impact.

Godot has no general `--build` benchmark flag, and this project has no export preset. Do not invent one.

## Measurement standard

A performance result must include:

- The exact scenario and workload
- Warm-up and sample count
- Baseline and post-fix numbers from comparable runs
- Median plus p95/worst when samples vary
- FPS or frame time, CPU script time, physics time, draw calls, visible instances, memory, or load time as appropriate
- Relevant renderer/device/viewport conditions
- Correctness tests after the change

For a small deterministic CPU benchmark, use a dedicated headless `SceneTree`/GDScript probe and enough iterations for stable results. For interactive rendering, capture at least three runs when practical. One visibly faster run is noise until repeated.

If reliable measurements cannot be collected, label the issue **unmeasured** and do not count it as a win.

## One-cost iteration

Handle one root cause at a time:

1. **REPRODUCE** — Create or identify a stable scenario that exposes the cost.
2. **MEASURE BASELINE** — Record the metric, workload, conditions, and variance before editing.
3. **TRACE ROOT CAUSE** — Use Godot profiler data, counters, temporary probes, and code tracing. Identify the allocation, repeated work, physics query, resource upload, draw submission, or lifetime issue causing the cost.
4. **OPTIMIZE MINIMALLY** — Remove the actual cost without changing gameplay or presentation. Do not bundle unrelated cleanup.
5. **COMPARE** — Rerun the same benchmark and confirm the delta exceeds noise. Keep the optimization only if the benefit is credible and stable.
6. **VERIFY CORRECTNESS** — Run focused checks, all relevant regressions, import, and the integration smoke. Add a visual/audio/platform check when headless mode cannot prove the path.
7. **REVIEW** — Inspect the exact diff and confirm that the benchmark improved for the intended reason—not from less work, changed input, a broken feature, or lower quality.
8. **COMMIT LOCALLY** — Stage only the focused performance change and use `perf(<area>): <metric delta and cause>`. Never stage unrelated user changes.

If the first optimization does not beat noise, revert it and re-profile. If correctness fails, the result is not a win.

## Performance tiers

### P1. Frame stalls and worst-case jank

- Blocking synchronous scene construction, shader compilation, texture upload, or resource generation
- Long physics ticks, synchronous file I/O, process stalls, or startup/load hitches
- GC or allocator spikes from per-frame churn
- Shader/material first-use compilation in a common path

### P2. Hot-loop CPU and physics work

- Full scans or O(n²) separation, targeting, line-of-sight, and collision checks
- Per-frame node searches, group calls, `get_node`, or dynamic property reflection
- Expensive queries repeated for static geometry or unchanged state
- Collision shapes/layers/masks that create avoidable broadphase work
- Audio/VFX/UI work performed for entities that are inactive or far off-screen

### P3. Per-frame allocations and garbage

- Arrays, dictionaries, vectors, transforms, strings, Variants, and closures allocated every frame
- Repeated `duplicate`, deep copies, filtered arrays, sorting, or conversion in `_process`
- Signals/closures/`Callable.bind` created continuously instead of once
- DOM/UI-style tree traversal or text rebuilding every frame
- Nodes, timers, callables, and effects spawned for the same persistent state

### P4. GPU and render load

- Missing `MultiMesh` or batching for repeated static geometry
- Excessive draw calls, meshes, materials, lights, shadow casters, decals, and transparent layers
- Overdraw from large transparent quads, particles, foliage, water, and glow
- Full-resolution post-processing where a cheaper validated path preserves the look
- Shadow or light updates every frame when nothing relevant moves
- Bad AABBs, culling, LOD, visibility ranges, or material transparency causing bad GPU cost
- Uniform/texture/mesh buffer uploads every frame without changes

### P5. Frame pacing and motion correctness

- Unclamped, tiny, huge, or non-finite delta values
- Frame-rate-dependent movement, animation, projectiles, cooldowns, or ceremony timing
- Missing interpolation or unsafe snapping
- Physics tunneling on slow frames
- Camera jitter, shake, recoil, or drift regressions

Never “fix” smoothness with camera shake.

### P6. Memory and resource lifetime

- Nodes not freed after despawn/scene replacement
- Signals/timers/callables surviving their owners
- Shared resources being duplicated unnecessarily or disposed while still used
- `AudioStreamPlayback`, threads, transient scenes, or coroutine state retained at exit
- Unbounded arrays, logs, particles, notes, rings, toasts, or cached resources
- Resource growth across repeated floor transitions, runs, saves, and menu cycles

### P7. Load, import, and boot time

- Synchronous boot work that can be safely deferred
- Runtime generation duplicated across retries or floor loads
- Shader/material/resource preloading choices that increase first-frame latency
- Oversized source assets or unnecessary startup scenes
- Import-time or editor-only cost caused by project structure

### P8. Future headroom

Report worker/off-main-thread opportunities, deeper LOD/occlusion work, or architecture migrations as backlog. Do not implement a broad platform change inside a micro-optimization iteration.

## Severity floor

These are not performance wins:

- “Should be faster” without a comparable measurement
- A change below benchmark noise; less than 2% is normally noise for small CPU budgets unless variance is demonstrably much lower
- Killing bloom, shadows, particles, foliage, water, warmth, animation, or input smoothness to save cost without explicit approval and evidence
- Dead-code removal, generic refactoring, file splitting, or dependency reshuffles
- Lowering simulation/collision quality in a way that changes behavior
- Measuring less work, a smaller scenario, fewer objects, or a lower-quality frame and calling it faster
- Headless results presented as proof of GPU or visual performance

A quality cut requires explicit user approval. If approved, preserve the closest look that meets the agreed target and document the visual/perf tradeoff.

A design-rule violation is a correctness defect even at zero measured cost: fix
it under a `fix(render):` commit rather than disguising it as performance work.
The rules live in `AGENTS.md`, which every iteration must read.

## Hunting discipline

- Worst-case stalls before average CPU cost
- CPU/physics before GPU when both are material
- Memory/lifetime growth before speculative load tuning
- Never cherry-pick an easy P7/P8 win while a measured P1/P2 issue is waiting
- Re-profile after each accepted change because bottlenecks move
- Keep unrelated findings in the backlog
- If a full pass finds nothing measurable, report the scenarios and numbers plainly

## Stopping

Valid reasons to stop:

- The user asks to stop.
- The agreed iteration budget is reached.
- Two complete, varied measurement passes find no cost above the severity floor.
- Reliable profiling is blocked by missing device, renderer, export templates, or user decisions.

If asked to stop mid-iteration, finish only an already-safe or already-verified optimization. Otherwise leave the tree clearly reported rather than forcing a benchmark.

## Final report

Always report:

- Fixed costs with before/after numbers and local commit hashes
- Benchmark scenario, conditions, sample count, and variance
- Exact correctness/import/smoke checks and outcomes
- Unmeasured or rejected candidates separately
- Remaining performance backlog and hardware/renderer limitations
- Honest frame-time/FPS and memory assessment

There is no quota. A small verified, stable win is better than a large speculative rewrite.
