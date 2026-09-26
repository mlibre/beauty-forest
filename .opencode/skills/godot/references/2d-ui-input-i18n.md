# 2D, UI, Input, and Localization

## 2D scene/rendering model

Use `Node2D` for positioned 2D world behavior and `CanvasItem` for drawing/custom rendering. `Control` is also a `CanvasItem` but follows UI layout rules.

- Default 2D content is in Canvas Layer 0 and follows the active `Camera2D`.
- Put camera-independent HUD/menus/overlays in a `CanvasLayer` with an appropriate layer/follow-viewport setting.
- `Node2D.position` is parent-relative; `global_position` is canvas-world position.
- `z_index` and `z_as_relative` control sibling draw order; `y_sort_enabled` can sort by Y where appropriate.
- `show_behind_parent` draws behind a parent CanvasItem.
- `CanvasItem` materials/modulate/self-modulate affect rendering but should not be confused with gameplay state.
- Keep pixel art crisp with nearest texture filtering/project settings; use linear filtering for scaled painted art. Do not globally choose one without checking assets.

### Coordinates and input

Useful conversions:

```gdscript
var canvas_position: Vector2 = get_global_transform() * local_position
var local_position: Vector2 = get_global_transform().affine_inverse() * canvas_position
var screen_position := get_viewport().get_screen_transform() * get_global_transform_with_canvas() * local_position
var event_local := make_input_local(event)
```

Prefer canvas/world coordinates for gameplay. Use screen-relative event properties (`screen_position`, `screen_relative`, `screen_velocity`) when UI/resolution independence matters. When synthesizing a mouse event, transform local coordinates to screen correctly before `Input.parse_input_event()`.

## Sprites, atlases, and texture filtering

- `Sprite2D`: one texture, optional region, frame count, centered/offset, flip, and material.
- `AnimatedSprite2D` + `SpriteFrames`: simple frame animations from images or sprite sheets.
- `TextureRect`: UI/source texture display with stretch modes.
- `AtlasTexture`: a region of a larger texture; use margins carefully.
- `NinePatchRect`/`StyleBoxFlat`: resizable panels that do not distort borders/content unexpectedly.
- `TextureButton` is a convenience Control; a Button with a normal/style-box theme is often more flexible.
- `CanvasItem.texture_filter` and project import/default filters affect magnified/minified art. Pixel art normally uses nearest; inspect seams/mipmaps rather than guessing.

For sprite sheets, keep frame dimensions and source separation consistent. `hframes`/`vframes` split one texture into a regular grid; `region_rect` selects an arbitrary atlas region.

## TileMapLayer (current) and TileMap (deprecated)

`TileMap` is deprecated in 4.7 — use one `TileMapLayer` node per layer. To convert, select the `TileMap`, open the TileMap bottom panel, and choose Extract TileMap layers as individual TileMapLayer nodes.

- A `TileSet` defines tile sources, atlases, alternate tiles, terrain sets, navigation polygons, custom data layers, and physics/material layers.
- A `TileMapLayer` owns cell data, enabled flags, navigation, collision, and rendering for one layer.
- Keep logical data (walkable, owner, objective) in custom data layers or parallel grid/resource data, not by reverse-engineering visual tiles.
- Use a navigation polygon in the TileSet for navigation baking when appropriate; collision polygons are independent.
- Use `TileMapLayer` events/signals for targeted gameplay instead of scanning all cells every frame.
- Large generated maps need chunking, deterministic seeds, and a stable cell-coordinate system.

## 2D cameras

`Camera2D` controls the 2D view. Choose one explicit style:

- `position_smoothing_enabled` for smooth follow.
- `drag_horizontal_enabled`/`drag_vertical_enabled` and limits for bounded maps.
- `zoom` values larger than 1 zoom in (Godot 4 behavior).
- `Camera2D.ignore_rotation` controls whether the camera rotates with its transform.
- `make_current()` or editor “Make Current” chooses the active camera; multiple cameras need a deliberate ownership rule.
- For UI, do not parent a camera-dependent world Control to a moving camera. Use CanvasLayer/anchors.
- Reset interpolation or explicitly handle camera snaps when changing world/level.

## Parallax

Use `Parallax2D`, not legacy `ParallaxBackground`/`ParallaxLayer`, for new work.

