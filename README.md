# HUE MASSACRE

> *A Legend of the Grand Melee.*

A top-down **colour-theory hack & slash**. You are **the Unsworn** — a knight with
no house, no name and no hue, thrown into the Grand Melee of the Wheel as a joke.
Your blade drinks colour, the sand keeps every hue ever spilled on it, and a
knight's oath is armour that **only a complementary colour can shatter**.

Built in Godot 4.7 with GDScript for a university Colour Theory Game assignment.
Nothing is placed in the editor: the whole game is code.

---

## Play it

| | |
|---|---|
| **Playable build** | `https://zeditya.github.io/hue-massacre/` |
| **AI chat history (PDF)** | `docs/AI_CHAT_HISTORY.pdf` |
| **Video walkthrough (20+ min)** | `[[PASTE YOUTUBE LINK HERE]]` |
| **Source** | `https://github.com/zeditya/hue-massacre` |

---

## 1. The pitch

The melee is fought on the Wheel, and the Wheel is colour. Four houses send their
knights into the sand. Each knight carries one hue, painted on his shield, in his
lantern and in the blood he spills. You arrive with nothing.

So you take colours the only way they can be taken: you kill, the colour pours out
of him, and then you go and *stand in it*. Now the sand under your feet is your
colour — and that is both your camouflage and your weapon.

**Colour is a rule here, not decoration.** Every mechanic below is one idea from
the colour wheel, and the same maths drives the hiding, the damage and the score.

---

## 2. How to play

The game opens **straight into the first arena** — there is no title screen, no
menu and no story sequence to click through. Round one of the melee starts as soon
as the window appears.

### Controls

| Input | Action |
|---|---|
| **W A S D** or **Arrow keys** | Move — this also aims your blade and your light |
| **J** or **Left mouse button** | Strike — a 3-swing chain of 12 / 12 / 20; the third knocks back |
| **Space** | Dodge roll — i-frames at the start of the roll |
| **R** | Restart the arena immediately |
| **Esc** | Pause — *Resume / Restart run / Quit game* |

There is deliberately **no separate mouse aim.** The way you steer is the way you
face and the way your blade swings. A swing gets one gentle pull onto a knight
already standing in front of you; it never reaches behind your back.

### The loop

*watch the telegraph → pick your moment → strike → take the colour → fight where
the floor matches you → repeat.*

- **You have vigour** (100 HP). So does every knight, and so does the Champion.
  Hits cost you tempo, not the run: **dying restarts the arena instantly**, with
  your score and the arena number kept.
- **Arena intros teach themselves.** Each arena prints its own lesson as a hint
  when it loads, and the HUD names your hue, your contrast, the wave count, the
  Champion's phase and the score multiplier while you fight.
- **Arenas feed their knights in waves.** 2–3 packs per arena, with a short
  intermission and a herald's banner, and every arriving knight gets a blind
  grace period so an arrival is never an ambush.
- **Colour motes** drift in every arena: walk into one to *drink a whole hue* — a
  second, quieter way to move your own colour on the wheel besides absorbing a
  kill.

---

## 3. The colour theory, mechanic by mechanic

This is the grading core of the assignment, so each rule below names the real
principle it comes from and where it lives in the code. All hue maths is in
`scripts/color_theory.gd`.

### 3.1 Simultaneous contrast — *why standing in your own colour hides you*

A knight can only build detection on you if you **contrast with the ground under
your feet.** This is *simultaneous contrast*: we perceive a colour relative to its
surroundings, not in isolation. The same red is blinding on bare sand and
invisible on red sand — the colour did not change, the *relationship* did.

```
standing on bare sand       -> contrast HIGH -> spotted in ~0.45s
standing in paint of your hue -> contrast NIL  -> never spotted
standing in paint 90 deg away  -> contrast HIGH -> spotted
```

The bare arena floor is a **warm sand whose saturation stays under 0.18**
(`ArenaArt.FLOOR_BASE`), which is exactly the threshold where
`ColorTheory.visibility()` declares "this has no usable hue". So the sand still
reads as sand to your eye, and still tells the rules *there is no colour here to
hide inside* — the picture and the maths stay one thing.

### 3.2 Hue difference on the wheel — *the measurement everything uses*

Every colour question in the game reduces to one function: **how far apart are
these two hues on the 360° colour wheel?**

```
hue_gap(a, b) = shortest angular distance between hue(a) and hue(b), 0..180
```

Godot's `Color.hue` returns 0.0–1.0, so it multiplies by 360. The "shortest" part
matters: hues are a circle, so red at 350° and orange at 10° are 20° apart, not
340°.

