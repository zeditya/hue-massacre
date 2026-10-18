class_name ArenaArt
extends RefCounted
##
## ARENA ART - the look of the four arenas, all drawn in code.
##
## Everything the player looks at is generated here: the sand floor (baked once
## per arena into a texture), the stone walls, the crowd in the stands, the
## house banners and the corner braziers. No new art file is imported for any of
## it, so the arena can be re-dressed by editing numbers.
##
## THE ONE RULE THIS FILE MUST NOT BREAK
##   The bare floor is the colour the guards measure the player against
##   (`ColorTheory.visibility`). A colour with saturation under
##   `ColorTheory.GREY_SATURATION` (0.18) counts as "no hue", so the sand is a
##   WARM BUT MEASURABLY GREY colour: it reads as sand next to the cold stone,
##   and it still tells the rules "there is no colour here to hide inside".
##   `FLOOR_BASE` sits at saturation ~0.16 on purpose. Do not warm it past 0.18.
##
## COST
##   The grain is baked into one 640x360 texture (drawn stretched to the
##   1280x720 playfield) and cached per arena, so the moving parts - flames,
##   crowd shimmer, the arena sigil - are a few dozen `draw_*` calls per frame.

## Base sand. Saturation 0.138: warm to the eye, grey to the colour rules.
## (Saturation is kept clear of 0.18 rather than merely under it, because the
## 8-bit bake plus the edge vignette can round a pixel up a percent or so.)
const FLOOR_BASE: Color = Color(0.435, 0.412, 0.375)
## The two grain tones the sand is speckled with.
const FLOOR_DARK: Color = Color(0.335, 0.316, 0.288)
const FLOOR_LIGHT: Color = Color(0.515, 0.490, 0.452)
## The arena is darker at the edges, so the eye is pulled to the middle.
const FLOOR_EDGE_DARKEN: float = 0.42
## Bake resolution (half the playfield) and the stretch factor back up to world
## pixels. Half-res grain reads as coarse sand and bakes in a quarter the time.
const BAKE_W: int = 640
const BAKE_H: int = 360
const SCALE: float = 2.0
## Size of one grain block in bake space, in pixels.
const GRAIN: int = 2

const STONE_LIT: float = 0.26
const BANNER_W: float = 30.0
const BANNER_H: float = 44.0

## Baked per arena id, so an arena is only built once per run.
static var _floors: Dictionary = {}
## The drift positions for the dust, built once and reused every frame.
static var _dust: Array = []


## The baked sand for this arena. Falls back to null if baking ever fails, in
## which case room.gd draws its flat grey floor instead.
static func floor_texture(data: Dictionary) -> ImageTexture:
	var key: int = int(data.get("id", 0))
	if not _floors.has(key):
		_floors[key] = _bake(key)
	return _floors[key]


