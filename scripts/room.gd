class_name Room
extends Node2D
##
## ROOM - builds one level from LevelData and runs its rules.
##
## Draw order inside the room is explicit and fixed:
##     room itself (floor + walls)  z = 0
##     PaintLayer (the splats)      z = 1
##     Guards                       z = 2
##     Player                       z = 3
## Anything with a higher z_index is drawn later, i.e. on top.
##
## The room is also the only place that knows the answers to:
##     "what colour is the floor here?"   -> ground_colour_at()
##     "is there a wall between A and B?" -> raycast_distance()
## and it is the only place that decides who dies, so there is exactly one
## rule book instead of two scripts disagreeing with each other.

signal guard_killed(guard: Guard)
signal player_died
signal room_cleared
signal boss_vulnerable_changed(is_vulnerable: bool)

@export_group("Rules")
## The boss can only be cut while the player's hue sits on his COMPLEMENT,
## within this many degrees either way. 25 gives a 50-degree kill window.
@export var boss_kill_tolerance_deg: float = 25.0
## Extra reach on the blade so kills feel generous instead of pixel-perfect.
@export var blade_reach_bonus: float = 8.0
## Must be the same value the guards use, or the visuals would lie.
@export var hide_tolerance_deg: float = 26.0

@export_group("Look")
## Must match ColorTheory.FLOOR_GREY: the picture and the rules are one thing.
@export var floor_colour: Color = Color(0.30, 0.30, 0.33)
@export var floor_grid_colour: Color = Color(1.0, 1.0, 1.0, 0.03)
@export var wall_colour: Color = Color(0.09, 0.09, 0.12)
@export var wall_edge_colour: Color = Color(0.24, 0.24, 0.30)
@export var grid_step: float = 64.0
## Draw the tiled Modern Interiors floor instead of the flat grey wash. Turn it
## off for the original flat-grey look. This only changes the PICTURE: collision
## and the colour rules are identical either way.
@export var tiled_floor: bool = true

## Which entry of LevelData.ROOMS to build. Set this before adding the room.
var room_index: int = 0
## The dictionary this room was built from.
var data: Dictionary = {}
var paint: PaintLayer = null
var player: Player = null
var guards: Array[Guard] = []
var boss: Guard = null
## Seconds since the room was built. Guards stay blind for SPAWN_GRACE.
var time_in_room: float = 0.0

var spawn_point: Vector2 = Vector2.ZERO
var _walls: Array = []
## Per-room wall tint, from the room's "wall_color", so the four rooms do not
## all read as the same grey box.
var _wall_tint: Color = Color(0.09, 0.09, 0.12)
var _player_gone: bool = false
var _cleared: bool = false
var _last_boss_vulnerable: bool = false


func _ready() -> void:
	var all_rooms: Array = LevelData.ROOMS
	room_index = clampi(room_index, 0, all_rooms.size() - 1)
	data = all_rooms[room_index]

	# Walls = the generated border plus whatever this room lists.
	_walls = LevelData.border_walls()
	for extra in data["walls"]:
		_walls.append(extra)
	_wall_tint = data.get("wall_color", wall_colour)

	_build_wall_bodies()

	# The paint layer is added FIRST so it is earliest in the child order at
	# its own z_index, but its z_index of 1 already guarantees the ordering.
	paint = PaintLayer.new()
	paint.name = "Paint"
	add_child(paint)

	_build_player()
	_build_guards()

	spawn_point = player.position
	queue_redraw()


func _process(_delta: float) -> void:
	# Only the spawn ring animates, and only for the first couple of seconds.
	if time_in_room < LevelData.SPAWN_GRACE:
		queue_redraw()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_wall_bodies() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	# Walls live on physics layer 1; actors are on layer 2 and only collide
	# with layer 1, which is how the player and guards walk through each other.
	body.collision_layer = 1
	body.collision_mask = 0
	for r in _walls:
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = r.size
		var shape := CollisionShape2D.new()
		shape.shape = rect_shape
		shape.position = r.position + r.size * 0.5
		body.add_child(shape)
	add_child(body)


func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.body_radius = LevelData.PLAYER_RADIUS
	player.colour = data["start_color"]
	player.hide_tolerance_deg = hide_tolerance_deg
	# The room sits at the origin, so position and global_position agree here.
	player.position = data["start"]
	player.died.connect(_on_player_died)
	add_child(player)