The wheel positions are fixed and exact, and the test suite re-derives every one
of them from the RGB values to prove the constants are honest:

| Colour | RGB | Hue |
|---|---|---|
| Red | `(1.00, 0.00, 0.00)` | 0° |
| Orange | `(1.00, 0.50, 0.00)` | 30° |
| Yellow | `(1.00, 1.00, 0.00)` | 60° |
| Green | `(0.00, 1.00, 0.00)` | 120° |
| Blue | `(0.00, 0.00, 1.00)` | 240° |
| Purple | `(0.75, 0.00, 1.00)` | 285° |

### 3.3 Hue-armour — *the strike rules*

A knight's hue **is** his armour. What your blade does is decided by the gap
between your hue and his:

| Strike | Rule | Result |
|---|---|---|
| **SHATTER** | hue gap within 30° of 180° | ×2.5 damage, he staggers (~1s), **+150 score** |
| **ABSORBED** | hue gap under 30° | ×0.2 damage — he drinks the blow |
| **NEUTRAL** | anything else | ×1.0 damage, an ordinary cut |

A shatter also **cancels the Champion's charge** mid-dash, which is the reward for
reading his lane.

### 3.4 Complementary contrast — *the combo system*

Two hues **180° apart** are complements. Placed together they vibrate; each makes
the other look more intense. Here they cancel, and a cancellation is worth points.

Kill two knights whose hues are within **25° of exactly 180° apart**, within
**3 seconds**, and you trigger a **combo**: the screen flashes white (two
complements average to white), the camera kicks, and the multiplier climbs
(×2, ×3, up to ×8 with a long enough chain).

The pairs that exist in the game are deliberate:

| Pair | Gap | Combo? |
|---|---|---|
| Yellow (60°) ↔ Blue (240°) | 180° | **Yes** — exact |
| Green (120°) ↔ Purple (285°) | 165° | **Yes** — 15° off |
| Orange (30°) ↔ Blue (240°) | 150° | **No** — 30° off |
| Red (0°) ↔ (nothing) | — | **No** |

Those last two rows are the actual lesson. "Opposite on the wheel" is a **measured
relationship, not a vibe** — and Arena 2 is built so you *cannot* combo by
accident, because Orange and Blue look dramatic together but are 30° short.

### 3.5 Additive hue blending — *colour mixing on the wheel*

When you kill a knight you **absorb** his colour: your hue blends 50% toward his,
through the **shortest arc** on the wheel.

```
hue_new = hue_old + hue_gap_signed(hue_old, hue_his) * blend
```

Blending through the shortest arc is what makes it feel like real paint. Red +
Blue averages the long way round to Yellow (the naive `mix()` answer, and it looks
wrong) or the short way to **Violet**, which is what red and blue actually make.
Arena 2 is built around this: the Red and Blue knights patrol across each other at
exactly one point, so their two puddles overlap and average to Violet — and so do
you. The painted lane floor in that arena is drawn in the same two house colours,
with the crossing square drawn in the hue they average to.

### 3.6 Complementary cancellation — *the Champion of the Wheel*

The Champion is a large knight who **rotates his own hue** around the wheel at
28°/s — a full lap in about 13 seconds. He is invulnerable, except in the
**1.8-second window** each lap when *his* hue is within 25° of *your* complement.
Striking him outside that window **clangs** off and does nothing.

The hue-wheel bar in the HUD shows where he is and where your complement is. You
manage two colours at once while he hunts you.

**He fights in three phases**, and each phase is telegraphed with a herald's
banner:

| Phase | Opens at | What changes |
|---|---|---|
| **I** | full vigour | sweeps only |
| **II** | two-thirds vigour | adds a **charging dash**: a locked lane painted on the sand, then a committed sprint. Roll it or step out of the lane |
| **III** | one-third vigour | **summons two Aspirants** (an exact Yellow/Blue complement pair, so they also let you shift your own hue) and spins the wheel **1.8× faster** |

**Victory beat:** he does not pop out of the world. He **kneels** in the sand, the
crowd goes silent, the sand is named back to you, and **the Unsworn is named**.

---

## 4. Content

Four arenas, four rounds of the melee, each one a different piece of architecture
teaching exactly one idea:

