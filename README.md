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

The walking screen paints **no sentences** — it is pictures, the way a storybook
is, with two bare numbers beside their icons. Four things are on it:

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
counts the text a player can actually see on each screen and **exits non-zero if
the walking screen paints any** — it is a gate, not a report. It starts a real
run first and fails if the HUD is not on screen, so that zero is measured rather
than vacuous, and it reads hand-painted `draw_string` captions as well as
Labels: a caption the minimap used to carry would otherwise be invisible to the
count.

Save data is stored in Godot's per-user `user://` directory, separate from the gentler-forest settings. Suites redirect that to a throwaway profile via `TestProfile`, so they never touch a real save.

### The two suites that need a display

Every other suite runs headless. These two render real frames and measure them,
so they must be run windowed — a headless build has no rasterizer, so
`RenderingServer.frame_post_draw` never fires and the run hangs to the timeout
and exits 124:

```bash
godot --path . --resolution 640x360 --script tests/regression_luminance.gd  # menu is as bright as the walk
godot --path . --resolution 1280x720 --script tests/regression_scrims.gd     # cards do not dim the forest into murk
```

`regression_luminance.gd` catches a screen that renders too dark to be cheerful.
`regression_scrims.gd` catches the opposite failure — a card that dims the world
too far — and also checks that High Contrast still darkens *more* than the
normal case, so the accessibility setting cannot quietly become a no-op.