- `scroll_scale` below 1 moves more slowly/farther; 0 is fixed; above 1 moves faster/closer.
- `repeat_size` defines the infinite-repeat tile; textures should be seamless and cover the viewport within that tile.
- `repeat_times` adds extra copies for zoom-out/safety, but is not a substitute for correct sizing.
- `scroll_offset` changes the starting phase.
- Place content from the `(0,0)` crossing into positive repeat space; centering a texture at origin can leave gaps.
- Split-screen Parallax2D layers require separate SubViewports plus canvas visibility-layer culling; one world texture cannot be in two independent viewports without duplication.

## Custom 2D drawing

Override `CanvasItem._draw()` for lightweight immediate drawing:

```gdscript
func _draw() -> void:
    draw_line(Vector2.ZERO, Vector2(100, 0), Color.WHITE, 2.0, true)
    draw_circle(Vector2(50, 50), 20.0, Color.CORAL)
    draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(0, 20)]), Color.GOLD)
```

- Call `queue_redraw()` only when drawing data changes; `_draw()` is not a per-frame update method.
- High-frequency dynamic geometry can be expensive and recreates command buffers. Use MultiMesh-like/batched/custom GPU approaches for large repeated geometry.
- `draw_*` coordinates are local CanvasItem coordinates.
- Godot 4.7 removed the old antialias feather behavior for lines; verify line width rather than compensating with duplicate lines.
- Prefer a dedicated shader/custom CanvasItem for complex or GPU-driven drawing.

## 2D lighting, meshes, and particles

- 2D lights affect CanvasItems only when the renderer/canvas settings and material/light modes permit it. Not every shader/BlendMode is compatible.
- `PointLight2D` has a texture-defined range; `DirectionalLight2D` affects an angle. Keep normal maps/textures appropriately sized and filtered.
- Light limits and per-item modes control 2D light-culling batches; excessive unique light/material combinations hurt batching.
- `MeshInstance2D` draws a mesh and can be useful for custom geometry/deformation, but custom `_draw()` is simpler for ordinary shapes.
- `CPUParticles2D`/`GPUParticles2D` are good for many identical effects. GPU particles are usually preferable for large counts but require target support and careful process material setup.
- Use `ParticleProcessMaterial` for reusable configuration; local/process space, amount, lifetime, randomness, collision, and trails determine behavior.
- Do not create a new particle node/material/mesh for every frequent hit if pooling/one-shot reuse is practical.

## Animation choices

- `AnimatedTexture`: texture resource with frame sequence; little runtime logic; useful in TileSet/batched contexts.
- `AnimatedSprite2D` + `SpriteFrames`: simple 2D frame animation.
- `AnimationPlayer`: sequences that animate arbitrary properties, transforms, sprites, audio, methods, and tracks.
- `AnimationTree`: state machines/blend spaces/control over many animations and parameters.

`AnimationPlayer.play()` may apply on the next processing tick; call `advance(0)` when an immediately visible update is required. Use a state machine/AnimationTree for locomotion blending rather than restarting overlapping `AnimationPlayer` clips manually.

## Responsive UI architecture

All UI is built from `Control` nodes:

- Content: Button, Label, LineEdit, TextEdit, TextureRect, ProgressBar, OptionButton, etc.
- Layout: MarginContainer, VBox/HBox/GridContainer, ScrollContainer, TabContainer, SplitContainer, Panel/anchors.

### Anchors and offsets

- Anchors are normalized references to parent edges/center; offsets are pixel distances from those anchors.
- Different left/right anchors make a Control resize with its parent.
- A full-rect root Control is the normal responsive UI root.
- Use MarginContainer for screen/section padding and Box/Grid containers for layout.
- A child of a Container is sorted by the Container; manual position/size is generally overwritten.
- Use anchors/offsets for edge-anchored HUD elements and simple overlays.
- Test minimum window size, aspect ratios, high text scale, localization expansion, and accessibility settings.

### Position, minimum size, and resize traps (verified 4.7.2)

These cause "the UI looks broken / never fits" reports. Each is a real engine behavior, not a preference.

