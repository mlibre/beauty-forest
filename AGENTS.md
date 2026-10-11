# Beauty Forest Game Design Rules

- **Good-hearted and kind**: no horror, no grimdark, no goreno, no killing others. Subjects are "lost wisps" that are *soothed home*.
- **Funny and gentle**: warm humor, cozy tone, no FOMO mechanics.
- **Non-addictive**: no streaks, timers-as-pressure, or nagging. Encourage leaving whenever.
- **Learning**: level-ups share real-world facts.
- **Auto-helping combat (survivor-style)**: the hero's lantern sings **automatically** — close wisps get a soothing pulse, distant ones get homing song-notes. The player's job is wandering, dodging, and choosing paths; there is **no manual melee swing** and no attack buttons. Combat upgrades come from charms and level-ups, not from clicking.
- **Beautiful**: bright, cozy, and welcoming — **NEVER dark, grim, spooky, or horror-like**. It is an enchanted forest at golden dusk: warm lantern light, lush sunlit greens, flowers and pollen. open (no ceilings, no black voids, no crypt/cave palettes).
- **Menus must be alive and joyful**: no static menus — animated, playful, breathing like the forest.
- **Camera**: Do not revert to first-person or distant high-angle views. **No camera shake, ever** — no screen-shake, no mouse- or aim-driven camera drift; the camera glides smoothly and settles rock-steady at its fixed offset from the hero.
- **Hero**: a visible real-time 3D character model with blend-tree walk/swing animation; the hero may visibly carry a staff as prophetic, cosmetic look — these are never manual attack inputs; combat stays fully automatic
- **Icons and visuals, not instructions**
- **Numbers die with the world, not on it**: state the player must feel continuously (warmth, being hurt) is expressed in the 3D scene — the lantern dims and reddens — so the HUD and the world can never disagree.

## Core principles

Every piece of work — code, game, tool, doc, commit — must be:

- **Clean.** No dead code, no leftovers, no scaffolding past its purpose. no dead document. Delete what is not needed. Leave the workspace better than you found it.
- **Simple.** The simplest design that *fully* solves the problem — deep and correct, not shallow or under-built. When two designs work, pick the one easier to explain and harder to break.
- **Robust.** Handles real inputs, not just the happy path. Fails visibly, not silently. If it can break, it either recovers or says so. Knows the parts that run most, measures before optimizing, and never trades clarity for speed it has not shown it needs.
- **Beautiful.** Craft matters. Naming, structure, and shape should feel intentional. Beauty is a symptom of good design, not decoration on top.
- **Clear.** Say exactly what is meant, once. Clarity comes from precision, not volume. If a paragraph is needed to justify the work, redesign instead.
- **Pleasant.** The interface — terminal, web, or in-game — should feel smooth and responsive: no jarring jumps, no input without feedback, no waiting without a sign of life. Adapt to the space it is given. Easy to pick up, easy to return to.
- **Intuitive.** Understood by use, not by instruction.
- **Visual.** Show, don't tell.

These reinforce each other — treat them as one standard, not six trade-offs.
Applies to any domain: a game, a script, a refactor, a document.

## Learning and maintaining knowledge

Only when work reveals something durable — a project principle, a reusable technique, a corrected fact, an operational lesson — write it down. Update the project's `AGENTS.md` for rules, the README for behavior and usage, and the relevant skill for lessons that belong to its domain — not the skill you happened to be using.

Be sparing. Most things are not worth recording. If a lesson will not matter in a week, or you are not sure it is true, leave it out. A short file that is read is worth more than a long one that is ignored.

Record evidence and confidence when uncertain. Never promote an experiment, benchmark, or hypothesis. Remove or correct stale claims the moment you notice them — documentation must describe reality. Left alone, rules pile up. Each rule must justify itself. If a rule cannot, remove it.

At the end of meaningful work, compare implementation against docs. Update the docs to match; never revert working code to match stale documentation.

## How to work

- **Batch independent work.** Commands that don't depend on each other are one call, not five.
- **Run what exists first.** Find the project's own tests and benchmarks, run them whole, once. Extending an existing test beats adding another; a new one is a guess until proven.
- **A benchmark is a question.** It earns its place by answering many at once: fast, correct, real.
- **No cosmetic git commands.**
- **One home per fact. Duplicates die on detection.**