static func _bake(seed_id: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	# A fixed seed per arena: the sand is identical on every playthrough and on
	# every machine, which matters when a marker is comparing screenshots.
	rng.seed = 20261017 + seed_id

	var img: Image = Image.create(BAKE_W, BAKE_H, false, Image.FORMAT_RGBA8)
	img.fill(FLOOR_BASE)

	var cx: float = float(BAKE_W) * 0.5
	var cy: float = float(BAKE_H) * 0.5
	var half_diag: float = sqrt(cx * cx + cy * cy)

	var by: int = 0
	while by < BAKE_H:
		var bx: int = 0
		while bx < BAKE_W:
			# Grain: a random tone per block, then a soft vignette on top so the
			# arena edges fall away and the middle stays readable.
			var t: float = rng.randf()
			var colour: Color = FLOOR_BASE
			if t < 0.22:
				colour = FLOOR_DARK
			elif t > 0.80:
				colour = FLOOR_LIGHT

			var px: float = float(bx) + float(GRAIN) * 0.5
			var py: float = float(by) + float(GRAIN) * 0.5
			var d: float = Vector2(px - cx, py - cy).length() / half_diag
			var shade: float = 1.0 - FLOOR_EDGE_DARKEN * clampf(d, 0.0, 1.0)
			colour = Color(colour.r * shade, colour.g * shade, colour.b * shade, 1.0)

			for dy in GRAIN:
				for dx in GRAIN:
					var x: int = bx + dx
					var y: int = by + dy
					if x < BAKE_W and y < BAKE_H:
						img.set_pixel(x, y, colour)
			bx += GRAIN
		by += GRAIN

	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# Walls
# ---------------------------------------------------------------------------

## Every wall block, drawn as cut stone: a lit cap, the body, a shadowed lip and
## brick courses. Three cheap bands turn what used to be a flat grey rectangle
## into something that reads as a solid object, which matters when the whole
## arena is built out of them.
static func draw_walls(canvas: CanvasItem, walls: Array, tint: Color) -> void:
	for r in walls:
		_draw_wall(canvas, r, tint)


static func _draw_wall(canvas: CanvasItem, r: Rect2, tint: Color) -> void:
	var body: Color = tint
	var lit: Color = body.lightened(STONE_LIT)
	var cap: float = minf(7.0, r.size.y * 0.4)

	# Drop shadow first, offset down-right, so blocks sit ON the sand.
	canvas.draw_rect(Rect2(r.position + Vector2(3.0, 5.0), r.size), Color(0.0, 0.0, 0.0, 0.30), true)
	canvas.draw_rect(r, body, true)
	# Lit top band: the face pointing at the camera is brighter.
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, cap)), lit, true)
	# Brick courses: horizontal seams, so a long wall reads as masonry.
	var seam: Color = Color(0.0, 0.0, 0.0, 0.22)
	var y: float = r.position.y + cap + 9.0
	while y < r.end.y - 3.0:
		canvas.draw_line(Vector2(r.position.x + 1.0, y), Vector2(r.end.x - 1.0, y), seam, 1.0)
		y += 11.0
	# A couple of staggered joints per course.
	var row: int = 0
	var jy: float = r.position.y + cap + 4.0
	while jy < r.end.y - 4.0:
		var jx: float = r.position.x + (16.0 if row % 2 == 0 else 30.0)
		while jx < r.end.x - 4.0:
			canvas.draw_line(Vector2(jx, jy), Vector2(jx, minf(jy + 11.0, r.end.y - 2.0)), seam, 1.0)
			jx += 28.0
		row += 1
		jy += 22.0
	# Shadowed lower lip, so blocks look like they have thickness.
	var lip: float = minf(4.0, r.size.y * 0.3)
	canvas.draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - lip), Vector2(r.size.x, lip)),
		Color(0.0, 0.0, 0.0, 0.38), true)
	canvas.draw_rect(r, Color(1.0, 1.0, 1.0, 0.10), false, 1.0)
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, cap)), Color(1.0, 1.0, 1.0, 0.06), false, 1.0)


# ---------------------------------------------------------------------------
# The arena mark on the sand (one per arena, drawn over the baked floor)
# ---------------------------------------------------------------------------

## The arena's signature: a sun over the Open Sand, the crossing mosaic in the
## Bannered Hall, the wheel in the Deep Ring and the spokes of the Wheel. Drawn
## live rather than baked, so it can breathe.
static func draw_mark(canvas: CanvasItem, data: Dictionary, time: float) -> void:
	var accent: Color = data.get("accent", Color(1.0, 0.82, 0.25))
	var centre: Vector2 = LevelData.PLAYFIELD * 0.5
	var pulse: float = 0.5 + 0.5 * sin(time * 1.3)
	match str(data.get("floor_style", "sun")):
		"cross":
			_draw_cross_mark(canvas, centre, accent)
		"wheel":
			_draw_wheel_mark(canvas, centre, time, accent)
		"spokes":
			_draw_spokes_mark(canvas, centre, time, accent)
		_:
			_draw_sun_mark(canvas, centre, accent, pulse)


## THE OPEN SAND: a sun wheel in the middle, with its rays reaching out to the
## four gates.
static func _draw_sun_mark(canvas: CanvasItem, centre: Vector2, accent: Color, pulse: float) -> void:
	var warm: Color = Color(accent.r, accent.g, accent.b, 0.10 + 0.05 * pulse)
	canvas.draw_circle(centre, 150.0, Color(warm.r, warm.g, warm.b, 0.05))
	canvas.draw_arc(centre, 108.0, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.22), 3.0, true)
	canvas.draw_arc(centre, 148.0, 0.0, TAU, 72, Color(accent.r, accent.g, accent.b, 0.14), 2.0, true)
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		var dir: Vector2 = Vector2.RIGHT.rotated(a)
		canvas.draw_line(centre + dir * 152.0, centre + dir * 196.0,
			Color(accent.r, accent.g, accent.b, 0.12), 3.0)


