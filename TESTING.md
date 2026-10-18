# TESTING — Hue Massacre (Arena of the Wheel)

Two kinds of verification are recorded here:

- **Automated** — **303 checks** in `tests/test_runner.gd`, run in a headless
  Godot engine. Reproducible in one command.
- **Manual** — a checklist for the things a script cannot judge, mostly *feel* and
  *visuals*, each with the expected result so you can tick it off.

---

## 1. How to run the automated suite

```bash
# Linux / macOS
/path/to/Godot_v4.7-stable_linux.x86_64 --headless --path . res://tests/test_runner.tscn

# Windows (PowerShell)
& "C:\path\to\Godot_v4.7-stable_win64.exe" --headless --path . res://tests/test_runner.tscn
```

Or open `tests/test_runner.tscn` in the editor and press **F6**.

**Exit code is 0 on success, 1 on failure**, so it can be wired into CI.

---

## 2. Results of the last run

```
=========================================================
HUE MASSACRE - automated test runner
Godot 4.7.2-stable (official)
=========================================================

--- A. COLOUR THEORY MATHS                                 37 checks
--- B. LEVEL GEOMETRY                                      88 checks
--- C. INTEGRATION (real scene, scripted playthrough)     137 checks
--- D. LIGHT, WAVES AND LEVEL ELEMENTS                     41 checks
=========================================================
RESULT: 303 passed, 0 failed
=========================================================
```

**Verified on:** Godot 4.7.2-stable (Linux build), headless renderer.
**Result:** `303 passed, 0 failed`, process exit code `0`.

### A. Colour theory maths (37 checks)

The colour system is the graded core, so it is tested hardest — including
re-deriving every hue constant from its RGB value, so the comments in
`level_data.gd` cannot silently lie.

| Check group | Proves |
|---|---|
| `hue_gap wraps through 0 (10 vs 350 = 20)`, `maxes at 180` | Hues are a **circle**, and distance is the shortest arc |
| `RED is 0 degrees` … `PURPLE is 285 degrees` | All six knight hues are exactly what they claim |
| `YELLOW <-> BLUE is a complement (exactly 180)` | The exact pair is real |
| `GREEN <-> PURPLE is a complement (165)` | The 15°-off pair is accepted |
| `ORANGE <-> BLUE is NOT (150)` / `RED <-> GREEN is NOT (120)` | **The tolerance rejects things** — it is not a rubber stamp |
| `YELLOW <-> BLUE survives even a near-zero tolerance` | Float precision does not break the exact pair |
| `grey-free floor: RED on RED paint is INVISIBLE`, `YELLOW on BLUE paint is fully exposed` | The camouflage rule, both directions |
| `bare grey floor always exposes you` | The starting condition is not accidentally safe |
| `equal overlap of RED and BLUE paint averages to VIOLET (300)` | Mixing happens **in hue space**, not RGB |
| `opposite hues that cancel still return a usable colour` | The degenerate blend returns, no NaN |
| `a colourless Unsworn takes the guard's hue outright` | Absorption, including the first kill |

### B. Level geometry (88 checks)

All 4 arenas, every knight route, every colour mote and every Aspirant spawn.

| Check | Proves |
|---|---|
| `there are 4 rooms (3 teaching + boss)` | The content matches the spec |
| `<ARENA>: player spawn is clear of walls` | You never spawn inside geometry |
| `<ARENA>: has guards` | No arena is accidentally empty (an unwinnable dead end) |
| `<ARENA>: guard N route clears every wall` | **No patrol clips through a wall.** Every leg of the route is sampled in 4px steps against every wall rect, inflated by that knight's own radius |
| `<ARENA>: guard N has a real patrol route` | Routes have at least 2 distinct points |
| `<ARENA>: aspirant N's arrival route clears every wall` | The Champion's summons do not arrive inside the stonework |
| `<ARENA>: has a verse for its house`, `has an accent colour and a sigil style` | Every arena can announce its house |
| `waves are numbered 1..N with knights in each` | No empty wave, no skipped wave number |
| `the boss hall fights its whole cast at once` | The Champion's arena is one fight, not a wave arena |
| `<ARENA>: mote/waypoint/aspirant can be walked to` | **Nothing is sealed behind geometry** — the floor is flood-filled from the spawn at 6px resolution, so a pickup or patrol point in a closed pocket fails |

### C. Integration — scripted playthrough (137 checks)

This drives the **real** `scenes/main.tscn`, through the whole game, asserting on
live game state. It is not a mock: it boots the actual scene and plays it.