- **`position` is absolute in parent coordinates once the node is in the tree.** Assigning a negative value does *not* mean "offset back from my anchor". The offset-from-anchor trick only appears to work while the node is still detached, because Godot then measures a zero-size parent. Repositioning an in-tree anchored control with the detached-node value throws it off-screen (a center-anchored 900×640 panel assigned `position = -size/2` lands at `(-450, -320)`). Center with `position = parent_size * 0.5 - size * 0.5`, and compute every HUD rect in real parent coordinates.
- **Prefer anchor centering for modals whose size settles late.** A one-shot `position = parent_size * 0.5 - size * 0.5` reads whatever `size` happens to be *now*; content that settles a layout pass later (a ScrollContainer bar appearing, wrapped text re-flowing) moves the card out from under the written position. Anchors `0.5` on all sides + `GROW_DIRECTION_BOTH` + zeroed offsets re-center on every pass instead. Assert centering from live rects at several viewport sizes.
- **An autowrapped `Label` with no width floor collapses its container.** `custom_minimum_size.x = 0` (or omitted) makes the minimum size "longest word" wide and one word per line tall — one short line measured **33×569**. Inside a `PanelContainer` that inflates the whole card past the window height. Give every autowrapped label a floor (`card_width - margins`) and re-apply it on resize.
- **`size` lags a `custom_minimum_size` change within the same frame.** Place neighbours from `get_combined_minimum_size()` (or call `reset_size()`), not from `size`; a child may still report its old height. For a `Control` parented directly to a plain `Control` (no Container sorting), changing `custom_minimum_size` never resizes it — call `reset_size()` explicitly or stale widths survive a window shrink.
- **Refit after building, not before.** A reflow pass that clamps content to the panel width is useless if it runs before the children are constructed. Build the panel, then reflow.
- **Measure the real inner width** (card size minus margins *and* the vertical scrollbar) when clamping rows, or content stays ~15px too wide.
- **Reflow the panel frame, not only its scrolling list.** Headings, separators, and closing buttons often live directly on the panel while only the rows sit inside the `ScrollContainer`; a pass that clamps just the list leaves an unwrapped heading forcing the whole card past the window. Recurse the clamp through the frame — the list inside is reached automatically.
- Pin two HUD cards so they cannot collide: side-by-side when the width allows, stacked below otherwise, and yield the corner to the minimap when the window is too short for either.
- **Never gate a layout reservation on `is_visible_in_tree()`.** It is false whenever *any* ancestor is hidden, and menus/pause/ending screens routinely hide the whole HUD. A reflow that runs underneath such a screen then believes a blocked corner is free, and the moment the HUD returns the control snaps back under whatever owns that corner. Read the control's own `visible` instead — it is the stable "does this exist on screen" predicate, and it stays testable (force it either way).
- **One screen corner, one positioning system.** Anchors and an absolute `position` reflow can each be correct on their own and still collide, because the anchor-derived rect of a freshly built child is unreliable in the frame it is constructed: `size` and `position` of bottom-anchored children under a just-created full-rect parent read as zero until the tree's first layout pass. Reserve the corner in the reflow pass, from `get_combined_minimum_size()`, and never from the authored anchor offsets (a 98px button whose label is 109px wide is wider than its `custom_minimum_size`). Note a reflow triggered only by `size_changed` leaves the initial guess in place until the player resizes — hook it to the state change that shows the UI too.
- **Button text makes buttons wider than their `custom_minimum_size`.** Measure live rects, not authored sizes, or collision checks pass while the buttons visibly overlap.
- Assert layout in tests with real rects (`Rect2(position, size)`) against the parent rect at several viewport sizes — "children outside card: 0" and card-height-vs-window checks catch what eyeballing misses. Be aware `get_rect()` reflects anchors/offsets, so compare like with like.
- **Test the visibility that does not exist on your machine.** Touch/on-screen controls gated on `DisplayServer.is_touchscreen_available()` never appear in headless CI or on a desktop test machine, so a collision they cause is invisible to the default path. Force the flag on in the suite and assert against the forced state.
- A control that cannot be placed clear of its blockers should be hidden (and still left inside the window so later measurements stay valid), not drawn on top. Optional chrome yields; the blocker keeps its thumb-reachable corner.

### Containers

Understand size flags: Fill, Expand, and Shrink Begin/Center/End; stretch ratio distributes extra space. Nested containers should express hierarchy. Use ScrollContainer when content can exceed available space rather than shrinking controls below readability.

