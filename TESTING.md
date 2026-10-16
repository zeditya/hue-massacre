# TESTING — Hue Massacre

Two kinds of verification are recorded here:

- **Automated** — 129 checks in `tests/test_runner.gd`, run in a headless Godot
  engine. Reproducible by you in one command.
- **Manual** — a checklist for the things a script cannot judge, mostly *feel* and
  *visuals*, each with the expected result so you can tick it off.

---

## 1. How to run the automated suite

```bash
# Linux / macOS
/path/to/Godot_v4.7-stable_linux.x86_64  --headless --path . res://tests/test_runner.tscn

# Windows (PowerShell)
& "C:\path\to\Godot_v4.7-stable_win64.exe" --headless --path . res://tests/test_runner.tscn
```

Or open `tests/test_runner.tscn` in the editor and press **F6**.

**Exit code is 0 on success, 1 on failure**, so it can be wired into CI.

---

## 2. Results of the last run

```
Godot Engine v4.7.2.stable.official.ed1daf0bf

=========================================================
HUE MASSACRE - automated test runner
Godot 4.7.2-stable (official)
=========================================================

--- A. COLOUR THEORY MATHS
  ... 30 checks ...
--- B. LEVEL GEOMETRY
  ... 35 checks ...
--- C. INTEGRATION (real scene, scripted playthrough)
  ... 64 checks ...
=========================================================
RESULT: 129 passed, 0 failed
=========================================================
```

**Verified on:** Godot 4.7.2-stable (official Linux build), headless renderer.
**Result:** `129 passed, 0 failed`, process exit code `0`.

### What each section proves

#### A. Colour theory maths (30 checks)

The colour system is the graded core, so it is tested hardest — including
re-deriving every hue constant from its RGB value, so the comments in
`level_data.gd` cannot silently lie.

| Check | Proves |
|---|---|
| `hue_gap wraps through 0 (10 vs 350 = 20)` | Hues are treated as a **circle**, not a number line |
| `hue_gap maxes at 180 (0 vs 180)` | Distance is the *shortest* arc |
| `RED is 0 degrees` … `PURPLE is 285 degrees` | All six guard hues are exactly what they claim |
| `YELLOW <-> BLUE is a complement (exactly 180)` | The exact complement pair is real |
| `GREEN <-> PURPLE is a complement (165)` | The 15°-off pair is accepted |
| `ORANGE <-> BLUE is NOT (only 150 apart)` | **The tolerance actually rejects things** — it is not a rubber stamp |
| `RED <-> BLUE is NOT (only 120 apart)` | Same, for a second common mistake |
| `RED <-> GREEN is NOT (only 120 apart)` | Same again |
| `YELLOW <-> BLUE survives even a near-zero tolerance` | Float precision does not make the exact pair fail at 0° tolerance |
| `grey-free floor: RED on RED paint is INVISIBLE` | Matching hue → hidden |
| `YELLOW on BLUE paint is fully exposed` | Contrasting hue → seen |
| `bare grey floor always exposes you` | The starting condition is not accidentally safe |

#### B. Level geometry (35 checks)

All 4 rooms, every guard route. This section caught several real bugs during
development, so it earns its place.

| Check | Proves |
|---|---|
| `there are 4 rooms (3 teaching + boss)` | The content matches the spec |
| `<ROOM>: player spawn is clear of walls` | You never spawn inside geometry |
| `<ROOM>: has guards` | No room is accidentally empty (which would be an unwinnable dead end) |
| `<ROOM>: guard N route clears every wall` | **No guard patrol clips through a wall.** Each path segment is checked against every wall rectangle inflated by the guard's radius |
| `<ROOM>: guard N has a real patrol route` | Routes have at least 2 distinct points, so no guard paces on the spot |

#### C. Integration — scripted playthrough (64 checks)

This drives the **real** `scenes/main.tscn`, through the complete game, asserting
on live game state. It is not a mock: it boots the actual scene and plays it.

**Title and intro**