**Boot — there is no menu (this is new)**

| Check | Proves |
|---|---|
| `the game boots straight into play` | No title screen, no story cards: the build opens in the arena |
| `and no page is blocking the arena` | The screen layer is idle on boot |
| `the first arena is built on boot` / `and it is the first arena` | Round one is live immediately |
| `the fight HUD is up from the first frame` | The player is not left without their vitals |
| `and the arena's verse is announced on load`, `with the house sigil next to the score` | The house announces itself — this is what replaced the removed intro pages |
| `the pause page has three rows` | The only pages left are pause / victory / defeat |

**Characters — the sprite system**

| Check | Proves |
|---|---|
| `the character sprite bank builds`, `12 animations`, `8 frames each` | The sheet layout is what the code claims |
| `facing angle 0 points right` … `270 points up` | The angle→facing maths is right for Godot's +y-down space |
| `the player is drawn as an animated character sprite`, `and is re-coloured by the hue-tint shader` | The imported art is tinted to the current hue |
| `guards are drawn as animated character sprites too` | Knights use the same system |

**Arena 1 — colour, capture and hiding**

| Check | Proves |
|---|---|
| `arena 1 fields 2 knights on its first wave`, `with 4 more waiting in the later waves`, `so the arena is a three-wave fight` | Wave data reaches the world |
| `the Unsworn starts colourless (white)` | Correct starting colour |
| `killing a guard removes it from the room` | The kill lands |
| `the Unsworn is no longer colourless after a kill`, `absorbs the dead guard's hue` | Colour capture, checked by **saturation as well as hue** so a white→red change cannot pass vacuously |
| `one kill scores the base amount` | Scoring is wired |
| `the floor under the kill is PAINTED, not bare grey`, `and it is the guard's hue` | The paint layer answers queries correctly |
| `standing in paint of your own hue HIDES you`, `and reports zero contrast` | The core camouflage mechanic |
| `stepping onto bare grey floor EXPOSES you`, `and reports full contrast` | And it is reversible |

**Waves**

| Check | Proves |
|---|---|
| `clearing wave 1 does NOT clear the arena`, `it starts the intermission instead` | Wave rooms gate on the last pack, not the first |
| `the reserved knights still count as left`, `and the HUD counts them too` | The HUD never says 0 while knights wait |
| `until the pause runs out, no wave arrives` → `then wave 2 marches in` | The intermission is a real timer |
| `a just-arrived knight is blind for its grace period` → `and once the grace ends, the knight can see again` | Arrivals are never ambushes, and the grace is a delay, not a disarm |
| `clearing wave 2 still does not clear a three-wave arena` → `beating the last wave clears the arena` | Three waves really is three waves |
| `the game advanced to room 2` | Arena progression |

**Combat — the hue-armour rules**

| Check | Proves |
|---|---|
| `the strike and dodge verbs are in the input map`, `the old lunge-dash verbs are gone` | Bindings match the spec |
| `swing 1/2/3 deal 12 / 12 / 20`, `one swing hits once however long the blade is out` | The chain and the per-swing dedupe |
| `the heavy third swing knocks the knight back` | The heavy beat is heavy |
| `a complement SHATTERS: x2.5` → `the next shatter breaks the armour for good` | The shatter maths |
| `the same hue is ABSORBED: x0.2` | The absorb maths |
| `a swing turns onto a knight standing inside its arc`, `never spins the player around to hit what is behind`, `a knight behind the swing is not cut` | Auto-aim assists without aiming for you |
| `a knight winds up instead of touching you to death`, `the telegraphed swing lands and costs vigour`, `taking a hit no longer ends the run` | Telegraphed attacks and player HP |
| `space starts a dodge roll`, `a hit during the roll's i-frames does nothing`, `the roll covers ground` | The defensive verb |
| `pressing J swings the blade` (a real `KEY_J` event through `Input.parse_input_event`) | The input map and the code have not drifted apart |

**The Champion of the Wheel — phases, charge, summons**

