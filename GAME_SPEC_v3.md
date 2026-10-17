# HUE MASSACRE — GAME SPEC v3 (Arena of the Wheel)

> Supersedes `GAME_SPEC.md` and `GAME_SPEC_v2.md`. The v1 stealth game is
> preserved forever at git tag `v1-stealth`.
>
> **This is the spec the rebuild is built against.** When code and this file
> disagree, one of them is a bug.

---

## 1. Pitch

A medieval chromatic tournament **hack & slash**. You are **the Unsworn** — a
knight with no house and no hue, entered into the Grand Melee of the Wheel like
a joke. Your blade *drinks colour*: every knight you cut bleeds their oath into
your steel. To survive the melee you must wear the right hue at the right time,
because a knight's oath is their armour, and **only a complementary colour
shatters it**.

The sand of the arena remembers every hue spilled on it. By the final round the
ground is a mural of everything you have killed.

**Tone:** brutal, bright, ceremonial. Gladiator × Hades. The crowd chants for
names; you don't have one yet.

## 2. Genre, view & look (LOCKED)

- **Top-down 2D hack & slash** — Soul Knight / Hades readability: chunky,
  readable figures, big hit feedback, clear arena.
- **NOT 3D.** A 3D billboard camera was prototyped (branch
  `proto/3d-billboard`) and deliberately shelved: too much production time for
  the visual gain within the deadline. It stays in the repo as a documented
  design decision for the video.
- **Optional "2.5D tilt"** — a second prototype (branch `camera-2d-tilt`) tests
  a tilted-floor camera trick in the 2D engine. If it survives the screenshot
  comparison we may adopt it as the default view; the game must be fully
  playable and readable in plain top-down either way.
- **Camera:** baseline is the existing room-as-a-screen layout, but with a
  **zoom-follow camera** (world scaled ~1.5×, camera eases toward the player)
  so figures read big like Soul Knight.
- **Palette:** warm sand + dark stone, one strong accent per house, saturated
  hue glows. Hades formula: warm key light, cool shadows, glow pools.
  Every hue ever spilled stays on the floor as paint.

## 3. The colour-theory core (40 marks — never dilute)

The whole game is one sentence: **colour is a rule, not decoration.**

| Rule | Meaning in game |
|---|---|
| Complement (180° apart) | Shatters a knight's oath-aura: stagger + heavy damage. |
| Same hue | Absorbed: near-zero damage, the knight drinks it back. |
| Everything else | Neutral: normal damage, no shatter. |
| Absorbing a kill | Your blade takes the dead knight's hue (existing `absorb`). |
| Paint on the floor | A knight standing in paint of their own hue is "veiled": chasers lose the trail briefly (stealth lives on as a repositioning tool). |
| Contrast | Shatter effects and telegraphs are designed so the deadliest read is the highest-contrast one on screen. |

## 4. Combat spec (the big rework)

### Player

| Stat | Value |
|---|---|
| HP | 100 (health bar; no more one-hit deaths) |
| Light strike | 3-hit combo: 12 / 12 / 20 dmg, 3rd hit knocks back |
| Facing/aim | Keyboard-first: attacks face movement direction with a gentle auto-aim to the nearest knight inside a ~120° arc |
| Dodge roll | Space: 0.35 s, 0.25 s i-frames, 0.9 s cooldown |
| Movement | WASD (existing actions) |

### Hue-armour rules (enemy damage)

- **Complementary hit → SHATTER.** Oath-aura breaks: ×2.5 damage on the hit,
  the knight staggers ~1 s, their hue splashes onto the sand as paint. The
  combo meter loves this.
- **Same-hue hit → ABSORBED.** ×0.2 damage, no stagger, a "drunk it back"
  spark, on-screen note.
- **Other hue → NEUTRAL.** ×1.0 damage, no stagger.
- Once broken, an aura stays broken until that knight dies.
- Death spills the knight's hue as a paint splat (existing paint system).

### Enemies (telegraphed, readable)

| Enemy | HP | Aura | Speed | Attack |
|---|---|---|---|---|
| **Aspirant** (basic) | 60 | 1 layer | medium | Telegraphed melee slash, 0.5 s windup, 12 dmg |
| **Warden** (heavy) | 140 | 1 layer, tougher | slow | Slam with a ground ring, 0.9 s windup, 25 dmg, knocks *you* back |
| **Harrier** (fast) | 45 | 1 layer | fast | Dash-lunge, 0.45 s windup, 10 dmg, overshoots past you |

