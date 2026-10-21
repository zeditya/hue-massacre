class_name ArenaArt
extends RefCounted
##
## ARENA ART - the look of the four arenas.
##
## THE PAINTINGS DO THE HEAVY LIFTING
##   Each arena is dressed with a painted backdrop built from the reference
##   art in gpt_assist/ by tools/build_backdrops.py: the painting's flat arena
##   floor is mapped onto the game's walking floor, and the painting's own
##   edge architecture (fences, stairs, gates, stands) rings the arena just
##   inside the walls, in full colour. The code below then layers the living
##   parts on top: stone walls, torchlight, fighter shadows, weather, dust and
##   the crowd shimmer along the rim.
##
## THE ONE RULE THIS FILE MUST NOT BREAK
##   The bare floor is the colour the guards measure the player against
##   (`ColorTheory.visibility`). A colour with saturation under
##   `ColorTheory.GREY_SATURATION` (0.18) counts as "no hue", so the painted
##   floor is desaturated to saturation <= 0.17 when the backdrops are built
##   (see tools/build_backdrops.py) while the rim keeps its full colour. If no
##   backdrop is found, the baked sand below stands in: warm to the eye, grey
##   to the colour rules. `FLOOR_BASE` sits at saturation ~0.16 on purpose.
##
## COST
##   One WebP texture per arena (drawn once per frame) plus a few dozen
##   `draw_*` calls for the living parts.

## Where each painted backdrop lands in world units. Built by
## tools/build_backdrops.py - re-run it and paste the new rects back here if
## the art pipeline changes. Rect index = arena id (0..3).
const BACKDROP_RECTS: Array = [
	Rect2(-95.1, -135.8, 1470.2, 991.7),
	Rect2(-94.0, -162.3, 1468.1, 1044.7),
	Rect2(-95.1, -135.8, 1470.2, 991.7),
	Rect2(-107.6, -183.5, 1495.2, 1087.0),
]

## The rim band (world px inside the playfield edge) where the paintings'
## architecture shows and where the crowd/torch shimmer is drawn.
const RIM: float = 46.0

## Base sand. Saturation 0.138: warm to the eye, grey to the colour rules.
## (Saturation is kept clear of 0.18 rather than merely under it, because the
## 8-bit bake plus the edge vignette can round a pixel up a percent or so.)
const FLOOR_BASE: Color = Color(0.470, 0.445, 0.405)
## The two grain tones the sand is speckled with.
const FLOOR_DARK: Color = Color(0.372, 0.352, 0.320)
const FLOOR_LIGHT: Color = Color(0.552, 0.524, 0.482)
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

## The crowd atlas: five factions (Red, Blue, Yellow, Purple, Black) by four
## props (empty-handed, axe, hammer, meat), eight idle frames each, 64px cells.
## Baked by tools/bake_itch_packs.sh from the Tiny Swords pawn sheets.
const CROWD_PATH: String = "res://assets/units/crowd/pawns.png"
const PAWN_CELL: int = 64
const PAWN_FRAMES: int = 8
const PAWN_ROWS: int = 20
## The row the figures' feet stand on inside a cell, measured off the art.
const PAWN_FEET: float = 45.0

## Weather types
enum Weather { CLEAR, OVERCAST, RAIN, SANDSTORM, ASH }

## Baked per arena id, so an arena is only built once per run.
static var _floors: Dictionary = {}
## The drift positions for the dust, built once and reused every frame.
static var _dust: Array = []
## Crowd members: built once per arena, reused every frame.
static var _crowd: Dictionary = {}
## Banner states per arena
static var _banners: Dictionary = {}
## Torch states per arena
static var _torches: Dictionary = {}
## Weather state per arena
static var _weather: Dictionary = {}
## Crowd excitement (0.0 to 1.0) - reacts to combat
static var _crowd_excitement: Dictionary = {}
## Sun angle per arena (slowly rotates)
static var _sun_angles: Dictionary = {}
## Loaded painted backdrops, keyed by arena id (null = missing asset).
static var _backdrops: Dictionary = {}
## The crowd pawn atlas, loaded once for every stand in every arena.
static var _pawn_atlas: Texture2D = null
## The two fire sheets (Tiny Swords particle FX): the campfire loop and the
## taller one the braziers burn.
static var _fire_sheet_cache: Dictionary = {}

## Arena depth layers (for Y-sorting illusion)
const LAYER_GROUND: int = 0
const LAYER_LOW_WALLS: int = 10
const LAYER_INTERACTIVE: int = 20
const LAYER_FIGHTERS: int = 30
const LAYER_UPPER_DECOR: int = 40
const LAYER_FOREGROUND: int = 50
const LAYER_OVERLAY: int = 100

## Weather configuration
const WEATHER_CHANGE_INTERVAL: float = 120.0  # seconds between weather shifts
const RAIN_DROP_COUNT: int = 200
const SANDSTORM_PARTICLE_COUNT: int = 150
const ASH_PARTICLE_COUNT: int = 100


## The baked sand for this arena. Falls back to null if baking ever fails, in
## which case room.gd draws its flat grey floor instead.
static func floor_texture(data: Dictionary) -> ImageTexture:
	var key: int = int(data.get("id", 0))
	if not _floors.has(key):
		_floors[key] = _bake(key, data.get("stones", {}))
	return _floors[key]


# ---------------------------------------------------------------------------
# Painted backdrops - NOT SHIPPED, kept only as an idea
# ---------------------------------------------------------------------------
#
# tools/build_backdrops.py can bake 2.5D arena paintings from the reference
# images in gpt_assist/. Those paintings are derived from the paid reference
# pack, so they are not in the repo, not in the export, and NOT DRAWN: every
# arena here is built in code from our own and licensed art. The arena may look
# like the reference. It may not contain its pixels.
#
# The lookup below is therefore a dormant path: it finds nothing, returns null,
# and the all-code floor in _bake() is what actually renders.

## The painting for this arena, loaded once and kept. Returns null when the
## asset is missing, which sends draw_arena down its all-code fallback path.
static func backdrop_texture(arena_id: int) -> Texture2D:
	if _backdrops.has(arena_id):
		return _backdrops[arena_id]
	var tex: Texture2D = null
	var path: String = "res://assets/arenas/arena_%02d.webp" % (arena_id + 1)
	if ResourceLoader.exists(path):
		tex = load(path)
	_backdrops[arena_id] = tex
	return tex


## Paint the arena floor. Returns true when a painting was drawn.
static func draw_backdrop(canvas: CanvasItem, arena_id: int) -> bool:
	var tex: Texture2D = backdrop_texture(arena_id)
	if tex == null:
		return false
	var idx: int = clampi(arena_id, 0, BACKDROP_RECTS.size() - 1)
	canvas.draw_texture_rect(tex, BACKDROP_RECTS[idx], false)
	return true


static func _bake(seed_id: int, stones: Dictionary = {}) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261018 + seed_id

	var base: Color = stones.get("base", FLOOR_BASE)
	var dark: Color = stones.get("dark", FLOOR_DARK)
	var light: Color = stones.get("light", FLOOR_LIGHT)
	var grout: Color = base.darkened(0.34)

	var img: Image = Image.create(BAKE_W, BAKE_H, false, Image.FORMAT_RGBA8)
	img.fill(grout)

	var cx: float = float(BAKE_W) * 0.5
	var cy: float = float(BAKE_H) * 0.5
	var half_diag: float = sqrt(cx * cx + cy * cy)

	# Bricks: 10x5 bake px = 20x10 world px each (40x20 screen px at the camera
	# zoom), laid in a running bond - every second course is offset by half a
	# brick. The 1px gaps show the grout fill through, and the joints running
	# WITH the course are what make a floor read as masonry instead of graph
	# paper. The tone range is tight on purpose: a laid floor is calm, and the
	# eye should be caught by fighters, fires and banners, never by the stone.
	var bw: int = 10
	var bh: int = 5
	var row: int = 0
	var gy: int = 0
	while gy < BAKE_H:
		var offset: int = 0 if row % 2 == 0 else -bw / 2
		var gx: int = offset
		while gx < BAKE_W:
			var t: float = rng.randf()
			var tone: Color = base
			if t < 0.06:
				tone = base.lerp(dark, 0.55)
			elif t > 0.94:
				tone = base.lerp(light, 0.55)
			else:
				tone = base.lerp(light if t > 0.5 else dark, absf(t - 0.5) * 0.35)

			# The rim of the arena darkens, so the middle of the room reads lit.
			var d: float = Vector2(float(gx) - cx, float(gy) - cy).length() / half_diag
			var shade: float = 1.0 - FLOOR_EDGE_DARKEN * clampf(d, 0.0, 1.0) * 0.5
			tone = Color(tone.r * shade, tone.g * shade, tone.b * shade, 1.0)

			var wy: int = gy
			while wy < mini(gy + bh - 1, BAKE_H):
				if wy >= 0:
					var wx: int = maxi(gx, 0)
					while wx < mini(gx + bw - 1, BAKE_W):
						img.set_pixel(wx, wy, tone)
						wx += 1
				wy += 1

			# Now and then a brick is cracked, or chipped at its corner. Both
			# are rare on purpose: damage should mark places, not speckle the
			# whole floor.
			var w0: int = maxi(gx, 0)
			var w1: int = mini(gx + bw - 2, BAKE_W - 1)
			var h1: int = mini(gy + bh - 2, BAKE_H - 1)
			if w1 > w0 and h1 >= gy and gy >= 0:
				var wear: float = rng.randf()
				if wear < 0.06:
					var cxx: int = rng.randi_range(w0, w1)
					var cyy: int = rng.randi_range(gy, h1)
					var dir: int = 1 if rng.randf() < 0.5 else -1
					for i2 in rng.randi_range(2, 4):
						var px2: int = clampi(cxx + dir * i2, w0, w1)
						var py2: int = clampi(cyy + rng.randi_range(-1, 1), gy, h1)
						if px2 < BAKE_W and py2 < BAKE_H:
							img.set_pixel(px2, py2, grout.darkened(0.15))
				elif wear > 0.985:
					img.set_pixel(w1, h1, grout)

			gx += bw
		row += 1
		gy += bh

	# Old stains baked into the stone.
	_add_baked_details(img, rng, base)

	return ImageTexture.create_from_image(img)


static func _add_baked_details(img: Image, rng: RandomNumberGenerator, base: Color = FLOOR_BASE) -> void:
	# A few permanent dark stains (old blood, oil, etc.), very soft: they are
	# texture, not decoration.
	for i in range(6):
		var x: int = rng.randi_range(50, BAKE_W - 50)
		var y: int = rng.randi_range(50, BAKE_H - 50)
		var radius: int = rng.randi_range(3, 12)
		var darkness: float = rng.randf_range(0.10, 0.22)
		var stain_colour: Color = Color(
			base.r * (1.0 - darkness),
			base.g * (1.0 - darkness),
			base.b * (1.0 - darkness),
			1.0
		)
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy <= radius * radius:
					var px: int = x + dx
					var py: int = y + dy
					if px >= 0 and px < BAKE_W and py >= 0 and py < BAKE_H:
						var existing: Color = img.get_pixel(px, py)
						img.set_pixel(px, py, existing.lerp(stain_colour, 0.25))

	# A couple of long hairline cracks, the kind that run across several stones.
	for i in range(3):
		var start_x: int = rng.randi_range(0, BAKE_W)
		var start_y: int = rng.randi_range(0, BAKE_H)
		var length: int = rng.randi_range(20, 60)
		var angle: float = rng.randf() * TAU
		var crack_colour: Color = Color(base.r * 0.55, base.g * 0.55, base.b * 0.55, 0.6)
		for j in range(length):
			var px: int = int(start_x + cos(angle) * j)
			var py: int = int(start_y + sin(angle) * j)
			if px >= 0 and px < BAKE_W and py >= 0 and py < BAKE_H:
				var existing: Color = img.get_pixel(px, py)
				img.set_pixel(px, py, existing.lerp(crack_colour, 0.22))
			angle += rng.randf_range(-0.3, 0.3)


