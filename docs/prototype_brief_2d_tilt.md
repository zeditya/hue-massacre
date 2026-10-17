# Prototype Brief — Camera Track B: "2D Tilt" (2.5D look, staying in Godot 2D)

> **For the second OpenCode agent.** You work in a dedicated git worktree of this
> repo, on its own branch (confirm with `git branch --show-current` — it should
> **not** be `master`). The main agent works on `master` in the primary checkout.
> **This file is your whole brief.** Read it, then execute it.

## Context

Hue Massacre is a working 2D top-down game (colour-theory stealth action — see
`README.md` and `PROJECT_STRUCTURE.md`). It is being redesigned into a **2.5D
hack & slash with a League-of-Legends-style camera**: the ground reads as a
plane tilted away from the viewer, characters stand upright on it, and the
camera sits higher, looking down at an angle.

Two camera tracks are being prototyped **in parallel, as throwaways**, so the
owner can look at screenshots side by side and pick one:

| Track | Owner | Approach |
|---|---|---|
| A — true 3D billboards | main agent (`master`) | Godot 3D, pitched `Camera3D`, `Sprite3D` upright billboards, real lights |
| **B — 2D tilt (YOU)** | you (this worktree) | stay in Godot 2D; make the world **look** tilted |

Your track wins if it looks close to the LoL-like feel and/or is clearly the
safer path. The owner will also run your scene live to judge the camera feel,
so the placeholder must be walkable with **WASD**.

## The trick you are implementing

Keep the world in the same 1280×720 2D coordinates the game already uses, and
apply the tilt ONLY as a visual transform:

1. Wrap the visual world in a `Node2D` whose `scale = Vector2(1, TILT)` with
   `TILT` around **0.55–0.65** (tune by eye; document what you chose). All
   gameplay math stays in the existing world coordinates.
2. Every character sprite is counter-scaled `scale.y = 1.0 / TILT` so figures
   stand **upright** while the ground is squashed. Anchor the sprite so the
   feet stay at the actor's world position.
3. Enable `y_sort_enabled` on the world wrapper so characters overlap walls
   and each other by depth (something "lower on screen" draws in front).
4. **Wall height illusion.** The real game draws walls as flat rects
   (`scripts/room.gd::_draw`). Do **not** modify it. In your prototype, read
   the wall rects from `LevelData.walls_for(LevelData.ROOMS[0])` and draw your
   own version: squashed footprint + a "front face" extruded **downwards on
   screen** from the footprint's bottom edge (this is the near face the camera
   would see). Because the parent squashes y by `TILT`, a face that should be
   `H` screen pixels tall is drawn `H / TILT` world pixels tall. Give walls a
   lit top edge and a soft shadow so they read as blocks, not paper.
5. **Camera placement hint:** the `Camera2D` must live **outside** the squashed
   node (a sibling), following the player's *transformed* screen position
   (`player.position * Vector2(1, TILT)`), or everything gets double-squashed.
   Lerp it for the soft LoL follow feel; offset it so the player sits
   lower-centre like LoL.
6. Nice-to-haves in order: floor from `TileBank.floor_texture()`; one or two
   paint splats (a circle becomes an ellipse once squashed — check how paint
   reads); a cheap vignette / gradient light. Darkness/HUD are **out of
   scope**.

## Fair-comparison constraints (so the owner can compare A vs B)

- Same room: **ROOM 01** geometry from `scripts/level_data.gd`. Place the
  player plus two guard-shaped figures using `SpriteBank.adventurer()` and
  `SpriteBank.tint_material(colour)` (reuse them — hue-tinted figures).
- Output **1280×720** PNGs.
- Commit **3 screenshots** to `docs/proto/2d_tilt/`:
  1. `overview.png` — player mid-room, several walls visible.
  2. `closeup.png` — player near a wall, showing wall height + y-sort.
  3. `alt_tilt.png` — the best frame again at a second `TILT` value.
- Optional, only if cheap: one 45°-rotated "classic isometric" variant as
  `iso_variant.png`, clearly labelled as a variant. Do not let it eat the core.

## Rules

- **New files only.** Do not edit anything in `scripts/`, `ui/`, `tests/`,
  `scenes/main.tscn`, or existing tools. Work around anything you dislike in
  prototype-local code.
- Repo style is "everything built in code", so a `tools/proto_2d_tilt.gd`
  SceneTree script that constructs the scene is fine; a small
  `scenes/proto_2d_tilt.tscn` is also fine.
- Capture like `tools/capture.gd` does (render frames, save PNG). Raw frames go
  to `build/proto_2d_tilt/` (gitignored); commit ONLY the final shots into
  `docs/proto/2d_tilt/`.
- Write `docs/proto/2d_tilt/README.md`: what you built, the TILT value chosen,
  how to run + capture, and one honest paragraph on how it looks and what is
  ugly.

## Running things (this machine)

```bash
# run the prototype interactively (needs a display)
flatpak run org.godotengine.Godot --path . res://scenes/proto_2d_tilt.tscn

# capture screenshots (needs a display; headless cannot render)
flatpak run org.godotengine.Godot --path . --script res://tools/proto_2d_tilt_capture.gd

# prove you broke nothing — still expect: RESULT: 187 passed, 0 failed
flatpak run org.godotengine.Godot --headless --path . res://tests/test_runner.tscn
```

If a headless run reports `Could not find type ...`, refresh the class cache
once: `flatpak run org.godotengine.Godot --headless --editor --path . --quit`.

## Done = report

Commit on your branch (do not push, do not merge; the main agent integrates).
Report back:

- the file list,
- the exact run + capture commands,
- the screenshot paths,
- your honest verdict: does it look good? what is ugly? chosen `TILT` and why.
