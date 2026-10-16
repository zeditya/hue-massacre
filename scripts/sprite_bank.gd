class_name SpriteBank
extends RefCounted
##
## SPRITE BANK - turns the Adventurer PNG sheets into ready-to-play SpriteFrames.
##
## WHY A BANK AND NOT A .tres FILE
##   The project deliberately keeps everything readable as code. Building the
##   animations here also means there is exactly one place that knows the sheet
##   layout, so a mis-sized frame can only be wrong in one spot.
##
## SHEET LAYOUT (verified against the source art)
##   idle_<dir>.png / run_<dir>.png / attack1_<dir>.png
##   Each sheet is 768x80 = 8 frames of 96x80, for dir in down/up/left/right.
##   The figure itself is about 19x34 px, centred in its 96x80 cell, so a frame
##   is used whole and the sprite is centred on the node.
##
## The characters are then recoloured to any hue by `hue_tint.gdshader`, which
## is what keeps colour theory the core of the game even though the art ships
## with its own fixed colours.

const ADV_PATH: String = "res://assets/characters/adventurer/"
const TINT_SHADER: String = "res://scripts/hue_tint.gdshader"

const FRAME_W: int = 96
const FRAME_H: int = 80
const FRAME_COUNT: int = 8

## The four facings, in the order the sheets use them.
const DIRECTIONS: PackedStringArray = ["down", "up", "left", "right"]

## Frames are expensive to build (many AtlasTextures), so build them once for
## the whole process and hand the same SpriteFrames to every character.
static var _adventurer: SpriteFrames = null


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
