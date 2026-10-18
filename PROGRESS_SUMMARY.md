# Hue Massacre — Rebuild Progress Log

> **Resuming the project? Read `PROGRESS_REPORT.md` first** — it is the full brief
> (assignment, history, codebase map, conventions, gotchas, next steps). This file
> is the detailed session-by-session log.
>
> **The most recent work is §9** (arena look-and-feel overhaul + the ten-pack
> integration). §7 and §8 describe what was open *before* that; §9.11 is the
> current to-do list. When you change something here, add it to §9 rather than
> rewriting history — this file is the handoff.

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

### 9.12 Still open (next agent)

1. **Push.** Everything is committed locally; `origin/master` is still at the
   pre-overhaul revision, so Pages is serving the old build until this is pushed.
   Preserve the `v1-stealth` → `ddb3a88` tag/squash while doing it.
2. **Serve and eyeball the web build** (`build/web/`, freshly exported, 44.8 MB
   pck) over HTTP — this is the first capture-verified build, and the first one
   where the crowd is people rather than silhouettes.
3. **`docs/AI_CHAT_HISTORY.pdf`** is still a dead link in the README, and the
   README still carries `[[PASTE YOUTUBE LINK HERE]]`.
4. **`PROJECT_STRUCTURE.md` and `SUBMISSION_CHECKLIST.md` still describe v1**
   (187 tests, stealth wording, story cards) — rewrite or delete before the
   grader sees them.
5. The "a by-eye pass is owed" warning in the older §7 is now partly satisfied:
   the arena and fight captures have been inspected, but nobody has yet played a
   full room start-to-finish at zoom 2 with darkness on.

### 9.13 Housekeeping note for whoever picks this up next

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
