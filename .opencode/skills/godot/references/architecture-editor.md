# Architecture, Scenes, Resources, and Editor Workflow

## Mental model

Godot projects usually combine four concepts:

1. **Nodes** provide scene-tree behavior and lifecycle callbacks.
2. **Scenes** are reusable, instantiable node trees serialized as `PackedScene` resources.
3. **Resources** provide reusable data/configuration and editor integration.
4. **Signals** publish events without requiring the emitter to own or know the listener.

A script extends a built-in base and adds behavior. A scene defines a composition, public interface, initialization, and internal wiring. Instantiate a scene with `PackedScene.instantiate()` and a script/resource with `.new()` where its construction model permits it.

Parent a node when destroying the parent should also destroy that child. This is an aggregation/lifetime relationship. `remove_child()` only detaches a node; it does not free either node. Godot's separate `Node.owner` property records scene serialization and scene-unique-name scope, not parenting or runtime ownership.

## Choose the right abstraction

| Need | Prefer |
| --- | --- |
| Scene-tree behavior and callbacks | A suitable `Node` subclass |
| Inspector-authored reusable data | `Resource` |
| Lightweight non-node helper with reference lifetime | `RefCounted` |
| Deliberate manual lifetime outside the tree | `Object` only when its API requires it |
| Reusable editor-wired composition | A `PackedScene` |
| Broad application-lifetime service | An autoload after simpler options are insufficient |
| Stateless shared operations | A named script class with static functions |
| Repeated records without behavior | Typed arrays, packed arrays, or dictionaries |

Nodes are individually inexpensive, but every active node consumes tree, signal, and possibly process/physics overhead. Use data plus a few controller nodes for large collections until profiling demonstrates a need for one node per record.

## Scene boundaries and dependency injection

A reusable scene should instantiate and run without hidden ancestor/sibling assumptions. Inject only what it needs:

- Use typed exported references such as `@export var target: Node2D` for Inspector-assigned dependencies.
- Use a small `Resource` for structured configuration.
- Use an exported `Callable` only when a child needs to invoke an externally owned action.
- Connect to a child signal when the child reports an event.
- Call a typed child method or set a command when its owner starts/controls behavior.

Prefer signals for notifications and direct calls for immediate commands. Do not make a scene search the whole tree for a global service when a narrow reference can be injected.

Keep internals private by convention unless they form the scene's Inspector/interface. Add `_get_configuration_warnings()` to editor-facing nodes when external wiring is required, but keep warnings actionable and testable.

## Project organization

Godot does not impose a directory layout. Preserve the repository's structure. A reasonable starting point is:

```text
project.godot
assets/                 # Source assets, preferably near consumers
features/               # Feature-oriented scenes/scripts when useful
shared/                 # Truly shared Resources, themes, and helpers
ui/
addons/<plugin>/         # Third-party or local editor plugins and licenses
tests/
tools/                  # Editor and command-line utilities
export_presets.cfg      # When the project has export presets
```

- Prefer `snake_case` for GDScript files/folders and `PascalCase` for node names unless the repository says otherwise.
- Resource virtual paths are case-sensitive in exports even when development filesystems are not.
- An empty `.gdignore` tells the editor filesystem/import/export pipeline to ignore a directory. It is not a glob or a security sandbox.
- Never hand-edit or commit `.godot/`; it is generated cache/import metadata.
- Move/rename assets through the editor when possible so references, `.import` remaps, and UIDs stay coherent.

## Project settings and effective values

`project.godot` is the main project manifest. It can record the main scene, input actions, layer names, rendering/audio/display/physics configuration, autoloads, and custom project settings. The editor is normally safer than hand-editing complex settings.

Do not guess setting keys. Inspect `project.godot`, search Project Settings in the editor, and verify uncertain names against the exact build. Important distinctions:

- Built-in settings have registered defaults even when they are not serialized in `project.godot`.
- `ProjectSettings.has_setting(name)` tests existence; use it before reading optional custom settings.
- `ProjectSettings.get_setting(name)` returns the ordinary/base setting.
- Feature-tag overrides, `override.cfg`, platform/export configuration, and applicable command-line options can change the effective value. Use `get_setting_with_override(name)` when feature-aware behavior matters.
- Use a project setting for genuinely project-wide configuration, not for every gameplay constant.
- Namespace custom settings and document them, for example `gameplay/dash/duration`.

Feature tags should express intentional platform/configuration differences, not hide incompatible behavior. Query each tag separately; `OS.has_feature("web/android")` is not a valid combined test.

## Building nodes and scene ownership

