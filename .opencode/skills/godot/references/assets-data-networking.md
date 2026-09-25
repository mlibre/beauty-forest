# Assets, Data I/O, Plugins, Networking, and Threads

## Asset import pipeline

Godot imports source assets placed inside the project. Imported representations and caches live under `.godot/`; source-adjacent `.import` files hold import settings and should be version-controlled. Never edit `.godot/`.

- Use `ResourceLoader`/`load()`/`preload()` for imported project resources.
- Use `FileAccess` for files intentionally kept/exported as raw files.
- A source asset that exists in the editor may not exist in an exported build when it was imported. This is a common `FileAccess` failure.
- Import options include Keep File (exported as-is) and Skip File (not exported). Use them deliberately for raw data/docs.
- Move/rename/delete assets through the editor FileSystem when possible so references and import metadata remain coherent.
- A `.gdignore` file in a folder prevents importing/loading that folder; it is empty and is not a pattern file.
- For large content, import/reimport deliberately and verify generated resources, warnings, and package size.

### Images

- Lossless is appropriate for pixel art/UI; lossy can reduce large 2D assets; VRAM compression is common for 3D; Basis Universal is a flexible but slower/larger option.
- Enable mipmaps for 3D textures and when minification matters; 2D mipmaps cost memory and can blur pixel art.
- Use correct texture filter/repeat and import size limits for target hardware. VRAM-compressed transparency is unreliable on many Android GPUs.
- SVG is rasterized on import; convert text to paths when the visual depends on outlines.
- Normal maps, roughness, metallic, and ORM channels must be imported/used with the correct color/data intent.

### 3D assets

Prefer glTF 2.0 for exchange. Fix units, axes, scale, normals, tangents, UVs, materials, and animation ranges before import. Use source collision when possible, scene inheritance for local modifications to imported scenes, and MeshDataTool/V-HACD or multiple convex shapes when runtime collision must be generated.

### Audio

WAV, Ogg Vorbis, and MP3 are supported. WAV uses less decode CPU but more disk/memory; Ogg compresses long content well but decodes with more CPU; MP3 is a compromise. For short/repeated SFX, WAV can be practical. For music, Ogg is common. Test memory, decode CPU, looping, and platform behavior.

## Paths and runtime file access

- `res://` is the project root and packaged source/resource space. Treat exported `res://` as read-only.
- `user://` is the per-user writable persistent location. Use it for saves, settings, logs, screenshots, and generated data.
- Always use `/` in Godot paths, including on Windows.
- `ProjectSettings.globalize_path()` and `localize_path()` convert to/from host paths where needed.
- `FileAccess.open()` returns `null` on failure; immediately check `FileAccess.get_open_error()` and handle `Error` return values.
- `WRITE` truncates an existing file and does not create missing parent directories; use `DirAccess.make_dir_recursive_absolute()`.
- `READ_WRITE` does not truncate; seek explicitly.
- Call `flush()` when data must survive an abrupt stop; close explicitly for long-lived tools.

```gdscript
const SAVE_PATH := "user://savegame.json"

func save_text(text: String) -> Error:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(text)
    file.flush()
    return file.get_error()
```

`OS.execute()` is blocking; use `OS.create_process()` or a worker if the main loop must remain responsive.

## JSON, ConfigFile, and binary saves

### JSON

```gdscript
func save_dict(data: Dictionary) -> Error:
    var file := FileAccess.open("user://save.json", FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(data, "\t"))
    file.flush()
    return file.get_error()

func load_dict() -> Dictionary:
    if not FileAccess.file_exists("user://save.json"):
        return {}
    var text := FileAccess.get_file_as_string("user://save.json")
    var value: Variant = JSON.parse_string(text)
    return value if value is Dictionary else {}
```

JSON is portable/readable but does not naturally preserve Vector/Color/Quaternion/custom objects. Build explicit DTO dictionaries and version them. `JSON.parse_string()` returns null on failure and is less diagnostic; use `JSON.new().parse()` when the error line/message matters. `JSON.from_native()`/`to_native()` can convert supported engine values but are not a replacement for a stable schema.

### ConfigFile

`ConfigFile` is a good choice for settings and simple section/key data. It supports Variant values, defaults, and encrypted variants/password files.

```gdscript
var config := ConfigFile.new()
config.set_value("audio", "master_volume", 0.8)
config.set_value("video", "fullscreen", false)
var error := config.save("user://settings.cfg")
if error != OK:
    push_error("Could not save settings: %s" % error_string(error))
```