# ---------------------------------------------------------------------------
# The raised block - how every wall of the arena is drawn
# ---------------------------------------------------------------------------

## ONE WALL as a raised slab of stone. The rect is the collision footprint;
## `lift` shifts a lit top surface north of it and `face_h` reserves the bottom
## band for the dark face that looks at the camera. Footprint + face + lifted
## top = a block with height, which is the whole trick: the flat rectangle
## becomes masonry you can stand behind.
##
## The stone is laid BRICK BY BRICK (each one gets its own tone from a hash of
## its course and column), because a block of one flat colour reads as a
## rectangle no matter how nice its outline is. The joints between bricks are
## what the eye actually uses to believe in the stone.
##
## Called with LOCAL coordinates from WallNode, whose position is the wall's
## ground line (the y-sort key).
static func draw_block(canvas: CanvasItem, r: Rect2, tint: Color, lift: float, face_h: float) -> void:
	var w: float = r.size.x
	var face: float = clampf(face_h, 4.0, maxf(r.size.y - 2.0, 4.0))
	var top_y: float = r.position.y - lift
	var top_h: float = maxf((r.end.y - face) - top_y, 3.0)

	# The cast shadow on the floor SOUTH of the block, where the sun drops it.
	canvas.draw_rect(Rect2(r.position.x + 4.0, r.end.y - 1.0, w, 10.0), Color(0.0, 0.0, 0.0, 0.07), true)
	canvas.draw_rect(Rect2(r.position.x + 2.0, r.end.y - 2.0, w, 6.0), Color(0.0, 0.0, 0.0, 0.13), true)
	# And the contact shadow inside the footprint, so the block is seated.
	canvas.draw_rect(Rect2(r.position.x, r.end.y - 5.0, w, 5.0), Color(0.0, 0.0, 0.0, 0.24), true)

	# The face that looks at the camera: the wall's height, in shadow. Laid in
	# courses too, but each course is a single long stone - it is a face, not a
	# floor, and the eye should read vertical height here.
	var face_col: Color = tint.darkened(0.40)
	var fy: float = r.end.y - face + 3.0
	var course_i: int = 0
	while fy < r.end.y - 2.0:
		var band_h: float = minf(9.0, r.end.y - 2.0 - fy)
		var tone: Color = face_col
		if course_i % 2 == 1:
			tone = face_col.lightened(0.06)
		canvas.draw_rect(Rect2(r.position.x, fy, w, band_h), tone, true)
		canvas.draw_line(Vector2(r.position.x + 1.0, fy), Vector2(r.end.x - 1.0, fy),
			Color(0.0, 0.0, 0.0, 0.22), 1.0)
		course_i += 1
		fy += 9.0
	var jx: float = r.position.x + 12.0
	while jx < r.end.x - 4.0:
		canvas.draw_line(Vector2(jx, r.end.y - face + 3.0), Vector2(jx, r.end.y - 3.0),
			Color(0.0, 0.0, 0.0, 0.22), 1.0)
		jx += 17.0
	# Under the lit top slab the face is deepest: the block's own shadow.
	canvas.draw_rect(Rect2(r.position.x, r.end.y - face, w, 3.0), Color(0.0, 0.0, 0.0, 0.34), true)
	canvas.draw_line(Vector2(r.position.x, r.end.y - 1.0), Vector2(r.end.x, r.end.y - 1.0),
		Color(0.0, 0.0, 0.0, 0.50), 1.5)

	# The lit top surface, lifted north: the lie that gives it height. It is
	# clearly LIGHTER than the floor, because that is what a stone catching the
	# sun looks like, and the read of "raised block" lives in that contrast.
	var top: Rect2 = Rect2(r.position.x, top_y, w, top_h)
	var top_col: Color = tint.lerp(Color(1.0, 0.95, 0.86), 0.52)
	canvas.draw_rect(top, top_col, true)

	# Brick by brick, in a running bond. The tone jitter is tiny (±4%) but it
	# is the difference between "stone" and "grey paint".
	var course: float = 11.0
	var row: int = 0
	var cy: float = top_y
	while cy < top.end.y - 1.0:
		var band_h: float = minf(course, top.end.y - cy)
		var off: float = 0.0 if row % 2 == 0 else 8.0
		var bx: float = r.position.x - 16.0 + off
		while bx < top.end.x:
			var b0: float = maxf(bx, top.position.x)
			var b1: float = minf(bx + 16.0, top.end.x)
			if b1 > b0 + 1.0:
				var hash: float = fposmod(float(row) * 12.9898 + float(int(bx) / 16) * 78.233, 1.0)
				var brick: Color = top_col.darkened(0.05 * hash) if hash < 0.5 else top_col.lightened(0.06 * (hash - 0.5))
				canvas.draw_rect(Rect2(b0, cy, b1 - b0, band_h), brick, true)
				canvas.draw_line(Vector2(b0, cy), Vector2(b0, cy + band_h), Color(0.0, 0.0, 0.0, 0.24), 1.0)
			bx += 16.0
		canvas.draw_line(Vector2(top.position.x + 1.0, cy), Vector2(top.end.x - 1.0, cy),
			Color(0.0, 0.0, 0.0, 0.24), 1.0)
		row += 1
		cy += course
	# The sun catches the north edge of the top: the single brightest line of
	# the block, and the reason the height reads at a glance.
	canvas.draw_line(Vector2(top.position.x, top_y + 0.5), Vector2(top.end.x, top_y + 0.5),
		Color(1.0, 0.97, 0.90, 0.30), 1.5)
	# The ends of the block catch a little light too.
	canvas.draw_line(Vector2(top.position.x + 0.5, top_y), Vector2(top.position.x + 0.5, top.end.y),
		Color(1.0, 0.97, 0.90, 0.14), 1.0)
	canvas.draw_line(Vector2(top.end.x - 0.5, top_y), Vector2(top.end.x - 0.5, top.end.y),
		Color(0.0, 0.0, 0.0, 0.20), 1.0)
	# A hard outline around the whole block: against a floor of the same stone
	# this is what keeps the silhouette readable.
	canvas.draw_rect(Rect2(top.position.x, top_y, w, r.end.y - top_y), Color(0.0, 0.0, 0.0, 0.34), false, 1.0)


# ---------------------------------------------------------------------------
# Props - the arena's furniture, drawn from their base (like the fighters)
# ---------------------------------------------------------------------------

## A watch-fire torch: a dark post with a burning head. Stands on the ring wall.
static func draw_torch(canvas: CanvasItem, base: Vector2, time: float, accent: Color) -> void:
	var flick: float = 0.8 + 0.2 * sin(time * 8.7 + base.x * 0.13)
	# Shadow on the stones.
	canvas.draw_ellipse(base + Vector2(3.0, 1.0), 9.0, 3.5, Color(0.0, 0.0, 0.0, 0.30))
	# Post.
	canvas.draw_rect(Rect2(base.x - 2.5, base.y - 26.0, 5.0, 26.0), Color(0.20, 0.17, 0.15))
	canvas.draw_rect(Rect2(base.x - 2.5, base.y - 26.0, 2.0, 26.0), Color(0.28, 0.24, 0.21))
	# Head: coals, then a real flame looped over them.
	canvas.draw_circle(base + Vector2(0.0, -27.0), 5.5, Color(0.16, 0.13, 0.12))
	canvas.draw_circle(base + Vector2(0.0, -27.0), 4.0, Color(0.85, 0.32, 0.08, 0.9))
	draw_fire(canvas, base + Vector2(0.0, -29.0), 1.0, time, base.y * 0.07, false)
	# A fleck of the house colour in the flame, so each arena burns its own way.
	canvas.draw_circle(base + Vector2(-1.0, -33.0), 1.3, Color(accent.r, accent.g, accent.b, 0.75))


## One looping flame from the Tiny Swords particle sheets, based at `base` and
## drawn upward. `tall` picks the brazier's fire over the campfire's. Fire is
## the one thing in the arena that keeps its own colour: hue is the game's
## language, but a cold flame reads as a mistake.
static func draw_fire(canvas: CanvasItem, base: Vector2, scale: float, time: float,
		phase: float, tall: bool) -> void:
	var path: String = "res://assets/fx/fire_tall.png" if tall else "res://assets/fx/fire.png"
	if not _fire_sheet_cache.has(path):
		_fire_sheet_cache[path] = load(path)
	var tex: Texture2D = _fire_sheet_cache[path]
	if tex == null:
		return
	var frames: int = 12 if tall else 8
	var cell: float = 32.0
	var f: int = int(fposmod(time * (11.0 if tall else 13.0) + phase * 40.0, float(frames)))
	var source := Rect2(float(f) * cell, 0.0, cell, cell)
	var size: float = cell * scale
	# The flame stands ON its base and the cell's empty top is kept, so the fire
	# does not hop up and down as the frames change height.
	var dest := Rect2(base.x - size * 0.5, base.y - size, size, size)
	canvas.draw_texture_rect_region(tex, dest, source, Color(1.0, 1.0, 1.0, 0.96))


## A herald pillar: square plinth, shaft, and a capital that caught the sun.
## Drawn 46px tall from the base; its collision is the plinth footprint.
static func draw_pillar(canvas: CanvasItem, base: Vector2, scale: float, accent: Color) -> void:
	var s: float = maxf(scale, 0.4)
	var half: float = 11.0 * s
	var tall: float = 44.0 * s
	# Shadow.
	canvas.draw_ellipse(base + Vector2(5.0, 1.0), half * 1.7, 6.0 * s, Color(0.0, 0.0, 0.0, 0.28))
	# Plinth. The stone is LIGHT and warm, like the wall tops: the props are
	# lit by the same sun as the architecture, and a dark prop on a dark wall
	# disappears into it.
	var stone: Color = Color(0.55, 0.51, 0.46)
	var stone_lit: Color = Color(0.66, 0.61, 0.55)
	var outline: Color = Color(0.0, 0.0, 0.0, 0.32)
	canvas.draw_rect(Rect2(base.x - half * 1.35, base.y - 9.0 * s, half * 2.7, 9.0 * s), stone.darkened(0.16))
	canvas.draw_rect(Rect2(base.x - half * 1.35, base.y - 9.0 * s, half * 2.7, 3.0 * s), stone_lit.darkened(0.05))
	canvas.draw_rect(Rect2(base.x - half * 1.35, base.y - 9.0 * s, half * 2.7, 9.0 * s), outline, false, 1.0)
	# Shaft, with a lit left edge and a coarse vertical joint.
	var shaft: Rect2 = Rect2(base.x - half, base.y - tall, half * 2.0, tall - 9.0 * s)
	canvas.draw_rect(shaft, stone)
	canvas.draw_rect(Rect2(shaft.position.x, shaft.position.y, shaft.size.x * 0.34, shaft.size.y), stone_lit)
	canvas.draw_line(Vector2(base.x + half * 0.15, shaft.position.y + 3.0),
		Vector2(base.x + half * 0.15, shaft.end.y - 3.0), Color(0.0, 0.0, 0.0, 0.22), 1.0)
	canvas.draw_rect(shaft, outline, false, 1.0)
	# Capital, with the house colour band that names the arena.
	canvas.draw_rect(Rect2(base.x - half * 1.25, base.y - tall - 6.0 * s, half * 2.5, 6.0 * s),
		stone_lit.darkened(0.03))
	canvas.draw_rect(Rect2(base.x - half * 1.25, base.y - tall - 2.0 * s, half * 2.5, 2.0 * s),
		Color(accent.r, accent.g, accent.b, 0.85))
	canvas.draw_rect(Rect2(base.x - half * 1.25, base.y - tall - 6.0 * s, half * 2.5, 6.0 * s),
		outline, false, 1.0)


