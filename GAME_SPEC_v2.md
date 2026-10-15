# HUE MASSACRE: Game Spec v2 (solo build, 3 days)

**Engine:** Godot 4 (GDScript) | **Genre:** Top-down stealth action | **Build:** Desktop first, web export only if time allows
**Changes from v1:** scope cut to 3 rooms + boss, exact numbers for contrast and combos, a boss rule that is actually winnable, and a one-hit-kill combat model.

## 1. Pitch
The world is gray because the **Collectors** stole every color. Each guard carries one stolen color. You are a bright **Spark**. Kills splash color back onto the floor, and standing in matching paint hides you. Color is both your weapon and your camouflage.

## 2. Core Loop
Sneak past vision cones, then lunge-kill a guard. The kill leaves a splatter in the guard's color. Hide in it, chain complementary kills for combos, clear the room, and move on.

## 3. Controls and Combat Model (Hotline Miami style)
| Input | Action |
|---|---|
| WASD / Arrows | Move (200 px/s) |
| Space | Lunge-dash with blade: 120 px in 0.15s, 0.6s cooldown. Kills any guard it touches |
| R | Restart room instantly |

- **Everything dies in one hit, including you.** No health system.
- A guard that touches you restarts the room. The dash can still kill a chasing guard, so being spotted is risky, not automatic death.

## 4. Color Rules (exact values)
- **Player color:** starts white. After each kill it becomes that guard's color (Drained kills do not change it).
- **Splatter:** an `Area2D` with a fixed radius of 48 px. It stays at full opacity for 6s, then fades to nothing over 4s (about 10s total). Overlapping splatters do not mix: the newest one wins.
- **Floor color under the player:** `lerp(gray, splatter_color, splatter_alpha)`, with gray as `Color(0.5, 0.5, 0.5)`.
- **Contrast (0 to 1):** `Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b)) / 1.732`, where a is the player color and b is the floor color. Put this in one function, `ColorRules.contrast(a, b)`.
- **Detection:** a guard's meter (0 to 1) fills at `contrast * 3` per second while the player is inside the cone with clear line of sight (RayCast2D). If contrast is below **0.2**, the guard sees nothing. Otherwise the meter drains at 0.5/s. A full meter starts a chase.
- **Complementary pairs (lookup table, not computed):** Red-Green, Blue-Orange, Yellow-Purple.

## 5. Combo and Score
- A kill that is the complement of the previous kill, within 3 seconds, triggers a **combo**: screen flash and multiplier x2, then x3, then x4 (cap) for consecutive combos.
- A non-complementary kill or a 3s gap resets the multiplier to x1. **Drained kills are neutral:** they neither count nor reset.
- Score: primary kill 100, secondary kill 150, Drained kill 50, all times the multiplier. Stealth bonus of 500 for clearing a room unspotted.
- Place guards in complementary pairs close together so combos are reachable.

## 6. Enemies
| Type | Colors | Behavior |
|---|---|---|
| Primary | Red, Yellow, Blue | Patrol 80 px/s, wide cone (90°) |
| Secondary | Orange, Green, Purple | Patrol 100 px/s, narrow, long cone (50°) |
| Drained (stretch goal) | Gray | Erases splatters it walks over. No paint, no combo |

All guards share one `Guard.tscn` with exported `color` and `cone_angle` variables. States: patrol, suspicious (investigate last seen spot), chase (160 px/s).

## 7. Levels (3 rooms + boss)
1. **Room 1:** movement, dash, splatter, hiding. 3 primary guards.
2. **Room 2:** secondary guards and complementary pairs, so combos are taught.
3. **Room 3:** mixed patrols, all mechanics. Add Drained guards only if time allows.
4. **Boss: the Collector.** 3 hits to defeat. Its color rotates 60°/s around the wheel (a full cycle in 6s).
   - It is vulnerable only if you hit it with the dash while **standing in paint complementary to its current color**.
   - It summons a primary or secondary guard every ~8s. Killing them makes the paint you need.
   - One hit kills you, and it chases at a slow 90 px/s.

Rooms 4 and 5 are stretch goals: reuse the same scenes with new layouts.

## 8. Visuals and Typography
- Desaturated gray world, saturated paint, glowing player. Color theory is the central aesthetic.
- **Pick fonts on Day 1** (typography is 15 marks): one bold display font for titles and the story intro, one readable font for HUD. HUD combo text uses the complement of the current floor color.
- Rhyming story intro at the start.

## 9. Godot Architecture
- `Player.tscn`: CharacterBody2D, dash, color state
- `Guard.tscn`: CharacterBody2D, vision cone (Polygon2D + RayCast2D), state machine
- `Splatter.tscn`: Area2D + Sprite2D, Tween fade
- `PaintManager` (autoload): returns the floor color at a position from overlapping splatters
- `ColorRules` (autoload): contrast function, complement table
- `ComboManager` (autoload): last kill color/time, multiplier, score
- `Boss.tscn`, `Room.tscn`, `HUD.tscn`

## 10. Build Order
- **Day 1 (vertical slice):** player move + dash, one guard, cone detection, splatter + fade, `ColorRules`, `PaintManager`. Export a desktop build at the end of the day to confirm it works.
- **Day 2:** `ComboManager`, secondary guards, rooms 1-3, restart and win/lose flow.
- **Day 3:** boss, HUD and fonts, story intro, final export, then README, AI chat history PDF, and video.
- Reserve time on Day 3 for the **20+ minute video**. It takes real time to record.

## 11. Assignment Checklist
- [ ] Fully functional game: win and lose states, score
- [ ] Public GitHub repo with documented source
- [ ] README with AI chat history PDF (selectable text, no screenshots) and a 20+ minute YouTube link
- [ ] You can explain and have modified all AI-generated code (this sets the Part 2 multiplier)
- [ ] Submit the repo link as a .txt file on the LMS
