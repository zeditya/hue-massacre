#!/usr/bin/env bash
#
# BAKE ITCH PACKS - turn the third-party art packs into the exact files the
# game loads, at the exact sizes the game's scale needs.
#
# WHY THIS SCRIPT EXISTS
#   The packs ship at their own scale (Tiny Swords units live in 192x192 cells,
#   the pawns are 192px tall, the effects are 48-192px per frame). The game runs
#   a 1px = 1world-px pixel grid with the camera at zoom 2, so every sheet has to
#   arrive at ONE agreed size or the art fights itself on screen. Baking here
#   keeps that decision in one readable place instead of scattered @export
#   scales, and means the shipped game only carries the cells it uses.
#
# SOURCES (the .zip files the project owner dropped in the repo root; unzip to
# $SRC first, e.g. `unzip -qo "Tiny Swords (Free Pack).zip" -d "$SRC"`).
#
#   * Tiny Swords (Free Pack)            - Pixel Frog     (CC-free, no resale)
#   * Tiny RPG Character Asset Pack 01   - Zerie          (CC-free, no resale)
#   * Super Pixel Effects Gigapack       - unTied Games   (credit required)
#
# Run from the repo root:  bash tools/bake_itch_packs.sh
#
set -euo pipefail

SRC="${SRC:-/tmp/opencode/packs}"
OUT="assets"

TS="$SRC/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)"
TR="$SRC/Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc/Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc"
SPE="$SRC/Super Pixel Effects Gigapack (Free Version) v3.1.0/Super Pixel Effects Gigapack (Free Version)"

command -v magick >/dev/null || { echo "ImageMagick 7 (magick) is required"; exit 1; }
[ -d "$TS" ] || { echo "missing Tiny Swords under $SRC"; exit 1; }

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# bake <src> <dst> <resize> [filter] [extra magick args...]
#   Character sheets are TINTED at runtime (hue_tint.gdshader throws the
#   artwork's colour away and paints the luminance back in the guard's hue), so
#   they are pre-greyed here: it costs nothing visually and makes the tint the
#   only colour in the picture.
bake() {
	local src="$1" dst="$2" size="$3"
	shift 3
	local filter="point"
	if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then filter="$1"; shift; fi
	mkdir -p "$(dirname "$dst")"
	magick "$src" -filter "$filter" -resize "$size" "$@" -depth 8 "$dst"
	echo "  $dst"
}

grey() {
	local src="$1" dst="$2" size="$3"
	shift 3
	local filter="point"
	if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then filter="$1"; shift; fi
	mkdir -p "$(dirname "$dst")"
	magick "$src" -colorspace Gray -filter "$filter" -resize "$size" "$@" -depth 8 "$dst"
	echo "  $dst"
}

# ---------------------------------------------------------------------------
# 1. THE HOUSE KNIGHTS - Tiny Swords "Warrior", half scale
#    192x192 cells -> 96x96, figure ~40x45 world px (the adventurer is 19x34,
#    so a knight reads a head taller than the Unsworn, which is the point).
# ---------------------------------------------------------------------------
echo "knights (Tiny Swords Warrior):"
W="$TS/Units/Blue Units/Warrior"
grey "$W/Warrior_Idle.png"    "$OUT/units/knight/idle.png"    50%
grey "$W/Warrior_Run.png"     "$OUT/units/knight/run.png"     50%
grey "$W/Warrior_Attack1.png" "$OUT/units/knight/attack1.png" 50%
grey "$W/Warrior_Attack2.png" "$OUT/units/knight/attack2.png" 50%
grey "$W/Warrior_Guard.png"   "$OUT/units/knight/guard.png"   50%
# The warden wears the same armour, cut 1.25x as large: the pack's own trick for
# making a "heavy" of the same silhouette (192x192 -> 120x120 cells).
grey "$W/Warrior_Idle.png"    "$OUT/units/warden/idle.png"    62.5%
grey "$W/Warrior_Run.png"     "$OUT/units/warden/run.png"     62.5%
grey "$W/Warrior_Attack1.png" "$OUT/units/warden/attack1.png" 62.5%
grey "$W/Warrior_Attack2.png" "$OUT/units/warden/attack2.png" 62.5%
grey "$W/Warrior_Guard.png"   "$OUT/units/warden/guard.png"   62.5%

# ---------------------------------------------------------------------------
# 2. THE CROWD'S OWN - Tiny Swords "Pawn", knife for the harriers and axe for
#    the Champion's Aspirants. Same half scale as the knights.
# ---------------------------------------------------------------------------
echo "pawn fighters (Tiny Swords Pawn):"
for who in harrier:Knife aspirant:Axe; do
	kind="${who%%:*}" prop="${who##*:}"
	grey "$TS/Units/Blue Units/Pawn/Pawn_Idle $prop.png"     "$OUT/units/$kind/idle.png"    50%
	grey "$TS/Units/Blue Units/Pawn/Pawn_Run $prop.png"      "$OUT/units/$kind/run.png"     50%
	grey "$TS/Units/Blue Units/Pawn/Pawn_Interact $prop.png" "$OUT/units/$kind/attack1.png" 50%
