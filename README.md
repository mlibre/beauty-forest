# Beauty Forest

A complete native Godot of **Beauty Forest**.

This folder is self-contained. Characters, creatures, the dragon, world meshes, shaders, animation graph, VFX, and music/SFX are generated at runtime, so there are no fragile external model or texture dependencies.

## Run

This folder is the project root, so run Godot from here:

```bash
godot --path .
```

Or open `project.godot` in Godot and press **F6/F5**.

## What you see

The walking screen paints **no text at all** — it is pictures, the way a storybook
is. Four things are on it:

- a **lantern ring** in the top-left; the arc is how much warmth you have left
- a **sparkle** glyph and count for what you can spend
- the **floor you are on**
- a **row of charm slots**, one picture per charm you are wearing

Where the walk wants you to go is a **glowing marker in the world**, not a
sentence. Your lantern's own light dims and reddens as warmth falls, so being
hurt is something you *see*. Everything else — level, song power, the charm
list, the forecast, what each key does — waits inside the pause menu, which you
opened on purpose.

Peddle's cart is a wall of **pictures**: each row is the charm's own icon, its
name and its price. Hover a row to learn what it does. Nothing to read in order
to browse.

## Controls

- **WASD / arrow keys / left stick** — wander with screen-relative isometric movement
- **Shift / shoulder button** — quick invulnerable dash
- **E / gamepad A** — descend, begin a Big Feeling song, or hit a GOLD lullaby beat
- **F** — browse Peddle's cart when nearby
- **J** — open Mote's memory book of fun facts and stickers
- **C** — open gentler-forest options
- **Esc** — pause (and the only place the numbers live)
- **F11** — toggle fullscreen
- Touch devices receive an on-screen joystick plus SING, DASH, CART, BOOK, and COZY buttons

## Verification

Run the native integration smoke test from this folder:

```bash
godot --headless --path . --script res://tests/runtime_smoke.gd
```

All art is generated at runtime — every glyph in the game is drawn pixel by
pixel into an `Image`, so the project ships with no external assets. Two
developer tools guard that, and both are worth running after any art change:

```bash
godot --headless --path . --script res://tests/capture_glyphs_check.gd  # every glyph, pixel-measured
godot --headless --path . --script res://tests/capture_text_census.gd    # visible text per screen
```

`capture_glyphs_check.gd` rejects any glyph that is too dark, too desaturated,
too solid or too thin to read against sunlit grass. `capture_text_census.gd`
counts the text a player can actually see on each screen; the walking screen is
expected to report **0 labels / 0 chars**.

Save data is stored in Godot's per-user `user://` directory, separate from the gentler-forest settings. Suites redirect that to a throwaway profile via `TestProfile`, so they never touch a real save.