| Check | Proves |
|---|---|
| `main.tscn loads` | The shipped entry point is valid |
| `the game boots to the title screen` | Correct initial state |
| `no room is built while on the title screen` | No work leaked before the player asks for it |
| `requesting start moves to the intro` | Title → intro transition |
| `the intro has exactly 5 story cards` | The required 5 cards |
| `every story card has 2 rhyming lines, each with its own tint` | **The exact assignment text is present, and the last-word colouring works** |
| `finishing the cards starts the run` | Intro → gameplay transition |

**Characters — the sprite system**

| Check | Proves |
|---|---|
| `the character sprite bank builds` | The 12 sprite sheets load and slice into frames |
| `the character has 12 animations (idle/run/attack x 4 facings)` | The sheet layout is what the code claims it is |
| `every facing has idle, run and attack animations` | All four directions exist for every state |
| `every animation is 8 frames (the sheet layout)` | Frame counts match the source art |
| `facing angle 0 points right` … `facing angle 270 points up` | The angle→facing maths is correct for Godot's +y-down space |
| `the player is drawn as an animated character sprite` | The player is a real figure, not a coloured dot |
| `and is re-coloured by the hue-tint shader (colour theory stays the core)` | The imported art is tinted to the current hue |
| `guards are drawn as animated character sprites too` | Guards use the same sprite + tint system |

**Room 1 — hiding by matching**

| Check | Proves |
|---|---|
| `room 1 is built` / `room 1 has 2 guards` | Level data reaches the world |
| `the spark starts colourless (white)` | Correct starting colour |
| `killing a guard removes it from the room` | The kill actually lands |
| `the spark is no longer colourless after a kill` | Colour absorption happens |
| `the spark absorbs the dead guard's hue` | **And it is the correct hue** — not just *some* colour |
| `one kill scores the base amount` | Scoring is wired up |
| `the kill left paint on the floor` | Splatter spawns |
| `the floor under the kill is PAINTED, not bare grey` | The paint layer answers queries correctly |
| `and it is the guard's hue` | In the right colour |
| `the restore bar started filling` | Room progress responds to paint |
| `standing in paint of your own hue HIDES you` | The core hiding mechanic |
| `and reports zero contrast` | Hiding is measured, not faked |
| `stepping onto bare grey floor EXPOSES you` | And it is reversible — you cannot hide by doing nothing |
| `and reports full contrast` | Contrast scales correctly |
| `clearing the last guard starts the room-clear sequence` | Room completion triggers |

**Rooms 2 & 3 — mixing and complements**

| Check | Proves |
|---|---|
| `the game advanced to room 2` | Room progression works |
| `room 2 has 3 guards` / `room 3 has 5 guards` | Guard counts per the design |
| `room 3 contains the YELLOW/BLUE complement pair` | The teaching room can actually teach |
| `the first kill of a chain is unscored-by-combo (x1)` | No multiplier for a lone kill |
| `the complementary kill doubles the multiplier` | **The combo trigger works** |
| `the combo paid 100 then 200` | ...and pays the right amounts |
| `the combo window is now ticking for the HUD` | The window is real and visible |
| `RED then GREEN does NOT combo (120 apart, not 180)` | **The combo rejects non-complements** — the key negative case |

**Death and restart**

| Check | Proves |
|---|---|
| `touching a guard kills the player` | One-hit death |
| `the death counter went up` | Deaths are tracked for the rank screen |
| `the restart prompt is on screen` | Player feedback on death |
| `the room restarts by itself after a death` | **Instant restart with no input required** |
| `and restarts the SAME room` | Not room 1 — the room you died in |

**The boss**

| Check | Proves |
|---|---|
| `the boss room has a Collector` | Boss spawns |
| `the Collector's hue rotates` | The rotating-hue gimmick exists |
| `the spark enters the boss room burning pure red (no soft lock)` | **The boss is always eventually killable** |
| `the Collector's hue actually moves over time` | It rotates in *time*, not just in theory |
| `with the player red, a red Collector is NOT vulnerable` | Invulnerability is enforced |
| `putting the player on the Collector's complement opens the kill window` | **The complement rule is the actual key** |
| `lunging at an un-cancelled Collector kills YOU instead` | The window is a real risk, not decoration |
| `the kill window is open on the second boss attempt` | The window *re-opens* — it is a cycle, so you get more than one try |
| `the complement lunge kills the Collector` | The boss is beatable by the intended route |