## THE BANNERED HALL: two house-coloured lanes laid across the sand, and the
## violet square where they meet - the mixing lesson, painted on the floor.
static func _draw_cross_mark(canvas: CanvasItem, centre: Vector2, accent: Color) -> void:
	var band: float = 21.0
	var gold: Color = Color(0.95, 0.72, 0.25, 0.13)
	var blue: Color = Color(accent.r, accent.g, accent.b, 0.15)
	# The east-west lane (gold) and the north-south lane (blue).
	canvas.draw_rect(Rect2(60.0, centre.y - band, LevelData.PLAYFIELD.x - 120.0, band * 2.0), gold, true)
	canvas.draw_rect(Rect2(centre.x - band, 60.0, band * 2.0, LevelData.PLAYFIELD.y - 120.0), blue, true)
	# Where they cross: the hue they average to. This is red + blue = violet.
	var violet: Color = ColorTheory.blend([Color(0.95, 0.72, 0.25), accent], [1.0, 1.0])
	canvas.draw_rect(Rect2(centre - Vector2(band * 2.4, band * 2.4), Vector2(band * 4.8, band * 4.8)),
		Color(violet.r, violet.g, violet.b, 0.30), true)
	canvas.draw_arc(centre, band * 3.4, 0.0, TAU, 48, Color(violet.r, violet.g, violet.b, 0.55), 2.0, true)


## THE DEEP RING: a full colour wheel drawn flat on the sand, so the complement
## the player is hunting is literally under their feet.
static func _draw_wheel_mark(canvas: CanvasItem, centre: Vector2, time: float, accent: Color) -> void:
	var inner: float = 92.0
	var outer: float = 124.0
	var segments: int = 72
	for i in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var hue: Color = ColorTheory.wheel(float(i) * (360.0 / float(segments)), 0.72, 0.92)
		var mid: float = (inner + outer) * 0.5
		var pts: PackedVector2Array = PackedVector2Array([
			centre + Vector2.RIGHT.rotated(a0) * inner,
			centre + Vector2.RIGHT.rotated(a1) * inner,
			centre + Vector2.RIGHT.rotated(a1) * outer,
			centre + Vector2.RIGHT.rotated(a0) * outer,
		])
		canvas.draw_colored_polygon(pts, Color(hue.r, hue.g, hue.b, 0.30))
		# Give the band a little depth with a lighter rim every few segments.
		if i % 6 == 0:
			canvas.draw_line(centre + Vector2.RIGHT.rotated(a0) * inner,
				centre + Vector2.RIGHT.rotated(a0) * outer, Color(0.0, 0.0, 0.0, 0.20), 1.5)
	canvas.draw_arc(centre, outer + 8.0, 0.0, TAU, 72, Color(accent.r, accent.g, accent.b, 0.20), 2.0, true)
	var breathe: float = 0.10 + 0.05 * sin(time * 1.6)
	canvas.draw_circle(centre, inner - 12.0, Color(0.0, 0.0, 0.0, 0.10))
	canvas.draw_arc(centre, inner - 12.0, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, breathe), 2.0, true)


## THE WHEEL: the champion's arena. Eight spokes from a hue ring, all of it
## turning slowly, because the whole fight is that wheel.
static func _draw_spokes_mark(canvas: CanvasItem, centre: Vector2, time: float, accent: Color) -> void:
	var segments: int = 96
	var inner: float = 128.0
	var outer: float = 158.0
	for i in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var hue: Color = ColorTheory.wheel(float(i) * (360.0 / float(segments)), 0.85, 0.95)
		var pts: PackedVector2Array = PackedVector2Array([
			centre + Vector2.RIGHT.rotated(a0) * inner,
			centre + Vector2.RIGHT.rotated(a1) * inner,
			centre + Vector2.RIGHT.rotated(a1) * outer,
			centre + Vector2.RIGHT.rotated(a0) * outer,
		])
		canvas.draw_colored_polygon(pts, Color(hue.r, hue.g, hue.b, 0.34))

	# The spokes: the same hue wheel reach down towards the dais.
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + time * 0.06
		var hue: Color = ColorTheory.wheel(float(i) * 45.0, 0.7, 0.95)
		var pts: PackedVector2Array = PackedVector2Array()
		var wide: float = 0.055
		pts.append(centre + Vector2.RIGHT.rotated(a - wide) * 190.0)
		pts.append(centre + Vector2.RIGHT.rotated(a + wide) * 190.0)
		pts.append(centre + Vector2.RIGHT.rotated(a + wide * 0.35) * 44.0)
		pts.append(centre + Vector2.RIGHT.rotated(a - wide * 0.35) * 44.0)
		canvas.draw_colored_polygon(pts, Color(hue.r, hue.g, hue.b, 0.13))
	canvas.draw_arc(centre, 190.0, 0.0, TAU, 96, Color(accent.r, accent.g, accent.b, 0.22), 3.0, true)
	canvas.draw_arc(centre, 46.0, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, 0.30), 2.5, true)


