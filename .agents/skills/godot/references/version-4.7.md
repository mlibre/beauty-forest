# Godot 4.7 Changes, Migration, and Compatibility

> Scope: native editor and GDScript. The verified baseline is Godot **4.7.2.stable** (`ed1daf0bf`, Linux). Always run `godot --version`; inspect `project.godot` separately and do not infer the exact patch from `config/features`.

## Version policy

Godot 4.7.2 is the supported 4.7 patch at this refresh. Godot patch releases are backward compatible and may add optional parameters, features, fixes, and usability changes; do not expect them to rename/remove existing APIs. Verify at minor/major boundaries and against the exact executable used by the project.

Before migrating, back up or commit. Open a copy in 4.7, migrate one source of truth at a time, and follow the official sequential upgrade chain when moving from older Godot 4.x branches. Do not open the only copy with a newer editor.

## Notable 4.7 features

These are selected end-user additions, not an exhaustive release list:

- `AreaLight3D` for rectangular 3D area lights.
- `DrawableTexture2D` and the `texture_blit` shader type for texture drawing/blitting.
- `VirtualJoystick` with Fixed, Dynamic, and Following modes.
- `Tween.tween_await()` to pause a tween until a signal is emitted.
- Per-Control offset transforms that can remain independent of container sorting; mouse filtering is separately configurable.
- Accessibility regions/landmarks and expanded `AccessibilityServer` metadata.
- More 3D particle scale and rotation controls.
- HDR output on supported Forward+/Mobile platforms (not Compatibility/Web).
- Android XR and Steam Frame support improvements.
- Export-template downloader support for individual platforms/architectures.
- `TileMapLayer` is the recommended node for new tile layers; `TileMap` is deprecated in 4.7.

Verify each feature's exact API, renderer, module, and platform requirements with installed `ClassDB` and the pinned class page before using it.

## Migration-relevant API and behavior changes

### Core, text, and editor

- `Object.is_class()` takes `StringName` rather than `String`; ordinary GDScript calls remain compatible.
- `ZIPPacker.start_file()` gained optional `permissions` and `modified_time` parameters.
- `OptimizedTranslation.generate()` now returns `bool`; check the result.
- `Font.find_variation()` gained optional `palette_index` and `custom_colors` parameters.
- `TreeItem.select()` gained an optional `set_as_cursor` argument.
- `EditorSceneFormatImporter` import constants moved under `ImportFlags`.
- `EditorVCSInterface._commit()` gained an `amend` parameter for custom editor VCS integrations.
- `Image.save_exr()` and `save_exr_to_buffer()` gained `color_image` and `max_linear_value` options.
- `ImageTexture.get_format()` and `PortableCompressedTexture2D.get_format()` moved to `Texture2D`.
- `RenderingServer.viewport_set_size()` gained `view_count`.

### GUI and GDScript

- `Control.accessibility_live` now uses `AccessibilityServer.AccessibilityLiveMode` rather than `DisplayServer.AccessibilityLiveMode`.
- `RichTextLabel` image width/height parameters changed from `int` to `float`.
- `width_in_percent`/`height_in_percent` became `width_unit`/`height_unit` with `RichTextLabel.ImageUnit`. Existing positional GDScript booleans are compatibility-supported, but code using the old named parameters must be updated.
- `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` was renamed to `UPDATE_WIDTH_UNIT`.
- Assigning an element of a packed array no longer invokes the setter for the whole packed-array property. Assign the complete value back when a whole-property setter must run.
- Methods inheriting a typed return now inherit that return type. Every override path needs an explicit return compatible with the inherited type. `return null` is valid only when the return type permits null.

### Animation and particles

- `AnimationNodeBlendSpace1D/2D.add_blend_point()` gained an optional point `name`.
- Blend spaces replace the old boolean `sync` behavior with `sync_mode`; inspect each blend space when transitions change after migration.
- `Animation.length` property metadata changed from `float` to `double` (the value remains seconds).
- CPU/GPU particle nodes' `request_particles_process()` gained optional `process_time_residual`.
- `RenderingServer.particles_request_process_time()` renamed `time` to `process_time` and gained `process_time_residual`.
- 3D particles gained additional scale/rotation controls.

### Physics and audio