| Arena | Lesson | What it is |
|---|---|---|
| **01 — THE OPEN SAND** | Simultaneous contrast | A low walled ring with four gates, a concourse around the outside and two herald plinths. Nothing to hide in but your own paint. 3 waves, 6 knights. |
| **02 — THE BANNERED HALL** | Additive hue blending | A cross of four halls meeting at one open crossing, rooms in the quadrants, a lantern-lit lane around the outside under the house banners. Red walks one hall, Blue the other, and the crossing is the only place their paint can meet. 3 waves, 5 knights. |
| **03 — THE DEEP RING** | Complementary contrast | A ring wall with four gates around a sunken pit with two altars. The smallest floor in the melee, and every route crosses every other one — here the shatter is mandatory. 2 waves, 5 knights. |
| **04 — THE WHEEL** | Complementary cancellation | Eight pillars around a central dais, and the Champion on his circle. 3 phases; he calls two Aspirants at a third of his vigour. |

**Knight archetypes** (spec §4, implemented as data on the same class — no
separate scripts):

| Knight | HP | Damage | Speed | Feel |
|---|---|---|---|---|
| **Aspirant** | 60 | 12 | medium | the basic sword |
| **Warden** | 140 | 25 | slow | a wall that hits back |
| **Harrier** | 45 | 10 | fast | rushes you, dies quickly |

Each arena is a **different kind of space**, and the architecture is doing work:
Arena 1 is a ring you cannot hide in, Arena 2 is a crossing you have to own,
Arena 3 is a pit with four gates and nowhere to run, Arena 4 is a wheel. Knight
routes are authored against that geometry, and the test suite re-measures every
route against every wall, flood-fills the floor from the spawn (so a layout that
traps a knight — or seals a mote or an Aspirant behind a wall — simply fails the
build), and checks the Champion's phase transitions, charge and summons.

![Floor plans for all four arenas, with every knight patrol route](docs/level_plans.png)

*All four arenas. Top-left ARENA 01, top-right 02, bottom-left 03, bottom-right 04.
Grey blocks are walls; each coloured line is a knight's patrol route drawn in that
knight's own hue (dashed lines are the Champion's Aspirants); the small coloured
dots are colour motes; the green ring is your spawn. Regenerate it any time with
`godot --headless --path . --script res://tools/make_floor_plans.gd` — it is drawn
straight from `level_data.gd`, so it cannot go stale.*

### Score

| Event | Points |
|---|---|
| Knight killed | 100 × combo multiplier |
| Oath-aura shattered | +150 |
| Arena cleared without being spotted | +250 (flawless arena) |
| The Champion | +1000 |

Your final **rank** is earned by score — **S — “Named”** is the run where the
crowd learns your name.

---

## 5. Project structure

```
res://
├─ project.godot          main scene + input map + renderer
├─ export_presets.cfg     Web export preset (single-threaded)
├─ LICENSE                MIT — covers the code, NOT the art in assets/
├─ docs/                  assignment artefacts (AI chat history PDF, floor plans)
├─ assets/
│  ├─ characters/         free top-down character sheets (the only imported art)
│  ├─ tiles/              floor tiles (kept from the first build, now unused)
│  ├─ LICENSES/           the licence text for each art pack
│  └─ ATTRIBUTION.md      where every asset came from, and its terms
├─ scenes/
│  └─ main.tscn           the ONLY scene in the game: one Node + game.gd
├─ scripts/
│  ├─ game.gd             the conductor: state machine, score, combo, camera, shake
│  ├─ color_theory.gd     ALL the hue maths (gaps, complements, blending, contrast)
│  ├─ level_data.gd       all 4 arenas as plain dictionaries — the whole level design
│  ├─ room.gd             builds an arena from its dictionary, runs the rules, waves
│  ├─ arena_art.gd        the arena's look: baked sand, masonry, stands, banners, braziers
│  ├─ player.gd           movement, strike chain, dodge roll, colour absorption
│  ├─ guard.gd            patrol / investigate / chase, vision cones, the Champion's phases
│  ├─ paint_layer.gd      splatters, fading, "what colour is the floor here?"
│  ├─ mote.gd             floating colour shards you can drink for a whole hue
│  ├─ sprite_bank.gd      slices the character sheets into SpriteFrames
│  ├─ tile_bank.gd        the old tiled floor (kept as the flat-grey fallback)
│  ├─ hue_tint.gdshader   recolours a character to ANY hue (colour theory on art)
│  ├─ darkness.gdshader   the dark arena: your torch beam + the knights' lanterns
│  └─ audio_bank.gd       procedural sound effects (no audio files)
├─ ui/
│  ├─ ui_style.gd         fonts + themed colours in one place
│  ├─ hud.gd              vigour, hue swatch, wheel strip, waves, Champion phase, score
│  └─ screens.gd          pause, victory and defeat pages — that is all of them
├─ tests/
│  ├─ test_runner.gd      289 automated checks
│  └─ test_runner.tscn    tiny scene to run them
└─ tools/
   ├─ make_input_map.gd    one-off generator for project.godot's input map
   ├─ make_floor_plans.gd  draws docs/level_plans.png straight from level_data.gd
   └─ capture.gd           renders a frame of each arena, for a by-eye look
```

