# Hue Massacre — Rebuild Progress Log

> **Resuming the project? Read `PROGRESS_REPORT.md` first** — it is the full brief
> (assignment, history, codebase map, conventions, gotchas, next steps). This file
> is the detailed session-by-session log.
>
> **The most recent work is §11** (the opening scene, guard/parry, footsteps, the
> marked overhead). §10 is the RPG pivot it was built on top of; §9 is the arena
> overhaul, and §10.4 / §11.7 are the live to-do lists. When you change something
> here, add a new section rather than rewriting history — this file is the
> handoff.

**Repo:** `https://github.com/zeditya/hue-massacre` (branch `master`, live via GitHub Pages)  
**Previous build:** tag `v1-stealth` → `ddb3a88` (stealth/Collector premise preserved)  
**Godot:** 4.7.2 via flatpak, web export forced to Compatibility (WebGL2)

---

## 1. What the rebuild is

Old premise (all of it removed): grey world, spark, Collectors, stolen colours, rhyme cards, grey city.  
New fiction: **Arena of the Wheel** — a medieval tournament.  
**Genre:** 2D flat top-down hack & slash (Soul Knight / Hades readability). Camera locked flat top-down at 1.5× zoom-follow, clamped to playfield (3D billboard and 2D tilt prototypes archived/deleted).  
**Core mechanic kept (rubric 40/100 = colour theory):** hue-armour shatter — complement strikes shatter (×2.5 + stagger), same hue absorbed (×0.2), other neutral (×1); blade absorbs kills' hues.

**Phase order (GAME_SPEC_v3.md §9):**  
(1) combat core ✓ → (2) hue-armour ✓ → (3) arenas/waves + camera ✓ → (4) boss → (5) reskin → (6) tests/docs/export

---

## 2. Combat core — completed (pre-existing state)

Commit `d266bbb` plus camera commit `4443736`. Key elements before this session:
- Player HP 100 / guard 60 / boss 400; `ColorTheory.hit_kind / hit_multiplier`
- Player `take_damage` + 0.8 s i-frames + hitstun + knockback + per-lunge dedupe (`dash_serial`)
- Guard `take_hit` / `clang` / stagger / telegraphed attack (0.55 s windup → damage → 0.55 s recover, cooldown 1.0, damage 12 / boss 25)
- Room `_resolve_contacts` rewritten (contact no longer kills; boss clangs outside window); guard-death accounting (paint + absorb) centralised in `room._on_guard_killed`
- HUD vigour bar, overhead enemy HP bars, audio `hit` / `clang` / `shatter`, `room.strike_landed` feedback (shake / flash / hit-stop / sound)
- Camera 2D zoom 1.5, follow speed 7, clamped; single `world_to_screen` feeds darkness shader + HUD barks
- Test suite was green at 215 passed / 0 failed

---

## 3. Just completed: strike / dodge split (combat v2)

**Commit:** `7042b06` — *"Split the verbs: strike on J / left click, space becomes the dodge roll"*  
Pushed to `master` → live build updates via Pages.

### 3.1 Spec implemented (§4 GAME_SPEC_v3.md)

| Verb | Binding | Behaviour |
|------|---------|-----------|
| Strike | `J` or left mouse | 3-swing chain 12 / 12 / 20; third hit knocks back; gentle auto-aim onto nearest knight inside ~120° arc |
| Dodge roll | `Space` | 0.35 s duration, 0.25 s i-frames (front-loaded), 0.9 s cooldown; cancels a swing in progress |

**Room rule change:** hit resolution moved from `player.is_dashing()` to `player.is_striking()` (strike window 0.14 s).

### 3.2 Files rewritten

**`scripts/player.gd`** — full redesign:
- Signals: `struck(direction)` (room answers with auto-aim + noise), `rolled(direction)` (game feedback), `hurt(amount, from_position)` — old `dashed(direction)` removed
- Strike exports: `combo_damage = [12, 12, 20]`, `strike_active` 0.14 s, `strike_cooldown` 0.28 s, `combo_window` 0.60 s, `strike_reach` 22 px, `strike_half_deg` 55°, `auto_aim_deg` 60°, `strike_step` 300 px/s
- Dodge exports: `roll_duration` 0.35 s, `roll_iframes` 0.25 s, `roll_speed` 560 px/s, `roll_cooldown` 0.90 s, `afterimage_count` 5, `afterimage_interval` 0.022 s
- State vars: `strike_left`, `strike_cooldown_left`, `combo_left`, `strike_index`, `strike_serial`, `roll_left`, `roll_cooldown_left`
- Old lunge state deleted: `dash_left`, `dash_cooldown_left`, `dash_serial`, `_dash_dir`, `is_dashing()`, `get_blade_direction()`
- Public API used by room/tests: `is_striking()`, `is_rolling()`, `strike_damage_now()`, `strike_is_heavy()`, `strike_angle()`, `aim_strike_at(pos)`, public `begin_strike(input)`, `begin_roll(input)`
- `_draw()`: white blade arc along swing direction (+ wider/heavier + hue-tipped core + blade-tip dot for heavy third swing), roll readiness ring, ground shadow, hurt flash, hue glow; tumbling rotation during roll

**`scripts/room.gd`**:
- `_resolve_contacts()` → `_resolve_strikes()`: wedge test via `strike_half_rad()`, reach via `strike_reach_now()`, boss clang gate kept, serial dedupe via `strike_serial`, `guard.take_hit(damage, shatter, heavy, from_position, strike_serial)`
- `_on_player_dashed()` → `_on_player_struck(direction)`: gentle auto-aim (`_nearest_guard_in_arc` + `_angle_delta` helpers) then noise broadcast within `hear_radius`
- `blade_reach_bonus` export removed (reach now lives entirely on the player)

**`scripts/guard.gd`**:
- `take_hit(amount, shatter, heavy, from_position, strike_serial)`; `_last_dash_serial` → `_last_strike_serial`; knockback 90 normal / 240 shatter / 320 heavy; stagger 0.18 normal / 0.30 heavy / 1.0 shatter

**`scripts/game.gd`**:
- `dash_shake` export → `roll_shake`; `_on_player_rolled(direction)`: camera shake + "dash" sfx pitched up
- `load_room` wires `room.player.rolled` after room added

**`tools/make_input_map.gd` + `project.godot`**:
- New actions: `strike` (KEY_J + MOUSE_BUTTON_LEFT), `dodge` (KEY_SPACE); `dash` and `dash_aim` purged from project.godot (regenerated by running the tool)

**`ui/screens.gd`** — controls panel now lists J / left click strike + Space dodge roll; rules text updated to shatter / absorb / hide language

**`README.md` + `HOW_TO_RUN.md`** — control tables and 30-second first run rewritten around strike/roll instead of lunge-dash