**Win state**

| Check | Proves |
|---|---|
| `clearing the boss room wins the game` | The full loop closes |
| `the win page is on screen` | The win screen appears |
| `the win screen received a rank and a run time` | The end-of-run summary is computed |
| `restarting from the win screen begins a fresh run at room 1` | The loop is replayable |
| `and resets the score and the death count` | A new run really is new |

---

## 3. What the automated tests can NOT check — stated honestly

**The headless engine does not execute `_draw()`.** Everything drawn with
`_draw()` was never rendered during the test run. Concretely, these are
**NOT covered by the automated suite** and must be checked by eye:

- That anything appears on screen at all
- The vision cones, the splatter blobs, the player/guard shapes
- The HUD layout, the restored bar, the boss wheel
- **Font sizes, spacing, and whether text is readable**
- The intro card fade-in and the coloured last words
- Screen flash, camera shake, hit-stop
- Sound

Everything else — the rules, the maths, the state machine, the geometry and the
win/lose flow — **is** machine-verified, because those all live in logic rather
than in `_draw()`.

**One benign warning.** The suite exits with
`2 ObjectDB instances were leaked at exit`. This is the **test harness** holding a
couple of script/object references in its own arrays until the process dies; it
does not affect the game. It appears only when running `test_runner.tscn`.

**Colour mixing is hue-only.** Saturation and value are largely preserved rather
than truly blended, so mixing two dark colours will not darken them like real
pigment. Known and deliberate — see the README's limitations section.

---

## 4. Manual test checklist

Run through this yourself (F5 in the editor). Each row gives the **expected**
result, so a failure is unambiguous.

### Setup

| # | Step | Expected |
|---|---|---|
| 1 | Press F5 | A 1280×720 window opens on the **title screen**. No black window, no error text. |
| 2 | Look at the title | "HUE MASSACRE" is large and legible; the tagline sits below it. |
| 3 | Press a key | Five story cards appear **one at a time**, each fading in. |
| 4 | Read each card | Two lines each, and the **last word of each line is a different colour** from the rest. |
| 5 | Compare to the assignment text | All five couplets match the specified text **exactly**. |
| 6 | Wait for the last card / press a key | Room 1 loads with a ~1.4s grace period before guards can detect you. |

### Room 1 — movement, dash, hiding

| # | Step | Expected |
|---|---|---|
| 7 | Press W A S D | The white spark moves smoothly and stops when released. |
| 8 | Walk into a wall | You **stop** — no passing through, no jitter. |
| 9 | Press Space | A short, fast lunge. You **cannot** spam it: there is a visible cooldown. |
| 10 | Click the left mouse button | The lunge goes **toward the cursor**. |
| 11 | Watch during the lunge | Fading after-images follow the spark. |
| 12 | Get seen: stand in a cone in the open | The guard's cone turns toward you and he **chases**. |
| 13 | Let a guard touch you | Instant death; screen shakes; a restart prompt appears. |
| 14 | Wait ~1s, do nothing | The **same room restarts by itself** — no button needed. |
| 15 | Press R mid-room | The room restarts immediately. |
| 16 | Kill a guard with a lunge | He dies, **paint splatters** in his colour, the screen flashes. |
| 17 | Check the HUD swatch | Your colour has changed, and it is **labelled with a hue name**. |
| 18 | Stand in that new paint | The guard's cone sweeps over you and **does not react**. You are hidden. |
| 19 | Step off the paint onto bare grey | You are **spotted again** within about half a second. |
| 20 | Kill the second guard | Room clears; a short beat; **Room 2 loads**. |

### Room 2 — colour mixing

| # | Step | Expected |
|---|---|---|
| 21 | Kill the Red guard, then the Blue guard | Violet puddles on the floor where their paint overlaps. |
| 22 | Check your swatch after both kills | It reads as a **violet / magenta** family hue, not yellow. |
| 23 | Kill Red then Blue again, in the other order | The same violet result — mixing is symmetric. |

### Room 3 — complement combos