**Almost nothing is built in the editor.** The game is one scene containing one
node; the arenas, the knights, the player, the HUD and the three pages are all
constructed in code at runtime.

---

## 6. The look

Everything you see is drawn in code, and the arena is the biggest piece of it
(`scripts/arena_art.gd`):

- **Sand.** A 640×360 image is baked once per arena (warm desaturated sand, two
  grain tones, an edge vignette) and stretched over the 1280×720 playfield, so the
  ground is one `draw_texture` call per frame instead of thousands of blobs.
- **Masonry.** Every wall is a lit cap, a body, a drop shadow and brick courses
  with staggered joints — so a wall reads as a solid block rather than a grey
  rectangle.
- **The arena's own sigil**, drawn live and breathing: a sun over the Open Sand,
  the two house lanes and the violet square where they cross in the Bannered Hall,
  a whole colour wheel laid flat on the sand in the Deep Ring, and eight turning
  spokes under the Champion in the Wheel.
- **The stands.** Two rows of silhouettes behind the border walls, swaying on a
  sine, with house-coloured banners in the crowd and proper banners hanging over
  the sand.
- **Braziers** at the corners of every arena: a stone bowl, three flickering
  licks of flame and the warm pool it throws on the ground.
- **Dust** drifting through the air at all times, so the arena is never a still
  picture.
- **Characters** are real animated sprites, recoloured to *any* hue by
  `hue_tint.gdshader` — the imported art is tinted, never drawn in its own palette.
- **The dark.** `darkness.gdshader` lays a semi-transparent night over the world,
  cut open by your torch beam (which follows WASD), a small pool at your feet, and
  a lantern around every knight in the colour that knight stole.

The whole mood is tunable in one place: set `darkness_enabled` to `false` in
`game.gd` to play the bright, unlit version.

---

## 7. Audio

There are **no audio files in this repo.** `scripts/audio_bank.gd` synthesises
every sound effect procedurally at runtime — the blade, the shatter, the clang,
the charge, the combo chime, the wave herald, the naming of the Unsworn. Each one
is a short burst of generated samples played through a small pool of
`AudioStreamPlayer`s.

Browsers block audio until the player interacts with the page, so the first
keypress or click also unlocks sound. Nothing is broken if the first second is
silent.

---

## 8. Build and run

Full instructions, including web export and hosting, are in **[HOW_TO_RUN.md](HOW_TO_RUN.md)**.
The short version:

1. Install **Godot 4.7** (standard build, not .NET) from <https://godotengine.org/download>.
2. **Import** → select this folder's `project.godot`.
3. Press **F5** — you are in the arena.

No assets to download, no addons to enable, no configuration required.

---

## 9. AI usage statement

This project was built with an AI coding agent (this is required to be disclosed).

- **All code** in `scripts/`, `ui/`, `tests/`, and `tools/` was written with AI
  assistance, from a design brief I wrote.
- **All design decisions** — the colour-theory mapping, the arena layouts, the
  difficulty curve, the fiction — came from the brief; the AI implemented them.
- **The AI did the arithmetic and the testing.** The six knight hues, the
  complement gaps, the arena geometry and the Champion's phase thresholds were all
  derived and then *verified* by the automated suite in `tests/`, which is why the
  comments in `level_data.gd` can claim exact hue values rather than approximate
  ones.
- **I have read and understood every file.** The code is heavily commented in
  plain language so it can be explained line by line in the video.
- The full chat history is merged into `docs/AI_CHAT_HISTORY.pdf` (selectable
  text, not screenshots).

---

## 10. Honest limitations

Stated plainly:

- **The automated suite cannot see the screen.** The headless engine does not
  render, so `_draw()` is never executed by the tests. The rules, the maths, the
  state machine, the arena geometry, the waves and the boss phases are all
  machine-verified (**289 checks**), but the *look* — the sand, the masonry, the
  stands, the flames, the arena sigils, the HUD layout, the pages — is verified by
  rendering frames during development and by playing it. Treat the first
  playthrough as the real art check.
- **Colour mixing blends hue only.** Saturation and value are mostly preserved
  rather than properly blended, so mixing two dark colours does not darken them
  the way real pigment would. Deliberate simplification for clarity.
- **The Warden and the Harrier are the same class with different numbers.** The
  spec's three enemy archetypes are implemented as data (HP / speed / damage /
  radius) rather than three scripts, so they share one AI. They read differently
  in play, but they are not three separate brains.

See [TESTING.md](TESTING.md) for the full list of what was and was not tested.