# ---------------------------------------------------------------------------
# The stands: crowd, banners and pennants along the border walls
# ---------------------------------------------------------------------------

## The crowd, drawn over the border walls top and bottom, plus the house banners
## hanging into the arena. Purely decorative - nothing here is solid.
static func draw_stands(canvas: CanvasItem, data: Dictionary, time: float) -> void:
	var accent: Color = data.get("accent", Color(1.0, 0.82, 0.25))
	var width: float = LevelData.PLAYFIELD.x
	var band: float = LevelData.WALL

	# --- crowd ----------------------------------------------------------
	# Rows of small silhouettes with a few house-coloured flags mixed in. The
	# wave in the row comes from a sine of x, so the stands are never static.
	var x: float = 26.0
	var index: int = 0
	while x < width - 26.0:
		var wob: float = sin(time * 1.6 + x * 0.05) * 1.6
		var tall: bool = (index % 3) == 0
		var head_y: float = band * 0.5 + wob
		var shade: float = 0.055 + 0.02 * float(index % 4)
		var body: Color = Color(shade, shade, shade + 0.012, 0.95)
		canvas.draw_circle(Vector2(x, head_y - 3.0), 4.2, body)
		canvas.draw_rect(Rect2(x - 5.0, head_y + 1.0, 10.0, 14.0), body, true)
		if index % 5 == 2:
			# A banner in the crowd, in the house's colour.
			canvas.draw_line(Vector2(x, 2.0), Vector2(x, 15.0), Color(0.35, 0.32, 0.28), 1.5)
			canvas.draw_rect(Rect2(x + 1.0, 3.0, 10.0, 7.0), Color(accent.r, accent.g, accent.b, 0.85), true)
		if tall:
			canvas.draw_rect(Rect2(x - 4.0, band - 4.0, 8.0, 5.0), Color(0.02, 0.02, 0.03, 0.9), true)
		x += 21.0
		index += 1

	# The same stands along the bottom, mirrored.
	x = 26.0
	index = 0
	while x < width - 26.0:
		var wob2: float = sin(time * 1.5 + x * 0.06) * 1.6
		var head_y: float = LevelData.PLAYFIELD.y - band * 0.5 + wob2
		var shade2: float = 0.055 + 0.02 * float(index % 3)
		var body2: Color = Color(shade2, shade2, shade2 + 0.012, 0.95)
		canvas.draw_circle(Vector2(x, head_y + 3.0), 4.2, body2)
		canvas.draw_rect(Rect2(x - 5.0, head_y - 15.0, 10.0, 14.0), body2, true)
		x += 21.0
		index += 1

	# --- banners on the walls -------------------------------------------
	for bx in [120.0, 400.0, 880.0, 1160.0]:
		_draw_banner(canvas, Vector2(bx, band), accent, false)
	for bx in [260.0, 640.0, 1020.0]:
		_draw_banner(canvas, Vector2(bx, LevelData.PLAYFIELD.y - band), accent, true)