## A pile of fallen masonry: broken stones heaped at the wall's foot. Clutter,
## never a collision - the room decides separately what is solid.
static func draw_rubble(canvas: CanvasItem, base: Vector2, scale: float) -> void:
	var s: float = maxf(scale, 0.4)
	canvas.draw_ellipse(base + Vector2(0.0, 1.0), 22.0 * s, 8.0 * s, Color(0.0, 0.0, 0.0, 0.20))
	var stones: Array = [
		[Vector2(-14.0, -4.0), 9.0, 6.0, Color(0.34, 0.31, 0.29)],
		[Vector2(-2.0, -7.0), 11.0, 8.0, Color(0.40, 0.36, 0.33)],
		[Vector2(11.0, -3.0), 8.0, 6.0, Color(0.31, 0.28, 0.27)],
		[Vector2(3.0, -2.0), 7.0, 5.0, Color(0.44, 0.40, 0.36)],
	]
	for st in stones:
		var p: Vector2 = base + st[0] * s
		canvas.draw_rect(Rect2(p.x - st[1] * s, p.y - st[2] * s, st[1] * 2.0 * s, st[2] * 2.0 * s), st[3])
		canvas.draw_rect(Rect2(p.x - st[1] * s, p.y - st[2] * s, st[1] * 2.0 * s, st[2] * 0.6 * s),
			Color(st[3].r * 1.25, st[3].g * 1.25, st[3].b * 1.25, 1.0))
	# A couple of scattered pebbles beyond the heap.
	canvas.draw_circle(base + Vector2(-24.0 * s, 0.0), 2.4 * s, Color(0.33, 0.30, 0.28))
	canvas.draw_circle(base + Vector2(21.0 * s, -2.0 * s), 2.0 * s, Color(0.36, 0.33, 0.30))


## Old bones: a skull and two long bones, half sunk in the sand. The arena has
## been here a long time.
static func draw_bones(canvas: CanvasItem, base: Vector2) -> void:
	canvas.draw_ellipse(base + Vector2(0.0, 1.0), 14.0, 4.0, Color(0.0, 0.0, 0.0, 0.16))
	var bone: Color = Color(0.78, 0.75, 0.66)
	# Skull.
	canvas.draw_circle(base + Vector2(-2.0, -4.0), 5.0, bone)
	canvas.draw_rect(Rect2(-6.0 + base.x, -2.0 + base.y, 8.0, 4.0), bone)
	canvas.draw_circle(base + Vector2(-4.0, -5.0), 1.3, Color(0.18, 0.16, 0.15))
	canvas.draw_circle(base + Vector2(0.5, -5.0), 1.3, Color(0.18, 0.16, 0.15))
	# Two bones, one angled.
	canvas.draw_line(base + Vector2(6.0, -1.0), base + Vector2(17.0, -5.0), bone, 2.4)
	canvas.draw_line(base + Vector2(-15.0, -1.5), base + Vector2(-7.0, -2.5), bone, 2.2)


## A soft pool of firelight on the stones, for the floor pass. Braziers and
## torches each get one; together with the darkness shader they are why the
## arena still reads at night.
static func draw_light_pool(canvas: CanvasItem, pos: Vector2, radius: float, time: float, accent: Color) -> void:
	var flick: float = 0.86 + 0.14 * sin(time * 7.9 + pos.x * 0.11) + 0.05 * sin(time * 19.0 + pos.y * 0.07)
	# Six stacked discs with a smooth alpha ramp: firelight over cold stone
	# reads as a glow only if the core is clearly hotter than the rim. Fewer,
	# bigger steps would show their own edge as a hard circle on the floor.
	var ramp: Array[float] = [0.030, 0.045, 0.065, 0.095, 0.150, 0.220]
	var extent: Array[float] = [1.00, 0.86, 0.72, 0.58, 0.40, 0.22]
	for i in ramp.size():
		var warm: Color = Color(1.0, 0.55 + 0.05 * float(i), 0.16 + 0.05 * float(i), ramp[i])
		canvas.draw_circle(pos + Vector2(0.0, 4.0 * (1.0 - extent[i])), radius * extent[i] * flick, warm)
	canvas.draw_arc(pos + Vector2(0.0, 2.0), radius * 0.9 * flick, 0.0, TAU, 40,
		Color(accent.r, accent.g, accent.b, 0.07), 2.0, true)


## A brazier: the squat stone bowl, a live flame and rising embers. The room
## draws its light pool separately on the floor pass, so the glow is always
## under the fighters, never pasted over them.
static func draw_brazier(canvas: CanvasItem, base: Vector2, time: float, accent: Color) -> void:
	var idx: int = int(base.x) * 7 + int(base.y) * 13
	var key: String = "brazier_%d" % idx
	if not _torches.has(key):
		_torches[key] = {
			"flame_offset": fposmod(float(idx) * 0.61803, 1.0) * TAU,
			"ember_particles": [],
		}
	var state: Dictionary = _torches[key]
	var flick: float = 0.82 + 0.18 * sin(time * 7.3 + state.flame_offset) + 0.06 * sin(time * 17.0 + float(idx))

	# Bowl shadow on the stones.
	canvas.draw_ellipse(base + Vector2(4.0, 1.0), 16.0, 6.0, Color(0.0, 0.0, 0.0, 0.28))
	# Stone base + bowl.
	canvas.draw_rect(Rect2(base.x - 10.0, base.y - 10.0, 20.0, 10.0), Color(0.24, 0.22, 0.20))
	canvas.draw_rect(Rect2(base.x - 10.0, base.y - 10.0, 20.0, 3.0), Color(0.34, 0.31, 0.28))
	canvas.draw_rect(Rect2(base.x - 14.0, base.y - 18.0, 28.0, 9.0), Color(0.19, 0.17, 0.16))
	canvas.draw_rect(Rect2(base.x - 13.0, base.y - 17.0, 26.0, 7.0), Color(0.26, 0.23, 0.21))
	canvas.draw_line(Vector2(base.x - 13.0, base.y - 17.0), Vector2(base.x + 13.0, base.y - 17.0),
		Color(0.38, 0.33, 0.28, 0.7), 1.0)

	# The flame, in three tongues. A real fire burns over the coals: the sprite
	# loop carries its own flicker, and the embers below are drawn from the
	# same clock so the two never disagree.
	var wob: float = sin(time * 12.0 + state.flame_offset) * 1.5
	draw_fire(canvas, base + Vector2(wob, -15.0), 1.0, time, state.flame_offset, true)
	canvas.draw_circle(base + Vector2(wob * 0.4, -20.0), 4.0 * flick, Color(1.0, 0.62, 0.16, 0.55))

	# Embers drift up and die.
	if randf() < 0.15 * flick:
		state.ember_particles.append({
			"pos": base + Vector2(randf_range(-8.0, 8.0), -22.0),
			"vel": Vector2(randf_range(-15.0, 15.0), randf_range(-60.0, -20.0)),
			"life": randf_range(0.5, 1.5),
			"age": 0.0,
			"size": randf_range(1.5, 3.5),
			"colour": Color(1.0, randf_range(0.4, 0.7), 0.05, 1.0),
		})
	var j: int = state.ember_particles.size() - 1
	while j >= 0:
		var ember: Dictionary = state.ember_particles[j]
		ember["age"] = float(ember["age"]) + 1.0 / 60.0
		if float(ember["age"]) >= float(ember["life"]):
			state.ember_particles.remove_at(j)
			j -= 1
			continue
		ember["pos"] = Vector2(ember["pos"]) + Vector2(ember["vel"]) * (1.0 / 60.0)
		ember["vel"] = Vector2(ember["vel"]) + Vector2(0.0, 20.0) * (1.0 / 60.0)
		var life_t: float = 1.0 - float(ember["age"]) / float(ember["life"])
		var col: Color = ember["colour"]
		canvas.draw_circle(ember["pos"], float(ember["size"]) * (0.6 + life_t * 0.6),
			Color(col.r, col.g, col.b, life_t * 0.85))
		j -= 1


static func draw_braziers(canvas: CanvasItem, positions: Array, time: float, accent: Color) -> void:
	for i in positions.size():
		var p: Vector2 = positions[i]
		draw_light_pool(canvas, p, 95.0, time, accent)
		draw_brazier(canvas, p, time, accent)


# ---------------------------------------------------------------------------
# Dressing from the packs - rocks, bushes, timber, gold, the standing stones
# ---------------------------------------------------------------------------

## Every prop the melee dresses itself with, straight out of the packs. Each
## file is trimmed to its content with its base on the cell's bottom edge (see
## tools/bake_itch_packs.sh), so a prop is drawn from its base exactly like a
## fighter: "frames" > 1 means the file is a strip of that many cells wide.
##
## "scale" is how big to draw it. A rock is a rock; a tree at pack size would
## be a forest.
const DECOR: Dictionary = {
	"rock": { "path": "res://assets/props/rock%d.png", "variants": 4, "frames": 1, "fps": 0.0, "scale": 1.0 },
	"stump": { "path": "res://assets/props/stump%d.png", "variants": 4, "frames": 1, "fps": 0.0, "scale": 1.0 },
	"gold": { "path": "res://assets/props/gold%d.png", "variants": 6, "frames": 1, "fps": 0.0, "scale": 1.0 },
	"tool": { "path": "res://assets/props/tool%d.png", "variants": 4, "frames": 1, "fps": 0.0, "scale": 0.9 },
	"wood": { "path": "res://assets/props/wood.png", "variants": 1, "frames": 1, "fps": 0.0, "scale": 1.0 },
	"meat": { "path": "res://assets/props/meat.png", "variants": 1, "frames": 1, "fps": 0.0, "scale": 1.0 },
	"bush": { "path": "res://assets/props/bush.png", "variants": 1, "frames": 8, "fps": 6.0, "scale": 1.0 },
	"sheep": { "path": "res://assets/props/sheep.png", "variants": 1, "frames": 6, "fps": 5.0, "scale": 1.0 },
	"tree": { "path": "res://assets/props/tree.png", "variants": 1, "frames": 8, "fps": 3.0, "scale": 0.7 },
	"statue_soldier": { "path": "res://assets/props/statue_soldier.png", "variants": 1, "frames": 1, "fps": 0.0, "scale": 1.0 },
	"statue_orc": { "path": "res://assets/props/statue_orc.png", "variants": 1, "frames": 1, "fps": 0.0, "scale": 1.0 },
}

