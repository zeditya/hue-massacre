# Asset attribution and licences

All art in `assets/` is third-party. Full licence texts are kept in
`assets/LICENSES/`. If you replace an asset, update this file **and** keep the
licence text alongside it.

---

## Characters — `assets/characters/adventurer/`

**"FREE Adventurer 2D Pixel Art"** — the hero. (The guards used to be Adventurer
sprites too; they are now Tiny Swords sheets — see the Units section below. The
Adventurer is the **player's** sheet only, because four-directional art keeps the
aim readable, and `tests/test_runner.gd` pins it.)

- `idle_<dir>.png`, `run_<dir>.png`, `attack1_<dir>.png` for `down/up/left/right`.
- Each sheet is **768×80**: **8 frames of 96×80**, top-down 4-direction artwork.

Licence (`assets/LICENSES/adventurer.txt`):

> - You can use this asset in any game project, personal or commercial.
> - DO NOT resell or redistribute AS A GAME ASSET, it has to be part of a project.
> - Credit is not required but it is appreciated.
> - Modify to suit your needs.
> - You are NOT allowed to turn any of my assets to an NFT.

**Credit is appreciated** — the author should be named here and in the README.
The original pack does not state a preferred name string in the licence file;
confirm the author name on the itch.io page and add it.

---

## Tileset — `assets/tiles/`

**"Modern Interiors" (LimeZu) — FREE version, v2.2.**

- `room_builder_16x16.png` — walls, wallpapers, floors, doors (272×368).
- `interiors_16x16.png` — furniture and props (256×1424).

Licence (`assets/LICENSES/modern_interiors.txt`):

> **CAN:** use in **non-commercial** projects · edit the sprites for non-commercial use
> **CAN'T:** use in **commercial** projects · edit and resell the sprites

> ⚠️ **NON-COMMERCIAL ONLY.** This art may not be used in a monetised build.
> The university assignment is non-commercial, so it is fine for now, but the
> game must not be sold or monetised while this tileset is in it. Credit **LimeZu**.

---

## Units — `assets/units/` and `assets/units/crowd/`

Every fighter except the Unsworn, the whole crowd, and the flame sheets come
from **one pack**, plus two statues from another. All of it is baked by
`tools/bake_itch_packs.sh`, which documents the source file and size of every
sheet it produces. Nothing in this repo is an unmodified pack file.

**"Tiny Swords (Free Pack)"** — Pixel Frog. `<https://pixelfrog-assets.itch.io/tiny-swords>`

- `assets/units/knight/` — the *Warrior* at 50% (96 px cells).
- `assets/units/warden/` — the same armour at 62.5% (120 px cells): the pack's
  own trick for making a heavy of one silhouette.
- `assets/units/harrier/` — the *Pawn with Knife* at 50%.
- `assets/units/aspirant/` — the *Pawn with Axe* at 50%.
- `assets/units/champion/` — the *Lancer* at 50% (160 px cells), including the
  Down Defence set used when a strike clangs off his shield.
- `assets/units/crowd/pawns.png` — 20 rows (Red / Blue / Yellow / Purple /
  Black × empty-handed, axe, hammer, meat) × 8 idle frames, 64 px cells.
- `assets/fx/{fire,fire_tall,dust,explosion,splash}.png` — the particle sheets.

Licence (`assets/LICENSES/tiny_swords.txt`):

> Feel free to use this asset pack in both personal and commercial projects,
> modifying the assets as needed. Crediting is not required, but it helps and
> is always welcome. You may not redistribute, resell, or repackage the assets,
> even if the files are modified.

So: commercial use **and** modification are fine, which is what the bake step
does (nearest-neighbour resize + greyscale so `hue_tint.gdshader` can recolour
everything). The raw pack is **not** redistributed and the paid *Enemy Pack* was
never downloaded. Credit is not required; **Pixel Frog** is credited anyway.

**"Tiny RPG Character Asset Pack 01 v2.0"** — Zerie. `<https://zerie.itch.io/tiny-rpg-character-asset-pack>`

- `assets/props/statue_soldier.png`, `assets/props/statue_orc.png` — frame 0 of
  the idle sheets of the free demo's two characters, trimmed, greyscaled and
  blown up 2× so they stand at knight height. They are the arenas' **stone
  champions**: dead houses' best, stood at the gates.

Licence (`assets/LICENSES/zerie_tiny_rpg.txt`):

> You may use these assets in both personal and commercial video game projects.
> You may edit or modify these assets to fit your game projects.
> You may not redistribute, resell, or re-upload these assets, whether modified
> or unmodified. You may not use these assets for AI training or NFT projects.
> Credit is appreciated but not required.

Complied with: the paid 22-character version was not bought, the raw sprites
never leave the project, and nothing here is AI-training material or an NFT.

---

## Effects — `assets/fx/`