| Check | Proves |
|---|---|
| `the boss hall is one fight, not a wave arena`, `the boss room has a Champion`, `his hue rotates`, `actually moves over time` | The rotating-hue gimmick exists in time, not just in theory |
| `the Unsworn enters the boss arena burning pure red (no soft lock)` | The window is always eventually reachable |
| `striking an un-cancelled Champion does not wound him`, `his stolen wheel takes exactly zero damage` | The clang gate |
| `the Champion starts in phase I`, `phase I is the Champion plus his two escorts` | Phase I |
| `dropping below two-thirds of his vigour opens phase II`, `phase II does not touch the speed of the wheel`, `phase II calls no new knights` | Phase II adds the charge, not adds |
| `dropping below a third opens phase III`, `phase III spins the wheel markedly faster`, `phase III calls two Aspirants`, `every Aspirant arrives with the same blind grace a wave gets`, `the two Aspirants are a complementary pair` | Phase III, including that its extra knights are fair and useful |
| `the kill window still opens in phase III (no soft lock)` | The faster wheel cannot lock the duel |
| `phase II winds up a charging dash instead of walking in`, `the lane locks in and the dash begins`, `the dash lands and costs vigour`, `the Champion is left open for a punish after the charge` | The full charge read |
| `a complement strike inside the window kills the Champion` | The duel is winnable by the intended route |
| `the beaten Champion does not vanish: he kneels on the sand` | The victory beat |
| `clearing the Champion's arena wins the game`, `the win page is on screen`, `the win screen received a rank and a run time` | The loop closes |
| `restarting from the win screen begins a fresh run at room 1`, `resets the score and the death count` | The loop is replayable |
| `a scripted run clears all four arenas`, `and the melee ends on the victory page`, `with a real score and a rank` | **The complete loop**, in one run: arena 1 → the Champion → victory, through the real clear delays |

**Death**

| Check | Proves |
|---|---|
| `a lethal hit drops the Unsworn to 0 vigour`, `0 vigour is the death the run remembers`, `the death counter went up` | Death is HP-based and tracked |
| `the restart prompt is on screen`, `the room restarts by itself after a death`, `and restarts the SAME room` | Instant, input-free restart of the arena you died in |

### D. Light, waves and level elements (41 checks)

| Check | Proves |
|---|---|
| `the darkness layer exists`, `runs the light-cone shader`, `darkness is drawn during play` | The dark arena is wired in |
| `the shader receives the player's cone width` / `darkness level` | The tunables reach the shader |
| `the lantern array is always the fixed 8 the shader expects` | No wrong-length uniform crash |
| `the light cone follows the player's facing (WASD), not the mouse` | The torch is keyboard-driven |
| `a heard noise sends a guard to investigate`, `a guard already chasing ignores a mere noise` | Guard hearing, without overriding a live chase |
| `a guard abandons an unreachable search instead of walking into a wall forever` | Investigate has a give-up timeout |
| `when one guard locks on, nearby allies come to help` | The alarm spreads |
| `a guard says a line when it spots the player`, `the line is real words`, `a spoken line fades over time` | Knight speech is real and transient |
| `every room has colour motes`, `standing on a mote drinks it`, `drinking a mote gives the Unsworn a colour`, `and it is the mote's own hue` | The pickup changes your hue correctly |
| `all four enriched rooms still build with guards present` | The richer geometry still loads |
| `the pause menu has three rows`, `ESC pauses the run`, `the tree really is paused`, `the pause page is on screen` | Pause freezes the game |
| `RESTART ROOM resumes the game`, `rebuilds the room from the top`, `ESC from the pause page resumes` | Pause is escapable and the restart works |

---

## 3. What the automated tests can NOT check — stated honestly

**The headless engine does not render.** Everything drawn with `_draw()` was never
painted during the test run, so none of the following is covered and all of it
must be checked by eye:

- That anything appears on screen at all
- The arena art: baked sand and its grain, the masonry walls, the stands and the
  crowd, the hanging banners, the corner braziers and their flames, the drifting
  dust, the four arena sigils
- The vision cones, the charge lane telegraph, the splatter blobs, the characters
- The HUD layout (vigour, hue swatch, wheel strip, wave line, Champion phase pips,
  the sand-painted bar)
- **Font sizes, spacing, and whether text is readable**
- The pause / victory / defeat pages, and the kneeling Champion's label
- The darkness itself — that the torch reads as a beam, that the knights' lanterns
  glow, and that the arena is *dim but navigable*
- Screen flash, camera shake, hit-stop, sound

Everything else — the rules, the maths, the state machine, the arena geometry,
the wave flow and the Champion's three phases — **is** machine-verified.

**One benign warning.** The suite exits with
`ObjectDB instances were leaked at exit`. This is the **test harness** holding a
few script/object references in its own arrays until the process dies; it does not
affect the game. It appears only when running `test_runner.tscn`.

**Colour mixing is hue-only.** Saturation and value are largely preserved rather
than truly blended, so mixing two dark colours does not darken them like real
pigment. Known and deliberate.

