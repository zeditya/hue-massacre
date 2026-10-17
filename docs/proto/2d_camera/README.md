# Camera comparison — screenshots (built by `proto/2d/`)

Four renders of the **same room** (ROOM 01's real layout, the real floor
texture, real wall colours, real character sprites, real paint circles). The
dressing here is v1's — this comparison is about **camera geometry only**; the
rebuild restyles everything anyway (Arena of the Wheel + Hades palette).

| shot | mode | what to look at |
|---|---|---|
| `00_topdown.png` | today's look | full room on one screen; characters read small |
| `01_zoom.png` | zoom-follow ×1.5 | characters read big; the room scrolls past |
| `02_tilt.png` | tilt ×0.62 + zoom | the ground reads as a **tilted plane** (the LoL trick); walls grow a fake height; paint squashes into ellipses |
| `03_tilt_closeup.png` | tilt, ×2 zoom | the trade-off, on purpose: the **green knight is fully hidden** behind the pillar. Y-sort is working "correctly" — and it shows that tall walls can swallow characters |

## Try it yourself

```bash
flatpak run org.godotengine.Godot --path . res://proto/2d/proto_camera.tscn
```

- **WASD** walks the white knight (the camera follows in zoom/tilt modes)
- **T** cycles the mode: top-down → zoom → tilt
- **mouse wheel** zooms

## Known trade-off (for the decision)

In **tilt** mode, a character standing directly behind a tall pillar is
occluded. If tilt is chosen, the fixes are: lower wall faces, a fade/outline
for walls between camera and player (LoL-style), or accepting it as part of
the look. **Flat** mode has zero occlusion risk but no sense of depth.

## Files

- `proto/2d/proto_camera.gd` — builds the scene, three modes, live controls.
- `proto/2d/proto_camera.tscn` — the scene to run.
- `proto/2d/capture.gd` — screenshot tool (writes raw frames to
  `build/proto_camera/`, gitignored).
