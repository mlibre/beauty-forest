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
- a **row of charm sockets**, one picture per charm you are wearing — plus one
  empty socket for every socket the current depth has opened and you have not
  filled, so a full loadout reads as *room to grow* rather than a dead end

Where the walk wants you to go is a **glowing marker in the world**, not a
sentence. Your lantern's own light dims and reddens as warmth falls, so being
hurt is something you *see* — the toast adds only the figure you can't see, like
`−7 warmth`. Everything else — level, song power, the charm list, the forecast,
what each key does — waits inside the pause menu, which you opened on purpose.

## Growth

Nothing in this game has a ceiling. The creatures below you scale without bound,
so everything you carry has to scale with them or the walk stops being a walk:

- **The hero keeps levelling — and chooses how.** A level costs soul on a
  *linear* curve, matching the linear, unbounded scaling of everything down
  there. This used to be exponential: simulated to floor 400 the hero stalled at
  level 41 while the creatures grew 72×. It also used to be a slot machine:
  every level handed the hero an arbitrary perk, so the game's one growth moment
  never asked you anything. Now every level offers three glyph cards and you
  pick — warmth, song, both, and, as the floors deepen, gifts that sharpen the
  walk itself. A balanced picker reaches level 538 by floor 400 with the
  song-to-creature ratio holding between 1.3 and 1.6 the whole way down —
  checked by `_audit/probe_growth.gd`, which walks the real `RunState` under
  that balanced policy.
- **Your loadout grows.** Charm sockets start at three and open one per floor,
  so by the last floor of a campaign there is room for every charm on the shelf.
  Descending is how you earn room.
- **A charm can be bought three times.** Each deeper copy is the same ware
  made stronger, marked with gold pips on its own icon — so the shelf keeps
  paying out on wares you already love instead of running out of new ones.
- **Sparkle income scales with depth**, so Peddle's cart is a live decision on
  every floor rather than a formality you complete once and never think about
  again.
- **Lantern songs are free and uncapped.** Hum every one you have found.

Mote still talks to you, in two different ways. Most of it is **personality**:
a Big Feeling is "just one feeling wearing a very big coat." That lives in a
transcript you can read while paused. The rest is **cues** — the lines that
explain a miss, like "Wait for the GOLD halo" — and those appear on screen
during the fight, in a few words, because they are the only kind of sentence
worth interrupting a walk for. Each one points at a picture that is already
there: the gold halo, the Warden's shield, your lantern's own dimming.

Peddle's cart is a shelf of **pictures**: each ware is its own icon, a gold rim if
you are wearing it, dimmed if you cannot afford it, and its price in sparkles — a
heart instead of digits when it is a gift. Hover a ware to learn what it does.
Nothing to read in order to browse.

The pause menu is pictures too. Every row leads with a glyph — a lantern for
warmth, a star for soul, a chime for song power, a sparkle for what you can
spend, a stair for depth — so a row reads as *this picture, this many*. The worn
charms show as the same icons your hero wears in the world, not as a list of
names. It was once two corner word-cards plus this summary, which meant every
figure was on screen twice; the corner cards are gone, and the summary is the one
place these numbers are said.

The menu above shows its promise as three pictures — a lantern, boots, a heart —
instead of a paragraph explaining that your lantern sings by itself. What you
learn by walking is not written down for you in advance.

When a run ends it ends the same way: a picture, then the figures. The cozy-nap
card shows a stair and how deep you got; the dragons-are-snuggled card shows a
dragon, a heart and a chime, and how many of each. The numbers that a picture
cannot disambiguate — reached or deepest — carry a three-letter label rather
than a sentence explaining the difference. The warm part is still words, because
no glyph says *nobody is cross*: that reassurance is the reason the screen
exists, and it is one sentence.

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