Do not put a fixed-size modal over the whole screen without checking smaller windows, TV overscan/safe areas, and touch/controller navigation.

### Focus and navigation

- Every Control can hold focus, but only controls with focus mode All/Click should be meaningful targets.
- Built-in `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_focus_next`, and `ui_focus_prev` are UI actions. Do not repurpose them for gameplay.
- Configure explicit focus neighbors for complex layouts; the engine otherwise guesses.
- Set initial focus after controls are ready: `$StartButton.grab_focus.call_deferred()`.
- Hidden controls lose focus. Pause/menu code must restore focus to a visible valid control.
- Test keyboard, controller, mouse, touch, and screen-reader/landmark behavior.

### Theme

Theme lookup considers local overrides, type variations/class hierarchy, ancestor themes, project theme, default theme, and fallback data. Use a project Theme resource for typography/colors/style consistency; use local overrides sparingly. Define type variations (for example a reusable `DangerButton`) rather than duplicating every control style.

Test contrast, focus visibility, disabled states, hover/pressed, high text scale, and color-blind usability. Godot 4.7 accessibility landmarks and live-region controls can improve screen-reader context, but verify the exact `AccessibilityServer` APIs and platform support.

### Rich text and dialogs

Use `RichTextLabel` for BBCode/styled text, not every label. Its image API changed in 4.7: use float dimensions and `ImageUnit` (`PIXEL`, `PERCENT`, `EM`). Use `Popup`/`PopupPanel`/`ConfirmationDialog`/`AcceptDialog` for modal workflows and parent them to the correct Window/UI root. Pause/process mode must match the desired modal behavior.

## Input design

### InputMap actions

Define semantic actions in **Project Settings → Input Map**, for example:

```text
move_left
move_right
move_forward
move_back
interact
jump
dash
pause
```

Use `StringName` actions. Gameplay should not depend on physical keys or a particular controller layout. Provide keyboard, mouse, and gamepad bindings; use deadzones tuned per stick; support remapping in user settings.

Built-in `ui_accept`, `ui_cancel`, and focus-navigation actions belong to UI navigation and should not be overloaded for unrelated actions.

### Polling versus events

Continuous state/movement:

```gdscript
var direction := Input.get_vector(
    &"move_left",
    &"move_right",
    &"move_forward",
    &"move_back",
)
```

> `Input.get_vector(neg_x, pos_x, neg_y, pos_y)` returns `y = -1` when the
> `neg_y` (forward/up) action is pressed and `y = +1` for `pos_y` (back/down).
> Map to 3D with the negated `y`: `wish = right * v.x + forward * -v.y`.
> Using `right * v.x + forward * v.y` inverts up/down — pressing Up walks
> toward the camera. The same rule applies to a fixed-isometric basis and to
> any custom touch stick, which must emit the same sign convention
> (`y = -1` for stick-up) so keyboard and stick stay consistent. Keep joystick
> knob drawing in the same space as the emitted value.

Discrete action:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"dash"):
        dash()
```

- `_input()` receives events before GUI and is for rare deliberate global interception.
- GUI `_gui_input()` handles a focused/hovered Control; call `accept_event()` after handling.
- `_shortcut_input()` handles unhandled shortcuts.
- `_unhandled_key_input()` and `_unhandled_input()` are normal gameplay fallbacks.
- `get_viewport().set_input_as_handled()` stops normal propagation. Polled `Input` state is separate and is not changed merely because an event was accepted.
- Check event subtype before reading specific properties; `event is InputEventMouseButton`, `InputEventKey`, `InputEventJoypadButton`, etc.
- Ignore key echo where a held key should trigger once.

### Devices and platform input

- `Input.get_connected_joypads()`, joypad button/axis APIs, vibration, and device IDs are String/int based; verify exact methods.
- Godot 4.7 keyboard/mouse no longer use numeric device ID 0. Compare `InputEvent.DEVICE_ID_KEYBOARD`/`DEVICE_ID_MOUSE` or check event type.
- Use `screen_relative`/`screen_velocity` for resolution-independent mouse-look; under capture use `relative`/`velocity`.
- Touch can emulate mouse when enabled, but a good mobile game still needs explicit touch controls/safe areas. Godot 4.7 adds `VirtualJoystick` for fixed/dynamic/following on-screen sticks.
- **A touch release outside the control never reaches `_gui_input`.** A custom stick that captures the touch index on press must also watch `_input` for the matching release index and reset there, or the gesture sticks forever when the thumb lifts off-rect. (`_input` runs before `_gui_input`, so an inside release still resolves exactly once when the `_gui_input` branch re-checks the index.)
- Handle focus loss, controller disconnect, device reconnection, and remapping while gameplay is active.
- Runtime `InputMap` changes are not automatically saved; persist user remaps in `user://` and reapply them.

