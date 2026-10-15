# HUE MASSACRE: Project Structure and Visual Plan

Use this file to track setup progress. Tick the boxes as you go.

## 1. Folder Structure

```
res://
├─ project.godot
├─ README.md
├─ docs/                      # GAME_SPEC.md, GAME_SPEC_v2.md, AI chat history PDF
├─ assets/
│  ├─ sprites/                # player, guards, tiles, props
│  ├─ fonts/
│  ├─ audio/
│  │  ├─ sfx/
│  │  └─ music/
│  └─ particles/              # textures for splatter drops, sparks
├─ shaders/                   # crt.gdshader, splatter.gdshader, flash.gdshader
├─ scenes/
│  ├─ main.tscn               # entry point: loads rooms, holds HUD
│  ├─ actors/
│  │  ├─ player.tscn
│  │  ├─ guard.tscn
│  │  └─ boss.tscn
│  ├─ world/
│  │  ├─ room_base.tscn       # template every room inherits from
│  │  ├─ splatter.tscn
│  │  └─ rooms/
│  │     ├─ room_01.tscn
│  │     ├─ room_02.tscn
│  │     ├─ room_03.tscn
│  │     └─ boss_room.tscn
│  ├─ fx/
│  │  ├─ kill_burst.tscn
│  │  ├─ dash_trail.tscn
│  │  └─ combo_flash.tscn
│  └─ ui/
│     ├─ hud.tscn
│     ├─ main_menu.tscn
│     ├─ story_intro.tscn
│     └─ game_over.tscn
├─ scripts/                   # mirrors scenes/ (actors, world, ui, fx)
│  ├─ autoload/
│  │  ├─ color_rules.gd
│  │  ├─ paint_manager.gd
│  │  ├─ combo_manager.gd
│  │  └─ events.gd            # signal bus
│  ├─ actors/
│  ├─ world/
│  └─ ui/
└─ resources/
   ├─ ui_theme.tres           # fonts, colors, button styles in one place
   └─ guard_types/            # red.tres, green.tres, ... (optional)
```

Putting each `.gd` next to its `.tscn` is also a normal Godot habit. Pick one layout and stay consistent.

## 2. Why Each Folder Exists

| Folder | Purpose |
|---|---|
| `assets/` | Raw files only (art, audio, fonts). No logic, so art can be swapped without touching code. |
| `shaders/` | Shared by many scenes; the screen effect is used by the whole game. |
| `scenes/actors/` | Things that move and think: player, guards, boss. |
| `scenes/world/` | The level itself and the paint: rooms, splatters. |
| `scenes/fx/` | Short-lived effects that spawn and destroy themselves. |
| `scenes/ui/` | Menus, HUD, story intro, game over. |
| `scripts/autoload/` | Global singletons: `ColorRules`, `PaintManager`, `ComboManager`, `Events`. |
| `resources/` | Data and styling, such as the UI theme. Change the look in one file. |
| `docs/` | Specs and AI chat history PDF, kept with the repo for submission. |

**Why the `Events` signal bus:** a guard can emit `guard_killed(color)` without knowing the combo system or HUD exist. This keeps the code decoupled and easier to debug.

## 3. Reusable Scenes

| Scene | Reuse | How |
|---|---|---|
| `guard.tscn` | 10+ times | Exported `color`, `cone_angle`, `patrol_speed`, and a patrol path. All six colored guards are this one scene with different settings. |
| `splatter.tscn` | Spawned at runtime on every kill | Area2D with a color and radius. It fades itself, then calls `queue_free()`. |
| `room_base.tscn` | Template for every room | Floor, walls, a player spawn marker, and an exit. Each `room_0X.tscn` is an inherited scene that adds its own guards and layout. |
| `player.tscn` | Placed in every room | Spawned at the room's spawn marker. |
| `kill_burst.tscn`, `combo_flash.tscn` | Spawned many times | Self-destroying one-shot effects. |

One-offs: `boss.tscn`, and `hud.tscn` (lives once in `main.tscn`).

## 4. Hotline Miami Visual Checklist (in priority order)

Hotline Miami's look comes from saturated neon colors on dark backgrounds, strong screen effects, and extreme feedback on every action. Your gray-world-with-paint idea already provides the contrast.

- [ ] **1. Pixel-crisp setup:** base resolution about 640x360, Stretch Mode `canvas_items` or `viewport`, Default Texture Filter `Nearest`.
- [ ] **2. Screen shake:** camera offset that decays quickly. Dash, kill, and combo each get their own strength.
- [ ] **3. Hit stop:** freeze about 0.05s on kill by briefly lowering `Engine.time_scale`.
- [ ] **4. Splatter variety:** 5-8 droplet sprites per kill with random size, rotation, and scatter, plus one big central blob and a faint glow.
- [ ] **5. Full-screen post effect:** one shader on a `ColorRect` with slight chromatic aberration, scanlines, and a vignette (uses `hint_screen_texture` in Godot 4).
- [ ] **6. Glow:** `WorldEnvironment` with glow enabled and HDR 2D on. Verify it works on your renderer. The web export uses the Compatibility renderer, where glow support is limited, so test early.
- [ ] **7. Color-cycling accents:** pulse title and combo text through neon hues; tint each guard's vision cone with that guard's color.
- [ ] **8. Dash afterimage:** 2-3 fading copies of the player sprite during the lunge.
- [ ] **9. Music and sound:** synthwave or dark electronic loop and punchy kill sounds. Check each free asset's license and credit it in the README.
- [ ] **Bonus:** a global saturation value that rises as you kill guards, so the gray world slowly fills with color (one shader uniform driven by `Events`).

**Art shortcut:** build everything first with simple neon geometric shapes (Polygon2D or ColorRect) so you do not need much hand-drawn art in 3 days. Add the effects above once the core loop works, in the order listed.

## 5. Setup Tracker

- [ ] Create Godot 4 project and the folders above
- [ ] Set resolution, stretch mode, and texture filter
- [ ] Register autoloads: `Events`, `ColorRules`, `PaintManager`, `ComboManager`
- [ ] Build `player.tscn`, `guard.tscn`, `splatter.tscn`
- [ ] Build `room_base.tscn` and inherit `room_01.tscn`
- [ ] Add UI theme and pick fonts
- [ ] Set up Git and a public GitHub repo on Day 1
- [ ] Save the AI chat history as you go (selectable text, no screenshots)