| # | Step | Expected |
|---|---|---|
| 24 | Kill Yellow, then Blue within 3 seconds | A big flash in those colours, a hard screen shake, and the **multiplier goes to x2**. |
| 25 | Watch the score | 100 paid for the first kill, 200 for the second. |
| 26 | Now kill Red, then Green within 3s | **No combo** — the multiplier stays at x1. (120° apart, not 180°.) |
| 27 | Wait 3+ seconds between two complement kills | **No combo** — the window genuinely expires. |
| 28 | Chain three or more complement pairs | The multiplier climbs (up to x8) and the combo readout stays visible while it ticks. |
| 29 | Watch the "restored" bar as you kill | It **fills up** as paint accumulates. |
| 30 | Clear the room without ever being spotted | A stealth bonus is awarded. |

### Room 4 — the Collector

| # | Step | Expected |
|---|---|---|
| 31 | Enter the boss room | You arrive as **pure red**, and a large guard appears with a **wide cone**. |
| 32 | Watch the boss wheel in the HUD | The boss's hue **visibly rotates** around the wheel. |
| 33 | Lunge at him at a random moment | **You die.** A red indicator shows the window is closed. |
| 34 | Kill a small guard to shift your hue | Your swatch changes and the **target band on the wheel moves**. |
| 35 | Wait until the boss's hue is inside your complement band, then lunge | **He dies.** Big flash, +1000, and the room clears. |
| 36 | If you miss, keep trying | The window **re-opens every lap** (~13s) — you can never be permanently stuck. |

### Win / lose / menus

| # | Step | Expected |
|---|---|---|
| 37 | Beat the Collector | The **win screen** appears with the specified couplet, your score, time and a rank. |
| 38 | Press the restart option on the win screen | A fresh run starts at Room 1 with score 0 and deaths 0. |
| 39 | Press Esc during play | You return to the title screen. |
| 40 | Press Esc, then start again | A clean run from the beginning. |

### Edge cases

| # | Step | Expected |
|---|---|---|
| 41 | Dash into a wall | You **stop at the wall**. No tunnelling, no sticking. |
| 42 | Kill a guard right next to a wall | Paint appears there and does not break anything. |
| 43 | Repeatedly kill guards to stack many splatters | Nothing slows down dramatically and no error appears in the Output panel. |
| 44 | Stand still for 60+ seconds | Old splatters **fade out** (~10s each) and disappear. |
| 45 | Spam R to restart repeatedly | No error spam; the room rebuilds cleanly each time. |
| 46 | Resize the window | The game **scales** rather than cropping, with no letterbox tearing. |
| 47 | Die on the boss repeatedly | Each restart puts you back in the boss room as red, ready to try again. |

### Web build (after exporting — see HOW_TO_RUN.md §5)

| # | Step | Expected |
|---|---|---|
| 48 | Serve `build/web/` over HTTP and open it | A loading bar, then the title screen. |
| 49 | Click the page | Sound begins (browsers block autoplay until you interact). |
| 50 | Play through Room 1 | Controls and framerate are acceptable. |
| 51 | Tab away for a minute, come back | The game resumes without a crash. |

---

## 5. Bugs found and fixed by these tests

Recorded because they are the reason the suite exists, and they are good material
for the video.

1. **The combo never fired for a lone complementary kill.** The link check compared
   against a timer that the first kill had already zeroed, so a two-kill combo
   could not register. Found by the scripted playthrough, fixed in `game.gd`.
2. **The player never absorbed the guard's colour.** The hidden mechanic was
   effectively missing — the swatch never changed. Found by an assertion that
   looked like it passed: two of the checks compared against colours that both
   report hue 0°, so they were passing **vacuously**. The assertions were tightened
   to compare against a *non-zero* hue, which exposed the bug.
3. **Misaligned hue constants.** Red and pure white both report hue 0°, so an early
   pass hid the fact that a "white" starting colour and a "red" guard were
   indistinguishable under the contrast test. The hue table now separates them and
   the tests re-derive every value from RGB.
4. **Guard patrol routes clipping walls.** Found and fixed by the geometry section,
   which checks each path segment against every wall rectangle.

Lesson worth stating plainly: **a test that passes is not the same as a test that
is meaningful.** Two of these four were found by noticing that an assertion was
passing for the wrong reason.