func _build_guards() -> void:
	for spec in data["guards"]:
		var guard := Guard.new()
		guard.name = "Guard"
		guard.colour = spec["color"]
		guard.is_boss = bool(spec.get("boss", false))
		guard.body_radius = float(spec.get("radius", LevelData.GUARD_RADIUS))
		guard.patrol_speed = float(spec.get("speed", 75.0))
		guard.chase_speed = float(spec.get("chase", 165.0))
		guard.cone_length = float(spec.get("cone", 310.0))
		guard.cone_angle_deg = float(spec.get("cone_angle", 64.0))
		guard.hue_speed = float(spec.get("hue_speed", 0.0))
		guard.hide_tolerance_deg = hide_tolerance_deg

		var route := PackedVector2Array()
		for point in spec["path"]:
			route.append(point)
		guard.patrol_points = route

		# Everything that _ready() needs must be set BEFORE add_child().
		guard.position = spec["pos"]
		guard.room = self
		guard.killed.connect(_on_guard_killed)
		guards.append(guard)
		add_child(guard)
		if guard.is_boss:
			boss = guard


# ---------------------------------------------------------------------------
# Per-frame rules
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	time_in_room += delta
	if player == null or _cleared:
		return
	_update_camouflage()
	_update_boss_windows()
	_resolve_contacts()


## Work out how visible the spark is right now, and store it on the player so
## both the drawing and the HUD can show it.
func _update_camouflage() -> void:
	var ground: Color = ground_colour_at(player.position)
	var vis: float = ColorTheory.visibility(player.colour, ground, player.hide_tolerance_deg)
	player.visibility_now = vis
	# visibility() returns exactly 0 when the hues match inside the tolerance,
	# so "hidden" and "the guards cannot build detection" are the same fact.
	player.is_hidden = vis <= 0.0


## The Collector is only killable while the player's hue is on his complement.
func _update_boss_windows() -> void:
	if boss == null or boss.dead:
		return
	boss.vulnerable = ColorTheory.is_complement(player.colour, boss.colour, boss_kill_tolerance_deg)
	if boss.vulnerable != _last_boss_vulnerable:
		_last_boss_vulnerable = boss.vulnerable
		boss_vulnerable_changed.emit(boss.vulnerable)


## Touching is decided by distance, not by physics. It is one comparison and
## it cannot be affected by tunnelling, so it always behaves the same.
func _resolve_contacts() -> void:
	if _player_gone:
		return
	for guard in guards.duplicate():
		if guard.dead:
			continue
		var reach: float = player.body_radius + guard.body_radius + blade_reach_bonus
		if player.position.distance_to(guard.position) > reach:
			continue
		# Blade out AND the boss is inside the kill window -> they die.
		# Anything else (plain contact, or a mistimed lunge at the Collector)
		# kills the player. One hit kills, both ways.
		if player.is_dashing() and (not guard.is_boss or guard.vulnerable):
			_kill_guard(guard)
		else:
			player.kill()
			return


func _kill_guard(guard: Guard) -> void:
	# 1. The stolen colour hits the floor, in the guard's own hue.
	#    A boss throws a much larger splat, which also fills the restore bar fast.
	paint.spawn(guard.position, guard.colour, 2.2 if guard.is_boss else 1.0)
	# 2. The spark DRINKS the colour. This is what makes the stealth loop work:
	#    the paint you just made matches the hue you now are, so the ground you
	#    are standing on hides you from whoever is left.
	#    (A previous version of this file forgot this line, and the test suite
	#     caught it - the player stayed white and could never hide.)
	player.absorb_colour(guard.colour)
	# 3. The guard itself dies and announces it.
	guard.die()


func _on_guard_killed(guard: Guard) -> void:
	guards.erase(guard)
	guard_killed.emit(guard)
	if guards.is_empty() and not _cleared:
		_cleared = true
		room_cleared.emit()


func _on_player_died() -> void:
	_player_gone = true
	player_died.emit()


# ---------------------------------------------------------------------------
# Public queries used by guards, the HUD and the game controller
# ---------------------------------------------------------------------------

## The blended colour of the floor at `point`. Bare floor returns FLOOR_GREY.
func ground_colour_at(point: Vector2) -> Color:
	if paint == null:
		return ColorTheory.FLOOR_GREY
	var result: Array = paint.color_at(point)
	var colour: Color = result[0]
	return colour


