#!/usr/bin/env python3
"""Throwaway: draw a source-pixel coordinate grid over each reference image
so the arena floor regions can be measured by eye."""
import os
from PIL import Image, ImageDraw

SRC = "/home/aditya/hue-massacre/gpt_assist"
OUT = "/home/aditya/hue-massacre/build/art_preview"
os.makedirs(OUT, exist_ok=True)

FILES = {
    "coliseum": "Medieval Coliseum Tournament Arena.png",
    "sunset": "Sunset Ruins of the Lion Arena.png",
    "infernal": "Infernal Pixel-Art Gladiator Arena.png",
    "compendium": "Pixel Arena Concept Compendium.png",
}

for key, name in FILES.items():
    im = Image.open(os.path.join(SRC, name)).convert("RGB")
    w, h = im.size
    d = ImageDraw.Draw(im)
    step = 128
    for x in range(0, w, step):
        d.line([(x, 0), (x, h)], fill=(0, 255, 255), width=2)
        d.text((x + 4, 4), str(x), fill=(0, 255, 255))
        d.text((x + 4, h - 20), str(x), fill=(0, 255, 255))
    for y in range(0, h, step):
        d.line([(0, y), (w, y)], fill=(255, 0, 255), width=2)
        d.text((4, y + 4), str(y), fill=(255, 0, 255))
        d.text((w - 60, y + 4), str(y), fill=(255, 0, 255))
    im = im.resize((1152, 768), Image.LANCZOS)
    im.save(os.path.join(OUT, f"grid_{key}.png"))
    print("wrote", key, w, h)