static var _decor_textures: Dictionary = {}


static func _decor_texture(path: String) -> Texture2D:
	if not _decor_textures.has(path):
		_decor_textures[path] = load(path)
	return _decor_textures[path]


## One prop, drawn from its base. The variant is picked from where the prop
## stands, so a rock never changes shape between frames - or between runs.
static func draw_decor(canvas: CanvasItem, base: Vector2, kind: String, time: float, scale: float) -> void:
	if not DECOR.has(kind):
		return
	var spec: Dictionary = DECOR[kind]
	var variants: int = int(spec["variants"])
	# The baked files are numbered from one, so the variant is too.
	var variant: int = int(fposmod(base.x * 0.173 + base.y * 0.317, 1.0) * float(variants)) + 1
	var path: String = (str(spec["path"]) % variant) if variants > 1 else str(spec["path"])
	var tex: Texture2D = _decor_texture(path)
	if tex == null:
		return
	var frames: int = int(spec["frames"])
	var cell_w: float = tex.get_width() / float(frames)
	var cell_h: float = float(tex.get_height())
	var size: float = float(spec["scale"]) * scale
	var f: int = 0
	if frames > 1:
		f = int(fposmod(time * float(spec["fps"]), float(frames)))
	var w: float = cell_w * size
	var h: float = cell_h * size
	# A soft shadow, so the prop sits in the sand instead of on top of it.
	canvas.draw_ellipse(base + Vector2(1.0, 0.0), maxf(w * 0.34, 3.0), maxf(h * 0.10, 2.0),
		Color(0.0, 0.0, 0.0, 0.20))
	canvas.draw_texture_rect_region(tex, Rect2(base.x - w * 0.5, base.y - h, w, h),
		Rect2(float(f) * cell_w, 0.0, cell_w, cell_h), Color(1.0, 1.0, 1.0, 1.0))


# ---------------------------------------------------------------------------
# Effects from the packs - the impact, the blood, the dust, the magic
# ---------------------------------------------------------------------------

## One-shot effects, cut into strips by the bake script. Everything that has to
## take a hue is grey in the file: the pack's own colour is thrown away and the
## effect is painted in the colour the moment calls for - a knight's blood is
## his hue, a shatter is the Unsworn's, a summon arrives in the summoned hue.
const FX: Dictionary = {
	"impact": { "path": "res://assets/fx/impact.png", "frames": 7, "cell": 48.0, "scale": 1.0 },
	"splatter": { "path": "res://assets/fx/splatter.png", "frames": 10, "cell": 64.0, "scale": 1.0 },
	"magic": { "path": "res://assets/fx/magic.png", "frames": 15, "cell": 48.0, "scale": 1.3 },
	"explosion": { "path": "res://assets/fx/explosion.png", "frames": 8, "cell": 64.0, "scale": 1.3 },
	"splash": { "path": "res://assets/fx/splash.png", "frames": 9, "cell": 64.0, "scale": 1.0 },
	"dust": { "path": "res://assets/fx/dust.png", "frames": 8, "cell": 32.0, "scale": 1.0 },
	"lightning": { "path": "res://assets/fx/lightning.png", "frames": 7, "cell": 64.0, "scale": 1.0 },
	# The THORN-SWORN's root answering: the pack's own Heal_Effect, eleven frames
	# of a bowl of light rising around whoever was mended. Greyed in the bake, so
	# it is painted in the healer's hue - the player can tell which sworn's
	# support is keeping which ally alive.
	"heal": { "path": "res://assets/fx/heal.png", "frames": 11, "cell": 96.0, "scale": 1.0 },
}

static var _fx_textures: Dictionary = {}


static func _fx_texture(path: String) -> Texture2D:
	if not _fx_textures.has(path):
		_fx_textures[path] = load(path)
	return _fx_textures[path]


## Draw one effect, `t` running 0..1 through its life. The frame is read off t,
## so the animation and the lifetime can never drift apart, and an effect that
## is interrupted is simply dropped.
static func draw_fx(canvas: CanvasItem, effect: String, pos: Vector2, colour: Color,
		t: float, scale: float = 1.0) -> void:
	if not FX.has(effect):
		return
	var spec: Dictionary = FX[effect]
	var tex: Texture2D = _fx_texture(str(spec["path"]))
	if tex == null:
		return
	var frames: int = int(spec["frames"])
	var cell: float = float(spec["cell"])
	var f: int = clampi(int(t * float(frames)), 0, frames - 1)
	var size: float = cell * float(spec["scale"]) * scale
	var dest := Rect2(pos.x - size * 0.5, pos.y - size * 0.5, size, size)
	canvas.draw_texture_rect_region(tex, dest, Rect2(float(f) * cell, 0.0, cell, cell), colour)


# ---------------------------------------------------------------------------
# Walls (flat fallback look, kept for the no-bake path)
# ---------------------------------------------------------------------------

## Every wall block, drawn as cut stone: a lit cap, the body, a shadowed lip and
## brick courses. Three cheap bands turn what used to be a flat grey rectangle
## into something that reads as a solid object, which matters when the whole
## arena is built out of them.
static func draw_walls(canvas: CanvasItem, walls: Array, tint: Color) -> void:
	for r in walls:
		_draw_wall(canvas, r, tint)


## The four border walls get their own treatment when a painting is up: the
## paintings already carry the arena's real rim architecture, so the border is
## drawn as a translucent shadowed band with a hard inner lip instead of a
## solid course of bricks - the collision edge still reads, the art still
## breathes.
static func draw_border_walls(canvas: CanvasItem, walls: Array, tint: Color) -> void:
	for i in mini(4, walls.size()):
		var r: Rect2 = walls[i]
		var shade: Color = Color(tint.r * 0.34, tint.g * 0.33, tint.b * 0.36, 0.66)
		canvas.draw_rect(r, shade, true)
		# The inner lip: which side of the rect faces the arena, and so gets
		# the lit edge that tells the eye "this is the wall, that is the floor".
		var lip: Color = Color(1.0, 1.0, 1.0, 0.10)
		var dark: Color = Color(0.0, 0.0, 0.0, 0.42)
		if r.size.x > r.size.y:
			if r.position.y <= 1.0:
				canvas.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), dark, 3.0)
				canvas.draw_line(Vector2(r.position.x, r.end.y - 2.5), Vector2(r.end.x, r.end.y - 2.5), lip, 1.5)
			else:
				canvas.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), dark, 3.0)
				canvas.draw_line(Vector2(r.position.x, r.position.y + 2.5), Vector2(r.end.x, r.position.y + 2.5), lip, 1.5)
		else:
			if r.position.x <= 1.0:
				canvas.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), dark, 3.0)
				canvas.draw_line(Vector2(r.end.x - 2.5, r.position.y), Vector2(r.end.x - 2.5, r.end.y), lip, 1.5)
			else:
				canvas.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), dark, 3.0)
				canvas.draw_line(Vector2(r.position.x + 2.5, r.position.y), Vector2(r.position.x + 2.5, r.end.y), lip, 1.5)


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
	# A few chips of lighter and darker stone, so the face is not a flat wash.
	# Placed from a hash of the rect, so they never shimmer between frames.
	var chip_seed: int = int(r.position.x) * 31 + int(r.position.y) * 17 + int(r.size.x)
	for i in 10:
		var h: float = fposmod(float(chip_seed + i * 97) * 0.61803, 1.0)
		var v: float = fposmod(float(chip_seed + i * 53) * 0.38197, 1.0)
		var cp: Vector2 = r.position + Vector2(2.0 + h * maxf(r.size.x - 4.0, 1.0),
			cap + 2.0 + v * maxf(r.size.y - cap - 4.0, 1.0))
		var tone: Color = body.lightened(0.10) if h > 0.5 else body.darkened(0.14)
		canvas.draw_rect(Rect2(cp, Vector2(2.0 + h * 3.0, 1.5 + v * 2.0)), Color(tone.r, tone.g, tone.b, 0.55), true)
	# Shadowed lower lip, so blocks look like they have thickness.
	var lip: float = minf(4.0, r.size.y * 0.3)
	canvas.draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - lip), Vector2(r.size.x, lip)),
		Color(0.0, 0.0, 0.0, 0.38), true)
	canvas.draw_rect(r, Color(0.0, 0.0, 0.0, 0.30), false, 1.0)
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
			_draw_cross_mark(canvas, centre, accent, time)
		"wheel":
			_draw_wheel_mark(canvas, centre, time, accent)
		"spokes":
			_draw_spokes_mark(canvas, centre, time, accent)
		_:
			_draw_sun_mark(canvas, centre, accent, pulse, time)


## THE OPEN SAND: a sun wheel in the middle, with its rays reaching out to the
## four gates.
static func _draw_sun_mark(canvas: CanvasItem, centre: Vector2, accent: Color, pulse: float, time: float) -> void:
	var warm: Color = Color(accent.r, accent.g, accent.b, 0.10 + 0.05 * pulse)
	canvas.draw_circle(centre, 150.0, Color(warm.r, warm.g, warm.b, 0.05))
	canvas.draw_arc(centre, 108.0, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.22), 3.0, true)
	canvas.draw_arc(centre, 148.0, 0.0, TAU, 72, Color(accent.r, accent.g, accent.b, 0.14), 2.0, true)
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + time * 0.02
		var dir: Vector2 = Vector2.RIGHT.rotated(a)
		canvas.draw_line(centre + dir * 152.0, centre + dir * 196.0,
			Color(accent.r, accent.g, accent.b, 0.12), 3.0)
	# Central glowing core
	var core_pulse: float = 0.6 + 0.4 * sin(time * 2.0)
	canvas.draw_circle(centre, 35.0 * core_pulse, Color(accent.r, accent.g, accent.b, 0.15 * core_pulse))