## Fraction (0..1) of the segment from `from` to `to` that is walkable before
## hitting a wall. 1.0 means the whole segment is clear.
func raycast_distance(from: Vector2, to: Vector2) -> float:
	var best: float = 1.0
	for r in _walls:
		var t: float = _segment_rect_t(from, to, r)
		if t >= 0.0 and t < best:
			best = t
	return best


func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return raycast_distance(from, to) >= 0.9999


## Slab test: where along the segment does it first enter this rectangle?
## Returns -1.0 for a miss, otherwise t in 0..1.
static func _segment_rect_t(a: Vector2, b: Vector2, r: Rect2) -> float:
	var d: Vector2 = b - a
	var tmin: float = 0.0
	var tmax: float = 1.0

	if absf(d.x) < 0.000001:
		if a.x < r.position.x or a.x > r.end.x:
			return -1.0
	else:
		var tx1: float = (r.position.x - a.x) / d.x
		var tx2: float = (r.end.x - a.x) / d.x
		tmin = maxf(tmin, minf(tx1, tx2))
		tmax = minf(tmax, maxf(tx1, tx2))

	if absf(d.y) < 0.000001:
		if a.y < r.position.y or a.y > r.end.y:
			return -1.0
	else:
		var ty1: float = (r.position.y - a.y) / d.y
		var ty2: float = (r.end.y - a.y) / d.y
		tmin = maxf(tmin, minf(ty1, ty2))
		tmax = minf(tmax, maxf(ty1, ty2))

	if tmin > tmax:
		return -1.0
	return tmin


## How much colour has come back into this room, 0..1, for the HUD bar.
func restore_ratio() -> float:
	return paint.coverage() if paint != null else 0.0


func alive_guard_count() -> int:
	return guards.size()


## Stop everything (used while the death or victory screen is up).
func freeze() -> void:
	set_physics_process(false)
	set_process(false)
	if player != null:
		player.frozen = true
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	for guard in guards:
		if is_instance_valid(guard):
			guard.set_physics_process(false)


# ---------------------------------------------------------------------------
# Drawing - the grey world itself
# ---------------------------------------------------------------------------

func _draw() -> void:
	var size: Vector2 = LevelData.PLAYFIELD

	_draw_floor(size)

	# Walls, drawn on top of the floor.
	for r in _walls:
		_draw_wall(r)

	# The spawn ring: a visible countdown telling you the guards are still
	# waking up, so the first second of a level is never a surprise death.
	if time_in_room < LevelData.SPAWN_GRACE:
		var left: float = 1.0 - time_in_room / LevelData.SPAWN_GRACE
		draw_arc(spawn_point, 30.0 + 26.0 * (1.0 - left), 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, 0.45 * left), 2.0, true)


## One wall block, given a little height: a lit top band, the body, and a
## shadow along the bottom edge. Three cheap `draw_rect` calls turn what used to
## be a flat grey rectangle into something that reads as a solid object, which
## matters when the whole room is built out of them.
func _draw_wall(r: Rect2) -> void:
	var body: Color = _wall_tint
	var lit: Color = body.lightened(0.22)
	var cap: float = minf(6.0, r.size.y * 0.4)

	draw_rect(r, body, true)
	# Lit top band - the face pointing at the "camera" is brighter.
	draw_rect(Rect2(r.position, Vector2(r.size.x, cap)), lit, true)
	# Shadowed lower lip, so blocks look like they have thickness.
	var lip: float = minf(4.0, r.size.y * 0.3)
	draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - lip), Vector2(r.size.x, lip)),
		Color(0.0, 0.0, 0.0, 0.35), true)
	draw_rect(r, wall_edge_colour, false, 1.5)


## The floor under everything. Prefers the baked tiled floor and falls back to
## the original flat grey wash if the tileset is missing.
func _draw_floor(size: Vector2) -> void:
	if tiled_floor:
		var tex: Texture2D = TileBank.floor_texture()
		if tex != null:
			# FLOOR_MODULATE darkens the tile to ColorTheory.FLOOR_GREY, so the
			# picture still shows the exact grey the rules measure against.
			draw_texture(tex, Vector2.ZERO, TileBank.FLOOR_MODULATE)
			return

	# Bare grey floor. This is the colour the camera sees when nothing matches.
	draw_rect(Rect2(Vector2.ZERO, size), floor_colour)

	# A faint grid gives the eye something to measure contrast against.
	var x: float = grid_step
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), floor_grid_colour, 1.0)
		x += grid_step
	var y: float = grid_step
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), floor_grid_colour, 1.0)
		y += grid_step
