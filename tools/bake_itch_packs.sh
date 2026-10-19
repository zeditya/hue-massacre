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
# 3b. THE SWORN ROLES - the pack's Archer, Monk and a smaller Lancer, for the
#     garrison §12.2 asks for. Same 192px cells as the Warrior (50% -> 96), so an
#     archer stands with the line; the Lancer's cells are 320px, so a soldier's
#     spear is cut at 37.5% (120px, the warden's scale) rather than the
#     Champion's 160.
#
#     The archer's shot is the pack's Archer_Shoot, the monk's action frame is
#     the pack's Heal pose, and the lancer borrows the pack's DEFENCE set for
#     the wall of spears.
# ---------------------------------------------------------------------------
echo "sworn roles (Tiny Swords Archer / Monk / Lancer):"
AR="$TS/Units/Blue Units/Archer"
grey "$AR/Archer_Idle.png"  "$OUT/units/archer/idle.png"    50%
grey "$AR/Archer_Run.png"   "$OUT/units/archer/run.png"     50%
grey "$AR/Archer_Shoot.png" "$OUT/units/archer/attack1.png" 50%
MO="$TS/Units/Blue Units/Monk"
grey "$MO/Idle.png" "$OUT/units/monk/idle.png"    50%
grey "$MO/Run.png"  "$OUT/units/monk/run.png"     50%
grey "$MO/Heal.png" "$OUT/units/monk/attack1.png" 50%
SL="$TS/Units/Blue Units/Lancer"
grey "$SL/Lancer_Idle.png"         "$OUT/units/lancer/idle.png"    37.5%
grey "$SL/Lancer_Run.png"          "$OUT/units/lancer/run.png"     37.5%
grey "$SL/Lancer_Down_Attack.png"  "$OUT/units/lancer/attack1.png" 37.5%
grey "$SL/Lancer_Down_Defence.png" "$OUT/units/lancer/guard.png"   37.5%

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

# ---------------------------------------------------------------------------
# 9. THE STORY STAGE - everything the opening scene and the hall gates need.
#    This is the "use everything" section: the pack's clouds, buildings,
#    portraits, papers, icons, buttons, cursors and big bar all ship now.
# ---------------------------------------------------------------------------
echo "story stage (Tiny Swords clouds + buildings):"
# Clouds: eight shapes, half scale. The opening drifts them across a dawn sky,
# and the halls hang the same art overhead.
for i in 1 2 3 4 5 6 7 8; do
	bake "$TS/Terrain/Decorations/Clouds/Clouds_0$i.png" "$OUT/ui/clouds/cloud_0$i.png" 50%
done
# Buildings: EVERY faction, eight types each, at half scale (96x128). The
# opening stacks the black ones into a night skyline and the red ones into the
# gate of the Sun's Hall; the halls themselves reuse them as scenery.
for pair in black:Black red:Red yellow:Yellow blue:Blue purple:Purple; do
	folder="${pair%%:*}" pack="${pair##*:}"
	for name in Archery Barracks Castle House1 House2 House3 Monastery Tower; do
		bake "$TS/Buildings/$pack Buildings/$name.png" "$OUT/ui/buildings/$folder/$name.png" 50%
	done
done

echo "story stage (portraits + scroll + furniture):"
# Portraits: the pack's 25 human avatars at full size (256px, 5 factions x 5
# faces). The dialogue boxes use them - the dying Unsworn, the herald, the
# Champion - so the story has faces instead of initials.
mkdir -p "$OUT/ui/avatars"
for i in $(seq -w 1 25); do
	bake "$TS/UI Elements/UI Elements/Human Avatars/Avatars_$i.png" "$OUT/ui/avatars/avatar_$i.png" 100%
done
# The scroll: the story panel is written on the pack's own paper.
bake "$TS/UI Elements/UI Elements/Papers/RegularPaper.png" "$OUT/ui/paper.png" 50%
bake "$TS/UI Elements/UI Elements/Papers/SpecialPaper.png" "$OUT/ui/paper_special.png" 50%
# The pack's twelve icons (sword, shield, gear, coin, meat, log, hammer, tree,
# flag, X, info, note) at native 64px - menus and the controls legend.
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
	bake "$TS/UI Elements/UI Elements/Icons/Icon_$i.png" "$OUT/ui/icons/icon_$i.png" 100%
done
# Four cursors, at native size: a real game cursor instead of the OS arrow.
for i in 01 02 03 04; do
	bake "$TS/UI Elements/UI Elements/Cursors/Cursor_$i.png" "$OUT/ui/cursors/cursor_$i.png" 100%