done

# ---------------------------------------------------------------------------
# 3. THE CHAMPION - Tiny Swords "Lancer": the tallest figure in the pack, and
#    the only one with a full set of aim-down-the-camera attack frames plus a
#    DEFENCE set (the wheel turns the blade aside -> the block pose).
#    320x320 cells -> 160x160, figure ~75 world px.
# ---------------------------------------------------------------------------
echo "champion (Tiny Swords Lancer):"
L="$TS/Units/Blue Units/Lancer"
grey "$L/Lancer_Idle.png"          "$OUT/units/champion/idle.png"    50%
grey "$L/Lancer_Run.png"           "$OUT/units/champion/run.png"     50%
grey "$L/Lancer_Down_Attack.png"   "$OUT/units/champion/attack1.png" 50%
grey "$L/Lancer_Down_Defence.png"  "$OUT/units/champion/guard.png"   50%

# ---------------------------------------------------------------------------
# 4. THE STANDING STONES - Zerie's Soldier and Orc as STATUES.
#    Their cells are 100x100 and the figures are tiny (17x21), so a 2x bake
#    lands them at knight scale. Greyed and darkened at runtime: they are
#    stone, not people.
# ---------------------------------------------------------------------------
echo "statues (Zerie Soldier + Orc):"
mkdir -p "$OUT/props"
for who in soldier:Soldier orc:Orc; do
	kind="${who%%:*}" name="${who##*:}"
	# One idle cell only: a statue does not idle. Trimmed to the figure and
	# blown up 2x so it stands at knight scale.
	magick "$TR/Characters(100x100 split)/$name/$name/${name}_Idle.png" \
		-crop 100x100+0+0 +repage -trim +repage \
		-background none -gravity south -extent 64x80 \
		-colorspace Gray -filter point -resize 200% -depth 8 \
		"$OUT/props/statue_$kind.png"
	echo "  $OUT/props/statue_$kind.png"
done

# ---------------------------------------------------------------------------
# 5. THE CROWD - Tiny Swords Pawns, one atlas: a row per (colour, prop), eight
#    idle frames per row, cells at one third (64px, figure ~21 world px - the
#    exact size the hand-drawn crowd used to be).
# ---------------------------------------------------------------------------
echo "crowd atlas (Tiny Swords Pawns):"
crowd_rows=()
for colour in Red Blue Yellow Purple Black; do
	for prop in "" " Axe" " Hammer" " Meat"; do
		crowd_rows+=("$TS/Units/$colour Units/Pawn/Pawn_Idle$prop.png")
	done
done
mkdir -p "$OUT/units/crowd"
tmpdir="$(mktemp -d)"
i=0
for row in "${crowd_rows[@]}"; do
	magick "$row" -filter point -resize 33.333% -depth 8 "$tmpdir/row$i.png"
	touch "$tmpdir/row$i.png"
	i=$((i + 1))
done
magick "$tmpdir"/row*.png -append -depth 8 "$OUT/units/crowd/pawns.png"
echo "  $OUT/units/crowd/pawns.png (20 rows x 8 frames, 64px cells)"
rm -rf "$tmpdir"

# ---------------------------------------------------------------------------
# 6. COMBAT EFFECTS - Super Pixel Effects (credited: unTied Games) plus the
#    Tiny Swords fire/dust/explosion sheets. Everything that has to take a hue
#    is greyed; fire and dust keep their own warm colour.
# ---------------------------------------------------------------------------
echo "effects:"
# Each effect is a folder of frame0000.png..frameNNNN.png: +append lays them out
# as one horizontal strip, which is how the game reads them at runtime.
mkdir -p "$OUT/fx"
magick "$SPE/PNG/Impacts/symmetrical_impact_001/symmetrical_impact_001_small_yellow"/frame*.png \
	+append -colorspace Gray -depth 8 "$OUT/fx/impact.png"
echo "  $OUT/fx/impact.png"
magick "$SPE/PNG/Splatters/burst_splatter_001/burst_splatter_001_large_red"/frame*.png \
	+append -colorspace Gray -depth 8 "$OUT/fx/splatter.png"
echo "  $OUT/fx/splatter.png"
magick "$SPE/PNG/Magic Bursts/round_firework_burst_001/round_firework_burst_001_large_green"/frame*.png \
	+append -filter point -resize 50% -colorspace Gray -depth 8 "$OUT/fx/magic.png"
