---
name: godot
description: Practical, version-aware guidance for native Godot 4.7 editor and GDScript projects. Use for designing, implementing, reviewing, debugging, testing, optimizing, or exporting Godot 2D/3D games and apps, including scenes, nodes, resources, UI, input, shaders, audio, physics, assets, networking, and platform integration. Also use when asked to refresh, audit, or update this skill from the official documentation. Excludes C#/.NET, C++/GDExtension, engine development, and engine compilation.
metadata:
  opencode/autoinvoke: true
---

# Godot 4.7 End-User Development

Use this skill as a router and quality standard, not as a substitute for the exact editor API.

## Scope and authority

- Target the **native Godot editor and GDScript** only.
- Do not introduce C#, Mono, `.sln`/`.csproj`, C++/GDExtension, native bindings, engine-module work, or engine build steps. The standard editor used to build this skill has no C#/.NET support.
- Treat repository instructions, the product's requirements, and existing project conventions as authoritative over generic recommendations.
- Godot patch releases are backward compatible, but they may add optional parameters and non-breaking behavior. Verify version-sensitive names against the executable actually used by the project.

Resolve sources in this order:

1. Existing project instructions, `project.godot`, scenes/scripts/resources, import metadata, tests, and export presets.
2. The exact installed editor and its `ClassDB`; use `scripts/api_lookup.gd` for methods, properties, signals, enums, constants, defaults, and inheritance.
3. Official English Godot 4.7 documentation and class reference: <https://docs.godotengine.org/en/4.7/>.
4. The official 4.7 migration guide and release/archive notes for version boundaries.
5. Prior knowledge only as a hypothesis that must be verified.

`https://docs.godotengine.org/en/stable/` may be used to identify the current stable branch, but persistent guidance for this skill must stay pinned to `/en/4.7/`. At this refresh, the current stable release is **4.7.2** and the verified local editor is `4.7.2.stable.arch_linux.ed1daf0bf`.

## Detect versions before version-sensitive work

```bash
godot --version
```

Also inspect `project.godot`, especially `config/features`. Do **not** infer the exact editor patch from `config/features`; detect the executable separately. If the project targets another major/minor branch, follow that branch and do not silently migrate it. Before a migration, back up or commit the project and read [version-4.7.md](references/version-4.7.md).

## Read only the relevant references

| Task | Read |
| --- | --- |
| Project structure, scenes, nodes, Resources, autoloads, editor tools/plugins | [architecture-editor.md](references/architecture-editor.md) |
| GDScript syntax, typing, signals, lifecycle, coroutines, errors, logging | [gdscript.md](references/gdscript.md) |
| 2D, TileMapLayer, UI layout, input, localization, accessibility | [2d-ui-input-i18n.md](references/2d-ui-input-i18n.md) |
| 3D, animation, navigation, cameras, XR | [3d-animation-navigation-xr.md](references/3d-animation-navigation-xr.md) |
| Renderers, shaders, VisualShader, viewports, lighting, audio | [rendering-shaders-audio.md](references/rendering-shaders-audio.md) |
| 2D/3D physics, collision, queries, Jolt, interpolation | [physics.md](references/physics.md) |
| Assets, Resources, file/save I/O, threads, networking, importers | [assets-data-networking.md](references/assets-data-networking.md) |
| Export presets/templates, feature tags, desktop/mobile/Web/server/platforms | [export-platforms.md](references/export-platforms.md) |
| Math types, interpolation, curves, deterministic RNG, OS/display/window integration | [math-runtime-os.md](references/math-runtime-os.md) |
| Profiling, debugging, test strategy, headless/CI verification | [performance-debug-testing.md](references/performance-debug-testing.md) |
| Godot 4.7 additions, behavior/default changes, 4.6 migration | [version-4.7.md](references/version-4.7.md) |
| Verify any uncertain class or member | [api-verification.md](references/api-verification.md), then run `scripts/api_lookup.gd` |
| Discover an official manual topic | [manual-index.md](references/manual-index.md) |
| Browse documented classes and built-in types in the installed API dump | [class-index.md](references/class-index.md) |

Read [architecture-editor.md](references/architecture-editor.md) as well when a change can affect scene structure, ownership, project settings, autoloads, or reusable Resources. For a broad feature, use the manual index to locate the focused official page rather than loading the whole manual.

## Working workflow