**"Super Pixel Effects Gigapack (Free Version) v3.1.0"** — Will Tice / unTied Games.

- `impact.png`, `splatter.png`, `magic.png`, `lightning.png` — greyscaled at
  bake time so they can be tinted to the hue the moment calls for (a knight's
  blood is his own hue; a shatter is the Unsworn's).

Licence (`assets/LICENSES/super_pixel_effects.txt`) requires:

> If you use the contents of the asset pack zip file in a game or application
> product, please give attribution in the credits or wherever appropriate.

**Credit (required):** `Super Pixel Effects Gigapack (Free Version) v3.1.0 —
Will Tice / unTied Games`. Commercial use is permitted; the pack may not be
re-uploaded or repackaged, and it may not be used as AI training material.

---

## Audio — three packs, licence-checked 2026-10-18 (staged in phase E)

Until now the game's sound was **procedural only** (`scripts/audio_bank.gd`).
Three sample packs were downloaded to the repo root on 2026-10-18 and
licence-checked; the selected files will be baked into `assets/audio/` when the
audio workstream lands (`PROGRESS_SUMMARY.md` §12.6). **Nothing has been
extracted or committed yet** — the raw `.zip`s are gitignored and are never
redistributed; only the files the game actually plays will be staged.

### Free Fantasy 200 SFX Pack — TomMusic

Source: <https://tommusic.itch.io/free-fantasy-200-sfx-pack>. 204 SFX as `.ogg`
*and* `.wav`, plus 8 seamless ambience loops (day/night/rain/storm per biome).
Licence record: `assets/LICENSES/tommusic_fantasy_sfx.txt`.

> Royalty-free! You can use this in your projects, commercial or otherwise,
> credit is not mandatory but appreciated. The asset is not to be up for resale
> or redistribution.

**Credit appreciated** (not required) — TomMusic is credited anyway. Planned
use: steel for sword/parry/block, bow, footsteps per surface, spells, gates and
chests, torch, ambience loops.

### Ultimate UI SFX Pack (FREE) — JDSherbert

Source: <https://jdsherbert.itch.io/ultimate-ui-sfx-pack>. Free tier, 56 files.
Licence record: `assets/LICENSES/jdsherbert_ui_sfx.txt`.

> Full credit is always required, as per the asset licence. […] You'd only need
> to put my name somewhere in a txt or a credits roll. […] Just put my name
> somewhere and don't redistribute the files.

**Credit (required):** `JDSherbert`. Planned use: cursor, select, cancel, popup
open/close, error, swipe — the menus, the opening's text advance, banners, HUD.

### Super Dialogue Audio Pack v1 — Dillon Becker

Source: <https://dillonbecker.com>. 1090 non-verbal lines; the licence ships
inside the zip (`Step 1 - License and Contact Info/License.pdf`). Licence
record: `assets/LICENSES/super_dialogue_audio.txt`.

> These files are licensed under Attribution 4.0 International (CC BY 4.0) […]
> Attribution should go to Dillon Becker.

**Attribution required**, and because we will trim/pitch, the credit must note
the material was adapted: `Super Dialogue Audio Pack v1 by Dillon Becker
(dillonbecker.com) — CC BY 4.0, edited for this game.` Planned use: per-hall
voice casts (damage, death, grunt, shout) and the bosses' vocal weight.

### The credits screen (owed — a shipping blocker, not polish)

Two of the three licences require *visible* credit. The game has no credits
screen yet; one is part of phase E (pause menu **and** the ending card). These
names must also stay in this file and in the README's credits.

---

## Packs deliberately NOT used

Recorded so the next person does not read these as oversights.

- `FREE Character 16-bit Thug Outlined` — side-view platformer sprites; they do
  not fit a top-down game, **and** the zip has no licence file.
- `FREE Character HD Survivor W Bike` — same (side-view), same missing licence.
- `Demon_sword` — side-view slash VFX only, same missing licence.
- `2D HD Character Knight` — licence could not be confirmed from the zip, so it
  is not staged into the project at all.

These have no licence file in the zip, so they must **not** be redistributed
until their terms are confirmed.

Licensed but not used, and why:

- **"Medieval Village MegaKit"** (Standard edition, **CC0**) — permission is
  clear, but its art is interior/architecture-first; dropping it into the
  arenas would fight the top-down readability the arena overhaul is built on.
  Kept as an option for future non-arena screens.
- **Tiny Swords' rubber duck** — deliberately left out. A bath toy in a
  medieval tournament breaks the tone the crowd banter depends on.
- **Tiny Swords' tile set, buildings, and the remaining unit colours** — the
  fighters use one faction's greyed sheets and the hue tint does the colouring,
  so the other four colours would be dead weight. The *crowd* does use all five.
- The **Adventurer** stays the player only: four-directional art keeps the aim
  readable, and the test suite pins it.