- `PhysicsServer2D.body_set_shape_as_one_way_collision()` gained an optional 2D `direction` (`direction: Vector2 = (0.0, 1.0)`, verified in 4.7.2 `ClassDB`). This migration entry does not add a corresponding 3D server method (no `one_way` method exists on `PhysicsServer3D`).
- With Jolt 3D, `WorldBoundaryShape3D.plane.d` is interpreted with the opposite sign from Godot 4.6 so it matches Godot Physics; flip old values to preserve behavior.
- With Jolt 3D, `SoftBody3D` now defaults to 1 kg for the whole body rather than 0, and `linear_stiffness` behavior changed. Retune mass/stiffness/damping and regression-test soft bodies.
- With Jolt 3D, `Area3D` reports `SoftBody3D` overlaps. Adjust layers/masks if those interactions are unwanted.
- `AudioEffectSpectrumAnalyzer.tap_back_pos` was removed; migrate affected spectrum/FFT code to the supported analyzer path.
- Positional audio player `area_mask` now defaults to `0` (disabled). Projects using Area bus overrides with the former layer-1 default must explicitly restore/set the intended mask.

### Rendering and input behavior

- `CanvasItem` no longer adds the antialiasing feather to line drawing, so lines intentionally using that old thickness may need a larger width.
- The `LinearToSRGB` Visual Shader node no longer clamps to `[0.0, 1.0]` on Mobile/Forward+.
- Keyboard and mouse device IDs changed from numeric `0` to `InputEvent.DEVICE_ID_KEYBOARD` and `InputEvent.DEVICE_ID_MOUSE`, because a joystick may use device ID 0. Compare event type or the constants.
- The minimum macOS version for running Godot increased to macOS 11. Export deployment targets are separate; see [export-platforms.md](export-platforms.md).

## Changed defaults

Defaults for newly created projects/settings are not retroactively rewritten into existing projects.

| Setting/property | Old | New in 4.7 |
| --- | ---: | ---: |
| `display/window/stretch/mode` for new projects | `disabled` | `canvas_items` |
| `display/window/stretch/aspect` for new projects | `keep` | `expand` |
| `LookAtModifier3D.relative` | `true` | `false` |
| `rendering/reflections/sky_reflections/roughness_layers` | `7` | `8` |
| `ResourceImporterDynamicFont.hinting` | `1` | `3` |
| Positional audio player `area_mask` | `1` | `0` |

Jolt is the default 3D physics engine for newly created projects; existing projects can retain `GodotPhysics3D`. Inspect `physics/3d/physics_engine` rather than assuming from the editor version.

## Migration workflow: 4.6 to 4.7

1. Commit/back up and migrate a copy with the exact target 4.7 patch.
2. Run `godot --headless --path <project> --import`; resolve import/editor errors first.
3. Parse changed scripts with `godot --headless --path <project> --check-only --script res://path/to/script.gd`.
4. Search for the renamed/changed APIs above, especially RichTextLabel image units, packed-array element writes, typed-return overrides, input device IDs, and audio area masks.
5. Run targeted automated and scene smoke tests on the project's existing physics backend; then repeat relevant collision/soft-body tests under Jolt if migrating it.
6. Run real-window visual/audio checks. Headless mode cannot validate lines, lighting, fonts, HDR, display scaling, audio, or every target renderer.
7. Re-bake light/GI data only when relevant inputs changed, and test each real export artifact on its target platform.

## Runtime compatibility checks

```gdscript
var version := Engine.get_version_info()
if version.major != 4 or version.minor < 7:
    push_warning("This code expects Godot 4.7+ within Godot 4.x")

if OS.has_feature("web"):
    pass
if OS.has_feature("android"):
    pass
if OS.has_feature("dedicated_server"):
    pass

var class_id := StringName("AreaLight3D")
if ClassDB.class_exists(class_id) \
        and ClassDB.is_class_enabled(class_id) \
        and ClassDB.can_instantiate(class_id):
    var light := AreaLight3D.new()
```

- Use `ProjectSettings.get_setting_with_override()` for feature-aware effective settings; ordinary `get_setting()` does not apply feature overrides.
- `override.cfg`, export/runtime feature configuration, platform builds, and command-line options may also alter active configuration.
- A class existing in `ClassDB` does not prove its renderer/platform/export support. Verify the pinned class documentation and test the target artifact.

## Official sources

- [Upgrading from Godot 4.6 to 4.7](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html)
- [Migration index](https://docs.godotengine.org/en/4.7/tutorials/migrating/index.html)
- [Godot 4.7 release page](https://godotengine.org/releases/4.7/)
- [Godot 4.7.2 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)
- [Release policy](https://docs.godotengine.org/en/4.7/about/release_policy.html)
- [Official release archive](https://godotengine.org/download/archive/)
