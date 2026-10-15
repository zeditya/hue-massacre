# HUE MASSACRE: Game Spec

**Engine:** Godot 4 (GDScript) | **Genre:** Top-down stealth action | **Platform:** Desktop / Web export

## 1. Pitch
The world is gray because the **Collectors** stole every color. Each guard carries one stolen color. You are a bright **Spark**. Kill a guard and the color splashes back onto the floor, and you can hide inside it. Color is both your weapon and your camouflage.

## 2. Core Loop
1. **Sneak** through a gray room and watch guard vision cones.
2. **Strike** with a silent blade and a short lunge-dash (one button).
3. **Splatter:** the kill paints the floor in the guard's color.
4. **Hide** by standing in paint that matches your color.
5. **Chain** kills of complementary colors for combos. Clear the room, then move on.

## 3. Controls
| Input | Action |
|---|---|
| WASD / Arrows | Move |
| Space (one button) | Lunge-dash with blade. Kills on contact, short cooldown |
| R | Restart room |

## 4. Color Rules (the color theory core)
- **Player color:** starts white and takes the color of the last guard you killed. *(Assumption: change if you want a different system.)*
- **Spotting (simultaneous contrast):** a guard's vision cone fills a detection meter faster the more your color contrasts with the floor under you.
  - Bright player on gray floor = high contrast = spotted fast.
  - Player on matching paint = near-zero contrast = effectively invisible.
  - Contrast is measured by hue distance on the color wheel plus brightness difference.
- **Splatters:** spawn at the kill location in the guard's color, then fade out over about 10 seconds.
- **Complementary pairs:** Red-Green, Blue-Orange, Yellow-Purple.
- **Combo:** two kills with complementary colors within 3 seconds trigger a screen flash and a score multiplier (x2, rising with repeated combos). The multiplier resets after a combo timer runs out.

## 5. Enemies
| Type | Colors | Behavior |
|---|---|---|
| Primary | Red, Yellow, Blue | Standard patrol with a wide vision cone |
| Secondary | Orange, Green, Purple | Faster patrol, narrower but longer cone |
| Drained | Gray | Patrols and **cleans paint** as it walks. Its kill leaves gray, which gives no cover and no combo |

Guards investigate the last spotted position before returning to patrol. Being fully spotted triggers a chase, and a guard contact hit restarts the room.

## 6. Levels
- **Rooms 1-5:** each introduces one idea.
  1. Move, lunge, and splatter basics (primary guards only)
  2. Hiding in paint
  3. Secondary colors and complementary combos
  4. Drained guards that clean your cover
  5. Mixed patrols, all mechanics together
- **Boss room: the Collector.** Its color rotates continuously around the color wheel. It is vulnerable only while its color is complementary to yours, so you must manage your color and the paint on the floor to line up the hit. *(Proposed rule, tune freely.)*

## 7. Score and Progression
- Base points per kill, times the combo multiplier.
- Bonus for stealth kills (never spotted in a room) and for speed.
- Win by defeating the Collector, and the world's color returns.

## 8. Visuals and Typography
- Gray, desaturated world with saturated paint and glowing player. Color theory is the central aesthetic.
- Color rule for UI: text uses high-contrast, wheel-aware colors (for example, combo text in the complement of the current floor color).
- One bold display font for titles and one clean readable font for HUD text.
- Rhyming story intro text at the start.

## 9. Godot Architecture (suggested)
- `Player.tscn`: CharacterBody2D with dash and color state
- `Guard.tscn`: CharacterBody2D with Area2D vision cone, patrol path, and state machine (patrol, suspicious, chase)
- `Splatter.tscn`: Sprite2D with Tween fade and a color value
- `PaintManager` (autoload): tracks splatters and answers "what color is the floor at position X?"
- `ComboManager` (autoload): last-kill color and timestamp, complement check, multiplier
- `Boss.tscn`, `Room.tscn`, `HUD.tscn`

## 10. Build Order (3-day plan)
1. **Day 1:** player movement, dash-kill, one guard, vision cone, splatter and fade
2. **Day 2:** contrast/hiding logic, combo manager, all guard types, rooms 1-3
3. **Day 3:** rooms 4-5, boss, HUD and typography, story intro, web export, README with AI chat history PDF and video link

## 11. Assignment Checklist
- [ ] Fully functional game (win and lose states, score)
- [ ] Color theory is the core mechanic (complements, contrast, hue wheel)
- [ ] Public GitHub repo with documented source
- [ ] README: AI chat history PDF (selectable text) and a 20+ minute YouTube video
- [ ] Understand and customize all AI-generated code (this feeds the AI-interaction multiplier)