## THE BANNERED HALL: two house-coloured lanes laid across the sand, and the
## violet square where they meet - the mixing lesson, painted on the floor.
static func _draw_cross_mark(canvas: CanvasItem, centre: Vector2, accent: Color, time: float) -> void:
	var band: float = 21.0
	var gold: Color = Color(0.95, 0.72, 0.25, 0.13)
	var blue: Color = Color(accent.r, accent.g, accent.b, 0.15)
	# The east-west lane (gold) and the north-south lane (blue).
	canvas.draw_rect(Rect2(60.0, centre.y - band, LevelData.PLAYFIELD.x - 120.0, band * 2.0), gold, true)
	canvas.draw_rect(Rect2(centre.x - band, 60.0, band * 2.0, LevelData.PLAYFIELD.y - 120.0), blue, true)
	# Where they cross: the hue they average to. This is red + blue = violet.
	var violet: Color = ColorTheory.blend([Color(0.95, 0.72, 0.25), accent], [1.0, 1.0])
	var pulse: float = 0.7 + 0.3 * sin(time * 1.5)
	canvas.draw_rect(Rect2(centre - Vector2(band * 2.4, band * 2.4), Vector2(band * 4.8, band * 4.8)),
		Color(violet.r, violet.g, violet.b, 0.30 * pulse), true)
	canvas.draw_arc(centre, band * 3.4, 0.0, TAU, 48, Color(violet.r, violet.g, violet.b, 0.55 * pulse), 2.0, true)
	# Subtle animated particles at the crossing
	for i in 6:
		var angle: float = time * 0.5 + float(i) * TAU / 6.0
		var r: float = band * 1.5 + sin(time * 2.0 + float(i)) * 8.0
		var p: Vector2 = centre + Vector2(cos(angle), sin(angle)) * r
		canvas.draw_circle(p, 3.0, Color(violet.r, violet.g, violet.b, 0.6))


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
		if i % 6 == 0:
			canvas.draw_line(centre + Vector2.RIGHT.rotated(a0) * inner,
				centre + Vector2.RIGHT.rotated(a0) * outer, Color(0.0, 0.0, 0.0, 0.20), 1.5)
	canvas.draw_arc(centre, outer + 8.0, 0.0, TAU, 72, Color(accent.r, accent.g, accent.b, 0.20), 2.0, true)
	var breathe: float = 0.10 + 0.05 * sin(time * 1.6)
	canvas.draw_circle(centre, inner - 12.0, Color(0.0, 0.0, 0.0, 0.10))
	canvas.draw_arc(centre, inner - 12.0, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, breathe), 2.0, true)
	# Rotating indicator showing current "north" on the wheel
	var north_angle: float = time * 0.1
	canvas.draw_line(centre, centre + Vector2.RIGHT.rotated(north_angle) * (inner - 18.0), Color(1.0, 1.0, 1.0, 0.4), 2.0)


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
	# Central dais glow
	var dais_pulse: float = 0.5 + 0.5 * sin(time * 1.8)
	canvas.draw_circle(centre, 50.0, Color(accent.r, accent.g, accent.b, 0.08 * dais_pulse))


# ---------------------------------------------------------------------------
# Crowd System - hundreds of animated spectators
# ---------------------------------------------------------------------------

## The crowd, drawn over the border walls top and bottom, plus the house banners
## hanging into the arena. Purely decorative - nothing here is solid.
static func draw_stands(canvas: CanvasItem, data: Dictionary, time: float, excitement: float = 0.0) -> void:
	var accent: Color = data.get("accent", Color(1.0, 0.82, 0.25))
	var width: float = LevelData.PLAYFIELD.x
	var band: float = LevelData.WALL
	var arena_id: int = data.get("id", 0)

	# Initialize crowd for this arena if needed
	var crowd_key: String = "crowd_%d" % arena_id
	if not _crowd.has(crowd_key):
		_crowd[crowd_key] = _generate_crowd(accent, width, band)
	var crowd_data: Dictionary = _crowd[crowd_key]

	# Initialize crowd excitement
	var excite_key: String = "excitement_%d" % arena_id
	if not _crowd_excitement.has(excite_key):
		_crowd_excitement[excite_key] = 0.0
	# Smooth excitement towards target
	var current_excitement: float = _crowd_excitement[excite_key]
	_crowd_excitement[excite_key] = lerp(current_excitement, excitement, 0.02)
	var final_excitement: float = _crowd_excitement[excite_key]

	# Draw crowd members
	_draw_crowd_layer(canvas, crowd_data, "north", time, band * 0.5, false, accent, final_excitement)
	_draw_crowd_layer(canvas, crowd_data, "south", time, LevelData.PLAYFIELD.y - band * 0.5, true, accent, final_excitement)

	# The parapet in front of the crowd: a dark timber rail whose arena-facing
	# edge catches the light. This is what makes the crowd read as people
	# LEANING OVER the arena wall instead of figures standing on the floor.
	_draw_parapet(canvas, band * 0.5, false)
	_draw_parapet(canvas, LevelData.PLAYFIELD.y - band * 0.5 - 10.0, true)

	# --- banners on the walls ---
	_draw_banners(canvas, data, time, final_excitement)


## The rail the crowd leans on, along the top and bottom of the stands. Drawn
## after the crowd, so the spectators really are behind it.
static func _draw_parapet(canvas: CanvasItem, y: float, flipped: bool) -> void:
	var w: float = LevelData.PLAYFIELD.x
	# Rail body, then the lit edge on the side that faces the arena.
	canvas.draw_rect(Rect2(0.0, y, w, 10.0), Color(0.17, 0.14, 0.12), true)
	var lit_y: float = y if flipped else y + 9.5
	canvas.draw_line(Vector2(0.0, lit_y), Vector2(w, lit_y), Color(0.58, 0.47, 0.35, 0.85), 1.5)
	# A joint every 96px, and the dark line that separates rail from crowd.
	var jx: float = 96.0
	while jx < w:
		canvas.draw_line(Vector2(jx, y + 1.0), Vector2(jx, y + 9.0), Color(0.0, 0.0, 0.0, 0.35), 1.5)
		jx += 96.0