1. **Inspect first.** Read project instructions and the relevant project artifacts; do not assume a blank project or a particular renderer/backend.
2. **Classify ownership.** Decide whether the change belongs in a scene, Node, Resource, script, project setting, import preset, editor plugin, or export preset. State who creates, connects, updates, and frees each object.
3. **Verify engine-facing names.** Do not invent classes, methods, properties, signals, enum values, constants, node paths, or project-setting keys. Check exact installed `ClassDB` data and pinned 4.7 docs.
4. **Design the behavior before polishing it.** Define state transitions, process/physics timing, pause and scene-change behavior, input ownership, failure handling, and save/network trust boundaries as applicable.
5. **Implement the smallest coherent change.** Match repository naming, indentation, scene organization, signal style, and tests.
6. **Validate in layers.** Parse/import, run targeted automated checks, then exercise the affected scene or user workflow on the relevant renderer/platform when possible.
7. **Report evidence and limits.** Give exact commands/tests and identify anything not exercised, especially visual, audio, window, GPU, XR, mobile, Web, or export behavior.

## Engineering rules that commonly prevent defects

### Files, Resources, and saves

- Use `res://` for shipped project resources and `user://` for the project's writable namespace. Writable does not guarantee durable persistence on every platform.
- Check every `FileAccess`/`DirAccess`/save/load/export result. Do not hand-edit `.godot/`; commit appropriate source assets, `.import` sidecars, `.uid` metadata, and `export_presets.cfg`.
- `.godot/` is a regenerable cache, and the global script class cache inside it outlives the code that built it. After pulling or otherwise replacing many scripts, a boot can fail with `Could not resolve class "X"` plus cascading `Failed to compile depended scripts` even though every current source is correct — the stale cache is the culprit, and deleting `.godot/` is the cure. The editor rebuilds the class cache on its next open; a plain run never builds it, so a project that must boot without an editor session (player machines, CI) has to parse cache-free: quote `extends` paths (`extends "res://..."`) and pin every bare class reference behind a `preload` constant.
- Use Resources for reusable/editor-authored data and explicit versioned DTOs for save schemas. Loaded Resources can be shared; Runtime Resources need their own stable identity when persisted.
- Keep object/Variant decoding disabled for untrusted data. Verify downloaded packs or patches before loading them as executable project content.

### Scenes and GDScript

- Use typed API boundaries, explicit signals, and deterministic initialization. `_enter_tree()` is top-down; children become ready before their parent, but sibling order is not a dependency mechanism.
- Set `Node.owner` only after a node is beneath the intended owner; it controls scene serialization/unique-name scope, not parenting or lifetime.
- Use `queue_free()` for normal runtime removal. Handle scene changes, awaits, cancellations, reconnects, and freed nodes deliberately.
- Use `await` only when the caller intentionally becomes a coroutine. Do not let pending work resume into a scene that no longer owns it.
- A coordinator's `_process`/`_physics_process` that chains gameplay systems is only guarded for the state at frame entry. Any step that can transition state (a contact-damage step calling a game-over, a pickup starting a ceremony) leaves the later steps running against a state that no longer exists. Re-check the gate after each such step and return early.
- A coarse mode flag is not a gameplay gate. Sequences that deliberately stay in `PLAYING` so their presentation can finish (ending epilogues, "held victory" states) keep passing a mode check while input must be dead. Derive one gameplay-enabled predicate and route every input entry point through it, so a keyboard action and its touch button cannot drift apart.
- Keep Godot 3 names out of Godot 4 code; verify suspicious APIs and 4.7 migration changes.

### Input, UI, physics, and rendering

- Define remappable input actions and separate gameplay input from UI focus/consumption.
- Map `Input.get_vector()` to 3D with negated Y (`right * v.x + forward * -v.y`); `y = -1` is forward/up, so the non-negated form inverts up/down. Keep custom sticks on the same sign convention.
- Use containers, anchors, theme resources, and safe-area-aware layout; test keyboard, controller, touch/mouse, text expansion, and relevant accessibility behavior.
- Use fixed physics ticks and explicit collision layers/masks. Check the project's actual 2D/3D backend before backend-specific work.
- Profile before optimizing. Choose renderers, lights, shadows, particles, post-processing, and object counts for the target device rather than desktop aesthetics alone.
- Use physics interpolation when visual and physics rates differ; verify teleports and snap-to-target behavior.

### Threads, networking, and exports

- Scene-tree and most engine objects are main-thread-bound. Worker threads may touch only APIs documented as thread-safe; join workers before their owners disappear.
- Treat network and file data as hostile. Enforce size, type, range, ownership, and authorization on the authoritative side. TLS does not replace game authentication/authorization.
- Export with the editor binary and the exact matching standard template, unless the preset intentionally uses a custom template. Keep credentials out of version control and verify the produced artifact, not only the exit code.

## Refreshing this skill

When asked to refresh, audit, or correct this skill: learn from the official, latest online documentation (persistent guidance stays pinned to `/en/4.7/` while `/en/stable/` may be consulted to identify the current stable branch), then update this skill from what you learned. The contract:

- Keep it **end-user focused**: native editor and GDScript only. Never introduce C#, Mono, or engine-build content.
- **Remove** anything that is not about Godot itself, and anything incorrect or stale -- documentation must describe reality, verified against the installed editor's `ClassDB` (use `scripts/api_lookup.gd`) before a claim is written down.
- Keep the goal: simple, comprehensive, practical, robust.