### Quit and window events

Use `_notification()`/`NOTIFICATION_WM_CLOSE_REQUEST` or `auto_accept_quit` policy deliberately. `get_tree().quit()` is immediate. On mobile/web, backgrounding and process suspension are not normal desktop cases; save state and avoid assuming timers keep running.

## Localization

### Project setup

- Import translations from CSV/spreadsheets or gettext `.po`.
- Add imported translations under **Project Settings → Localization → Translations**; importing alone is not enough.
- Use `TranslationServer.set_locale()` for runtime language changes.
- Default to `OS.get_locale_language()` only as an initial preference; allow explicit user choice and configure fallback.
- A locale can be language/region/script/variant (`en`, `en_GB`, `sr_Latn`, etc.).

### Translation calls

```gdscript
text = tr("START_GAME")
text = tr("Close", "Actions")
text = tr_n("There is %d item", "There are %d items", count) % count
text = tr("{player} found {item}").format({
    "player": player_name,
    "item": item_name,
})
```

Use named placeholders and translator context. `tr_n` is for nonnegative integer counts; languages can have more than two plural forms. Some text-bearing properties auto-translate; disable auto translation for user-generated names/content and use `NO_TRANSLATE`/`TRANSLATORS:` hints in extraction where appropriate.

### Fonts, shaping, RTL, and text server data

- Use a font covering every intended script; configure fallbacks.
- Dynamic-font fallback is preferable for arbitrary user-language text and multiplayer chat.
- Enable **Include Text Server Data** for exported word/line-breaking dictionaries for languages without spaces; it adds several MB.
- Godot automatically mirrors many UI anchors/margins, container order, text alignment, and internal control elements for RTL. Coordinate systems and non-UI nodes are not mirrored.
- Override `text_direction`, `layout_direction`, or structured-text BiDi handling for files, URLs, code, and other high-level order cases.
- Use localized number formatting/parsing through `TextServer` for non-Western digits.
- Pseudolocalization catches untranslated strings, missing glyphs, and insufficient space; it is not a complete CJK/RTL test.
- Test with `godot --language <locale> --path <project>` and reset any committed locale test override.

## Official sources

- 2D: <https://docs.godotengine.org/en/4.7/tutorials/2d/index.html>
- 2D transforms: <https://docs.godotengine.org/en/4.7/tutorials/2d/2d_transforms.html>
- 2D parallax: <https://docs.godotengine.org/en/4.7/tutorials/2d/2d_parallax.html>
- 2D sprite animation: <https://docs.godotengine.org/en/4.7/tutorials/2d/2d_sprite_animation.html>
- TileMaps: <https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilemaps.html>
- UI: <https://docs.godotengine.org/en/4.7/tutorials/ui/index.html>
- Anchors: <https://docs.godotengine.org/en/4.7/tutorials/ui/size_and_anchors.html>
- Containers: <https://docs.godotengine.org/en/4.7/tutorials/ui/gui_containers.html>
- Focus: <https://docs.godotengine.org/en/4.7/tutorials/ui/gui_navigation.html>
- Theming: <https://docs.godotengine.org/en/4.7/tutorials/ui/gui_skinning.html>
- Input: <https://docs.godotengine.org/en/4.7/tutorials/inputs/index.html>
- Input events: <https://docs.godotengine.org/en/4.7/tutorials/inputs/inputevent.html>
- Localization: <https://docs.godotengine.org/en/4.7/tutorials/i18n/internationalizing_games.html>
- Spreadsheet localization: <https://docs.godotengine.org/en/4.7/tutorials/i18n/localization_using_spreadsheets.html>
- Gettext localization: <https://docs.godotengine.org/en/4.7/tutorials/i18n/localization_using_gettext.html>
- Pseudolocalization: <https://docs.godotengine.org/en/4.7/tutorials/i18n/pseudolocalization.html>