---

## 4. Manual test checklist

Run through this yourself (F5 in the editor). Each row gives the **expected**
result, so a failure is unambiguous.

### Setup

| # | Step | Expected |
|---|---|---|
| 1 | Press F5 | A 1280×720 window opens **already in the arena**. No title screen, no menu, no story cards, no error text. |
| 2 | Look at the arena itself | Warm sand with visible grain, stone walls with brick courses, a crowd of silhouettes behind the top and bottom walls, banners hanging over the sand, four braziers with moving flames, dust drifting. Never a flat grey box. |
| 3 | Look at the middle of the floor | Arena 1 shows a red-orange sun sigil; the others show their own marks (a cross with a violet centre, a full colour wheel, the wheel's spokes). |
| 4 | Read the top of the screen | A gold **verse for the house** appears above the lesson hint and fades after ~9s, never competing with a fight. |
| 5 | Look beside the score (top right) | The **house sigil**: a hue ring with that house's emblem inside, in the arena's accent colour. It changes every round. |
| 6 | Wait out the first second | A white ring around you counts down the ~1.4s grace before any knight can see you. |

### Arena 1 — The Open Sand (matching)

| # | Step | Expected |
|---|---|---|
| 5 | Press W A S D | You move smoothly and stop when released, with no drift. The arena is dark but readable: a pool of light at your feet and a torch beam ahead that sweeps the way you steer. |
| 6 | Walk into a wall | You **stop** — no passing through, no jitter. Walls read as stone, not as flat rectangles. |
| 7 | Press Space | A short, fast roll in the direction you are steering, with fading after-images and a readiness ring. You cannot spam it. |
| 8 | Press J / left click | A white blade arc in the arc you face, in the chain 12 / 12 / 20. The third swing is visibly wider and heavier. |
| 9 | Walk up to the **red** knight and cut him down | He spills red paint, the screen flashes, the sand is marked. |
| 10 | Stand in that paint | The HUD swatch reads RED, and the remaining knight's cone sweeps over you without reacting: `CAMOUFLAGED`. |
| 11 | Step off onto bare sand | You are exposed again within about half a second (`CONTRAST 100%`). |
| 12 | Kill the last knight of wave 1 | A herald banner announces `WAVE 2 / 3`, two knights march in from the north and south gates with arrival rings, and the HUD counts the reserve. |
| 13 | Clear all three waves | `ARENA CLEARED` banner, a short beat, then Arena 2 loads with its own art and hint. |

### Arena 2 — The Bannered Hall (mixing)

| # | Step | Expected |
|---|---|---|
| 14 | Look at the hall | A cross of four halls, a bright crossing in the middle painted with the two house colours and the violet square where they meet, banners on the walls. |
| 15 | Kill RED where the two lanes cross | Red paint on the sand. |
| 16 | Kill BLUE in the same place | The two puddles overlap and the HUD swatch reads **violet / magenta**, not yellow. Order does not matter. |

### Arena 3 — The Deep Ring (complements)

| # | Step | Expected |
|---|---|---|
| 17 | Look at the pit | A ring wall with four gates around a small pit with two altars, and **a whole colour wheel painted on the sand**. |
| 18 | Kill YELLOW, then BLUE within 3 seconds | White flash, hard shake, `COMPLEMENT x2`, and 100 then 200 on the score. |
| 19 | Kill RED then GREEN within 3s | **No combo** — the multiplier stays x1 (120° apart, not 180°). |
| 20 | Wait 3+ seconds between two complement kills | **No combo** — the window genuinely expires. |
| 21 | Watch the "SAND PAINTED" bar as you kill | It fills as paint accumulates. |
| 22 | Clear the arena without ever being spotted | `+250 flawless arena` on the clear banner. |

### Arena 4 — The Wheel (the Champion)

| # | Step | Expected |
|---|---|---|
| 23 | Enter the last arena | You arrive as **pure red** on a floor with a turning eight-spoke wheel, with eight pillars and a dais. |
| 24 | Watch the HUD wheel bar | The Champion's hue tick visibly rotates, and the gold band shows where your complement is. |
| 25 | Strike him while his tick is outside the band | He clangs, takes **zero** damage, and a red indicator says the window is closed. |
| 26 | Strike inside the band | Big shatter, stagger, `+150` for the break. |
| 27 | Take him below two-thirds of his vigour | `PHASE II — THE CHARGE` banner. He now plants his feet, paints a long lane on the sand, and sprints down it. **Space** rolls through it; walking does not. |
| 28 | Take him below a third | `PHASE III — THE ASPIRANTS` banner, his hue visibly spins much faster, and **two Aspirants** march in (a Yellow/Blue pair) with arrival rings. |
| 29 | Kill the last thing in the arena | He **kneels** where he falls with the label `THE CHAMPION KNEELS`, the crowd goes quiet, then `THE UNSWORN IS NAMED`, then the victory page. |
| 30 | Press the restart option on the victory page | A fresh run at Arena 1 with score 0 and 0 falls. |
| 31 | Press Esc during play | The **pause page** appears (RESUME / RESTART RUN / QUIT GAME) and the arena freezes behind it. Choosing RESUME puts you back exactly where you left. |

### Edge cases

| # | Step | Expected |
|---|---|---|
| 32 | Roll into a wall | You **stop at the wall**. No tunnelling, no sticking. |
| 33 | Kill a knight right next to a wall | Paint appears there and does not break anything. |
| 34 | Stack many splatters | No slowdown, no errors in the Output panel. |
| 35 | Stand still for 60+ seconds | Old splatters **fade out** (~10s each) and disappear. |
| 36 | Spam R | No error spam; the arena rebuilds cleanly each time. |
| 37 | Resize the window | The game **scales** rather than cropping, with no letterbox tearing. |
| 38 | Die repeatedly in the boss arena | Each restart puts you back there as red, ready to try again. |
| 39 | Let the Champion call his Aspirants, then die | The restart rebuilds the arena at phase I with no leftover Aspirants. |

### Web build (after exporting — see HOW_TO_RUN.md §5)

| # | Step | Expected |
|---|---|---|
| 40 | Serve `build/web/` over HTTP and open it | A loading bar, then the first arena — no menu to click. |
| 41 | Click the page | Sound begins (browsers block autoplay until you interact). |
| 42 | Play through Arena 1 | Controls and framerate are acceptable. |
| 43 | Tab away for a minute, come back | The game resumes without a crash. |

---

## 5. Bugs found and fixed by these tests

Recorded because they are the reason the suite exists, and they are good material
for the video.

1. **The combo never fired for a lone complementary kill.** The link check compared
   against a timer the first kill had already zeroed, so a two-kill combo could not
   register. Found by the scripted playthrough.
2. **The player never absorbed the kill colour.** Two checks compared against
   colours that both report hue 0°, so they were passing **vacuously**. Tightening
   them to compare a *non-zero* hue exposed the bug.
3. **Misaligned hue constants.** Red and pure white both report hue 0°, so an early
   pass hid the fact that a "white" starting colour and a "red" knight were
   indistinguishable under the contrast test. The suite now re-derives every value
   from RGB.
4. **Knight patrol routes clipping walls.** Found by the geometry section, which
   samples every leg of every route against every wall rect.
5. **The player spawned underneath the HUD.** Found by *rendering a frame and
   looking at it* — a reminder that the suite cannot catch layout. Spawns moved.
6. **The dark was too dark to navigate.** At `darkness_amount = 0.90` the world was
   a keyhole. Tuned down with an ambient pool around the player.
7. **Guards could investigate a spot forever**, pressing into a wall they could not
   reach. Fixed with a give-up timeout, and covered by a test.
8. **The wave-1 herald banner was never seen.** It was announced during
   `Room._ready()` and wiped a line later by the game's `clear_messages()`. The
   headless suite was green while the banner never appeared — found only in a
   visual pass, and fixed by deferring the announcement.
9. **The combat tests were passing because a knight was stuck inside a pillar.**
   The old arena's geometry pushed the test knight towards the player, closing the
   2px gap that the strike reach needed. Rebuilding the arenas exposed it: the
   tests now stand their combatants at an honest distance instead of relying on
   depenetration.

Lesson worth stating plainly: **a test that passes is not the same as a test that
is meaningful.** Several of these were found by noticing an assertion passing for
the wrong reason — and several only by *looking at a frame*.

---

## 6. A note for future runs

The project uses global `class_name`s (`Game`, `Guard`, `Mote`, `ArenaArt`, …). A
**brand-new** script with a `class_name` is only visible to a headless run *after
the editor has scanned it once*, because that scan writes Godot's script-class
cache (inside the git-ignored `.godot/`). If you add a new `class_name` and a
headless run reports `Could not find type …` or
`Identifier "X" not declared in the current scope`, run:

```bash
godot --headless --editor --path . --quit
```

…then re-run the tests. This is a Godot quirk, not a bug in the game.
