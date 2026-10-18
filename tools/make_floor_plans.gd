extends SceneTree
##
## Dev tool: draw a floor-plan sheet of all four arenas — walls, every knight
## patrol route (in that knight's own hue), the spawn and the colour motes — and
## save it to docs/level_plans.png so the README image always matches
## level_data.gd.
##
## Run it with:
##     godot --headless --path . --script res://tools/make_floor_plans.gd
##
## It paints straight into an Image instead of capturing a rendered frame, so it
## works in a headless engine (no display, no renderer) and can be re-run by CI.
##
## Layout: a 2x2 sheet. Top-left ARENA 01, top-right 02, bottom-left 03,
## bottom-right 04 (the order in LevelData.ROOMS).

const OUT_PATH: String = "res://docs/level_plans.png"
const PANEL := Vector2(640.0, 360.0)
const SCALE: float = 0.5
const PAD: float = 8.0

const BG: Color = Color(0.055, 0.055, 0.07)
const FLOOR: Color = Color(0.13, 0.125, 0.115)
const WALL: Color = Color(0.40, 0.39, 0.42)
const FRAME: Color = Color(0.28, 0.28, 0.33)
const SPAWN: Color = Color(0.40, 1.0, 0.50)


func _init() -> void:
	var w: int = int(PANEL.x * 2.0)
	var h: int = int(PANEL.y * 2.0)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)

	var rooms: Array = LevelData.ROOMS
	for i in rooms.size():
		_draw_panel(img, i, rooms[i])

	var err: int = img.save_png(OUT_PATH)
	if err == OK:
		print("wrote %s (%dx%d, %d arenas)" % [OUT_PATH, w, h, rooms.size()])
	else:
		print("FAILED to write %s (err %d)" % [OUT_PATH, err])
	quit(0 if err == OK else 1)


func _origin(i: int) -> Vector2:
	return Vector2(float(i % 2) * PANEL.x, float(i / 2) * PANEL.y)


func _draw_panel(img: Image, i: int, room: Dictionary) -> void:
	var o: Vector2 = _origin(i) + Vector2(PAD, PAD)
	var inner: Vector2 = PANEL - Vector2(PAD * 2.0, PAD * 2.0)

	# The panel's own floor and frame.
	_fill_rect(img, Rect2(o, inner), FLOOR)

	# Walls: the border plus this arena's own geometry, exactly as the game
	# builds them (LevelData.walls_for is the single source of truth).
	for r in LevelData.walls_for(room):
		_fill_rect(img, Rect2(o + r.position * SCALE, r.size * SCALE), WALL)

	# Every knight route in that knight's own colour, plus its waypoints.
	for spec in room["guards"]:
		var col: Color = spec["color"]
		var pts: Array = [Vector2(spec["pos"])]
		for p in spec["path"]:
			pts.append(Vector2(p))
		for k in range(1, pts.size()):
			_line(img, o + pts[k - 1] * SCALE, o + pts[k] * SCALE, col)
		if pts.size() >= 3:
			# Routes are walked out and back, so the outline is the patrolled
			# area rather than a one-way trip.
			_line(img, o + pts[pts.size() - 1] * SCALE, o + pts[0] * SCALE, Color(col.r, col.g, col.b, 0.55))
		for p in pts:
			_disc(img, o + p * SCALE, 2.0, col)

	# The Champion's Aspirants, dashed in their own hues.
	for spec in room.get("summons", []):
		var col2: Color = spec["color"]
		var spts: Array = [Vector2(spec["pos"])]
		for p in spec["path"]:
			spts.append(Vector2(p))
		for k in range(1, spts.size()):
			_dashed(img, o + spts[k - 1] * SCALE, o + spts[k] * SCALE, col2)
		_disc(img, o + Vector2(spec["pos"]) * SCALE, 2.0, col2)

	# Colour motes: small filled dots.
	for mote in room.get("motes", []):
		_disc(img, o + Vector2(mote["pos"]) * SCALE, 2.0, mote["color"])

	# The player's spawn: a green ring, as in the README legend.
	_ring(img, o + Vector2(room["start"]) * SCALE, 5.0, SPAWN)

	# Panel frame.
	_stroke_rect(img, Rect2(o - Vector2(1.0, 1.0), inner + Vector2(2.0, 2.0)), FRAME)


# ---------------------------------------------------------------------------
# Tiny raster helpers (all in image space)
# ---------------------------------------------------------------------------

func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


func _fill_rect(img: Image, r: Rect2, c: Color) -> void:
	var x0: int = int(r.position.x)
	var y0: int = int(r.position.y)
	var x1: int = int(ceil(r.position.x + r.size.x))
	var y1: int = int(ceil(r.position.y + r.size.y))
	for y in range(y0, y1):
		for x in range(x0, x1):
			_put(img, x, y, c)


func _stroke_rect(img: Image, r: Rect2, c: Color) -> void:
	var x0: int = int(r.position.x)
	var y0: int = int(r.position.y)
	var x1: int = int(r.position.x + r.size.x)
	var y1: int = int(r.position.y + r.size.y)
	for x in range(x0, x1 + 1):
		_put(img, x, y0, c)
		_put(img, x, y1, c)
	for y in range(y0, y1 + 1):
		_put(img, x0, y, c)
		_put(img, x1, y, c)


func _disc(img: Image, p: Vector2, radius: float, c: Color) -> void:
	var r: int = int(ceil(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if float(dx * dx + dy * dy) <= radius * radius:
				_put(img, int(p.x) + dx, int(p.y) + dy, c)


func _ring(img: Image, p: Vector2, radius: float, c: Color) -> void:
	var steps: int = 40
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		_put(img, int(p.x + cos(a) * radius), int(p.y + sin(a) * radius), c)
		_put(img, int(p.x + cos(a) * (radius + 1.0)), int(p.y + sin(a) * (radius + 1.0)), c)


## A 1px line (integer Bresenham).
func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var x0: int = int(a.x)
	var y0: int = int(a.y)
	var x1: int = int(b.x)
	var y1: int = int(b.y)
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		_put(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


## A line with every other 4-pixel run skipped, for the Aspirant routes.
func _dashed(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps: int = maxi(int(a.distance_to(b)), 1)
	for i in steps:
		if (i / 4) % 2 == 1:
			continue
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		_put(img, int(p.x), int(p.y), c)