## One hanging house banner: cloth, gold trim and an emblem ring.
static func _draw_banner(canvas: CanvasItem, top: Vector2, accent: Color, flipped: bool) -> void:
	var h: float = BANNER_H * (1.0 if flipped else 1.0)
	var y0: float = top.y - h if flipped else top.y
	var cloth := Rect2(top.x - BANNER_W * 0.5, y0, BANNER_W, h)
	canvas.draw_rect(cloth, Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.92), true)
	canvas.draw_rect(Rect2(cloth.position, Vector2(cloth.size.x, 4.0)), Color(0.95, 0.80, 0.35, 0.85), true)
	# The notch at the hanging end, so it reads as cloth rather than a sign.
	var tail: float = cloth.end.y if not flipped else cloth.position.y
	var dir: float = 1.0 if not flipped else -1.0
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(cloth.position.x, tail),
		Vector2(cloth.end.x, tail),
		Vector2(cloth.get_center().x, tail + dir * 12.0),
	]), Color(0.0, 0.0, 0.0, 0.35))
	canvas.draw_arc(cloth.get_center(), 8.0, 0.0, TAU, 20, Color(0.95, 0.80, 0.35, 0.75), 2.0, true)


## Sand dust hanging in the air, so the arena is never a still picture. Each
## speck drifts on a couple of slow sines of the clock: cheap, and it makes the
## space feel like a place rather than a diagram.
static func draw_dust(canvas: CanvasItem, time: float, accent: Color) -> void:
	if _dust.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in 44:
			_dust.append(Vector4(
				rng.randf_range(30.0, LevelData.PLAYFIELD.x - 30.0),
				rng.randf_range(40.0, LevelData.PLAYFIELD.y - 40.0),
				rng.randf_range(0.10, 0.34),
				rng.randf_range(10.0, 40.0)))
	for i in _dust.size():
		var d: Vector4 = _dust[i]
		var p: Vector2 = Vector2(
			d.x + sin(time * d.z + float(i)) * d.w,
			d.y + cos(time * d.z * 0.8 + float(i) * 1.7) * d.w * 0.6)
		var alpha: float = 0.06 + 0.05 * (0.5 + 0.5 * sin(time * 0.9 + float(i) * 2.1))
		canvas.draw_circle(p, 1.6, Color(1.0, 0.94, 0.80, alpha))
		if i % 11 == 0:
			# A few larger, house-coloured motes, like chaff off the banners.
			canvas.draw_circle(p, 2.4, Color(accent.r, accent.g, accent.b, alpha * 1.4))


# ---------------------------------------------------------------------------
# Braziers: the light the arena is lit by
# ---------------------------------------------------------------------------

## A stone bowl with a flame in it, plus the warm pool it throws on the sand.
## Purely decoration - it has no collision, so it never blocks a fight.
static func draw_braziers(canvas: CanvasItem, positions: Array, time: float, accent: Color) -> void:
	for i in positions.size():
		var p: Vector2 = positions[i]
		var flick: float = 0.82 + 0.18 * sin(time * 7.3 + float(i) * 1.7) + 0.06 * sin(time * 17.0 + float(i))
		# The pool of light on the sand.
		canvas.draw_circle(p, 78.0 * flick, Color(1.0, 0.62, 0.22, 0.075))
		canvas.draw_circle(p, 44.0 * flick, Color(1.0, 0.70, 0.28, 0.09))
		# Stone base + bowl.
		canvas.draw_rect(Rect2(p.x - 9.0, p.y + 4.0, 18.0, 12.0), Color(0.24, 0.22, 0.20, 0.95), true)
		canvas.draw_rect(Rect2(p.x - 9.0, p.y + 4.0, 18.0, 4.0), Color(0.34, 0.31, 0.28, 0.95), true)
		canvas.draw_rect(Rect2(p.x - 12.0, p.y - 2.0, 24.0, 8.0), Color(0.20, 0.18, 0.17, 0.95), true)
		# The flame: three stacked licks, each flickering a little differently.
		var h1: float = 22.0 * flick
		canvas.draw_circle(p + Vector2(0.0, -6.0), 8.0, Color(1.0, 0.45, 0.12, 0.85))
		canvas.draw_circle(p + Vector2(0.0, -12.0), 5.6, Color(1.0, 0.72, 0.20, 0.90))
		canvas.draw_circle(p + Vector2(0.0, -6.0 - h1 * 0.35), 3.2, Color(1.0, 0.95, 0.62, 0.95))
		# A thin rim of the house colour, so each arena's fire is dressed.
		canvas.draw_arc(p + Vector2(0.0, -6.0), 26.0 * flick, 0.0, TAU, 24,
			Color(accent.r, accent.g, accent.b, 0.10), 2.0, true)