Section/key names cannot contain spaces. Comments are not preserved when Godot rewrites the file.

### Binary Variant

`FileAccess.store_var()`/`get_var()` is compact and preserves more engine types than JSON. Object serialization includes storage properties only. Never call `get_var(true)` or enable object decoding for untrusted data: deserialized objects may contain executable behavior. Add a schema/version field and handle malformed/truncated/incompatible saves as recoverable errors.

For important saves, write a temporary file in the same directory, check writes, flush/close, and promote it with `DirAccess`; retain a backup if appropriate. Godot's `OS.set_use_file_access_save_and_swap()` is available for projects that need save-and-swap behavior—verify the exact platform semantics.

## Resources as data

Use custom `Resource` for reusable editor-authored data:

- Item/enemy/upgrade definitions with typed exported fields
- Dialogue/quest/level metadata
- Themes, curves, animation libraries, materials, and save DTOs
- Tables that need Inspector editing, validation, signals, or subresources

A Resource script can define typed properties, validation, setters, constants, and subresources. Use a separate `.gd` file for the Resource script, not an inner class, when the resource must serialize reliably. `resource_local_to_scene` duplicates a resource for each scene instance when true; use it only for genuinely per-instance mutable state. External resources are shared by default.

Use `ResourceSaver.save()` for `.tres`/`.res` data. `.tres` is VCS-friendly; exports may convert it to binary. Do not dump arbitrary live node graphs as save data. Store a dedicated save DTO/schema and migrate it explicitly.

## Background loading and threads

### Thread safety

The active SceneTree and most engine objects are main-thread-bound. Do not call `add_child()`, mutate Nodes, touch most RenderingServer resources, or modify physics state from a worker.

Safe patterns:

- Build detached scene/resource data off-thread, then add/instantiate on the main thread.
- `ResourceLoader.load_threaded_request()` loads a resource; query `load_threaded_get_status()` and call `load_threaded_get()` once ready. Calling `get()` too early can still block.
- Use `Mutex` for short shared-state protection.
- Use `Semaphore` for work-on-demand.
- Use `WorkerThreadPool.add_task()`/`add_group_task()` for substantial independent work; wait for group completion before consuming results.
- Use `Thread.start()`/`wait_to_finish()` for a dedicated worker and always join before releasing its owner.
- NavigationServer APIs are documented thread-friendly, but the same AStar object is not safe for concurrent mutation and NavigationMesh editing can contend.
- The SceneTree's separate-thread physics/render settings are advanced/experimental; do not enable without target stress tests.

Design a shutdown protocol: set a synchronized stop flag, wake a waiting worker, and join it. Never leave a worker referencing a freed owner.

## Editor plugins

A plugin is an editor extension, not gameplay code:

```text
addons/my_plugin/plugin.cfg
addons/my_plugin/my_plugin.gd
```

The main script is `@tool extends EditorPlugin`. Register in `_enter_tree()` and remove everything in `_exit_tree()`.

Useful `EditorPlugin` extensions include docks, tool menu items, autoloads, import/inspector/export/debugger/context-menu/scene-import plugins, and 3D gizmos. Prefer current `add_dock()`/`add_control_to_container()` APIs over deprecated dock helpers. Every added control/plugin must be removed on deactivation.

`EditorImportPlugin` defines recognized extensions, import options, and `_import(source_file, save_path, options, platform_variants, gen_files)`. Save the imported resource to `save_path + "." + save_extension`, validate arbitrary source data, list generated `res://` files in `gen_files`, and only claim threaded import when safe.

`EditorInspectorPlugin`/`EditorProperty` customize Inspector controls. Build controls in `_init()`, add focusable controls, update from the object in `_update_property()`, and call `emit_changed()` when the value changes. Use `EditorUndoRedoManager`/`EditorInterface.mark_scene_as_unsaved()` for persistent editor mutations.

## High-level multiplayer

`SceneTree` owns a `MultiplayerAPI` (normally `SceneMultiplayer`) and a `MultiplayerPeer`. Built-in peers include ENet, WebSocket, WebRTC, and OfflineMultiplayerPeer. The high-level protocol is an implementation detail for Godot peers, not a generic non-Godot server protocol.

### ENet example