**`tests/test_runner.gd`** — combat block rewritten:
- Neutral chain 12/12/20 verified (hp 48 → 36 → 16), single-swing dedupe verified (hp stays 48 across frames), heavy stagger > 0.2 s
- Complement shatter chain: 30 → dead (two shatters break 60 HP)
- Absorbed: hp ≈ 57.6 after one swing
- New dodge-roll test block: starts roll, i-frames block damage, covers ground, ends after duration
- Chain bookkeeping: combo window expiry resets; third swing is heavy; chain wraps back to hit 1
- Wedge test: knight behind the swing is NOT cut
- Auto-aim test: swing turns onto knight inside arc; never spins to hit behind
- Boss: shatter swing inside complement window kills at hp 25; mistimed swing clangs harmlessly; full-room clear still wins
- **Input-path smoke test**: real `KEY_J` / `KEY_SPACE` events via `Input.parse_input_event` must swing / roll (proves input map and code aren't drifted)
- Noise test: `_on_player_struck` heard by nearby guard

**Test count:** 236 passed, 0 failed (was 215). Headless command:
```
flatpak run org.godotengine.Godot --headless --path . res://tests/test_runner.tscn
```

**`tools/capture.gd`** — fixed a reader race: `RenderingServer.force_draw(false)` before grabbing the viewport texture (post-swap reads on the Compatibility renderer returned blank frames, which had invalidated an earlier visual-check round)

**`build/shot_strike.gd`** — throwaway gitignored capture script producing `strike_1`, `strike_heavy`, `roll_mid`, `strike_autoaim` in `build/capture/` for visual verification (swing arc, heavy cleave, tumble trail, auto-aim turn all confirmed readable)

---

## 4. Just completed: wave arenas (phase 3b)

**Commit:** `78bab31` — *"Feed the arenas in waves: reserves, intermissions, herald calls"*

### 4.1 What changed

Arenas now feed their knights in packs instead of dropping the whole cast at once — the Soul Knight / Hades pacing beat that keeps a room from being a one-shot gallery.

| Arena | Wave 1 | Wave 2 |
|-------|--------|--------|
| 01 MATCHING | RED + YELLOW (the original pair) | ORANGE (left aisle) + GREEN (bottom corridor) |
| 02 MIXING | RED + BLUE (the crossing pair — the lesson is always winnable in one wave) | ORANGE (straggler) |
| 03 COMPLEMENTS | RED + GREEN + PURPLE | YELLOW + BLUE (a complement pair in each wave) |
| 04 boss | boss + 2 escorts, single fight (no wave UI) | — |

### 4.2 Implementation

- **`level_data.gd`** — per-room `"waves"` count, per-guard `"wave"` tag (default 1, so untagged rooms fight exactly as before; the boss hall is untouched)
- **`room.gd`** — every knight is built at load; wave > 1 knights go dormant via `guard.sleep_for_wave()` (hidden, process and physics off) and are held in `_reserve`. When the last active knight falls: `wave_cleared.emit()`, `intermission_left = intermission_seconds` (2.0 s), then `_call_next_wave()` wakes the pack (`wave_started(wave, total, count)`). `remaining_guard_count()` = active + reserve, so the HUD never says "0 left" while reserves wait. `release_all_waves()` lets the tests stage a full room without sitting through pauses. Arrival rings drawn per-guard in `_draw()`.
- **`guard.gd`** — `sleep_for_wave()` / `wake_for_wave()`; per-guard `spawn_grace_until` extends the existing room-start blind moment to every arrival (tested: a knight parked in front of the player stays blind for its grace, then sees again).
- **`hud.gd` / `game.gd`** — "WAVE n / t" line + "NEXT WAVE IN x.xs" countdown in the top-right block; herald banner `WAVE 2 / 2 — 2 knights enter the arena`; "the arena falls quiet" flash on wave clear; new `"wave"` audio cue baked in `audio_bank.gd`.

### 4.3 Bug caught by the visual pass

The first-wave banner was announced during `Room._ready()` but wiped a line later by `load_room`'s `hud.clear_messages()`. Fixed by announcing the first pack via `_announce_wave.call_deferred(...)` so it lands after the room is fully dressed. (This is why the visual capture step matters: the headless tests were green while the banner never appeared.)

### 4.4 Tests

**264 passed, 0 failed** (was 236). New coverage: per-room wave-data validation (waves dense 1..N, knights in each, boss hall single cast), the full wave flow (wave 1 clear → intermission, not room clear → reserve counted by HUD and `remaining_guard_count()` → wave 2 arrival), arrival grace (blind, then sees again), and wave-aware room-clear advance. Existing guard-index tests still pass because wave 1 keeps the original cast order.

### 4.5 Captures (build/capture, gitignored)

`wave_start.png` (WAVE 1/2 banner + HUD line), `wave_intermission.png` (quiet flash + countdown, HUD counting the reserve), `wave_arrival.png` (WAVE 2/2 + ORANGE marching in with his arrival ring, player turned orange from absorbing RED+YELLOW — the colours-do-mix proof).

---

## 5. Just completed: Phase 4 (Champion) + the menu cut + new arenas + the look

**Commit:** `ec2d146` — *"Rebuild the melee: the Champion, four new arenas, and a
code-drawn look"* (local commit; not pushed in this session).

Four directives landed together this session, all from the user: the boss spec,
the instruction to **cut the menu and the story screens entirely**, a **completely
new level design**, and *"I need the graphics to be very good"*.

### 5.1 The Champion of the Wheel (spec §4, phase 4)

`guard.gd` gained an isolated boss branch:

| Phase | Opens at | Behaviour |
|-------|----------|-----------|
| I | 100% | sweeps only (the existing telegraphed melee) |
| II | ≤ 66% HP | adds a **charging dash**: `Charge.WINDUP` (0.65s, lane painted on the sand) → `DASH` (620 px/s, 0.55s, direction locked at the end of the windup) → `RECOVER` (0.75s punish window). A shatter *cancels* the charge. |
| III | ≤ 33% HP | `summons_requested.emit(2)` and `hue_speed = base * 1.8` |

- Signals: `phase_changed(phase)`, `summons_requested(count)`, `charge_started()`.
- `room.gd` answers the summons by building the arena's `"summons"` specs through
the same `_make_guard()` path, joins them to `guards` (so the arena is not clear
until they are down) and gives each one `spawn_grace_until` — the same blind grace
a wave gets.
- **Victory beat:** `die()` on a boss sets `kneeling = true` and an effectively
infinite death timer, so he stays on the floor in a slump with the label *THE
CHAMPION KNEELS*; `game.gd` runs a three-beat sequence (*kneels* → *the sand
remembers every hue* → *THE UNSWORN IS NAMED*) inside the 2.1s room-clear pause.
- `game.gd` banners for both phase changes, a camera shove on the charge, and new
audio cues `charge` / `named`.
- HUD: `CHAMPION PHASE I/II/III` with three pips, next to the wave line.

### 5.2 The menu and the story are gone

- `Screens` now has exactly three modes: **PAUSE, WIN, DEAD**. `TITLE`, `HOWTO`,
  `STORY`, `INTRO`, the five rhyme cards, `STORY_LINE` and `MENU_ITEMS` are deleted.
- `Game.State` is now `PLAY / PAUSED / DEAD / WIN`; `_ready()` calls `start_run()`,
  so the build **opens in arena 1**.
- Pause rows are now **RESUME / RESTART RUN / QUIT GAME** (- `run_restart_requested`
  wired straight to `start_run`), since there is no title screen to go back to.
- The teaching the pages used to do moved into the HUD: each arena prints its own
  lesson as a hint on load, and the banner system carries the herald's calls.
- Rank is now earned by **score** (S ≥ 9000 "NAMED", A ≥ 6000, B ≥ 3000, else C),
  per spec §6, not by deaths.

### 5.3 New level design (all four arenas rebuilt from scratch)

| Arena | Architecture | Waves | Knights |
|-------|--------------|-------|---------|
| 01 THE OPEN SAND | a low walled **ring with four gates**, a concourse around it, two herald plinths | 3 (2+2+2) | RED, YELLOW / ORANGE, GREEN / PURPLE (warden) + BLUE (harrier) |
| 02 THE BANNERED HALL | a **cross of four halls** meeting at one open crossing, quadrant rooms, an outside lane that passes the hall mouths | 3 (2+1+2) | RED + BLUE / ORANGE / GREEN (harrier) + PURPLE (warden) |
| 03 THE DEEP RING | a **ring wall with four gates around a sunken pit** with two altars | 2 (3+2) | RED + GREEN + PURPLE / YELLOW + BLUE |
| 04 THE WHEEL | **eight pillars around a central dais**, the Champion on a circle between them | 1 | Champion + 2 escorts, + 2 Aspirants at phase III |

- The spec's enemy table is implemented as **data on the existing class**: ASPIRANT
  (60 hp / 12 dmg), WARDEN (140 / 25 / slow), HARRIER (45 / 10 / fast), each a
  `guards` entry with different `hp` / `speed` / `damage` / `radius`.
- Every wave room keeps a real complementary pair inside a single wave so the 3s
  combo is always available.
- The old geometry is gone, so the tests that leaned on it were rebuilt (see 5.5).

### 5.4 "Graphics very good": everything is now drawn, and it is dressed

New file **`scripts/arena_art.gd`**:

- **Baked sand floor** (640×360 per arena, stretched to 1280×720): warm sand, two
  grain tones in 2px blocks, an edge vignette. Cached per arena id.
- **The colour-rules constraint is enforced by a measurement, not a comment:**
  `FLOOR_BASE` is at saturation **0.138**, and the baked result measures
  **0.112–0.157** across every arena — under `ColorTheory.GREY_SATURATION` (0.18),
  so `visibility()` still treats the bare floor as "no hue to hide in". Warm to the
  eye, grey to the maths.
- **Masonry walls**: shadow, lit cap, brick courses, staggered joints, inverted
  bevel highlight.
- **A sigil per arena**, drawn live and breathing: a sun (01), the two house lanes
  and their violet crossing (02), a full colour wheel flat on the sand (03), eight
  turning spokes under the Champion (04).
- **Stands**: two rows of swaying crowd silhouettes behind the border walls, with
  flags in the crowd and house banners hanging over the sand.
- **Braziers** at four corners: stone bowl, three flickering licks, warm light pool,
  house-coloured rim.
- **Dust** drifting through the air, so nothing is ever a still image.
- `room.gd` now redraws every frame (it is cheap) and delegates the whole look.
- **`tools/make_floor_plans.gd` was rewritten to rasterise into an `Image`**, so it
  runs headless (the old one needed a display and a rendered frame).
  `docs/level_plans.png` is regenerated from the new layouts.

### 5.5 Tests: 264 → **303 passed, 0 failed**

- Rebuilt the header/intro block as *"the game boots straight into play"*.
- Arena counts/waves updated to the new data (3-wave arenas, new reserves).
- **Fixed a test that was passing for the wrong reason:** the combat tests had put
  their knight inside an old pillar, and depenetration was closing the 2px that the
  strike reach needed. The combatants now stand at an honest 40px.
- New checks: Champion phase thresholds (and that phase II adds no knights), phase
  III's faster wheel + two Aspirants with arrival grace + complementary hues, the
  window still opening in phase III (no soft lock), the whole charge read
  (windup → dash → land → punish window), the kneeling death, and aspirant spawn
  geometry in section B.
- New end-to-end check: **a scripted run that clears all four arenas and ends on
  the victory page with a real score and rank** — the complete-loop guarantee.

### 5.6 Runtime and export checks (no display needed)

- **Stress run** (`build/debug_stress.gd`, throwaway): every wave arena loaded
  with *all* packs on the floor and left fighting for 240 physics frames each -
  no runtime errors, correct knight counts (6 / 5 / 5). The Champion was then
  driven from 400 HP through phase II and III to dead, live: `hue_speed` came out
  at **50.4** (= 28 x 1.8), he ended `dead=true kneeling=true`, and the arena
  correctly refused to clear with **4** knights still standing (2 escorts + 2
  summoned Aspirants).
- **Web export verified locally**: the flatpak Godot looked for templates in its
  own sandbox data dir, which was empty, so `web_nothreads_release.zip` was copied
  from `~/.local/share/godot/export_templates/4.7.2.stable/` into
  `~/.var/app/org.godotengine.Godot/data/godot/export_templates/4.7.2.stable/`.
  `--export-release "Web" build/web/index.html` then produced a complete site
  (`index.html`, `index.js`, `index.wasm` 39.5MB, `index.pck` 13.4MB), and serving
  it with `python3 -m http.server` returned **200** for all three. The preset's
  `exclude_filter="tests/*, tools/*"` keeps the suite out of the shipped pck.
- **Sand bake measured**: `ColorTheory.GREY_SATURATION` is 0.18 and the baked
  arena sand measures 0.112-0.157, so the picture and the hiding rule agree.

### 5.7 Docs

- `README.md`, `TESTING.md` and the play/test sections of `HOW_TO_RUN.md` were
  rewritten for this build (no menu, no story, new arenas, boss phases, the art
  system, 303 checks).
- `PROJECT_STRUCTURE.md` and `SUBMISSION_CHECKLIST.md` are still v1-era.

---

## 6. Git status

- Last commit `ec2d146` on `master` (committed locally this session; **not pushed**)
- Previous pushed commit: `78bab31` (wave arenas)
- Old stealth tag `v1-stealth` → `ddb3a88` preserved
- Pages deploys on master push — the live build still shows the previous revision
  until this is pushed

---

## 7. What remains

**Phase 5 — reskin (mostly done, small pieces left):**
- House **sigils** as a drawn emblem + hue ring (spec §7): the floor marks exist,
  a HUD sigil does not.
- Arena intros: spec asks for *one short verse per house*. Right now each arena
  prints a one-line lesson hint (`room["hint"]`). A verse would mean another HUD
  slot or a held banner.
- Arena-2 "warden" and arena-1/2 "3 waves" from spec §5 are now actually
  implemented (warden = the 140 hp knight; waves = 3/3/2).

**Phase 6 — packaging:**
- `PROJECT_STRUCTURE.md` + `SUBMISSION_CHECKLIST.md` still describe v1 (187 tests,
  stealth wording, story cards) — rewrite or delete before the grader sees them.
- Web export to `build/web` + confirm the Pages workflow still builds.
- `docs/AI_CHAT_HISTORY.pdf` — still not built (dead link in the README).
- 20-minute public YouTube video (`[[PASTE YOUTUBE LINK HERE]]` still a placeholder).
- LMS `submission.txt` — verify before upload.
- Optional at packaging: archive `proto/2d`.

**A by-eye pass is owed.** The environment this session ran in has no display and
no Xvfb, so the headless engine could not render a single frame: the *sand
saturation* was verified numerically (0.112–0.157 vs the 0.18 limit), and the web
build was exported and served locally, but the masonry, stands, banners, braziers,
dust, arena sigils, HUD layout and pages have **not been looked at since they were
written**. Run `tools/capture.gd`, or open the exported `build/web/` over HTTP, on a
machine with a display before trusting the look.

The flatpak template quirk is worth remembering: Godot's flatpak looks for export
templates *inside its sandbox* (`~/.var/app/org.godotengine.Godot/data/godot/export_templates/`),
not in `~/.local/share/godot/export_templates/`, so the web zips may need copying
across once.

---

## 8. Commands used in this session

```bash
# Test suite (303 checks)
flatpak run org.godotengine.Godot --headless --path . res://tests/test_runner.tscn

# Refresh Godot's script-class cache after adding a new class_name (ArenaArt!)
flatpak run org.godotengine.Godot --headless --editor --path . --quit

# Regenerate the floor-plan figure (now headless-safe, paints into an Image)
flatpak run org.godotengine.Godot --headless --path . --script res://tools/make_floor_plans.gd

# Debug harnesses used this session (gitignored, in build/)
flatpak run org.godotengine.Godot --headless --path . --script res://build/debug_arena.gd
flatpak run org.godotengine.Godot --headless --path . --script res://build/debug_strike.gd

# Visual captures (needs a display - NOT possible in this session)
flatpak run org.godotengine.Godot --path . --script res://tools/capture.gd

# Git
git add -A && git commit -m "..."    # done
git push origin master                # NOT done
```

---

## 9. Session: the arena look-and-feel overhaul + the ten-pack integration

> This is the *current* work. Read this section first if you are picking the
> project up cold: it supersedes §7 above wherever they disagree.

### 9.1 The brief for this session

1. **Arena look-and-feel** — the arena must match the paid reference pack
   (captainskolot.itch.io, "10 Dungeon Arena Asset Pixelart … Battle Field Pack"),
   using **only our own / licensed art**. The paid pack's files are never
   shipped.
2. **Walls and props must occlude fighters**; things must read as objects, not
   as flat decals.
3. **Combat must read as combos and dynamics**, not as taps.
4. **Ten newly added itch.io packs** were to be integrated at their best-fitting
   places — *"make use of everything to the extreme best fits, don't leave
   anything behind"*.
5. **Hard rule the user chose: keep strict** — bare gameplay floor stays below
   `ColorTheory.GREY_SATURATION` (0.18). Vividness comes from fire, light,
   blood and props, never from the floor itself.
6. Licence safety follows the existing `assets/ATTRIBUTION.md` policy: anything
   whose terms are not confirmed is **not** shipped, and the exclusion is
   documented.

### 9.2 Arena overhaul (done, verified by capture)

| Decision | Detail |
|---|---|
| View | fully top-down, "viewed from the south" — so single-view front-facing art is fine for everyone **except the player** |
| Floor | baked brick bake (`_bake_floor`), saturation held under the 0.18 limit (measured 0.112–0.157) |
| Walls | drawn as **raised blocks**: cast shadow → dark face (`face_h`) → lit top lifted `lift` px north, via y-sorted `WallNode`; flat layers opt out by `z_index` |
| Wall metrics | border walls `lift 12 / face 18`; interior `lift 8 / face ≈ 0.55 × thickness ≤ 15` |
| Torches | horizontal at `(x, r.end.y + 3)`, vertical at `(r.end.x + 4, y)` |
| Crowd | front pass, **behind a timber parapet** so the stands never cover a fighter |
| Camera | zoom **2.0** (`camera_zoom = 2.0`); bake pixel = 4×4 screen px; visible region ≈ 640×360 |
| Level data | `"stones"` and `"props"` keys added; all four arenas + zoom-2 frame captured and verified |
| Colour rule | `color_at()` returns `ColorTheory.FLOOR_GREY` for bare floor |

### 9.3 The ten packs, and where every one of them ended up

All ten zips were unpacked to `/tmp/opencode/packs/` and inventoried (frame sizes,
frame counts, licences) before anything was adopted.

| Pack | Licence status | What ships from it |
|---|---|---|
| **Tiny Swords** (Pixel Frog) | commercial OK, modify OK, **no redistribution**, credit welcome | The whole cast: units, crowd, fire, dust, explosion, splash, rocks, bushes, stumps, gold, timber, tools, meat, sheep, trees |
| **Zerie — Tiny RPG Character Asset Pack 01 v2.0** | commercial OK, modify OK, no resale, no AI/NFT usage | `Soldier` + `Orc` idle frame 0, greyed, ×2 → **stone statues** |
| **Super Pixel Effects Gigapack v3.1** (unTied Games) | free, **credit required** | Tintable impacts, splatters, magic bursts, lightning |
| **Medieval Village MegaKit** (Standard) | CC0 | (inspected; see §9.7 for why most of it is not used) |
| **FREE Adventurer 2D Pixel Art** | already shipped | still the **player only** (aim clarity; the test suite pins it) |
| **FREE Character 16-bit Thug Outlined** | **no licence file** | *not shipped* — documented exclusion |
| **FREE Character HD Survivor W Bike** | **no licence file** | *not shipped* — documented exclusion |
| **Demon_sword** | **no licence file** | *not shipped* — side-view slash VFX only |
| **Modern Interiors (LimeZu) Free v2.2** | non-commercial only | already shipped as `assets/tiles/`; flagged in attribution as blocking monetisation |
| **2D HD Character Knight** | licence unconfirmed | *not shipped* — documented exclusion |

#### Final unit mapping

| Unit | Art | Cell | Notes |
|---|---|---|---|
| **player** | FREE Adventurer, 4-direction | 96×80 | keeps aim clarity; test-pinned |
| **knight** | Tiny Swords *Warrior* @ 50% | 96 px | the 60 hp line |
| **warden** | *Warrior* @ **62.5%** | **120 px** | the 140 hp heavy; reads bigger from the same armour |
| **harrier** | *Pawn with Knife* @ 50% | 96 px | 45 hp, fast, fragile |
| **aspirant** | *Pawn with Axe* @ 50% | 96 px | boss summon — "the crowd claims its due" |
| **champion** | Tiny Swords *Lancer* @ 50% | 160 px | + wheel ring; uses its Defence pose on clang |

All non-player art is **pre-greyed at bake time** so `hue_tint.gdshader`
(strength 0.82) yields exact hues — only neutral grey leaks through.

#### FX grammar (every effect tinted by hue, per the game's colour rules)

- white core = impact · hue ring / red = the victim's own colour
- hit → **impact** · heavy → +splatter · shatter → **explosion** + the shatter ring
- kill → **splatter** + splash (the Unsworn drinking the hue) + dust
- mote drunk → **magic** in the mote's hue · boss phase change → **magic** in his hue
- Aspirant summoned → **lightning** in the summoned knight's hue
- roll → **dust** · braziers → `fire_tall` · torches → `fire`

### 9.4 `tools/bake_itch_packs.sh` — the bake pipeline

One script produces every derived sheet, and it documents the provenance and
source size of each one. Run with `SRC=/tmp/opencode/packs`:

```bash
bash tools/bake_itch_packs.sh          # SRC defaults to /tmp/opencode/packs
flatpak run org.godotengine.Godot --headless --editor --path . --quit   # re-import
```

Outputs: `assets/units/{knight,warden,harrier,aspirant,champion}`,
`assets/units/crowd/pawns.png`, `assets/fx/{impact,splatter,magic,splash,dust,
explosion,fire,fire_tall,lightning}.png`,
`assets/props/{rock1-4,bush,stump1-4,gold1-6,wood,meat,tool1-4,sheep,tree,
statue_soldier,statue_orc}.png`, `assets/ui/{banner,bar_base,bar_fill}.png`.

**Three bugs were found and fixed in this script — read them before editing it:**

1. `shift 3` helper-argument handling.
2. `mkdir -p assets/props` was missing.
3. **Zerie statues grabbed all 6 idle frames** instead of one (`[0]` on the PNG
   does not do what it does on a sequence) — needs `-crop 100x100+0+0 +repage`.
4. **ImageMagick `-crop WxH+X+Y` does not tile** in this version; it yields a
   single image. Animated props now cut the band first and tile evenly
   afterwards (`anim_prop` takes `<frames>` and does two crops).

### 9.5 Code changed

**`scripts/sprite_bank.gd`** — `UNITS` table (knight/warden/harrier/aspirant/champion),
`ATTACK_FPS = 7.3`, `unit(kind)`, `_build_unit`, `_slice` (frame count derived
from sheet width ÷ cell), `FEET_Y = 15.0`, `unit_offset(kind)` +
`_measure_offset` (alpha-bbox scan, cached). **The Adventurer API is unchanged** —
`tests/test_runner.gd` pins 12 anims × 8 frames and the player's `"idle_down"`.

**`scripts/guard.gd`** — new `unit` var; sprite from `SpriteBank.unit()` +
`unit_offset()`; `attack1`/`attack2` playback during windup and hold through
recover; `flip_h` for left; the **warden idles in the shield-up guard pose**;
the Champion plays Defence on clang (`_guard_pose_left`); non-boss death is a
**topple** (rotate + fade over the existing white pop) with `_fall_side` set
from the killing blow's direction in `take_hit()`.

**`scripts/room.gd`** — `_make_guard()` picks the unit: an explicit `"unit"` in
the spec wins (that is how Aspirants are marked), otherwise it is read off the
build — boss → champion, radius above `GUARD_RADIUS + 1.5` → warden,
hp ≤ 50 → harrier, else knight. Added `queue_fx()` + `FX_DURATIONS`, and
**wired the combat-effect queue, which was previously dead code**:
`report_strike_effect()` now fires from `_resolve_strikes`, `report_kill_effect()`
from `_on_guard_killed`, `"splash"` + kill fx from the absorb, `"magic"` from
`_resolve_motes`, `"lightning"` per Aspirant in `_on_boss_summons_requested`.

**`scripts/arena_art.gd`** — `CROWD_PATH` / `PAWN_CELL 64` / `PAWN_FRAMES 8` /
`PAWN_ROWS 20` / `PAWN_FEET 45.0` (measured off the art); the crowd is now the
pawn atlas (5 factions × 4 props = 20 rows), with `_house_row()` mapping the
arena's accent to the nearest faction and 34 % of the stands wearing the house
colour; `_draw_spectator()` rewritten to draw a pawn with whole-body actions
(cheer / clap / wave / jump / victory) and a lift scaled by excitement;
`draw_fire()` + `draw_torch()`/`draw_brazier()` now burn the pack's fire;
`DECOR` table + `draw_decor()` (variant picked from the prop's own position so a
rock never changes shape between frames); `FX` table + `draw_fx()` (the frame is
read off `t`, so animation and lifetime can never drift apart).

**`scripts/prop_node.gd`** — every unknown kind routes to
`ArenaArt.draw_decor()`; `_animates()` now also true for multi-frame props.

**`scripts/game.gd`** — `_on_player_rolled()` queues roll dust;
`_on_boss_phase_changed()` flares `magic` in the Champion's hue.

**`scripts/level_data.gd`** — new prop kinds placed in all four arenas
(statues, rocks, stumps, trees, bushes, gold, wood, meat, tools, sheep);
`"unit": "aspirant"` added to the two summons specs.

**`tools/probe_camera.gd`** (new, dev-only) — prints camera position, zoom and
the visible world size. Useful: it proved the capture camera really is at zoom
2 showing a 640×360 region, which is what made the "where is that big knight?"
confusion go away.

### 9.6 Verification

```bash
# tests
flatpak run org.godotengine.Godot --headless --path . res://tests/test_runner.tscn
#  ->  RESULT: 303 passed, 0 failed

# import / class cache
flatpak run org.godotengine.Godot --headless --editor --path . --quit

# visual captures (need a display)
timeout 200 flatpak run org.godotengine.Godot --path . --script res://tools/capture_fight.gd
timeout 300 flatpak run org.godotengine.Godot --path . --script res://tools/capture_arena.gd
```

**Capture results:** all four arenas (`build/capture/arena_0X.png`) inspected —
statues, tree, bushes, rocks, gold and timber all land where they were placed;
bush/sheep/tree animate (all three strips verified at 8/6/8 frames of real
artwork after the `-crop` tiling fix); braziers and torches burn sprite fire;
the crowd reads as people on the parapet. The white ring near a statue is the
**spawn-grace countdown** at `spawn_point` (`room.gd:861-864`) — pre-existing and
correct, not a bug. The long diagonals across the sand are the sun mark's rays
("rays reaching out to the four gates") — also pre-existing and intended.

### 9.7 Deliberate non-uses (documented so they are not "rediscovered" as bugs)

- **Rubber duck** (Tiny Swords) — anachronistic; the arena's tone wins.
- **Side-view** Thug / Survivor / Demon_sword — top-down game, and no licence file.
- **Medieval Village MegaKit** — CC0 so it *may* be used, but its tiles are
  interior/architecture-first and would fight the top-down readability we just
  built. Kept as an option for future non-arena screens.
- The Adventurer stays the **player only**.

### 9.8 Combat-feel polish — DONE this session

- **`_set_hit_stop(weight)`** in `game.gd` now takes a scale instead of being
  all-or-nothing, and the deadline only ever moves *later* (`maxi`), so a kill
  during a cut's micro-stop extends it rather than truncating it. Callers:
  shatter = full (1.0), kill = full, ordinary cut = **0.34**, glance off a
  shield = **0.0** (a stop there would eat the punish window that follows a
  wrong swing).
- **Multiplier pulse** in `ui/hud.gd`: `pulse_multiplier(step)` (called by
  `game.gd` only when the multiplier actually climbs) swells the readout with
  `pow(pulse, 0.55)` — fast out, slower settle — scaling the font 13 → ~17,
  lerping it toward white, and blooming three concentric rings behind it in the
  floor colour's complement. The number says the same thing either way; the
  pulse is what makes it impossible to miss mid-fight.

### 9.9 Licence paperwork — DONE this session (was the blocking item)

- **`assets/LICENSES/tiny_swords.txt`** — the itch.io licence verbatim, plus what
  it means here (commercial + modify allowed, no redistribution, credit given
  anyway) and the note that the zip itself ships **no** licence file, so the
  page's terms are the record.
- **`assets/LICENSES/zerie_tiny_rpg.txt`** — same treatment. Records that only
  the **free demo** (Soldier + Orc) was downloaded, the paid 22-character
  version was not bought, and the AI-training/NFT clause is honoured.
- **`assets/LICENSES/super_pixel_effects.txt`** — the pack's own `license.txt`
  (unTied Games) copied in, plus a "what this means for this project" section
  that names the four effects used and **reproduces the required credit line**.
- **`assets/ATTRIBUTION.md`** — new Units, Effects sections; the Adventurer
  entry corrected (the player *only* — the guards moved to Tiny Swords); the
  exclusions list extended with `2D HD Character Knight` (unconfirmed licence),
  the CC0 Medieval MegaKit (legal but wrong art for this arena), the rubber duck,
  and the unused Tiny Swords sheets.
- **`README.md`** — new "Where the pixels come from" + **"Art credits"**
  sections (the SPE credit is licence-required, so it belongs in the README and
  not only in `assets/`), and the project-structure block now lists
  `units/ fx/ props/ ui/`.

### 9.10 Verified after all of the above

- `RESULT: 303 passed, 0 failed`
- Fight captures re-shot: hits now carry the impact burst + white core in the
  defender's hue; a kill reads as score 100, the Unsworn turning RED, the panel
  border following, and the whole room answering red.
- Arena captures re-shot: braziers burn sprite fire, the tree and bushes
  animate, statues stand at the gates, the crowd is pawns.

### 9.11 Licence safety catch — the paid backdrops

`assets/arenas/*.webp` (3.4 MB, four paintings) were baked by
`tools/build_backdrops.py` **from the reference images in `gpt_assist/`**, which
are shots of the paid reference pack. Shipping those would have been
redistributing paid artwork — the exact thing the brief forbids. Checks made:

- `draw_backdrop()` has **no callers**: the game never drew them.
- Added `/gpt_assist/`, `/assets/arenas/` and `freebuff-chat-*.md` to
  `.gitignore`, excluded `assets/arenas/*` and `gpt_assist/*` in the Web preset,
  and rewrote the `arena_art.gd` section comment to say plainly that the arena
  may *look* like the reference but may not contain its pixels.
- Verified the exported pack by scanning the `.pck` bytes: `assets/arenas`,
  `gpt_assist` and `.zip` are **absent**; `assets/fx/`, `assets/units/`,
  `assets/props/` and the crowd atlas are **present**.

**Lesson for the next session:** the export preset's `exclude_filter` is read by
Godot's `ConfigFile`, which only understands `;` comments — a `#` comment inside
`[preset.0]` makes Godot reject the whole key (it printed
*"Couldn't find the given section preset.0 and key exclude_filter"*). Use `;`.

### 9.12 Pushed

`7616a0b` → `origin/master` (was `76e647d`). Pages now builds this revision, so
the live game is the one in `build/capture/` for the first time. Committed in
that push:

- the overhaul + all ten packs' art (`assets/{fx,props,units,ui}/` — 116 files)
- `scripts/{prop_node,room_front,wall_node,blood_field}.gd` and the changes to
  `arena_art / game / guard / level_data / mote / paint_layer / player / room /
  sprite_bank`, `ui/hud.gd`, `tests/test_runner.gd`
- `tools/{bake_itch_packs.sh, capture_arena.gd, capture_fight.gd,
  build_backdrops.py, probe_camera.gd}`
- three licence files, the attribution rewrite, the README credits
- `.gitignore` (paid backdrops, gpt_assist, the chat log, the personal report)
  and `export_presets.cfg` exclusions

The `v1-stealth` tag is untouched, and the committed tree was checked: no zips,
no `gpt_assist/`, no `assets/arenas/`, no `submission.txt`.

### 9.13 Still open (next agent)

1. **Look at the live build** (Pages deploys `master`; the exported pck is 44.8 MB
   and was scanned clean, but nobody has watched it run in a browser yet). Serve
   `build/web/` over HTTP if you want the same thing locally.
2. **`docs/AI_CHAT_HISTORY.pdf`** is still a dead link in the README, and the
   README still carries `[[PASTE YOUTUBE LINK HERE]]`.
3. **`PROJECT_STRUCTURE.md` and `SUBMISSION_CHECKLIST.md` still describe v1**
   (187 tests, stealth wording, story cards) — rewrite or delete before the
   grader sees them.
4. The "a by-eye pass is owed" warning in the older §7 is now partly satisfied:
   the arena and fight captures have been inspected, but nobody has yet played a
   full room start-to-finish at zoom 2 with darkness on.

### 9.14 The live build, verified

`https://zeditya.github.io/hue-massacre/index.pck` now serves this revision
(418 KB). Scanned the downloaded bytes: `assets/units/{knight,warden,champion}`,
the crowd atlas, `assets/fx/{impact,lightning}`, `assets/props/{statue_soldier,
statue_orc,tree,sheep}` and the Adventurer are **in**; `assets/arenas`,
`gpt_assist`, `.zip`, `build/capture`, `tests/` and `PROGRESS_REPORT` are
**out**.

Two things worth knowing about exporting locally, both learned here:

- **`build/` gets imported.** The capture PNGs live under `build/capture/` but
  are inside the project, so Godot imports them and `export_filter=all_resources`
  ships them: a local export was **44.8 MB** before `build/*` was excluded, and
  **8.9 MB** after. CI never had the problem, because it checks out a clean tree
  where `build/` does not exist — which is exactly why the live pck was 418 KB.
- **`;` not `#`.** Inside `[preset.0]`, a `#` comment makes Godot's ConfigFile
  lose the whole key and the export fails with *"Couldn't find the given section
  preset.0 and key exclude_filter"*.

### 9.15 Housekeeping note for whoever picks this up next

- `tools/probe_camera.gd` was written to settle a confusion (it prints camera
  position, zoom and visible world size, which proved the fight capture is a
  640×360 window at zoom 2, not a whole-arena shot). Dev tool; safe to delete.
- `PROGRESS_SUMMARY.md` is no longer gitignored: it holds no personal data and
  the next agent needs it. `PROGRESS_REPORT.md` and `submission.txt` still are.
- `freebuff-chat-2026-10-18T05-17-59.732Z.md` is untouched on disk and now
  ignored, so `git add -A` can never sweep it into a commit by accident.

### 9.12 Housekeeping note for whoever picks this up next

`tools/probe_camera.gd` was written to settle a confusion (it prints camera
position, zoom and visible world size). It is useful and safe to keep, but it is
a dev tool: delete it if the repo is being tidied for submission.

---

## 10. Session: the story, and the RPG pivot

> **This section supersedes §9.13's "still open" list.** The user's new brief is
> bigger than the assignment: keep the arcade arena game, but make it a
> top-down RPG whose colour theory is both the combat **and** the story, with a
> real boss per hall, smart enemies, weapons and magic, music and footsteps, and
> a proper opening screen. Read `docs/STORY.md` before writing any string.

### 10.1 The story (decided; full bible in `docs/STORY.md`)

**One line: the last colours in the world are locked in four halls. A knight
with no colour comes to take them, hall by hall, and the ones who guard them
will not let go.**

- **The Unsworn** has no hue and no name; their colour was spent. They never
  speak until the end, and their only line is their name.
- **The sworn** are the enemies, and they are *right*: the four halls guard the
  last four quarters of the Wheel, and a hall that loses its colour goes grey,
  then its people do. That is why they fight to the death.
- **Once they see you they never leave** — no cones, no searching, no giving up
  (this is the user's AI rule, and the fiction *is* the rule: the oath is
  total). One exception, kept as a first-strike tool only: standing in paint of
  your own hue keeps a sworn knight from noticing you *before* the fight starts.
- **The Champion was the last Unsworn.** He took the same road and became the
  office: every colour, no self. He invites rather than threatens (*"Take it.
  Take all of it."*), and when he falls he **kneels** and offers the office.
- **The turn is the ending:** the crowd names the Unsworn from the hue they are
  wearing when the Champion kneels — *the name is the colour you kept*. Rank S
  is "NAMED" and always was. Different runs, different names.

**Four halls = four bosses = the four Tiny Swords classes** (a happy accident
worth keeping):

| Hall | Warden | Art | Abilities | Quarter → reward |
|---|---|---|---|---|
| I Open Sand | the Sun's Warden | Warrior | shield stance, slam shockwave, bull charge | EMBER → **heavy strike** |
| II Bannered Hall | the Twin Wardens (red + blue) | Knight pair | kill one, the other **blends** red+blue → violet, both movesets | VIOLET → **bow** |
| III Deep Ring | the Thorn Warden | Monk | hue **ward** (only its complement cuts it), self-heals, thorns erupt, summons | THORN → **ward** (spell) |
| IV The Wheel | the Champion | Lancer | rotation, charge, Aspirants, + quarter storm | GOLD → the office |

The lesson of each hall is taught by *fighting its warden*, never by a text box.

### 10.2 Newly available art (inventoried this session)

The first pass only skimmed the packs. What is actually in them:

- **Tiny Swords** — `Archer_{Idle,Run,Shoot}` + `Arrow.png` (a real ranged
  enemy), `Monk/{Idle,Run,Heal}` + `Heal_Effect.png` (a healer boss + a ward
  spell), the **full 8-direction Lancer** attack/defence sheets, `Warrior_Guard`,
  and per-class Pawn `Interact` sets. 5 colour factions for every unit.
- **Buildings** — 8 types × 5 factions (`Castle`, `Tower`, `Barracks`,
  `Archery`, `Monastery`, `House1-3`): the halls/strongholds *as places*.
- **Terrain** — tilesets in 5 colourways, decorations incl. **clouds** — an
  outdoor backdrop is now buildable for the opening screen.
- **UI** — banners, big/small bars, 3 button families, 4 cursors, **14 avatar
  sheets**, icons, papers. Every piece of the new opening screen can be pack art.
- **Super Pixel Effects** — 5923 PNGs across every effect family; we use four.
- **Medieval Village MegaKit** — **it is a 3D kit** (OBJ/FBX/glTF + PBR
  textures). It cannot be used in a 2D pixel game at all; this closes the
  "why is the CC0 pack unused" question for good.
- **No pack ships audio** (checked: zero .wav/.ogg/.mp3). Music and footsteps
  must stay **procedural** — which is what `scripts/audio_bank.gd` already is.
- Still unusable, still licence-blocked: `Thug`, `Survivor W Bike`,
  `Demon_sword`, `2D HD Character Knight` (no licence file), `Modern Interiors`
  (non-commercial only).

### 10.3 The plan (phases; each one ends green)

- **A — story & opening.** Story bible (§10.1); rewrite the four verses,
  verses→hymn; herald, kill, death and naming lines; the sworn's barks (the
  motive); the naming = hue-you-wear mechanic; and a **real opening screen**
  built from Tiny Swords buildings/terrain/clouds/UI, with the rules taught as
  live hue swatches. This is the visible, graded work.
- **B — the sworn get smart.** Delete the vision cones and every "lose the
  player" state; permanent aggro; LOS through walls; the shout that wakes
  nearby sworn; roles (archers keep range and only shoot with LOS, monks hide
  behind the line and heal, lancers hold the line); spacing and flanking.
- **C — four bosses.** Per-hall wardens with the abilities above, incl. the
  twin **blend** and the thorn **ward**; boss intro beats, health bars for
  wardens, reward beats.
- **D — weapons & magic.** Quarter pickups → heavy strike, bow, ward; HUD row of
  the quarters taken; the Champion's office.
- **E — audio.** Footsteps per surface/unit, weapon-specific impacts, deaths,
  the ward hum, shard pickups, and an adaptive music bed per hall (drone +
  drums, intensity from crowd excitement).
- **F — packaging.** Docs, captures, export, video.**

### 10.4 Next move

Start at **Phase A**: the story strings + the opening screen, then Phase B's
aggro rewrite (they are the two the user asked for most directly). Re-run
`tests/test_runner.tscn` (303/0 baseline) and the capture tools after each.

---

## 11. Session: the gate opens, and the melee gets a defence

> Supersedes §10.4's "next move". Phases A and B are **done**: §11.1 is the
> opening (the user's flagship ask), §11.2–11.4 the melee work it dragged in
> behind it. Tests went **303 → 344 passed, 0 failed**.

### 11.1 The opening scene — `ui/opening.gd` (new, ~1200 lines)

The game **no longer starts on a menu**. It starts on the story: a dark dawn at
the gate of Hall I, a dying knight in the sand, and a conversation that hands the
player their identity, their task and their mechanic before a single enemy moves.

- **One node, no children, no art dependency for the stage.** Everything — the
  sky gradient, the sun, the wall, the gate, the road, the camp, the statues, the
  two figures, the sword, the FX and the cards — is drawn in `_draw()` in "stage"
  coordinates (a ~2400×1500 painting the camera moves over). Draw order and
  framing are therefore fully controllable, and there is nothing to break in the
  scene tree.
- **The script is data.** `SCRIPT: Array` holds `{"nar": …}` narration,
  `{"who": …, "text": …}` dialogue, and `{"beat": …}` stage directions (`gift`,
  `walk`, `take`, `gate`, `title`, `done`). Beats are timed, or `hold: true` to
  wait for SPACE. Adding a line is adding a dictionary.
- **Five camera shots** (`WIDE`, `CLOSE`, `GIFT`, `SWORD`, `GATE`), declared per
  entry and eased between; the shot in force is the *last* one declared above the
  entry, so a beat always owns the framing it happens in.
- **Both speakers are pack portraits from the grey row** (24 = the Unsworn,
  25 = the one before; 7 = the Sun's Warden). The two hueless people in the world
  are shown as hueless.
- **Typewriter dialogue, SPACE to advance/skip the line, ESC to skip the scene**,
  `finished` signal → `game.start_run()`. The HUD is hidden and input is ignored
  while `State.OPENING` is active.
- **The gift is one travelling burst** (knight → player), then a sparkle that
  lands on the player: `_spawn_fx` takes an optional `to` and `_draw_fx` lerps.
- **The last card teaches the controls** as a key-box legend — WASD move,
  LMB strike ×3, RMB guard/parry, SPACE roll — which forced §11.2 to exist.

Verified with `tools/capture_opening.gd`, which is *flow-faithful*: it finds each
beat by searching the SCRIPT, uses the shot in force at that entry, and freezes
the beat (`_beat_hold = true`) so nothing auto-advances during the settle frames.
Ten frames in `build/capture/opening_XX_*.png`, all inspected.

### 11.2 Guard and parry — the legend is not allowed to lie

- **Hold RMB (or SHIFT)** → the blade comes across the body: a block. Damage is
  cut by `block_absorb` (65%), the player is **not** stunned and barely shoved,
  and the block is a **wall in front of the player**, not a shell around them
  (`guard_half_deg`): a blow from behind lands whole. Blocking never grants
  i-frames — the cost of a late guard is blood.
- **The first 0.22 s of the raise PARRYS.** Only the *raise* opens the window, so
  a permanently held guard is safe but slow; timing it is the skill. A parried
  blow does nothing at all, and `room.gd` hands out the reward, because only the
  room knows who swung: the attacker is staggered for **1.15 s** (0.7× for the
  boss), barks a new `"parried"` line (*"It TURNED my blow!"*), and game.gd adds
  a hard hit-stop, a white flash, a bright clang and `parry_bonus` (120).
- **A blow ≥ `guard_break_damage` (46)** breaks the guard open and lands whole,
  with a longer stun: a big knight coming through a small defence.
- A swing or a roll drops the guard, so the player cannot turtle and cut at the
  same time. The ward arc, the bright window edge and the parry ring are all
  drawn in `player.gd` — the arc that is *drawn* is the arc that *blocks*.
- **Footsteps**: distance-based (`step_length`), so the sound stays locked to the
  legs however the walk speed is tuned; pitch and volume jittered in game.gd.

### 11.3 The marked overhead — Souls/Sekiro's perilous attack

Every `perilous_every` (4) swings, a sworn knight commits to an **overhead**: a
longer windup (×1.7), longer reach (×1.15), more damage (×2.2), and — the point —
**it cannot be blocked at all** (`take_damage(..., unblockable)`). The player is
told in the genre's own language: a **red** wedge on the ground at the swing's
real reach, and the pack's own triangular hazard sign (`mark_warning.png`, 60
frames) held over the knight's head, tinted red and bobbing. The Champion's
charging dash is marked the same way, so "get out of the lane" and "do not block
this" are one visual rule. **Parrying it still works** — that is the reward for
reading the beat instead of running from it — and the room teaches the whole rule
*once* per room with a hint line the first time any sworn commits to one.

### 11.4 Bugs found by measuring, not by looking

- **`Transform2D.scaled()` pre-multiplies: it scales the ORIGIN too.** Using it to
  place the camera and the actors dragged the entire stage towards the top-left by
  the zoom factor — invisible at zoom 0.88, glaring in a close-up. Every planted
  actor and the camera are now built from explicit basis vectors
  (`_actor_xform(base, rot, sx, sy)`); debug markers in the capture prove the
  knight and the sword land within a pixel of the arithmetic.
- **The gate beat did not own its shot**, so the gate opened in the previous
  beat's framing. Beats now declare their shot; see 11.1.
- **`_draw_perilous_mark` played the sign strip to its last frame**, which is the
  animation's *collapse* — the warning vanished exactly when it mattered. It now
  pops in over the first fifth of the windup and holds inside the visible stretch.
- **Capture tools booted straight into the fight**: they now dismiss the opening
  the way a player does (`opening.skip()`), and the melee capture holds **real
  input** (`Input.action_press("guard")`) because a programmatically raised guard
  is dropped by the player's own `_physics_process` before the frame is drawn.

### 11.5 New dev tooling

| Tool | What it is for |
|---|---|
| `tools/capture_opening.gd` | Ten staged frames of the opening, flow-faithful (search-based beats, shot in force, frozen beats). |
| `tools/capture_melee.gd` | One frame each of the three new reads: the ward, the parry ring, the marked overhead. |
| `tools/bake_itch_packs.sh` | Extended (sections 9–10) with the props, FX, UI and marks used above; every file carries its provenance comment. |

Removed: `tools/dbg_opening.gd` (superseded by `capture_opening.gd`) and the
one-off `tools/add_guard_action.gd` (the `guard` action now lives in
`project.godot`: right mouse button + SHIFT).

### 11.6 Verification

```bash
flatpak run org.godotengine.Godot --headless --path . res://tests/test_runner.tscn
#  ->  RESULT: 344 passed, 0 failed   (was 303 before this session)

flatpak run org.godotengine.Godot --path . --script res://tools/capture_opening.gd
flatpak run org.godotengine.Godot --path . --script res://tools/capture_melee.gd
```

New checks this session include: the opening exists and its speakers/beats are
really in the SCRIPT; the `guard` action exists on two keys; a front blow inside
the window does not land and announces itself; a late guard still blocks and does
*not* stun; a blow from behind lands whole; a heavy blow breaks the guard; the
room blames the knight who swung and staggers him; the parry pays its bonus; the
marked overhead winds up longer, reaches further, goes through a held guard and
is still beaten by a parry; walking makes footfalls.

### 11.7 Next move

1. **Boss powers** (the user's "Sekiro/Elden Ring-inspired" ask, only partly
   done: the charge and the marked overhead are in; the Sun's Warden's shield
   stance + slam, the Twins' blend, and the Thorn Warden's ward/heal/thorns are
   still to be hunted down in `guard.gd`).
2. **Smarter unit-role movement**: archers keep their range, monks stand behind
   the line, thralls swarm instead of queueing.
3. `docs/STORY.md` is current as of this session (§4 is the opening, §10 has the
   white-light hope thread). The writing that remains is the **ending beat**:
   the four hues mixing to white, and the Unsworn's one spoken line — the
   verses, hints and hall strings are all done and in `level_data.gd`.
4. Web export re-check (`--export-release "Web"`) and a fresh round of captures.