static func _generate_crowd(accent: Color, width: float, band: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + hash(accent)

	var crowd: Dictionary = {
		"north": [],
		"south": [],
		"members": []  # all members for global effects
	}

	# Generate 80-100 spectators per side
	var spectator_count: int = 90
	var x: float = 30.0
	var spacing: float = (width - 60.0) / float(spectator_count)

	# Archetypes: each has different animation sets and colours. The clothes are
	# mid-value and clearly coloured on purpose: a crowd of near-black blobs
	# reads as dirt on the wall, not as people.
	var archetypes: Array[Dictionary] = [
		# Common folk
		{ "weight": 40, "colours": [Color(0.46, 0.39, 0.33), Color(0.52, 0.43, 0.35), Color(0.40, 0.35, 0.31)], "height_mult": 1.0, "anim_speed": 1.0 },
		# Nobles in richer clothes
		{ "weight": 15, "colours": [Color(0.64, 0.52, 0.30), Color(0.72, 0.32, 0.24), Color(0.52, 0.44, 0.58)], "height_mult": 1.1, "anim_speed": 0.8 },
		# Guards/soldiers
		{ "weight": 15, "colours": [Color(0.44, 0.46, 0.54), Color(0.38, 0.46, 0.38), Color(0.52, 0.38, 0.34)], "height_mult": 1.05, "anim_speed": 1.1 },
		# Flag bearers
		{ "weight": 10, "colours": [Color(0.50, 0.44, 0.37)], "height_mult": 1.0, "anim_speed": 0.9, "has_flag": true },
		# Children (smaller)
		{ "weight": 10, "colours": [Color(0.58, 0.50, 0.42)], "height_mult": 0.65, "anim_speed": 1.3 },
		# House colours (die-hard fans)
		{ "weight": 10, "colours": [Color(accent.r * 0.9, accent.g * 0.9, accent.b * 0.9)], "height_mult": 1.0, "anim_speed": 1.2, "diehard": true }
	]

	var id_counter: int = 0
	var house_row: int = _house_row(accent)
	for side in ["north", "south"]:
		x = 30.0
		for i in range(spectator_count):
			# Pick archetype by weight
			var total_weight: int = 0
			for a in archetypes:
				total_weight += a["weight"]
			var pick: int = rng.randi_range(1, total_weight)
			var accum: int = 0
			var chosen: Dictionary = archetypes[0]
			for a in archetypes:
				accum += a["weight"]
				if pick <= accum:
					chosen = a
					break

			var body_colour: Color = chosen["colours"].pick_random()
			var height_mult: float = chosen["height_mult"]
			var anim_speed: float = chosen["anim_speed"]
			var has_flag: bool = chosen.get("has_flag", false)
			var is_diehard: bool = chosen.get("diehard", false)

			var wobble_freq: float = randf_range(0.8, 2.2) * anim_speed
			var wobble_amp: float = randf_range(1.0, 2.5) * height_mult
			var action_timer: float = randf() * 8.0
			var current_action: String = "idle"
			var action_frame: float = randf()
			var flag_angle: float = 0.0

			# Which peasant this one is, out of the atlas: a third of the stands
			# wear the arena's own house, the rest are the other four factions -
			# a melee crowd, not a garrison.
			var pawn_row: int = house_row if rng.randf() < 0.34 else rng.randi_range(0, PAWN_ROWS - 1)

			var spectator: Dictionary = {
				"x": x,
				"base_y": 0.0,  # will be set per side
				"body_colour": body_colour,
				"height_mult": height_mult,
				"wobble_freq": wobble_freq,
				"wobble_amp": wobble_amp,
				"wobble_phase": randf() * TAU,
				"action_timer": action_timer,
				"current_action": current_action,
				"action_frame": action_frame,
				"anim_speed": anim_speed,
				"has_flag": has_flag,
				"flag_angle": flag_angle,
				"flag_phase": randf() * TAU,
				"is_diehard": is_diehard,
				"pawn_row": pawn_row,
				"id": id_counter
			}
			crowd[side].append(spectator)
			crowd["members"].append(spectator)
			id_counter += 1
			x += spacing

	return crowd


static func _draw_crowd_layer(canvas: CanvasItem, crowd_data: Dictionary, side: String, time: float, base_y: float, flipped: bool, accent: Color, excitement: float) -> void:
	var spectators: Array = crowd_data[side]
	var dir: float = 1.0 if not flipped else -1.0

	for spec in spectators:
		var x: float = spec["x"]
		var y: float = base_y + sin(time * spec["wobble_freq"] + spec["wobble_phase"]) * spec["wobble_amp"] * dir

		# Update action timer
		spec["action_timer"] -= 1.0 / 60.0
		if spec["action_timer"] <= 0.0:
			# Pick new action based on excitement
			var actions: Array[String] = ["idle"]
			var weights: Array[float] = [1.0]
			if excitement > 0.2:
				actions.append("cheer")
				weights.append(excitement * 2.0)
			if excitement > 0.4:
				actions.append("clap")
				weights.append(excitement * 1.5)
			if excitement > 0.5:
				actions.append("wave")
				weights.append(excitement * 1.2)
			if excitement > 0.7:
				actions.append("jump")
				weights.append(excitement * 1.0)
			if spec["is_diehard"] and excitement > 0.3:
				actions.append("victory")
				weights.append(excitement * 2.0)

			# Weighted random pick
			var total_w: float = 0.0
			for w in weights:
				total_w += w
			var pick: float = randf() * total_w
			var accum: float = 0.0
			for idx in range(actions.size()):
				accum += weights[idx]
				if pick <= accum:
					spec["current_action"] = actions[idx]
					break
			spec["action_frame"] = 0.0
			spec["action_timer"] = randf_range(3.0, 8.0) / spec["anim_speed"]

		# Animate action frame
		spec["action_frame"] += (1.0 / 60.0) * spec["anim_speed"] * 8.0  # ~8 FPS base

		# Draw spectator based on action
		_draw_spectator(canvas, spec, Vector2(x, y), dir, time, accent, excitement)

		# Draw flag if bearer
		if spec["has_flag"]:
			spec["flag_angle"] = sin(time * 1.5 + spec["flag_phase"]) * 0.35 * (1.0 + excitement)
			var flag_x: float = x + 6.0 * dir
			var flag_y: float = y - 14.0 * spec["height_mult"] * dir
			_draw_flag(canvas, Vector2(flag_x, flag_y), spec["flag_angle"], accent, spec["height_mult"])


## Which faction of the atlas stands for this arena's house. The five crowd
## colours sit at these hues; the arena's accent picks the nearest, and a grey
## accent (no house colour at all) gets the blacks.
static func _house_row(accent: Color) -> int:
	var factions: Array[Color] = [
		Color(0.78, 0.25, 0.22),  # Red
		Color(0.30, 0.44, 0.78),  # Blue
		Color(0.85, 0.72, 0.30),  # Yellow
		Color(0.55, 0.35, 0.68),  # Purple
		Color(0.22, 0.22, 0.24),  # Black
	]
	var best: int = 4
	var best_d: float = INF
	for i in factions.size():
		if accent.s < 0.12:
			# A colourless arena is no one's: the blacks fill its stands.
			if i == 4:
				return 16
			continue
		var dh: float = absf(accent.h - factions[i].h)
		dh = minf(dh, 1.0 - dh)
		if dh < best_d:
			best_d = dh
			best = i
	return best * 4


static func _pawn_sheet() -> Texture2D:
	if _pawn_atlas == null:
		_pawn_atlas = load(CROWD_PATH)
	return _pawn_atlas


static func _draw_spectator(canvas: CanvasItem, spec: Dictionary, pos: Vector2, dir: float, time: float, accent: Color, excitement: float) -> void:
	var tex: Texture2D = _pawn_sheet()
	if tex == null:
		return
	var action: String = spec["current_action"]
	var frame: float = spec["action_frame"]
	var row: int = int(spec.get("pawn_row", 0))
	var id: int = spec["id"]
	# Children are drawn smaller, everyone else at the pack's own size (a
	# spectator is about 24px tall in a 26px stand: leaning on the rail).
	var scale: float = 0.72 + 0.28 * float(spec["height_mult"])

	# A sprite has a whole body to move, so the actions are whole-body: a jump
	# clears the rail, a cheer leans over it, the idle breathes.
	var lift: float = 0.0
	match action:
		"cheer":
			lift = -1.4 - 1.6 * absf(sin(frame * 0.9))
		"clap":
			lift = 0.0
		"wave":
			lift = -0.6
		"jump":
			lift = -6.5 * absf(sin(frame * 1.2))
		"victory":
			lift = -3.0 - 1.0 * sin(frame * 0.7)
		_:
			lift = 0.5 * sin(time * 0.9 + float(id))
	lift *= 1.0 + excitement * 0.8

	var source := Rect2(float((int(frame) % PAWN_FRAMES) * PAWN_CELL), float(row * PAWN_CELL),
		float(PAWN_CELL), float(PAWN_CELL))
	# The figures stand ON the stand, so their feet are what is placed: the
	# pack's cells carry their own empty space above the head.
	var feet_y: float = pos.y + 12.0 + lift
	var dest := Rect2(pos.x - PAWN_CELL * 0.5 * scale, feet_y - PAWN_FEET * scale,
		float(PAWN_CELL) * scale, float(PAWN_CELL) * scale)
	canvas.draw_texture_rect_region(tex, dest, source, Color(1.0, 1.0, 1.0, 1.0))


static func _draw_flag(canvas: CanvasItem, pos: Vector2, angle: float, accent: Color, scale: float) -> void:
	var pole_len: float = 20.0 * scale
	var cloth_w: float = 14.0 * scale
	var cloth_h: float = 10.0 * scale

	# Pole
	canvas.draw_line(pos, pos + Vector2(-sin(angle), -cos(angle)) * pole_len, Color(0.35, 0.32, 0.28), 1.5 * scale)
	# Cloth (triangle)
	var tip: Vector2 = pos + Vector2(-sin(angle), -cos(angle)) * pole_len
	var left: Vector2 = tip + Vector2.RIGHT.rotated(angle + PI * 0.5) * cloth_w * 0.5
	var right: Vector2 = tip + Vector2.RIGHT.rotated(angle - PI * 0.5) * cloth_w * 0.5
	canvas.draw_colored_polygon(PackedVector2Array([pos, left, right]), Color(accent.r, accent.g, accent.b, 0.9))
	# Gold trim
	canvas.draw_line(pos, left, Color(0.95, 0.80, 0.35, 0.8), 1.0)
	canvas.draw_line(pos, right, Color(0.95, 0.80, 0.35, 0.8), 1.0)


static func _draw_banners(canvas: CanvasItem, data: Dictionary, time: float, excitement: float) -> void:
	var accent: Color = data.get("accent", Color(1.0, 0.82, 0.25))
	var banner_key: String = "banners_%d" % data.get("id", 0)
	if not _banners.has(banner_key):
		_banners[banner_key] = _init_banners(accent)
	var banner_data: Dictionary = _banners[banner_key]

	# Top banners (hanging down)
	for bx in [120.0, 400.0, 880.0, 1160.0]:
		_draw_hanging_banner(canvas, Vector2(bx, LevelData.WALL), accent, false, time, excitement, banner_data)

	# Bottom banners (hanging up)
	for bx in [260.0, 640.0, 1020.0]:
		_draw_hanging_banner(canvas, Vector2(bx, LevelData.PLAYFIELD.y - LevelData.WALL), accent, true, time, excitement, banner_data)


static func _init_banners(accent: Color) -> Dictionary:
	var banners: Array = []
	for i in range(7):  # 4 top + 3 bottom
		banners.append({
			"wave_phase": randf() * TAU,
			"wave_speed": randf_range(0.6, 1.2),
			"wave_amp": randf_range(3.0, 6.0),
			"tear": randf() < 0.1  # some banners are torn
		})
	return { "list": banners }


static func _draw_hanging_banner(canvas: CanvasItem, top: Vector2, accent: Color, flipped: bool, time: float, excitement: float, banner_data: Dictionary) -> void:
	var h: float = BANNER_H
	var y0: float = top.y - h if flipped else top.y
	var idx: int = 0  # simplified - in reality would track per banner
	var b: Dictionary = banner_data["list"][idx % banner_data["list"].size()]

	var wave: float = sin(time * b["wave_speed"] + b["wave_phase"]) * b["wave_amp"] * (1.0 + excitement * 0.5)

	var cloth_x: float = top.x - BANNER_W * 0.5 + wave * 0.3
	var cloth := Rect2(cloth_x, y0, BANNER_W, h)
	var cloth_colour: Color = Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.92)
	canvas.draw_rect(cloth, cloth_colour, true)

	# Gold trim at top
	canvas.draw_rect(Rect2(cloth.position, Vector2(cloth.size.x, 4.0)), Color(0.95, 0.80, 0.35, 0.85), true)
	# Gold trim at bottom
	var trim_y: float = cloth.end.y - 4.0
	canvas.draw_rect(Rect2(cloth.position.x, trim_y, cloth.size.x, 4.0), Color(0.95, 0.80, 0.35, 0.85), true)

	# Vertical gold stripes
	for stripe_i in 2:
		var sx: float = cloth.position.x + cloth.size.x * (0.25 + float(stripe_i) * 0.5)
		canvas.draw_line(Vector2(sx, cloth.position.y), Vector2(sx, cloth.end.y), Color(0.95, 0.80, 0.35, 0.6), 1.0)

	# The notch at the hanging end
	var tail: float = cloth.end.y if not flipped else cloth.position.y
	var dir: float = 1.0 if not flipped else -1.0
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(cloth.position.x, tail),
		Vector2(cloth.end.x, tail),
		Vector2(cloth.get_center().x, tail + dir * 12.0),
	]), Color(0.0, 0.0, 0.0, 0.35))

	# Emblem ring
	canvas.draw_arc(cloth.get_center(), 8.0, 0.0, TAU, 20, Color(0.95, 0.80, 0.35, 0.75), 2.0, true)

	# Tattered bottom if torn
	if b["tear"]:
		for tear_i in 3:
			var tx: float = cloth.position.x + cloth.size.x * (0.2 + tear_i * 0.3)
			var ty: float = cloth.end.y + (4.0 if tear_i % 2 == 0 else -2.0) * dir
			canvas.draw_line(Vector2(tx, cloth.end.y), Vector2(tx + randf_range(-3.0, 3.0), ty), Color(0.1, 0.08, 0.06, 0.7), 1.0)


# ---------------------------------------------------------------------------
# Environmental Particles - dust, pollen, sand, weather
# ---------------------------------------------------------------------------

## Sand dust hanging in the air, so the arena is never a still picture.
static func draw_dust(canvas: CanvasItem, time: float, accent: Color, weather: Weather = Weather.CLEAR) -> void:
	if _dust.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in 60:  # more dust particles
			_dust.append(Vector4(
				rng.randf_range(30.0, LevelData.PLAYFIELD.x - 30.0),
				rng.randf_range(40.0, LevelData.PLAYFIELD.y - 40.0),
				rng.randf_range(0.08, 0.25),
				rng.randf_range(8.0, 35.0)))

	for i in _dust.size():
		var d: Vector4 = _dust[i]
		var p: Vector2 = Vector2(
			d.x + sin(time * d.z + float(i)) * d.w,
			d.y + cos(time * d.z * 0.8 + float(i) * 1.7) * d.w * 0.6)
		var alpha: float = 0.04 + 0.04 * (0.5 + 0.5 * sin(time * 0.9 + float(i) * 2.1))
		canvas.draw_circle(p, 1.2, Color(1.0, 0.94, 0.80, alpha))
		if i % 11 == 0:
			canvas.draw_circle(p, 2.0, Color(accent.r, accent.g, accent.b, alpha * 1.2))

	# Weather-specific particles
	match weather:
		Weather.RAIN:
			_draw_rain(canvas, time)
		Weather.SANDSTORM:
			_draw_sandstorm(canvas, time, accent)
		Weather.ASH:
			_draw_ash(canvas, time)
		Weather.OVERCAST:
			_draw_overcast(canvas, time)


static func _draw_rain(canvas: CanvasItem, time: float) -> void:
	# Rain is drawn as streaks
	for i in range(RAIN_DROP_COUNT):
		# Deterministic per-drop
		var seed: int = i * 173 + int(time * 60) % 1000
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var x: float = rng.randf_range(0.0, LevelData.PLAYFIELD.x)
		var y: float = fmod(time * 800.0 + float(i) * 17.3, LevelData.PLAYFIELD.y + 100.0) - 50.0
		var length: float = 12.0 + rng.randf_range(-3.0, 3.0)
		var tilt: float = 0.15
		canvas.draw_line(
			Vector2(x, y),
			Vector2(x - tilt * length, y + length),
			Color(0.6, 0.7, 0.85, 0.35),
			1.0
		)
		# Splash on ground occasionally
		if y > LevelData.PLAYFIELD.y - 30.0 and rng.randf() < 0.02:
			canvas.draw_circle(Vector2(x, LevelData.PLAYFIELD.y - 26.0), 1.5, Color(0.6, 0.7, 0.85, 0.25))


