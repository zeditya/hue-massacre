class_name SpriteBank
extends RefCounted
##
## SPRITE BANK - turns the PNG sheets into ready-to-play SpriteFrames.
##
## WHY A BANK AND NOT A .tres FILE
##   The project deliberately keeps everything readable as code. Building the
##   animations here also means there is exactly one place that knows the sheet
##   layout, so a mis-sized frame can only be wrong in one spot.
##
## THE TWO ART FAMILIES
##   1. THE UNSWORN - the adventurer sheets (`adventurer()`), the only
##      FOUR-DIRECTION art in the game, because the player is the one figure you
##      have to read the aim from at a glance. 768x80 = 8 frames of 96x80.
##   2. EVERYONE ELSE - the melee's knights, the crowd's own pawns and the
##      Champion (`unit()`), baked from the Tiny Swords pack by
##      tools/bake_itch_packs.sh. That art is drawn for a camera looking from
##      the south, so it is FRONT-facing in every direction: the four facing
##      names all point at the same frames and the guards flip horizontally for
##      left. At this scale - and with the swing arcs drawn on the ground - the
##      flip is all the facing the eye needs, and the figures gain in bulk and
##      armour what they lose in tedium.
##
## The characters are then recoloured to any hue by `hue_tint.gdshader`, which
## is what keeps colour theory the core of the game even though the art ships
## with its own fixed colours. Those sheets are pre-greyed by the bake script.
##

const ADV_PATH: String = "res://assets/characters/adventurer/"
const TINT_SHADER: String = "res://scripts/hue_tint.gdshader"

const FRAME_W: int = 96
const FRAME_H: int = 80
const FRAME_COUNT: int = 8

## The four facings, in the order the sheets use them.
const DIRECTIONS: PackedStringArray = ["down", "up", "left", "right"]

## Every unit the melee fields. Each entry names the folder under
## res://assets/units/ and the size of one animation cell; the frame COUNT of
## every animation is read off the sheet itself (width / cell), so a re-bake
## with more frames cannot silently desync from this table.
##
##   fps is the sheet's own playback speed. The attack sheets are timed to the
##   guard's windup (~0.55s from the first frame to the blade landing).
const UNITS: Dictionary = {
	# The house knights: shield and sword, the basic 60hp line.
	"knight": {
		"cell": 96, "fps": 10.0,
		"anims": ["idle", "run", "attack1", "attack2", "guard"],
	},
	# The same armour, worn bigger: the 140hp warden plants and holds.
	"warden": {
		"cell": 120, "fps": 10.0,
		"anims": ["idle", "run", "attack1", "attack2", "guard"],
	},
	# The crowd's own, out of the stands with a knife: fast, fragile, 45hp.
	"harrier": {
		"cell": 96, "fps": 10.0,
		"anims": ["idle", "run", "attack1"],
	},
	# What the Champion calls up: the stands' axe hands.
	"aspirant": {
		"cell": 96, "fps": 10.0,
		"anims": ["idle", "run", "attack1"],
	},
	# The Champion of the Wheel: a lancer, the tallest figure on the sand.
	"champion": {
		"cell": 160, "fps": 10.0,
		"anims": ["idle", "run", "attack1", "guard"],
	},
	# §12.2's garrison. The archer keeps the line's own scale and fires the
	# pack's Shoot sheet; the THORN-SWORN monk's action is the pack's Heal pose;
	# the sworn lance is the same Lancer art cut to soldier size.
	"archer": {
		"cell": 96, "fps": 10.0,
		"anims": ["idle", "run", "attack1"],
	},
	"monk": {
		"cell": 96, "fps": 10.0,
		"anims": ["idle", "run", "attack1"],
	},
	"lancer": {
		"cell": 120, "fps": 10.0,
		"anims": ["idle", "run", "attack1", "guard"],
	},
}

## Frames per second for the ATTACK sheets, per unit: timed so the sheet's last
## frame lands on the windup, which is when the blade is coded to connect.
const ATTACK_FPS: float = 7.3

## Frames are expensive to build (many AtlasTextures), so build them once for
## the whole process and hand the same SpriteFrames to every character.
static var _adventurer: SpriteFrames = null
static var _units: Dictionary = {}
static var _unit_offsets: Dictionary = {}



## The shared SpriteFrames for every human character in the game.
static func adventurer() -> SpriteFrames:
	if _adventurer == null:
		_adventurer = _build_adventurer()
	return _adventurer


static func _build_adventurer() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for dir in DIRECTIONS:
		# Idle and run loop; the attack is a one-shot that ends on its last frame.
		_add(sf, "idle_%s" % dir, "%sidle_%s.png" % [ADV_PATH, dir], 4.0, true)
		_add(sf, "run_%s" % dir, "%srun_%s.png" % [ADV_PATH, dir], 13.0, true)
		_add(sf, "attack_%s" % dir, "%sattack1_%s.png" % [ADV_PATH, dir], 18.0, false)
	return sf