`$Path` is shorthand for `get_node("Path")`; `%Name` resolves a node marked unique in the same `owner` scope. Scene-unique names are useful when children may move within an owned scene. Required references should fail validation/runtime visibly; use `get_node_or_null()` only when absence is expected. Check `is_instance_valid()` for references retained across scenes or deferred callbacks.

When constructing a tree:

1. Set safe pre-tree state such as `name`, script, local properties, groups, and process mode.
2. Connect signals before behavior that may emit immediately.
3. Call `add_child()`.
4. Assign `owner` afterward when the node must be serialized as part of a `PackedScene`. `owner` must be an ancestor.
5. Query global transforms/parent state only after tree entry when required.

`Node.owner` is not a general runtime parent/dependency mechanism. Prefer explicit exported references or scene-unique paths in authored scenes.

Use `queue_free()` for normal runtime removal. A queued node remains until the end of the frame. Use immediate `free()` only when destruction semantics require it and no signal/call/tween stack may still use the object.

## Lifecycle, groups, and notifications

Normal ordering is:

1. Parent `_enter_tree()`.
2. Children `_enter_tree()`.
3. Children `_ready()`.
4. Parent `_ready()`.
5. Eligible `_process()` or `_physics_process()` callbacks on later frames.

Children leave the tree before their parent's `_exit_tree()`. `_enter_tree()` can run every time a node enters; `_ready()` normally runs once per node lifetime unless `request_ready()` is called. `@onready` initializes immediately before `_ready()` and is not available during `_enter_tree()`. Never depend on sibling order.

Use groups for broad debug/editor queries or simple registries, not as an unvalidated service locator. Prefer named callbacks over raw `NOTIFICATION_*` handling unless a notification provides a unique lifecycle event. Use `_exit_tree()` to release subscriptions/resources owned by the node.

## SceneTree and scene transitions

`application/run/main_scene` selects the initial scene. A common architecture keeps a persistent root, a swappable world, and a persistent UI layer, but use the project's established architecture.

`SceneTree.change_scene_to_file()` and `change_scene_to_packed()` have a two-phase lifecycle:

1. On a successful call, the outgoing current scene is immediately removed from the tree.
2. Until end-of-frame replacement, do not assume `current_scene` or old-scene references are valid.
3. At end of frame, the old scene is freed and the new scene is added/initialized.
4. `scene_changed` is emitted after the new scene is ready.

Always check the returned `Error`. Save data and collect references before requesting a change. Await `scene_changed` only from a coroutine owner that is expected to survive the transition; a node in the outgoing scene may be freed before resuming.

For explicit transitions, a persistent root can instantiate and validate the next scene, swap children, then queue-free the old scene. Choose pause and `process_mode` behavior deliberately.

## Resources and data

Resources are reference-counted and can expose typed/exported properties in the Inspector. Use them for reusable editor-authored definitions, themes, curves, dialogue, materials, and other configuration.

- A loaded external Resource is normally shared through the resource cache. Use `duplicate()` or `duplicate_deep()` deliberately for independent mutable state.
- `resource_local_to_scene` duplicates an embedded Resource for each scene instance; it is not a general deep-clone operation.
- `resource_path` is a virtual path. It may be empty for an unsaved Resource or identify a containing resource plus subresource ID for an embedded resource. `resource_name` is display metadata.
- Call `emit_changed()` after meaningful runtime changes, but connect consumers that actually need to react.
- Save custom Resource files with `ResourceSaver.save()` and check its `Error`.
- Do not put a Node in a Resource merely to make scene wiring convenient.
- Runtime-generated Resource UIDs are not a stable save identity. Give persisted DTOs their own versioned identifier/schema.

Packed arrays reduce per-element container overhead for homogeneous data; they do not guarantee lower total memory in every case, and `PackedStringArray` is not a primitive numeric container. Packed arrays are reference types: duplicate when independent mutation is required. Values returned by built-in properties/methods are copies, so assign a modified returned packed array back to the property. In Godot 4.7, assigning an element of a packed array no longer invokes the whole-property setter.

For save data, serialize a dedicated versioned DTO/schema rather than an arbitrary live node graph or Resource object graph. Use `JSON`/`ConfigFile` or checked binary APIs as appropriate, and see [assets-data-networking.md](assets-data-networking.md).

## Autoloads

Autoloads are created under `/root` after project settings and before the ordinary main scene, in Project Settings list order. They survive main-scene changes. A configured autoload is not a language-enforced singleton: another instance can exist, and the configured node should not be manually freed.

Before adding one, consider a scene-local node, an injected service, a Resource, or a named class with static methods. When using an autoload:

- Put dependencies before the autoloads that depend on them.
- Keep its public API narrow and its mutable state intentional.
- Define pause/process behavior and test reset/reset-state APIs rather than freeing the autoload in tests.
- Scene roots and autoload scripts must be Node-compatible.
- Editor plugins should add/remove registrations with `EditorPlugin.add_autoload_singleton()` and `remove_autoload_singleton()`.

## Localization workflow

Keep source translations under `res://`. CSV translation files must be UTF-8 without BOM. Importing a CSV generates a translation Resource but does not automatically register it in Project Settings; add imported Resources under `internationalization/locale/translations` and configure fallback behavior.

Choose deliberately between source text and stable keys as translation keys. Use `tr_n()` for plural-aware text and the context-aware API where context distinguishes otherwise identical strings. Gettext workflows add POT generation, contexts, and plural forms. At runtime, manage locale through `TranslationServer`.

Ensure fonts contain or fall back to every required glyph. Test text expansion, right-to-left layout, input methods, and the editor's pseudolocalization mode. See [2d-ui-input-i18n.md](2d-ui-input-i18n.md) for the user-facing workflow.

## Editor workflow and tools

Open/run with the latest supported patch on the project's declared stable branch; back up or commit before opening with a newer editor. `project.godot` does not record the exact editor patch—use `godot --version` for that.

- Use Scene dock for hierarchy, Inspector for properties, and specialized editors/scripts for their content.
- Prefer the Inspector over hand-editing `.tscn`/`.tres` for routine work.
- For an instanced scene, Editable Children exposes its existing child hierarchy for inspection. Use Editable Instance, or `set_editable_instance()`, when intentionally making owned instance content available for persistent local structural overrides. Inherited scenes are a separate workflow; do not treat the modes as interchangeable.
- Inspect configuration warnings and import errors after structural changes.

### `@tool`

`@tool` executes a script in the editor as well as at runtime. Tool code may run during editor changes and tool-enabled importer contexts, including worker threads.

- Keep it fast, deterministic, bounded, and non-destructive.
- Guard editor-only effects with `Engine.is_editor_hint()` when needed.
- Do not start gameplay networking, audio, or expensive world generation in the editor.
- Use editor undo/redo APIs and configuration warnings instead of silently mutating unrelated content.
- Tool scripts used by an importer must be safe in that importer's threading mode.

### Editor plugins

A conventional plugin lives under `res://addons/<plugin_name>/plugin.cfg`; the configured script normally uses `@tool` and extends `EditorPlugin`. Register docks, controls, shortcuts, importers, custom types, and handlers in `_enter_tree()`, then remove every registration in `_exit_tree()`.

`add_custom_type()` creates an editor-facing custom type; it is not a runtime global script class. Use `class_name` when scripts need a runtime global identifier. Prefer current dock APIs such as `add_dock()`/`add_control_to_container()` over deprecated helpers.

### EditorScript

An `EditorScript` uses `@tool`, extends `EditorScript`, and performs its operation in `_run()`. It does not automatically participate in Undo/Redo or mark modified scenes/resources unsaved. Call `EditorInterface.mark_scene_as_unsaved()` after changing an open scene intentionally. Build an `EditorPlugin` with `EditorUndoRedoManager` when undoable editor tooling is required.

## Version control

Commit source scenes/scripts/resources/assets, source translation files, source-adjacent `.import` files, generated `.uid` sidecars where used, and `export_presets.cfg` after checking it for secrets or machine-specific data. Do not commit `.godot/`. Godot 4.1+ stores export credentials in `.godot/export_credentials.cfg`; keep that ignored and review custom presets for passwords, paths, tokens, and keys.

Use external Git tools or the editor's VCS integration. Consider Git LFS before committing large source assets when it fits the project's hosting and workflow.

## Official sources

- [Key concepts](https://docs.godotengine.org/en/4.7/getting_started/introduction/key_concepts_overview.html)
- [Scene organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html)
- [Scenes versus scripts](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scenes_versus_scripts.html)
- [Using Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Scene-unique nodes](https://docs.godotengine.org/en/4.7/tutorials/scripting/scene_unique_nodes.html)
- [Autoloads](https://docs.godotengine.org/en/4.7/tutorials/scripting/singletons_autoload.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
- [Version control](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html)
- [Project Settings](https://docs.godotengine.org/en/4.7/tutorials/editor/project_settings.html)
- [Editor plugins](https://docs.godotengine.org/en/4.7/tutorials/plugins/editor/making_plugins.html)
- [Running code in the editor](https://docs.godotengine.org/en/4.7/tutorials/plugins/running_code_in_the_editor.html)
- [Internationalizing games](https://docs.godotengine.org/en/4.7/tutorials/i18n/internationalizing_games.html)
- [Command-line tutorial](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)