```gdscript
const PORT := 7000

func start_server() -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, 32)
    if error != OK:
        return error
    multiplayer.multiplayer_peer = peer
    return OK

func join_server(address: String) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(address, PORT)
    if error != OK:
        return error
    multiplayer.multiplayer_peer = peer
    return OK
```

Server ID is 1; clients receive random positive IDs. Connect to `peer_connected`, `peer_disconnected`, `connected_to_server`, `connection_failed`, and `server_disconnected`. Use `OfflineMultiplayerPeer.new()` to return offline.

ENet is UDP; public servers need port forwarding/binding choices. WebSocket is reliable ordered TCP and fits turn-based/chat/browser/native connectivity, not usually fast action. WebRTC is peer-to-peer and needs signaling/ICE, often TURN, and has platform/plugin limitations.

### RPCs and authority

RPC methods must be on a Node with the same node path on every peer and the same declaration/signature. Use:

```gdscript
@rpc("authority", "call_remote", "reliable", 0)
func server_start_round() -> void:
    pass

server_start_round.rpc()
server_start_round.rpc_id(1)
```

Modes:

- Authority: only the node's multiplayer authority may call remotely.
- Any peer: any connected peer may call remotely.
- `call_remote` vs `call_local`.
- `unreliable`, `unreliable_ordered`, or `reliable`.
- Channel 0 is internally divided by transfer mode; use separate channels for independent streams.

RPC signature checks do not reliably validate argument values. Never send arbitrary Objects/Callables as RPC data. Use readable names for dynamically added RPC nodes (`add_child(node, true)`).

`get_remote_sender_id()` is valid only during the RPC call and can be lost across `await`; capture it immediately.

### Authentication and authority

The high-level API does not secure gameplay. A server must authenticate/authorize peers, reject malformed/oversized/out-of-range data, rate-limit actions, and never trust client position, inventory, damage, timers, cooldowns, or results. Prefer sending input/intent and simulating authoritative state. Keep object decoding disabled; do not deserialize untrusted object Variants.

## HTTP, TLS, and WebSocket

- `HTTPRequest` is a simple asynchronous one-request-per-node HTTP client. Check result, response code, and JSON parse errors.
- `HTTPClient` is a lower-level polling API; poll it and read chunks.
- Android networking needs the INTERNET permission in the export preset.
- Godot uses OS certificate bundles with a Mozilla fallback. `TLSOptions.client()` validates certificates; `client_unsafe()` disables common-name validation and should not be used except controlled testing. Keep TLS private keys on servers.
- `WebSocketPeer` must be polled; use TLS for `wss://`.
- Browser/Web export has CORS, secure-context, storage, permissions, and single-thread/sample-audio constraints. Never assume `user://` persistence is guaranteed in private browsing/iframes.

## PCK, ZIP, and mods

`PCK` is faster/uncompressed; ZIP is inspectable/compressed. Load extra packs early with `ProjectSettings.load_resource_pack(path, replace_files)`. A later pack can replace an earlier path; choose replacement policy deliberately.

A pack/mod is a code/data trust boundary. Malicious packs can contain scripts. Validate and sign packs/patches with an asymmetric signature; keep the private key off-client. Do not treat a downloaded PCK/ZIP as safe. Preserve exact base-pack order for patch generation and test cumulative loading.

## Official sources

- Asset pipeline: <https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/index.html>
- Import process: <https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html>
- 3D import configuration: <https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html>
- Images: <https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_images.html>
- Audio import: <https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_audio_samples.html>
- Paths: <https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html>
- Runtime file loading/saving: <https://docs.godotengine.org/en/4.7/tutorials/io/runtime_file_loading_and_saving.html>
- Saving games: <https://docs.godotengine.org/en/4.7/tutorials/io/saving_games.html>
- Background loading: <https://docs.godotengine.org/en/4.7/tutorials/io/background_loading.html>
- Plugins: <https://docs.godotengine.org/en/4.7/tutorials/plugins/index.html>
- Editor plugins: <https://docs.godotengine.org/en/4.7/tutorials/plugins/editor/index.html>
- High-level multiplayer: <https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html>
- TLS: <https://docs.godotengine.org/en/4.7/tutorials/networking/ssl_certificates.html>
- PCK/patches/mods: <https://docs.godotengine.org/en/4.7/tutorials/export/exporting_pcks.html>
- Threads: <https://docs.godotengine.org/en/4.7/tutorials/performance/using_multiple_threads.html>
