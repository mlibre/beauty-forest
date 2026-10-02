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

Save data is stored in Godot's per-user `user://` directory, separate from the
gentler-forest settings.

Developers: see `docs/TESTING.md` for the test suites.