static func _draw_sandstorm(canvas: CanvasItem, time: float, accent: Color) -> void:
	for i in range(SANDSTORM_PARTICLE_COUNT):
		var seed: int = i * 211 + int(time * 30) % 2000
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var x: float = fmod(time * 200.0 + float(i) * 23.7, LevelData.PLAYFIELD.x + 100.0) - 50.0
		var y: float = rng.randf_range(40.0, LevelData.PLAYFIELD.y - 40.0)
		var size: float = rng.randf_range(1.5, 4.0)
		var alpha: float = rng.randf_range(0.05, 0.15)
		var drift: float = sin(time * 0.5 + float(i)) * 20.0
		canvas.draw_circle(Vector2(x + drift, y), size, Color(0.7, 0.65, 0.55, alpha))


static func _draw_ash(canvas: CanvasItem, time: float) -> void:
	for i in range(ASH_PARTICLE_COUNT):
		var seed: int = i * 239 + int(time * 15) % 1500
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var x: float = fmod(time * 40.0 + float(i) * 31.3, LevelData.PLAYFIELD.x + 100.0) - 50.0
		var y: float = fmod(-time * 30.0 + float(i) * 19.1, LevelData.PLAYFIELD.y + 100.0) - 50.0
		var size: float = rng.randf_range(0.8, 2.5)
		var alpha: float = rng.randf_range(0.08, 0.2)
		var sway: float = sin(time * 0.3 + float(i) * 1.3) * 15.0
		canvas.draw_circle(Vector2(x + sway, y), size, Color(0.25, 0.22, 0.20, alpha))


static func _draw_overcast(canvas: CanvasItem, time: float) -> void:
	# Subtle dark clouds drifting
	for i in range(8):
		var seed: int = i * 101
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var cx: float = fmod(time * 8.0 + float(i) * 160.0, LevelData.PLAYFIELD.x + 200.0) - 100.0
		var cy: float = rng.randf_range(50.0, 200.0)
		var radius: float = rng.randf_range(80.0, 180.0)
		var alpha: float = 0.03 + 0.02 * sin(time * 0.15 + float(i))
		canvas.draw_circle(Vector2(cx, cy), radius, Color(0.15, 0.15, 0.18, alpha))


# ---------------------------------------------------------------------------
# Weather System
# ---------------------------------------------------------------------------

static func get_weather(data: Dictionary, time: float) -> Weather:
	var arena_id: int = data.get("id", 0)
	var weather_key: String = "weather_%d" % arena_id

	if not _weather.has(weather_key):
		_weather[weather_key] = {
			"current": Weather.CLEAR,
			"next_change": time + WEATHER_CHANGE_INTERVAL,
			"transition": 0.0,
			"target": Weather.CLEAR
		}

	var w: Dictionary = _weather[weather_key]

	# Check for weather change
	if time >= w["next_change"]:
		# Pick new weather (weighted)
		var options: Array[Weather] = [Weather.CLEAR, Weather.CLEAR, Weather.CLEAR, Weather.OVERCAST, Weather.OVERCAST, Weather.RAIN, Weather.SANDSTORM, Weather.ASH]
		var weights: Array[float] = [0.4, 0.4, 0.4, 0.15, 0.15, 0.1, 0.05, 0.03]  # Arena 3 gets more sandstorms
		if arena_id == 2:  # Deep Ring
			weights = [0.2, 0.2, 0.2, 0.15, 0.15, 0.05, 0.2, 0.05]
		elif arena_id == 3:  # The Wheel
			weights = [0.3, 0.3, 0.3, 0.1, 0.1, 0.05, 0.05, 0.1]

		# Weighted random
		var total: float = 0.0
		for wt in weights:
			total += wt
		var pick: float = randf() * total
		var accum: float = 0.0
		var new_weather: Weather = Weather.CLEAR
		for idx in range(options.size()):
			accum += weights[idx]
			if pick <= accum:
				new_weather = options[idx]
				break

		if new_weather != w["current"]:
			w["target"] = new_weather
			w["transition"] = 0.0
			w["current"] = new_weather  # instant for now, could interpolate
		w["next_change"] = time + WEATHER_CHANGE_INTERVAL * randf_range(0.7, 1.4)

	return w["current"]


# ---------------------------------------------------------------------------
# Sunlight System - directional light with shadows
# ---------------------------------------------------------------------------

static func draw_sunlight(canvas: CanvasItem, data: Dictionary, time: float, fighter_positions: Array[Vector2]) -> void:
	var arena_id: int = data.get("id", 0)

	# Initialize sun angle
	if not _sun_angles.has(arena_id):
		_sun_angles[arena_id] = randf() * TAU  # random initial angle per arena

	# Very slow sun movement (full rotation over ~20 minutes real time)
	var sun_angle: float = _sun_angles[arena_id] + time * 0.0005
	_sun_angles[arena_id] = sun_angle

	var sun_dir: Vector2 = Vector2(cos(sun_angle), sin(sun_angle)).normalized()
	var sun_colour: Color = Color(1.0, 0.92, 0.75, 0.18)  # warm golden

	# Draw sunlight rays through the arena (god rays)
	var centre: Vector2 = LevelData.PLAYFIELD * 0.5
	var ray_length: float = 800.0

	# Soft volumetric shafts: wide, faint bands of light rather than laser
	# lines - a hard bright line reads as a glitch across a painted floor.
	if sun_dir.y < 0.0:
		var num_rays: int = 7
		for i in range(num_rays):
			var ray_angle: float = sun_angle + (float(i) - num_rays * 0.5) * 0.16
			var ray_dir: Vector2 = Vector2(cos(ray_angle), sin(ray_angle))
			var start: Vector2 = centre - ray_dir * (ray_length * 0.45)
			var end: Vector2 = centre + ray_dir * ray_length
			var width: float = 42.0 + 26.0 * sin(float(i) * 2.1)
			var alpha: float = 0.010 + 0.006 * sin(float(i) * 1.7)
			canvas.draw_line(start, end, Color(sun_colour.r, sun_colour.g, sun_colour.b, alpha), width)

	# Draw fighter shadows
	for fpos in fighter_positions:
		_draw_fighter_shadow(canvas, fpos, sun_dir, sun_colour)


static func _draw_fighter_shadow(canvas: CanvasItem, pos: Vector2, sun_dir: Vector2, sun_colour: Color) -> void:
	# Elliptical shadow stretched opposite to sun direction
	var shadow_len: float = 28.0
	var shadow_wid: float = 14.0
	var offset: Vector2 = sun_dir * 8.0  # shadow offset from feet

	var shadow_center: Vector2 = pos + offset
	var perp: Vector2 = Vector2(-sun_dir.y, sun_dir.x)

	# Draw as stretched ellipse (approximated with polygon)
	var pts: PackedVector2Array = PackedVector2Array([
		shadow_center + sun_dir * shadow_len * 0.5 + perp * shadow_wid * 0.5,
		shadow_center - sun_dir * shadow_len * 0.5 + perp * shadow_wid * 0.5,
		shadow_center - sun_dir * shadow_len * 0.5 - perp * shadow_wid * 0.5,
		shadow_center + sun_dir * shadow_len * 0.5 - perp * shadow_wid * 0.5,
	])
	canvas.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.22))


# ---------------------------------------------------------------------------
# House Sigil (HUD)
# ---------------------------------------------------------------------------

## A house sigil: a hue ring with the house's own emblem inside it, drawn in the
## arena's accent colour. Used by the HUD, so the round you are fighting is
## announced by the mark of the house that owns it.
static func draw_sigil(canvas: CanvasItem, centre: Vector2, radius: float,
		style: String, accent: Color, time: float) -> void:
	var breathe: float = 0.75 + 0.25 * sin(time * 2.0)
	# The ring: the whole wheel, faintly, so every sigil is unmistakably colour.
	var segments: int = 40
	for i in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var hue: Color = ColorTheory.wheel(float(i) * (360.0 / float(segments)), 0.75, 0.95)
		canvas.draw_arc(centre, radius, a0, a1, 3, Color(hue.r, hue.g, hue.b, 0.85), 3.0, true)
	canvas.draw_circle(centre, radius - 4.0, Color(0.03, 0.03, 0.05, 0.85))
	canvas.draw_arc(centre, radius, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.35 * breathe), 1.5, true)

	# Animated accent particles around sigil
	for i in 4:
		var angle: float = time * 1.5 + float(i) * TAU / 4.0
		var p: Vector2 = centre + Vector2(cos(angle), sin(angle)) * (radius + 6.0)
		canvas.draw_circle(p, 2.0, Color(accent.r, accent.g, accent.b, 0.6))

	match style:
		"cross":
			# Two bars, the two houses: the mixing mark.
			canvas.draw_rect(Rect2(centre - Vector2(radius - 7.0, 3.0), Vector2((radius - 7.0) * 2.0, 6.0)), accent, true)
			canvas.draw_rect(Rect2(centre - Vector2(3.0, radius - 7.0), Vector2(6.0, (radius - 7.0) * 2.0)),
				Color(0.95, 0.78, 0.35, 0.9), true)
			# Pulsing center
			var cp: float = 0.8 + 0.2 * sin(time * 3.0)
			canvas.draw_circle(centre, 5.0 * cp, Color(0.95, 0.78, 0.35, 0.9))
		"wheel":
			for i in 3:
				var rp: float = 0.8 + 0.2 * sin(time * 2.0 + float(i))
				canvas.draw_arc(centre, radius - 7.0 - float(i) * 5.0, 0.0, TAU, 24, accent, 2.0, true)
			# Rotating indicator
			var ind_angle: float = time * 0.5
			canvas.draw_line(centre, centre + Vector2.RIGHT.rotated(ind_angle) * (radius - 10.0), Color(1.0, 1.0, 1.0, 0.7), 2.0)
		"spokes":
			for i in 4:
				var a: float = TAU * float(i) / 4.0 + time * 0.3
				canvas.draw_line(centre, centre + Vector2.RIGHT.rotated(a) * (radius - 7.0), accent, 3.0)
			canvas.draw_circle(centre, 4.0, accent)
			# Inner rotating detail
			for i in 8:
				var a2: float = TAU * float(i) / 8.0 - time * 0.4
				canvas.draw_line(centre + Vector2.RIGHT.rotated(a2) * 6.0, centre + Vector2.RIGHT.rotated(a2) * 14.0, accent, 1.5)
		_:
			# The sun: a disc with rays, which is house one's mark.
			var sun_pulse: float = 0.85 + 0.15 * sin(time * 2.5)
			canvas.draw_circle(centre, 8.0 * sun_pulse, accent)
			for i in 8:
				var a2: float = TAU * float(i) / 8.0 + time * 0.15
				var r1: float = 11.0 + sin(time * 2.0 + float(i)) * 2.0
				var r2: float = (radius - 6.0) + cos(time * 1.5 + float(i)) * 3.0
				canvas.draw_line(centre + Vector2.RIGHT.rotated(a2) * r1,
					centre + Vector2.RIGHT.rotated(a2) * r2, accent, 2.0)


# ---------------------------------------------------------------------------
# Combat Effects - screen shake, hit pauses, impact effects
# ---------------------------------------------------------------------------

