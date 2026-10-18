#!/usr/bin/env python3
"""Build the arena backdrops from the gpt_assist reference images.

Each source image is a 1536x1024 2.5D arena painting. The flat arena floor in
the middle of it is mapped onto the game's walking floor, the paintings' own
edge architecture (fences, stairs, gates, the crowd's front rows) is kept in
FULL COLOUR around the rim of the arena, and the fighting floor itself is
desaturated so it still reads "no hue" for the hiding rules.

Mapping (world units, 1280x720):
    the floor rect of the painting -> world (56,56)-(1224,664)
    the 130px ring of painting around it -> the arena rim, inside the walls
    -> everything the player fights on is painted art: sand, cracks, the
       central sigil, scattered debris.

Rules baked in:
    * the floor's saturation is clamped to 0.17 (< ColorTheory.GREY_SATURATION
      0.18) over the walkable floor only, via a soft mask,
    * the rim keeps full saturation, contrast is lifted slightly overall,
    * ARENA 03 is the same coliseum pushed to night (the run's arc:
      day -> dusk -> night -> inferno).

Outputs 1.5x the world size so the 1.5x camera samples at 1:1.

Run:  python3 tools/build_backdrops.py
"""
import json
import os
from PIL import Image, ImageDraw, ImageFilter

SRC = "/home/aditya/hue-massacre/gpt_assist"
OUT = "/home/aditya/hue-massacre/assets/arenas"
PREVIEW = "/home/aditya/hue-massacre/build/art_preview"

# Measured floor rects, in source pixels (x0, y0, x1, y1).
FLOORS = {
    "coliseum": (285, 234, 1290, 646),
    "sunset": (256, 344, 1268, 706),
    "infernal": (308, 362, 1236, 692),
}
SOURCES = {
    "coliseum": "Medieval Coliseum Tournament Arena.png",
    "sunset": "Sunset Ruins of the Lion Arena.png",
    "infernal": "Infernal Pixel-Art Gladiator Arena.png",
}

WORLD_W, WORLD_H = 1280.0, 720.0
ZOOM = 1.5             # the game camera zoom: render at 1.5x the world size
FLOOR_W0, FLOOR_Y0 = 56.0, 56.0        # where the painting's floor lands
FLOOR_W1, FLOOR_Y1 = 1224.0, 664.0
MARGIN_SRC = 130       # source px of rim architecture kept around the floor
SAT_CAP = 0.17         # floor saturation ceiling (must stay < 0.18)
CAP_SOFT = 30          # texture px of falloff on the saturation mask


def cap_saturation(im: Image.Image, cap: float = SAT_CAP) -> Image.Image:
    hsv = im.convert("HSV")
    h, s, v = hsv.split()
    ceil = int(cap * 255.0)
    s = s.point(lambda x: x if x <= ceil else ceil)
    return Image.merge("HSV", (h, s, v)).convert("RGB")


def boost_vivid(im: Image.Image, sat: float = 1.07, con: float = 1.05) -> Image.Image:
    hsv = im.convert("HSV")
    h, s, v = hsv.split()
    s = s.point(lambda x: min(255, int(x * sat)))
    v = v.point(lambda x: max(0, min(255, int((x - 128) * con + 128))))
    return Image.merge("HSV", (h, s, v)).convert("RGB")


def grade_night(im: Image.Image) -> Image.Image:
    """Day coliseum -> a cold, moonlit night for ARENA 03."""
    hsv = im.convert("HSV")
    h, s, v = hsv.split()
    s = s.point(lambda x: int(x * 0.62))
    v = v.point(lambda x: int(min(255, x * 0.82)))
    im = Image.merge("HSV", (h, s, v)).convert("RGB")
    r, g, b = im.split()
    r = r.point(lambda x: int(x * 0.72))
    g = g.point(lambda x: int(x * 0.82))
    b = b.point(lambda x: min(255, int(x * 1.05)))
    return Image.merge("RGB", (r, g, b))


