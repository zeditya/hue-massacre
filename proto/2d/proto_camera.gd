extends Node2D
##
## PROTOTYPE - the "which camera?" comparison. Throwaway, but honest: it uses
## the REAL room data, floor texture, wall colours and character sprites.
##
## Three modes, cycled live with T, so the same room can be judged three ways:
##   0 TOPDOWN - today's look: full room on one screen, flat walls.
##   1 ZOOM    - the same world with a 1.5x follow camera (Soul-Knight-ish
##               framing: characters read big, the room scrolls past).
##   2 TILT    - the League-of-Legends trick in 2D: the world is squashed on
##               the Y axis (TILT = 0.62), characters stand upright and walls
##               grow a fake height, so the ground reads as a tilted plane.
##
## Controls: WASD walks the white knight, T cycles the mode, wheel zooms.
## Run it:   godot --path . res://proto/2d/proto_camera.tscn
## Capture:  godot --path . --script res://proto/2d/capture.gd
##
## Nothing outside proto/2d/ is touched.

const TILT: float = 0.62
## Wall fake heights in SCREEN pixels (the point of the comparison is exactly
## how much a wall should hide of a character standing behind it).
const FACE_PILLAR: float = 36.0
const FACE_LOW: float = 18.0
const FACE_BORDER: float = 26.0
## Cell measurements of the adventurer sheet (see scripts/sprite_bank.gd and
## the earlier PNG measurement): the figure's feet sit 17 px below the cell's
## centre, figure centre-x is 2 px left of the cell's centre.
const FEET_BELOW_CENTRE: float = 17.0
const CENTRE_X_OFFSET: float = 2.0

enum Mode { TOPDOWN, ZOOM, TILT }

var mode: int = Mode.TOPDOWN
var world: Node2D = null
var camera: Camera2D = null
var player_root: Node2D = null

var _zoom: float = 1.5
var _actor_sprites: Array[Sprite2D] = []
var _wall_nodes: Array = []


func _ready() -> void:
	_build_floor()
	_build_paint()
	_build_walls()
	_build_actors()
	_build_camera()
	set_mode(Mode.TOPDOWN)


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

func _build_floor() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	var floor := Sprite2D.new()
	floor.name = "Floor"
	floor.texture = TileBank.floor_texture()
	floor.centered = false
	floor.modulate = TileBank.FLOOR_MODULATE
	floor.z_index = -100
	world.add_child(floor)


## Spilled hues: circles in world space that squash into ellipses in TILT -
## exactly how the real paint layer would read.
func _build_paint() -> void:
	var blobs := [
		[Vector2(300.0, 520.0), 60.0, Color(0.85, 0.12, 0.16, 0.62)],
		[Vector2(700.0, 560.0), 45.0, Color(0.95, 0.78, 0.15, 0.55)],
		[Vector2(960.0, 380.0), 55.0, Color(0.10, 0.65, 0.75, 0.55)],
	]
	var drawer := PaintDraw.new()
	drawer.blobs = blobs
	drawer.z_index = -50
	world.add_child(drawer)


func _build_walls() -> void:
	var all: Array = LevelData.border_walls()
	var room: Dictionary = LevelData.ROOMS[0]
	for extra in room["walls"]:
		all.append(extra)
	var body: Color = room.get("wall_color", Color(0.09, 0.09, 0.12))

	for r in all:
		var is_border: bool = r.position.x <= 0.1 or r.position.y <= 0.1 \
			or r.end.x >= LevelData.PLAYFIELD.x - 0.1 or r.end.y >= LevelData.PLAYFIELD.y - 0.1
		var is_pillar: bool = r.size.x <= 48.0 and r.size.y <= 48.0
		var face: float = FACE_BORDER
		if is_pillar:
			face = FACE_PILLAR
		elif not is_border:
			face = FACE_LOW

		var node := WallDraw.new()
		node.rect_size = r.size
		node.body = body
		node.face_screen = face
		# Origin at the footprint's bottom edge: y-sorting then reads
		# "lower base = in front", which is what depth means in this view.
		node.position = Vector2(r.position.x + r.size.x * 0.5, r.end.y)
		world.add_child(node)
		_wall_nodes.append(node)


func _build_actors() -> void:
	var frames: SpriteFrames = SpriteBank.adventurer()
	var setup := [
		[Vector2(620.0, 450.0), Color(1.0, 1.0, 1.0), true],    # the player
		[Vector2(740.0, 330.0), Color(1.0, 0.16, 0.16), false], # red knight
		[Vector2(860.0, 480.0), Color(1.0, 0.88, 0.12), false], # yellow knight
		[Vector2(462.0, 318.0), Color(0.25, 0.9, 0.35), false], # green knight
	]
	for entry in setup:
		var root := Node2D.new()
		root.position = entry[0]
		var sprite := Sprite2D.new()
		sprite.texture = frames.get_frame_texture("idle_down", 0)
		sprite.material = SpriteBank.tint_material(entry[1])
		root.add_child(sprite)
		world.add_child(root)
		_actor_sprites.append(sprite)
		if entry[2]:
			player_root = root


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	add_child(camera)


# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------

func set_mode(m: int) -> void:
	mode = clampi(m, 0, 2)
	var tilt: bool = mode == Mode.TILT

	world.scale = Vector2(1.0, TILT) if tilt else Vector2.ONE
	for sprite in _actor_sprites:
		if tilt:
			# Counter-scale so the figure stands upright on the squashed
			# ground, with its feet kept where they were in flat modes
			# (17 px below the actor's centre).
			var s: float = 1.0 / TILT
			sprite.scale = Vector2(1.0, s)
			sprite.position = Vector2(
				CENTRE_X_OFFSET,
				FEET_BELOW_CENTRE - FEET_BELOW_CENTRE * s)
		else:
			sprite.scale = Vector2.ONE
			sprite.position = Vector2.ZERO

	for node in _wall_nodes:
		node.tilt = tilt
		node.queue_redraw()

	_update_camera()


func _update_camera() -> void:
	var target := LevelData.PLAYFIELD * 0.5
	var z: float = 1.0
	if mode == Mode.ZOOM or mode == Mode.TILT:
		target = player_root.position
		z = _zoom
		if mode == Mode.TILT:
			# The camera lives OUTSIDE the squashed world, so it must look at
			# the player's transformed (on-screen) position, not the raw one.
			target.y *= TILT
	camera.zoom = Vector2(z, z)
	camera.position = target


# ---------------------------------------------------------------------------
# Interactive
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player_root == null:
		return
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v != Vector2.ZERO:
		player_root.position += v * 240.0 * delta
		player_root.position.x = clampf(player_root.position.x, 20.0, LevelData.PLAYFIELD.x - 20.0)
		player_root.position.y = clampf(player_root.position.y, 40.0, LevelData.PLAYFIELD.y - 30.0)
		_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_T:
			set_mode((mode + 1) % 3)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom + 0.1, 1.0, 2.6)
			_update_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom - 0.1, 1.0, 2.6)
			_update_camera()


# ---------------------------------------------------------------------------
# Capture API (proto/2d/capture.gd)
# ---------------------------------------------------------------------------

func snap(m: int, player_pos: Vector2, zoom: float) -> void:
	if player_root != null:
		player_root.position = player_pos
	_zoom = zoom
	set_mode(m)


# ---------------------------------------------------------------------------
# Inner drawing helpers
# ---------------------------------------------------------------------------

## Flat wall = today's drawing (copy of room.gd::_draw_wall).
## Tilt wall = the same block, but with a fake height: the south face rises
## from the footprint's bottom edge, and the "roof" is the footprint lifted by
## the same amount. Correct for a camera pitched to the south.
class WallDraw extends Node2D:
	var rect_size: Vector2 = Vector2.ONE
	var body: Color = Color(0.09, 0.09, 0.12)
	var edge: Color = Color(0.0, 0.0, 0.0, 0.45)
	var face_screen: float = 20.0
	var tilt: bool = false

	func _draw() -> void:
		var w: float = rect_size.x
		var h: float = rect_size.y
		if not tilt:
			var lit: Color = body.lightened(0.22)
			var cap: float = minf(6.0, h * 0.4)
			draw_rect(Rect2(-w * 0.5, -h, w, h), body, true)
			draw_rect(Rect2(-w * 0.5, -h, w, cap), lit, true)
			var lip: float = minf(4.0, h * 0.3)
			draw_rect(Rect2(-w * 0.5, -lip, w, lip), Color(0.0, 0.0, 0.0, 0.35), true)
			draw_rect(Rect2(-w * 0.5, -h, w, h), edge, false, 1.5)
			return

		# Tilted: body = face (rises from the base line) + roof (footprint
		# lifted by the face height). Face height is given in screen pixels,
		# so it must be divided by the world squash to come out right.
		var face: float = face_screen / 0.62
		var lit: Color = body.lightened(0.22)
		# Ground shadow hugging the base, on the floor side (south).
		draw_rect(Rect2(-w * 0.5, 0.0, w, 5.0), Color(0.0, 0.0, 0.0, 0.22), true)
		# The face: slightly darker than the roof, catching less sky.
		draw_rect(Rect2(-w * 0.5, -face, w, face), body.darkened(0.10), true)
		# The roof: the lit top.
		draw_rect(Rect2(-w * 0.5, -h - face, w, h), lit, true)
		# A lip line where face meets roof, so the edge reads.
		draw_rect(Rect2(-w * 0.5, -face - 2.0, w, 2.0), Color(0.0, 0.0, 0.0, 0.30), true)
		draw_rect(Rect2(-w * 0.5, -h - face, w, h + face), edge, false, 1.5)


## Paint blobs, drawn as world-space circles.
class PaintDraw extends Node2D:
	var blobs: Array = []

	func _draw() -> void:
		for b in blobs:
			draw_circle(b[0], b[1], b[2])
