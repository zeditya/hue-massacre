class_name PaintLayer
extends Node2D
##
## PAINT LAYER - the hue that ends up on the sand.
##
## Every kill splashes a puddle of the guard's colour here. The layer answers
## the one question the whole camouflage system depends on:
##
##     "What colour is the floor at this point?"
##
## Because overlapping puddles are averaged ON THE HUE WHEEL (see
## ColorTheory.blend), dropping red and blue paint in the same place really
## does make the floor read violet - and then a violet Unsworn standing there is
## camouflaged. That single behaviour is room 2's whole lesson.
##
## Drawing is done with `_draw()` circles, so there are zero image files.
## Puddles fade out over `blob_lifetime` seconds and are then forgotten.

@export_group("Fade")
## Total life of a puddle in seconds. The spec asks for "about 10 seconds".
@export var blob_lifetime: float = 10.0
## Fraction of the life the puddle stays fully solid. 0.45 means 4.5s solid
## then 5.5s of fading, which reads as "drying paint".
@export var fade_hold: float = 0.45
## How transparent the freshest puddle is. Low enough to still see the floor.
@export var puddle_alpha: float = 0.62

@export_group("Splatter shape")
## Extra droplets thrown out around the main puddle.
@export var splat_droplets: int = 6
## Radius of the main puddle at the point of the kill.
@export var splat_radius: float = 54.0
## How far the droplets scatter away from the kill point.
@export var splat_scatter: float = 46.0
## Hard cap on puddles so the frame time stays flat in long fights.
@export var max_blobs: int = 160

@export_group("Progress bar")
## Puddle area (as a fraction of the room) that counts as "100% restored".
## Lower = the bar fills faster. 0.42 makes one cleared room read ~80-100%.
@export var coverage_reference: float = 0.42

## Each entry: { pos, radius, color, age, life, main }
var blobs: Array = []


func _ready() -> void:
	# Paint is a picture on the floor: below every y-sorted object.
	z_index = -2
	set_process(true)


func _process(delta: float) -> void:
	if blobs.is_empty():
		return
	# Age every puddle and drop the ones whose life has run out.
	var i: int = blobs.size() - 1
	while i >= 0:
		var b: Dictionary = blobs[i]
		b["age"] = float(b["age"]) + delta
		if float(b["age"]) >= float(b["life"]):
			blobs.remove_at(i)
		i -= 1
	# Puddles are semi-transparent and always changing, so redraw each frame.
	# The array is capped by max_blobs, so this stays cheap.
	queue_redraw()


# ---------------------------------------------------------------------------
# Adding paint
# ---------------------------------------------------------------------------

## Splash a puddle of `colour` centred on `pos`.
## `scale_mul` lets a big boss kill throw a much bigger splat than a normal one.
func spawn(pos: Vector2, colour: Color, scale_mul: float = 1.0) -> void:
	var life: float = blob_lifetime
	_add_blob(pos, splat_radius * scale_mul, colour, life, true)
	# Random droplets around the point of impact give it a splatter shape
	# instead of a boring bullseye.
	for i in splat_droplets:
		var angle: float = randf() * TAU
		var dist: float = randf_range(splat_scatter * 0.35, splat_scatter) * scale_mul
		var drop_pos: Vector2 = pos + Vector2.RIGHT.rotated(angle) * dist
		var drop_radius: float = splat_radius * randf_range(0.16, 0.38) * scale_mul
		_add_blob(drop_pos, drop_radius, colour, life * randf_range(0.85, 1.0), false)
	queue_redraw()


func _add_blob(pos: Vector2, radius: float, colour: Color, life: float, is_main: bool) -> void:
	blobs.append({
		"pos": pos,
		"radius": maxf(radius, 4.0),
		"color": colour,
		"age": 0.0,
		"life": maxf(life, 0.5),
		"main": is_main,
	})
	# Forget the oldest paint if we are over budget.
	while blobs.size() > max_blobs:
		blobs.pop_front()


## Wipe the floor (used when a room restarts).
func clear_all() -> void:
	blobs.clear()
	queue_redraw()


# ---------------------------------------------------------------------------
# Reading the floor
# ---------------------------------------------------------------------------

## 0 = completely dry, 1 = freshly painted.
func _alpha_of(blob: Dictionary) -> float:
	var t: float = clampf(float(blob["age"]) / float(blob["life"]), 0.0, 1.0)
	if t <= fade_hold:
		return 1.0
	return clampf(1.0 - (t - fade_hold) / maxf(1.0 - fade_hold, 0.001), 0.0, 1.0)


## Puddles shrink slightly as they dry, so the cover really does disappear.
func _radius_of(blob: Dictionary) -> float:
	return float(blob["radius"]) * lerpf(0.78, 1.0, _alpha_of(blob))


## The colour of the floor at `pos`, blended from every puddle covering it.
## Returns [Color, weight] where weight is 0.0 when the floor is bare grey.
func color_at(pos: Vector2) -> Array:
	var colours: Array = []
	var weights: Array = []
	var strongest: float = 0.0
	for blob in blobs:
		var r: float = _radius_of(blob)
		if r <= 1.0:
			continue
		var d: float = pos.distance_to(blob["pos"])
		if d > r:
			continue
		var a: float = _alpha_of(blob)
		# Deep inside a puddle counts for more than clipping its edge.
		var w: float = a * (0.35 + 0.65 * (1.0 - d / r))
		colours.append(blob["color"])
		weights.append(w)
		strongest = maxf(strongest, w)

	if colours.is_empty():
		return [ColorTheory.FLOOR_GREY, 0.0]
	return [ColorTheory.blend(colours, weights), clampf(strongest, 0.0, 1.0)]


## Fraction of the room that has colour back in it, 0..1, for the HUD bar.
## Cheap on purpose: it just sums the puddle areas instead of scanning a grid.
func coverage() -> float:
	var painted: float = 0.0
	for blob in blobs:
		if not bool(blob["main"]):
			continue
		var r: float = _radius_of(blob)
		# 1.45 accounts for the area of the surrounding droplets.
		painted += PI * r * r * _alpha_of(blob) * 1.45
	var room_area: float = LevelData.PLAYFIELD.x * LevelData.PLAYFIELD.y
	return clampf(painted / maxf(room_area * coverage_reference, 1.0), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	for blob in blobs:
		var a: float = _alpha_of(blob)
		if a <= 0.02:
			continue
		var c: Color = blob["color"]
		var r: float = _radius_of(blob)
		# A soft outer halo plus a solid core reads like wet paint without
		# needing a single texture or shader.
		draw_circle(blob["pos"], r * 1.25, Color(c.r, c.g, c.b, a * puddle_alpha * 0.28))
		draw_circle(blob["pos"], r, Color(c.r, c.g, c.b, a * puddle_alpha))