All attacks are telegraphed (windup flash + shape on the ground). Contact
damage only while attacking, with a per-enemy cooldown — no graze deaths.

### Boss — **Champion of the Wheel**

- 400 HP, his hue **rotates continuously** (existing boss logic, re-costumed).
- 3 phases: sweeps → adds a charging dash → summons Aspirants and rotates
  faster. Vulnerability window: when his hue passes within shatter range of
  yours, strike.
- Victory = he kneels, the crowd goes silent, the born-name chant: the Unsworn
  is *named*.

## 5. Arenas & flow (reuse the 4-room skeleton)

Four arenas = four rounds of the Grand Melee, one per great house, each
recognisable by its hue dressing (banners, lights, crowd colour):

1. **The Open Sand** — pillars and open aisles (existing ROOM 01 layout, lesson
   "matching"): teaches the shatter. 3 waves, no warden.
2. **The Bannered Hall** — corners and low walls (existing ROOM 02 layout,
   lesson "mixing"): two houses fight together, waves mix hues. 3 waves + 1
   warden.
3. **The Deep Ring** — tighter, harrier-heavy (existing ROOM 03 layout, lesson
   "complements"): the shatter is mandatory here; the floor is quickly painted.
4. **The Wheel itself** — the champion, alone (existing ROOM 04 layout as the
   final duel arena).

Wave flow: herald bark → wave spawns (2–5 knights, escalating) → clear → next
wave → arena clear → short intermission page → next arena. A run is ~10–18
minutes.

**Win:** clear all 4 arenas. **Lose:** HP 0 → defeat page, run stats, restart.

## 6. Score

- Kill: 100 × combo multiplier (existing chain: consecutive complement kills
  raise it; any neutral/same-hue kill dims it).
- Shatter bonus: +150 per aura broken.
- Wave clear (untouched): +250 flawless bonus.
- End-of-run rank by score: C / B / A / **S — "Named"**.

## 7. Story & typography (15 marks)

All v1 text goes (rhyme cards, Collectors, "bring the colours back" — gone).
New text, same strong typography system (`ui/screens.gd`):

- **Title:** HUE MASSACRE — *A Legend of the Grand Melee*.
- **Intro:** a herald's proclamation, red-wax scroll styling.
- **Arena intros:** one short verse per house, naming the house and its hue.
- **HUD:** HP bar, current hue swatch + name (`ColorTheory.color_name` lives
  on), combo "×N" readout, wave counter, score.
- **Boss intro / victory / defeat pages**: written for the Wheel.
- House sigils: simple procedural emblem + hue ring, drawn in code.

## 8. What survives from v1 (code reuse map)

| Keep (adapt) | Rewrite |
|---|---|
| `scripts/color_theory.gd` (extend: shatter maths) | `scripts/player.gd` → hack & slash states |
| `scripts/paint_layer.gd` | `scripts/guard.gd` → `knight.gd` (HP, aura, telegraphs) |
| `scripts/sprite_bank.gd` / `tile_bank.gd` / `audio_bank.gd` | `scripts/room.gd` → arena rules (waves, paint veil) |
| `ui/screens.gd` framework + typography | `scripts/game.gd` (score→waves→boss→rank flow) |
| `scripts/hue_tint.gdshader` | `scripts/darkness.gdshader` → torch-lit arena dusk mood |
| `tests/test_runner.gd` infrastructure | boss logic → folded into the Champion |
| `scripts/level_data.gd` layout pattern | all story text in `ui/screens.gd` |

## 9. Build phases (order of work)

1. **Combat core** — player HP/combo/dodge; knight HP/stagger/telegraphs.
2. **Hue-armour** — shatter/absorb/neutral rules + splatter + feedback.
3. **Arenas & waves** — wave spawner, arena flow, zoom-follow camera.
4. **Boss** — Champion of the Wheel phases.
5. **Reskin** — arena dressing, new text, HUD, house sigils, Hades palette.
6. **Tests & docs** — rewrite the suite against the new mechanics; update
   README / TESTING / HOW_TO_RUN; web export; video; package.

## 10. Deliverables (assignment)

- Playable public build (GitHub Pages, web export).
- README with selectable-text AI chat PDF + 20-min YouTube video.
- LMS submission txt. AI chat history from **every agent session**, including
  the two prototype branches' work — export both transcripts at packaging
  time.