echo "  $OUT/fx/magic.png"
grey "$TS/Particle FX/Water Splash.png" "$OUT/fx/splash.png" 33.333%
bake "$TS/Particle FX/Dust_01.png"      "$OUT/fx/dust.png"      50%
grey "$TS/Particle FX/Explosion_01.png" "$OUT/fx/explosion.png" 33.333%
bake "$TS/Particle FX/Fire_01.png"      "$OUT/fx/fire.png"      50%
bake "$TS/Particle FX/Fire_03.png"      "$OUT/fx/fire_tall.png" 50%
# The Champion's summons arrive on a bolt: a lightning strike, cut down to a
# 64px cell and greyed so it takes the summoned knight's own hue.
magick "$SPE/PNG/Lightning/lightning_strike_001/lightning_strike_001_large_violet"/frame*.png \
	+append -filter point -resize 50% -colorspace Gray -depth 8 "$OUT/fx/lightning.png"
echo "  $OUT/fx/lightning.png"

# ---------------------------------------------------------------------------
# 7. ARENA DRESSING - rocks, bushes, gold, timber, tools, sheep and trees.
#    Every prop is TRIMMED TO ITS CONTENT with the base on the cell's bottom
#    edge, because a prop is drawn from its base exactly like a fighter is.
#    The animated ones (bush, sheep, tree) keep uniform cells so they can be
#    read as strips.
# ---------------------------------------------------------------------------
echo "dressing:"
# static <src> <dst> <max cell> [resize]
static_prop() {
	local src="$1" dst="$2" cell="$3" size="${4:-50%}"
	mkdir -p "$(dirname "$dst")"
	magick "$src" -trim +repage -background none -gravity south -extent "$cell" \
		-filter point -resize "$size" -depth 8 "$dst"
	echo "  $dst"
}
for i in 1 2 3 4; do
	static_prop "$TS/Terrain/Decorations/Rocks/Rock$i.png" "$OUT/props/rock$i.png" 64x64
done
for i in 1 2 3 4; do
	static_prop "$TS/Terrain/Resources/Wood/Trees/Stump $i.png" "$OUT/props/stump$i.png" 64x64
done
for i in 1 2 3 4 5 6; do
	static_prop "$TS/Terrain/Resources/Gold/Gold Stones/Gold Stone $i.png" "$OUT/props/gold$i.png" 64x64
done
static_prop "$TS/Terrain/Resources/Wood/Wood Resource/Wood Resource.png" "$OUT/props/wood.png" 64x64
static_prop "$TS/Terrain/Resources/Meat/Meat Resource/Meat Resource.png" "$OUT/props/meat.png" 64x64
for i in 1 2 3 4; do
	static_prop "$TS/Terrain/Resources/Tools/Tool_0$i.png" "$OUT/props/tool$i.png" 64x64
done

# animated <src> <dst> <frames> <band WxH+X+Y> <resize>
#   The band is cut off the sheet FIRST (an offset crop yields one image), then
#   tiled evenly into frames. The band's height is the cell height, plus two
#   rows below the art so a base is never clipped.
anim_prop() {
	local src="$1" dst="$2" frames="$3" band="$4" size="$5"
	local bandw="${band%%x*}" rest="${band#*x}"
	local bandh="${rest%%+*}"
	local cellw=$(( bandw / frames ))
	mkdir -p "$(dirname "$dst")"
	magick "$src" -crop "$band" +repage -crop "${cellw}x${bandh}" +repage \
		-background none -gravity south -extent "${cellw}x$(( bandh + 2 ))" \
		-filter point -resize "$size" +append -depth 8 "$dst"
	echo "  $dst"
}
# A bush sways (8 frames), a sheep grazes (6), a tree stands in the wind (8).
anim_prop "$TS/Terrain/Decorations/Bushes/Bushe1.png"       "$OUT/props/bush.png"  8 "1024x46+0+33" 50%
anim_prop "$TS/Terrain/Resources/Meat/Sheep/Sheep_Idle.png" "$OUT/props/sheep.png" 6 "768x44+0+40"  50%
anim_prop "$TS/Terrain/Resources/Wood/Trees/Tree1.png"      "$OUT/props/tree.png"  8 "1536x192+0+48" 50%

# ---------------------------------------------------------------------------
# 8. UI - the paper banner behind announcements, and the bar frames.
# ---------------------------------------------------------------------------
echo "ui:"
bake "$TS/UI Elements/UI Elements/Banners/Banner.png" "$OUT/ui/banner.png" 50%
bake "$TS/UI Elements/UI Elements/Bars/SmallBar_Base.png" "$OUT/ui/bar_base.png" 100%
bake "$TS/UI Elements/UI Elements/Bars/SmallBar_Fill.png" "$OUT/ui/bar_fill.png" 100%

echo
echo "done. Re-import in Godot:"
echo "  flatpak run org.godotengine.Godot --headless --editor --path . --quit"