## Verification ladder

Use the least expensive check that can prove the claim, then broaden:

```bash
# Exact executable and project-declared feature tags
godot --version
# Inspect project.godot separately.

# Import assets and surface project/resource/import errors
godot --headless --path <project> --import

# Parse one script without running it
godot --headless --path <project> --check-only --script res://path/to/script.gd

# Run a SceneTree/MainLoop test entry point
godot --headless --path <project> --script res://tests/smoke.gd

# Start a scene for a bounded smoke run; choose enough frames for the test
godot --headless --path <project> --scene res://path/to/scene.tscn --quit-after 120

# Export only after import/runtime checks and exact template availability are confirmed
godot --headless --path <project> --export-release "<preset>" <output>
```

- A script executed with `--script` must extend `SceneTree` or `MainLoop`; `--check-only` in the verified 4.7.2 editor can parse a normal script without running it.
- A successful parse does not validate scene wiring, signals, resources, or runtime behavior.
- Assert observable behavior, not internal configuration. A live `AnimationTree` can drive nothing while `active == true` and every blend parameter reads correctly; a UI can lay out every rect while sitting off-screen. Sample what the player actually receives — bone transforms, control rects versus the parent rect, signal counts — and prove a new regression **fails before** the fix, not only after it.
- Unknown Godot command-line arguments have no effect and are not warned about. Check the installed editor's `--help` before relying on a flag.
- Headless mode uses dummy display/audio facilities. It cannot prove visual quality, window behavior, audio routing, haptics, XR, or every GPU/platform path.
- The standard official editor does not provide a general built-in GDScript unit-test runner; there is no `--test` flag in `godot --help`. Use project-owned test runners/scenes and report their exact behavior.
- Never weaken a valid test merely to make a run pass. If a check cannot run, report the blocker instead of claiming success.

## Headless testing traps (each one produced a false failure before it was found)

- **A defaulted `get` makes an inverted guard.** `if source.get("stickers", []) is Array:` is true when the key is MISSING, because the default is already an Array — the body then re-indexes `source[key]` and throws. Test the value you iterate, not the source dictionary.
- **Keep one source of truth for a derived constant.** Two formulas for the same hit test (`0.72` fixed aim vs `0.70 * visual_scale` connect sphere) silently diverge the moment one becomes scale-aware. Compute the point once and use it for both.
- **The first element of a sorted list is not "the biggest".** Rooms already sorted largest-first make a re-scan for `max(area)` return `rooms[0]` — often the spawn room. Assert the prop is NOT in the spawn clearing rather than only asserting it exists.
- **A flag cleared by `stop_*` needs an owner.** A ceremony that clears `_ambient_should_play` leaves it false until some unrelated path re-arms it. Every branch that returns control to the player must re-arm.
- **`await process_frame` is not 60 fps headless.** Never derive gameplay timing from frame counts; use `Time.get_ticks_msec()`.
- **`queue_free()` does not invalidate immediately.** The node stays `is_instance_valid` until the frame ends; observe the outcome through a signal, not validity.
- **Probe facts, not theories.** A probe that stands still in a swarm dies and looks like a balance defect; one that kites survives. Check the probe's behaviour is even legal before reporting a failure as a defect — and treat every probe FAIL as suspect test code first.
- **A synthetic fixture may not reproduce the real generator.** Hand-picked rooms never exercise the generator's ordering; build regressions from the real generator when the defect lives in generated layout.
- **Match indentation per file.** These suites use 4 spaces; a stray tab is a hard parse error, not a warning.
- **GDScript needs explicit types on Variant expressions.** `:=` on an untyped call result fails to parse; annotate `var x: bool = ...`.

## Finish checklist

- The implementation matches the project's exact Godot version, renderer, physics backend, feature tags, and platform constraints.
- Every uncertain API and project-setting key is verified; required nodes, signals, resources, and wiring are explicit.
- Ownership, freeing, scene changes, awaits, pause behavior, quit/close-request paths, process mode, and repeated starts are handled.
- Deferred callbacks, timers, and tweens outliving their captured nodes are handled by capturing an `int` instance id rather than an `Object` (see `references/gdscript.md`); a freed capture fails before any in-body validity guard can run.
- Anchored UI is positioned in absolute parent coordinates, and autowrapped labels carry a width floor, at every tested viewport size (see `references/2d-ui-input-i18n.md`).
- Saves and external/network inputs are bounded, checked, versioned, and recoverable where applicable.
- Relevant input, resolution, localization, accessibility, renderer, audio, and platform cases were considered.
- Import, parse, targeted tests, runtime smoke checks, and relevant export checks were actually run—or their blockers were reported.
- The change preserves project instructions and did not add unrelated generated files.