## Slice one sheet into an animation. Missing art is skipped rather than
## crashing, so the game still runs if a file is renamed.
static func _add(sf: SpriteFrames, anim: String, path: String, fps: float, loops: bool) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("SpriteBank: missing sprite sheet %s" % path)
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loops)
	for i in FRAME_COUNT:
		var frame := AtlasTexture.new()
		frame.atlas = tex
		frame.region = Rect2(float(i * FRAME_W), 0.0, float(FRAME_W), float(FRAME_H))
		sf.add_frame(anim, frame)


# ---------------------------------------------------------------------------
# The melee's own art: knights, pawns, the Champion
# ---------------------------------------------------------------------------

## The SpriteFrames for one melee unit ("knight", "warden", "harrier",
## "aspirant", "champion"). Built once per kind and shared by every body that
## wears it. The frame COUNT is read off each sheet (width / cell), so a re-bake
## with more or fewer frames can never desync from this table.
static func unit(kind: String) -> SpriteFrames:
	if not _units.has(kind):
		_units[kind] = _build_unit(kind)
	return _units[kind]


static func _build_unit(kind: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var spec: Dictionary = UNITS.get(kind, UNITS["knight"])
	var cell: int = int(spec.get("cell", 96))
	for anim_name in spec.get("anims", []):
		var path: String = "res://assets/units/%s/%s.png" % [kind, anim_name]
		var is_attack: bool = anim_name.begins_with("attack")
		var fps: float = ATTACK_FPS if is_attack else float(spec.get("fps", 10.0))
		_slice(sf, anim_name, path, cell, cell, fps, not is_attack)
	return sf


## One animation from one horizontal strip of square cells.
static func _slice(sf: SpriteFrames, anim: String, path: String, w: int, h: int,
		fps: float, loops: bool) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("SpriteBank: missing sprite sheet %s" % path)
		return
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loops)
	var count: int = maxi(int(tex.get_width() / float(w)), 1)
	for i in count:
		var frame := AtlasTexture.new()
		frame.atlas = tex
		frame.region = Rect2(float(i * w), 0.0, float(w), float(h))
		sf.add_frame(anim, frame)


## Where the ground line sits, in world px below a character's origin. Both the
## drawn shadows and the sprite offsets agree on this number.
const FEET_Y: float = 15.0

## How far a unit's sprite must be shifted so its FEET stand on FEET_Y, and so
## the figure is centred on its own body (the pack draws figures off-centre in
## their cells). Measured from the idle sheet the first time it is asked for, so
## a re-bake re-plants every knight instead of every knight floating.
static func unit_offset(kind: String) -> Vector2:
	if not _unit_offsets.has(kind):
		_unit_offsets[kind] = _measure_offset(kind)
	return _unit_offsets[kind]


static func _measure_offset(kind: String) -> Vector2:
	var spec: Dictionary = UNITS.get(kind, UNITS["knight"])
	var cell: int = int(spec.get("cell", 96))
	var tex: Texture2D = load("res://assets/units/%s/idle.png" % kind)
	if tex == null:
		return Vector2.ZERO
	var img: Image = tex.get_image()
	if img == null or img.get_width() < cell or img.get_height() < cell:
		return Vector2.ZERO
	var first: int = -1
	var last: int = -1
	var min_x: int = cell
	var max_x: int = -1
	for y in cell:
		for x in cell:
			if img.get_pixel(x, y).a > 0.35:
				if first < 0:
					first = y
				last = y
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	if last < 0:
		return Vector2.ZERO
	var half: float = float(cell) * 0.5
	var centre_x: float = (float(min_x) + float(max_x) + 1.0) * 0.5
	return Vector2(half - centre_x, FEET_Y + half - float(last + 1))



## A material that paints a character sprite in `colour` while keeping its
## shading. Give each character its own instance so the hue can change live
## (the player's hue changes every time they absorb a guard).
static func tint_material(colour: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader: Shader = load(TINT_SHADER)
	if shader != null:
		mat.shader = shader
		set_tint(mat, colour)
	return mat


## Point an existing tint material at a new hue.
static func set_tint(mat: Material, colour: Color) -> void:
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter(
			"tint", Vector3(colour.r, colour.g, colour.b))


## Facing name for an angle in radians.
##
## Godot 2D has +y pointing DOWN the screen, so the four quadrants map like this:
##     0 rad   -> right        90 deg -> down
##     180 deg -> left         270 deg -> up
static func dir_from_angle(angle: float) -> String:
	var a: float = fposmod(angle, TAU)
	if a < PI * 0.25 or a >= PI * 1.75:
		return "right"
	if a < PI * 0.75:
		return "down"
	if a < PI * 1.25:
		return "left"
	return "up"


## Facing name for a movement vector. A still character keeps facing down.
static func dir_from_vector(v: Vector2) -> String:
	if v.length() < 0.001:
		return "down"
	return dir_from_angle(v.angle())
