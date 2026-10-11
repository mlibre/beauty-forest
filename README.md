# Beauty Forest

A cozy walk through an enchanted forest at golden dusk. Your lantern does the
singing — you do the wandering.

Everything you see is grown by the game itself: the forest, the wisps, the
music, the hero, the dragon at the bottom. No asset packs, no downloads, no
install — just the game, grown fresh on every machine that runs it.

## Play it

- **In your browser** — the main branch is built and published to GitHub Pages
  automatically: `https://mlibre.github.io/beauty-forest/` (once Pages is
  enabled in the repository settings: *Settings → Pages → Source: GitHub
  Actions*).
- **On your machine** — grab a build from
  [Releases](https://github.com/mlibre/beauty-forest/releases) (Windows, Linux
  and Android are built for every `v*` tag by GitHub Actions), or from this
  folder:

  ```bash
  godot --path .
  ```

  or open `project.godot` in Godot and press **F5**.

## How a walk goes

- **Wander.** Your lantern sings by itself and soothes the lost wisps it
  reaches. Your job is to walk, dodge, and choose a path — there are no
  attack buttons.
- **Warmth is your lantern's light.** Bumps dim it, thank-you hearts and
  stairwells refill it, and the lantern in the world dims with it — the
  readout and the world can never disagree.
- **Follow the glow.** A glowing marker in the world shows the way to the
  stairwell. Every floor below is a little stranger and a little more
  generous than the last, and every tenth floor the forest throws petals.
- **Visit Peddle's cart.** A shelf of pictures: warm tea, charms for your
  belt, songs for your lantern. Every card says exactly what it does.
- **Make a wish.** The wishing pool grants one small wish a floor: toss a
  sparkle in, catch the warmth that comes back up.
- **Hum along.** Lantern songs are free, and every one you find stays on.
- **Rest when you like.** A run ends with a nap card or a dragon tucked in —
  nobody is ever cross, the pause card can walk you back to the title, and
  leaving is always okay.

## Controls

| Key                            | What it does                                                         |
| ------------------------------ | -------------------------------------------------------------------- |
| **WASD / arrows / left stick** | wander                                                               |
| **Shift / shoulder button**    | a quick dash that nothing can touch                                  |
| **E / gamepad A**              | take the stairwell, start a Big Feeling's song, catch a GOLD beat, or make a wish |
| **F**                          | browse Peddle's cart when the cart is near                           |
| **J**                          | Mote's memory book — fun facts and stickers                          |
| **C**                          | cozy options                                                         |
| **Esc**                        | pause (and the one place with numbers in it)                         |
| **F11**                        | fullscreen                                                           |

On a touch screen, an on-screen joystick and six big buttons appear instead.

## You keep growing — and so does the forest

Nothing here has a ceiling. The deeper you go, the bigger everything gets,
and everything you carry grows right along with it:

- **The hero keeps levelling — and chooses how.** Every level, Mote offers
  three cards that say exactly what they do — more warmth, stronger song, or
  a gift for the walk itself — and you pick the one that feels like yours.
  Each card carries a fresh real-world fact Mote just learned.
- **Your belt grows with you.** Charm sockets open as you descend, so there
  is room for every charm you love.
- **A charm you love can be loved again.** Buy the same charm deeper and it
  comes back stronger, with a gold pip to show for it.
- **Sparkles come easier the deeper you wander**, so the cart is always
  worth a browse.
- **The forest grows chapters below the thirteenth floor** — new regions,
  new stories, and one enormous cousin yawning for more lullabies.

## Mote

Mote walks beside you and talks the whole way — her lines appear as little
story cards during the walk, not in a corner you have to remember to read.
Most of what she says is just her — a Big Feeling is "just one feeling
wearing a very big coat" — and the rest are tiny cues during a fight, like
*Wait for the GOLD halo*, which only ever point at something you can already
see.

## Cozy options

Press **C** anywhere: high contrast, gentler wisp speeds, a wider rhythm
window, a quieter forest. Change anything, any time — nothing is a test,
nothing is graded.

## Building and shipping

The game exports with the presets in `export_presets.cfg`:

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Web" builds/web/index.html
godot --headless --path . --export-release "Windows" builds/windows/BeautyForest.exe
godot --headless --path . --export-release "Linux" builds/linux/BeautyForest.x86_64
godot --headless --path . --export-release "Android" builds/android/BeautyForest.apk
```

The web build is single-threaded on purpose, so it runs on any static host
(including GitHub Pages) without cross-origin headers.

CI (`.github/workflows/`) does all of this on GitHub's machines:

- **pages.yml** — every push to `master` rebuilds the web export and deploys
  it to GitHub Pages.
- **release.yml** — every `v*` tag builds Windows, Linux and Android, then
  publishes them to a GitHub Release. The Android APK is self-signed by a
  keystore generated inside the runner; replace it with your own store
  keystore before publishing to Google Play.

The Android export needs the Android SDK and a keystore; the workflow wires
both up (JDK 17, SDK via `android-actions/setup-android`, and a keystore it
generates into `.godot/export_credentials.cfg`, which never leaves the
runner).

## Developing

`docs/TESTING.md` is the run-book: 24 headless regression suites, a two-pass
battery that also boots with an emptied class cache (the stale-machine
shape), art gates for the procedural glyphs and the text census, and
measurement probes under `_audit/`. `.agents/skills/` carries the project's
working contracts, and `AGENTS.md` the design rules every change is held to.

## 🇵🇸 In Support of Palestine

This project supports Palestine. If you can, donate to [UNRWA](https://www.unrwa.org).

The people of Palestine endure daily suffering and loss, too often unseen and
unhelped. They are asking for support — and we can give our voice, our care,
and our help. Even a small act can matter. Please do what you can. 🤲

And if you ever doubt what is right and what is wrong, remember: when someone
kills a baby to loot baby’s belongings, he is the devil — and he stands on the
wrong side. ✊