def build(key: str, floor: tuple, grade=None):
    src = Image.open(os.path.join(SRC, SOURCES[key])).convert("RGB")
    fx0, fy0, fx1, fy1 = floor
    crop = src.crop((fx0 - MARGIN_SRC, fy0 - MARGIN_SRC, fx1 + MARGIN_SRC, fy1 + MARGIN_SRC))

    if grade is not None:
        crop = grade(crop)

    # world scale that maps the FLOOR rect onto (56,56)-(1224,664)
    sx = (FLOOR_W1 - FLOOR_W0) / float(fx1 - fx0)
    sy = (FLOOR_Y1 - FLOOR_Y0) / float(fy1 - fy0)
    world_w = crop.width * sx
    world_h = crop.height * sy
    tex_w = int(round(world_w * ZOOM))
    tex_h = int(round(world_h * ZOOM))

    im = crop.resize((tex_w, tex_h), Image.LANCZOS).convert("RGB")
    im = boost_vivid(im)

    rect_x = (WORLD_W - world_w) * 0.5
    rect_y = (WORLD_H - world_h) * 0.5

    # --- saturation mask: 255 on the walkable floor, 0 over the rim -------
    mask = Image.new("L", (tex_w, tex_h), 0)
    md = ImageDraw.Draw(mask)
    x0 = (FLOOR_W0 - rect_x) * ZOOM
    y0 = (FLOOR_Y0 - rect_y) * ZOOM
    x1 = (FLOOR_W1 - rect_x) * ZOOM
    y1 = (FLOOR_Y1 - rect_y) * ZOOM
    md.rectangle([x0 - CAP_SOFT, y0 - CAP_SOFT, x1 + CAP_SOFT, y1 + CAP_SOFT], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(CAP_SOFT * 0.6))

    capped = cap_saturation(im)
    im = Image.composite(capped, im, mask)

    rect = {
        "x": round(rect_x, 1), "y": round(rect_y, 1),
        "w": round(world_w, 1), "h": round(world_h, 1),
        "tex_w": tex_w, "tex_h": tex_h,
    }
    return im, rect, (rect_x, rect_y, world_w, world_h)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    recipes = {
        "arena_01": ("coliseum", None),
        "arena_02": ("sunset", None),
        "arena_03": ("coliseum", grade_night),
        "arena_04": ("infernal", None),
    }
    meta = {}
    for name, (key, grade) in recipes.items():
        im, rect, world = build(key, FLOORS[key], grade)
        # WebP for the game (5x smaller than PNG, keeps the painted detail),
        # PNG preview for eyeballing in build/ (gitignored).
        path = os.path.join(OUT, name + ".webp")
        im.save(path, quality=92, method=6)
        im.save(os.path.join(PREVIEW, name + ".png"), optimize=True)
        meta[name] = rect
        size_mb = os.path.getsize(path) / 1e6
        print(f"{name}: {im.size[0]}x{im.size[1]}  rect={rect}  {size_mb:.2f} MB")
        # previews: whole thing + the top-left corner at gameplay scale
        thumb = im.resize((960, int(960 * im.size[1] / im.size[0])), Image.LANCZOS)
        thumb.save(os.path.join(PREVIEW, "backdrop_%s.png" % name))
        rx, ry, rw, rh = world
        tl = im.crop((
            int(max(0.0, -rx * ZOOM)), int(max(0.0, -ry * ZOOM)),
            int(max(0.0, -rx * ZOOM) + 960), int(max(0.0, -ry * ZOOM) + 540),
        ))
        tl.save(os.path.join(PREVIEW, "corner_%s.png" % name))
    with open(os.path.join(PREVIEW, "backdrop_rects.json"), "w") as f:
        json.dump(meta, f, indent=2)
    print("rects ->", os.path.join(PREVIEW, "backdrop_rects.json"))


if __name__ == "__main__":
    main()