done
# Buttons and the big bar: the pages (pause / win / dead) are built from these
# from now on, and the Champion's health bar wears the BigBar frame.
for who in big_blue:BigBlueButton small_blue_square:SmallBlueSquareButton small_blue_round:SmallBlueRoundButton; do
	name="${who%%:*}" src="${who##*:}"
	bake "$TS/UI Elements/UI Elements/Buttons/${src}_Regular.png" "$OUT/ui/buttons/${name}.png" 50%
	bake "$TS/UI Elements/UI Elements/Buttons/${src}_Pressed.png" "$OUT/ui/buttons/${name}_pressed.png" 50%
done
for who in big_red:BigRedButton small_red_square:SmallRedSquareButton; do
	name="${who%%:*}" src="${who##*:}"
	bake "$TS/UI Elements/UI Elements/Buttons/${src}_Regular.png" "$OUT/ui/buttons/${name}.png" 50%
	bake "$TS/UI Elements/UI Elements/Buttons/${src}_Pressed.png" "$OUT/ui/buttons/${name}_pressed.png" 50%
done
bake "$TS/UI Elements/UI Elements/Bars/BigBar_Base.png" "$OUT/ui/big_bar_base.png" 100%
bake "$TS/UI Elements/UI Elements/Bars/BigBar_Fill.png" "$OUT/ui/big_bar_fill.png" 100%
bake "$TS/UI Elements/UI Elements/Banners/Banner_Slots.png" "$OUT/ui/banner_slots.png" 50%

echo "story stage (ward magic):"
# The wheel's spells, from Super Pixel Effects (credited: unTied Games). Every
# one is greyed so the runtime tint throws the right hue on it, exactly like
# the unit sheets.
spell() {
	local src="$1" dst="$2" size="$3"
	magick "$src"/frame*.png +append -filter point -resize "$size" -colorspace Gray -depth 8 "$dst"
	echo "  $dst"
}
# The gift the dying Unsworn gives: hue absorption itself.
spell "$SPE/PNG/Fantasy Spells/spell_absorb_001/spell_absorb_001_large_violet" \
	"$OUT/fx/absorb.png" 50%
# The Thorn Warden's heal, the Warrior's shield ward, a colour leaving a body,
# and the sparkle the wheel leaves on everything it touches.
spell "$SPE/PNG/Fantasy Spells/spell_heal_001/spell_heal_001_large_red" \
	"$OUT/fx/heal.png" 50%
spell "$SPE/PNG/Fantasy Spells/spell_defense_up_001/spell_defense_up_001_large_blue" \
	"$OUT/fx/ward.png" 50%
spell "$SPE/PNG/Fantasy Spells/spell_death_001/spell_death_001_large_red" \
	"$OUT/fx/drain.png" 50%
spell "$SPE/PNG/Fantasy Spells/status_sparkling_001/status_sparkling_001_large_yellow" \
	"$OUT/fx/sparkle.png" 50%
# The marks: the S rank the crowd stamps on a NAMED Unsworn, the alert the
# sworn shout, the warning before a perilous blow, and the Champion's crown.
spell "$SPE/PNG/Symbols/symbol_rank_S_001/symbol_rank_S_001_large_yellow" "$OUT/fx/mark_rank_s.png" 100%
spell "$SPE/PNG/Symbols/symbol_alert_001/symbol_alert_001_large_red"           "$OUT/fx/mark_alert.png" 100%
spell "$SPE/PNG/Symbols/symbol_warning_001/symbol_warning_001_large_yellow"    "$OUT/fx/mark_warning.png" 100%
spell "$SPE/PNG/Symbols/symbol_crown_001/symbol_crown_001_large_yellow"        "$OUT/fx/mark_crown.png" 100%

# ---------------------------------------------------------------------------
# 10. THE REST OF THE TERRAIN - the variants the earlier pass left on the
#     table. Every one of them is now picked by position hash in the halls, so
#     no two stretches of the same ground wear the same rock twice.
# ---------------------------------------------------------------------------
echo "terrain, the rest of it:"
# Bushes 2-4 and trees 2-4 are animated strips exactly like bush1/tree1, so they
# go through the same band-then-tile helper.
for i in 2 3 4; do
	anim_prop "$TS/Terrain/Decorations/Bushes/Bushe$i.png" "$OUT/props/bush$i.png" 8 "1024x46+0+33" 50%
done
for i in 2 3 4; do
	anim_prop "$TS/Terrain/Resources/Wood/Trees/Tree$i.png" "$OUT/props/tree$i.png" 8 "1536x192+0+48" 50%
done
for i in 1 2 3 4; do
	static_prop "$TS/Terrain/Decorations/Rocks in the Water/Water Rocks_0$i.png" "$OUT/props/water_rock$i.png" 64x64 50%
done
static_prop "$TS/Terrain/Resources/Gold/Gold Resource/Gold_Resource.png" "$OUT/props/gold_vein.png" 64x64 50%

echo
echo "done. Re-import in Godot:"
echo "  flatpak run org.godotengine.Godot --headless --editor --path . --quit"