static func draw_hit_flash(canvas: CanvasItem, pos: Vector2, colour: Color, intensity: float, time: float) -> void:
	# A white-hot core for the first instant. In an arena this dark the eye
	# catches white before it catches hue, so the hit reads as an IMPACT and
	# the colour is read a beat later, as the wound.
	var core: float = maxf(1.0 - time * 3.2, 0.0)
	if core > 0.0:
		canvas.draw_circle(pos, (5.0 + 9.0 * intensity) * (1.0 - 0.35 * time),
			Color(1.0, 1.0, 1.0, 0.85 * core * intensity))

	# Expanding ring, in the defender's own colour.
	var ring: float = lerp(8.0, 44.0, minf(time * 1.4, 1.0)) * intensity
	canvas.draw_arc(pos, ring, 0.0, TAU, 24, Color(colour.r, colour.g, colour.b, 0.55 * (1.0 - time)), 2.5, true)
	var ring2: float = lerp(5.0, 26.0, minf(time * 1.8, 1.0)) * intensity
	canvas.draw_arc(pos, ring2, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.30 * (1.0 - time)), 1.5, true)

	# Sparks: a handful of hot grains thrown outward, dropping as they fade.
	# Stateless - their whole flight is a function of `time` - so any number of
	# hits can be in flight without any bookkeeping.
	var seed_angle: float = fposmod(pos.x * 0.37 + pos.y * 0.61, TAU)
	for i in 7:
		var a: float = seed_angle + float(i) * TAU / 7.0
		var d: float = lerp(3.0, 26.0 + 14.0 * intensity, minf(time * 2.4, 1.0))
		var spark_pos: Vector2 = pos + Vector2(cos(a), sin(a)) * d + Vector2(0.0, time * time * 30.0)
		var fade: float = maxf(1.0 - time * 1.5, 0.0)
		if fade > 0.0:
			canvas.draw_line(spark_pos, spark_pos - Vector2(cos(a), sin(a)) * 6.0,
				Color(colour.r, colour.g, colour.b, 0.55 * fade), 1.5)
			canvas.draw_circle(spark_pos, 1.2 + 1.0 * intensity, Color(1.0, 0.94, 0.74, 0.95 * fade))


static func draw_shatter_effect(canvas: CanvasItem, pos: Vector2, colour: Color, time: float) -> void:
	# Complementary shatter = white flash + colour burst
	var white_intensity: float = max(0.0, 1.0 - time * 8.0)
	var colour_intensity: float = max(0.0, 1.0 - time * 4.0)

	# White core
	canvas.draw_circle(pos, 60.0 * white_intensity, Color(1.0, 1.0, 1.0, white_intensity * 0.6))
	canvas.draw_circle(pos, 35.0 * white_intensity, Color(1.0, 1.0, 1.0, white_intensity * 0.9))

	# Colour shards flying outward
	for i in 16:
		var angle: float = float(i) * TAU / 16.0
		var dist: float = lerp(0.0, 80.0, 1.0 - time * 2.5) * colour_intensity
		var shard_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * dist
		var shard_size: float = lerp(6.0, 1.0, time * 2.0) * colour_intensity
		canvas.draw_circle(shard_pos, shard_size, Color(colour.r, colour.g, colour.b, colour_intensity * 0.8))

	# Expanding complement ring
	var ring_prog: float = min(1.0, time * 3.0)
	var ring_r: float = lerp(20.0, 120.0, ring_prog)
	var ring_alpha: float = (1.0 - ring_prog) * 0.7
	canvas.draw_arc(pos, ring_r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, ring_alpha), 3.0, true)


static func draw_kill_effect(canvas: CanvasItem, pos: Vector2, colour: Color, time: float) -> void:
	# Rising soul/colour particles
	for i in 12:
		var angle: float = float(i) * TAU / 12.0 + time * 0.5
		var height: float = lerp(0.0, 60.0, time * 1.5)
		var p: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 15.0 + Vector2(0.0, -height)
		var alpha: float = max(0.0, 1.0 - time * 1.2)
		canvas.draw_circle(p, 4.0 * alpha, Color(colour.r, colour.g, colour.b, alpha * 0.8))

	# Ground impact ring
	var ring_prog: float = min(1.0, time * 2.0)
	canvas.draw_arc(pos, lerp(10.0, 50.0, ring_prog), 0.0, TAU, 32, Color(colour.r, colour.g, colour.b, (1.0 - ring_prog) * 0.5), 2.0, true)


# ---------------------------------------------------------------------------
# Blood Field Integration - enhanced visual blood
# ---------------------------------------------------------------------------

static func draw_blood_overlay(canvas: CanvasItem, blood_field: Object, time: float) -> void:
	# This is called from room.gd to draw blood on top of everything
	# The blood_field handles its own drawing, but we can add extra atmospheric blood effects here
	pass


# ---------------------------------------------------------------------------
# Master Draw Functions - called from room.gd
# ---------------------------------------------------------------------------
#
# The arena is drawn in two passes, because the fighters and the wall blocks
# stand BETWEEN them:
#
#   draw_floor_atmosphere()  the ground plane: flagstones, the mark, the
#                            firelight pools, shadows, rim sparks.
#   draw_arena_front()       the air: the crowd on the parapet, dust, weather
#                            and the vignette. May never be hidden.

## Everything that belongs to the floor plane, drawn by the room itself so it
## lands under the fighters and under every wall block.
##
## `lights` is the room's list of live fire positions (braziers + torches,
## Vector2 or {pos, radius}) - the pools are the reason the arena still reads
## when the night falls on it.
static func draw_floor_atmosphere(canvas: CanvasItem, data: Dictionary, time: float,
		fighter_positions: Array[Vector2], excitement: float = 0.0,
		lights: Array = []) -> void:
	var accent: Color = data.get("accent", Color(1.0, 0.82, 0.25))

	# 1. The baked flagstones.
	var floor_tex: ImageTexture = floor_texture(data)
	if floor_tex != null:
		canvas.draw_texture(floor_tex, Vector2.ZERO, Color(1.0, 1.0, 1.0, 1.0))

	# 2. The arena's mark, worn into the middle of the floor.
	draw_mark(canvas, data, time)

	# 3. Firelight pools, one per live flame.
	for l in lights:
		if l is Dictionary:
			draw_light_pool(canvas, l.get("pos", Vector2.ZERO), float(l.get("radius", 110.0)), time, accent)
		else:
			draw_light_pool(canvas, l, 110.0, time, accent)

	# 4. Sunlight, god rays, and every fighter's shadow.
	draw_sunlight(canvas, data, time, fighter_positions)

	# 5. The living rim: sparks twinkling along the arena edges, brighter as
	#    the crowd wakes up.
	draw_rim_life(canvas, accent, time, excitement)


## The front pass: crowd, dust, weather and vignette, drawn above every wall
## and every fighter by RoomFront.
static func draw_arena_front(canvas: CanvasItem, data: Dictionary, time: float, excitement: float = 0.0) -> void:
	var accent: Color = data.get("accent", Color(1.0, 0.82, 0.25))

	# The crowd on the parapet, with the house banners.
	draw_stands(canvas, data, time, excitement)

	# Weather and dust in the air.
	var weather: Weather = get_weather(data, time)
	draw_dust(canvas, time, accent, weather)

	# Subtle vignette.
	_draw_vignette(canvas)


## The arena rim, alive: torch-flecks and crowd-sparks twinkling in the band
## just inside the walls, brighter when the crowd is excited. Pure sugar - it
## never touches the rules. The positions come from index hashing, so there is
## no per-frame state and no cost worth measuring.
static func draw_rim_life(canvas: CanvasItem, accent: Color, time: float, excitement: float) -> void:
	var w: float = LevelData.PLAYFIELD.x
	var h: float = LevelData.PLAYFIELD.y
	var bands: Array = [
		Rect2(0.0, 0.0, w, RIM),
		Rect2(0.0, h - RIM, w, RIM),
		Rect2(0.0, RIM, RIM, h - RIM * 2.0),
		Rect2(w - RIM, RIM, RIM, h - RIM * 2.0),
	]
	var base_alpha: float = 0.05 + 0.13 * clampf(excitement, 0.0, 1.0)
	var band_index: int = 0
	for band in bands:
		var count: int = 16
		for i in count:
			var f: float = float(i)
			var seed: float = f * 0.618 + float(band_index) * 7.31
			var u: float = fposmod(seed * 3.77, 1.0)
			var v: float = fposmod(seed * 9.13, 1.0)
			var pos: Vector2 = Vector2(
				band.position.x + u * band.size.x,
				band.position.y + v * band.size.y)
			var twinkle: float = 0.55 + 0.45 * sin(time * (1.6 + v * 2.2) + seed * 5.0)
			var warm: bool = fposmod(seed * 1.7, 1.0) > 0.45
			var col: Color = Color(1.0, 0.86, 0.55) if warm else accent
			canvas.draw_circle(pos, 1.4 + 1.6 * twinkle, Color(col.r, col.g, col.b, base_alpha * twinkle))
		band_index += 1


static func _draw_vignette(canvas: CanvasItem) -> void:
	var vignette_colour: Color = Color(0.0, 0.0, 0.05, 0.15)
	var thickness: float = 180.0
	# Top
	canvas.draw_rect(Rect2(-thickness, -thickness, LevelData.PLAYFIELD.x + thickness * 2, thickness), vignette_colour, true)
	# Bottom
	canvas.draw_rect(Rect2(-thickness, LevelData.PLAYFIELD.y, LevelData.PLAYFIELD.x + thickness * 2, thickness), vignette_colour, true)
	# Left
	canvas.draw_rect(Rect2(-thickness, -thickness, thickness, LevelData.PLAYFIELD.y + thickness * 2), vignette_colour, true)
	# Right
	canvas.draw_rect(Rect2(LevelData.PLAYFIELD.x, -thickness, thickness, LevelData.PLAYFIELD.y + thickness * 2), vignette_colour, true)


# ---------------------------------------------------------------------------
# Crowd Excitement Control
# ---------------------------------------------------------------------------

## game.gd owns the number (it goes up on hits, kills, combos, boss phases and
## decays on its own); this is how it reaches the arena. The rim shimmer and
## any drawn crowd read it back through get_crowd_excitement().
static func set_crowd_excitement(arena_id: int, value: float) -> void:
	_crowd_excitement["excitement_%d" % arena_id] = clampf(value, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

static func get_crowd_excitement(arena_id: int) -> float:
	var key: String = "excitement_%d" % arena_id
	return _crowd_excitement.get(key, 0.0)


static func reset_arena_state(arena_id: int) -> void:
	# Call when arena loads/resets
	var crowd_key: String = "crowd_%d" % arena_id
	var banner_key: String = "banners_%d" % arena_id
	var torch_key: String = "torches_%d" % arena_id  # not used directly
	var weather_key: String = "weather_%d" % arena_id
	var excitement_key: String = "excitement_%d" % arena_id
	var sun_key: String = "%d" % arena_id

	# Don't clear crowd (expensive to regenerate), just reset excitement
	if _crowd_excitement.has(excitement_key):
		_crowd_excitement[excitement_key] = 0.0
	# Reset weather
	if _weather.has(weather_key):
		_weather[weather_key] = {
			"current": Weather.CLEAR,
			"next_change": 0.0,
			"transition": 0.0,
			"target": Weather.CLEAR
		}