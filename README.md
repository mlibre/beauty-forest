# Beauty Forest

A complete native Godot of **Beauty Forest**.

This folder is self-contained. Characters, creatures, the dragon, world meshes, shaders, animation graph, VFX, and music/SFX are generated at runtime, so there are no fragile external model or texture dependencies.

## Run

This folder is the project root, so run Godot from here:

```bash
godot --path .
```

Or open `project.godot` in Godot and press **F6/F5**.

## Controls

- **WASD / arrow keys / left stick** — wander with screen-relative isometric movement
- **Shift / shoulder button** — quick invulnerable dash
- **E / gamepad A** — descend, begin a Big Feeling song, or hit a GOLD lullaby beat
- **F** — browse Peddle's cart when nearby
- **J** — open Mote's memory book of fun facts and stickers
- **C** — open gentler-forest options
- **Esc** — pause
- **F11** — toggle fullscreen
- Touch devices receive an on-screen joystick plus SING, DASH, CART, BOOK, and COZY buttons

## Verification

Run the native integration smoke test from this folder:

```bash
godot --headless --path . --script res://tests/runtime_smoke.gd
```

Save data is stored in Godot's per-user `user://` directory, separate from the gentler-forest settings. Suites redirect that to a throwaway profile via `TestProfile`, so they never touch a real save.
