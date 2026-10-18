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
##
## Since the arena rebuild a room can also be a SEQUENCE: guards carry a
## "wave" tag, the room feeds them in packs with a short intermission between,
## and only the last pack falling clears the room.

signal guard_killed(guard: Guard)
signal player_died
signal room_cleared
## A new pack of knights just stepped onto the floor (multi-wave rooms only).
signal wave_started(wave: int, total: int, count: int)
## The current wave has fallen; the next one is already on its way.
signal wave_cleared(wave: int)
signal boss_vulnerable_changed(is_vulnerable: bool)
## The Champion crossed into a new phase (2 adds the charge, 3 the summons).
signal boss_phase_changed(phase: int)
## The Champion called his Aspirants and they are now on the floor.
signal boss_summons_spawned(count: int)
## The Champion committed to a charging dash (feedback hook for game.gd).
signal boss_charge_started
## A strike landed on a guard (before any kill). kind = ColorTheory.Hit.
signal strike_landed(kind: int, at: Vector2)

@export_group("Rules")
## The boss can only be cut while the player's hue sits on his COMPLEMENT,
## within this many degrees either way. 25 gives a 50-degree kill window.
@export var boss_kill_tolerance_deg: float = 25.0
## How far a swing reaches beyond the two bodies is the PLAYER's strike_reach
## (it lives next to the arc that draws it, so reach and picture cannot drift).
## Must be the same value the guards use, or the visuals would lie.
@export var hide_tolerance_deg: float = 26.0

@export_group("Look")
## Must match ColorTheory.FLOOR_GREY: the picture and the rules are one thing.
@export var floor_colour: Color = Color(0.30, 0.30, 0.33)
@export var floor_grid_colour: Color = Color(1.0, 1.0, 1.0, 0.03)
@export var wall_colour: Color = Color(0.09, 0.09, 0.12)
@export var wall_edge_colour: Color = Color(0.24, 0.24, 0.30)
@export var grid_step: float = 64.0
## Draw the arena art (baked sand, stone masonry, the stands, the braziers and
## this arena's sigil) instead of the original flat grey wash. This only changes
## the PICTURE: collision and the colour rules are identical either way - the
## sand is deliberately desaturated enough to still count as "no colour" to
## ColorTheory.visibility().
@export var arena_floor: bool = true

## Guards within this range hear a lunge and come to investigate.
@export var hear_radius: float = 260.0
## Guards within this range react when an ally shouts that it has spotted you.
@export var shout_radius: float = 360.0

## A wave room holds its breath for this long after the last knight of a wave
## falls, then the next pack marches in.
@export var intermission_seconds: float = 2.0

## Which entry of LevelData.ROOMS to build. Set this before adding the room.
var room_index: int = 0
## The dictionary this room was built from.
var data: Dictionary = {}
var paint: PaintLayer = null
var player: Player = null
var guards: Array[Guard] = []
var boss: Guard = null
## Floating colour shards the player can drink to change hue. Built from the
## room's "motes" list; each one is consumed on touch.
var motes: Array[Mote] = []
## Seconds since the room was built. Guards stay blind for SPAWN_GRACE.
var time_in_room: float = 0.0

## Waves: an arena can feed its knights in packs. `guards` holds the LIVING
## ACTIVE knights; later packs wait hidden in `_reserve` until the floor is
## silent, then march in (see _update_waves / _call_next_wave).
var waves_total: int = 1
var current_wave: int = 1
## Seconds left before the next pack marches in; 0 when none is waiting.
var intermission_left: float = 0.0
var _reserve: Dictionary = {}

var spawn_point: Vector2 = Vector2.ZERO
var _walls: Array = []
## Per-room wall tint, from the room's "wall_color", so the four rooms do not
## all read as the same grey box.
var _wall_tint: Color = Color(0.09, 0.09, 0.12)
var _player_gone: bool = false
var _cleared: bool = false
var _last_boss_vulnerable: bool = false


func _ready() -> void:
	# Resolve strikes AFTER the actors have moved. Godot processes a parent
	# before its children, so without this the room would read the blade state
	# from before this frame's swing: the first frame of every cut would whiff.
	process_physics_priority = 1

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
	_build_motes()

	spawn_point = player.position
	queue_redraw()


func _process(_delta: float) -> void:
	# The arena is never a still image: the braziers flicker, the crowd sways and
	# the arena sigil breathes, so the room redraws every frame. It is cheap -
	# the sand is one texture and the walls are a handful of rects - but it is
	# worth knowing that this is why the room is not redrawn on demand.
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
	# A swung blade is loud: nearby guards hear it and come to look. The same
	# signal also runs the room's gentle auto-aim (see _on_player_struck).
	player.struck.connect(_on_player_struck)
	add_child(player)


func _build_guards() -> void:
	# Group the authored knights into waves. A spec with no "wave" tag is wave
	# 1, so a room without wave data fights its whole cast at once - exactly
	# the way every room did before waves existed.
	var by_wave: Dictionary = {}
	var highest: int = 0
	for spec in data["guards"]:
		var wave: int = maxi(int(spec.get("wave", 1)), 1)
		if not by_wave.has(wave):
			by_wave[wave] = []
		by_wave[wave].append(spec)
		highest = maxi(highest, wave)

	waves_total = maxi(int(data.get("waves", highest)), 1)
	current_wave = 1
	intermission_left = 0.0
	_reserve.clear()

	for wave_num in range(1, waves_total + 1):
		for spec in by_wave.get(wave_num, []):
			var guard: Guard = _make_guard(spec)
			if wave_num == 1:
				guards.append(guard)
				if guard.is_boss:
					boss = guard
			else:
				# Waiting in the wings: built and ready, but off the field
				# until _call_next_wave() wakes it.
				if not _reserve.has(wave_num):
					_reserve[wave_num] = []
				_reserve[wave_num].append(guard)
				guard.sleep_for_wave()

	# The first pack gets the same "WAVE 1 / N" herald call later packs do -
	# deferred, because the game finishes dressing the room (wiping old
	# messages) right after add_child(), and an immediate call would be lost.
	if waves_total > 1:
		_announce_wave.call_deferred(1, guards.size())


## Build one knight from its room spec. Everything _ready() needs must be set
## BEFORE add_child().
func _make_guard(spec: Dictionary) -> Guard:
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
	# Combat stats: a basic knight dies fast, the Champion of the Wheel
	# takes a full duel's worth of shatters. Room specs may override both.
	guard.max_hp = float(spec.get("hp", (400.0 if guard.is_boss else 60.0)))
	guard.damage = float(spec.get("damage", (25.0 if guard.is_boss else 12.0)))
	# The Champion's three-phase tuning comes from the room data, so the duel
	# is balanced in level_data.gd next to everything else.
	if guard.is_boss:
		guard.phase_two_ratio = float(spec.get("phase_two_ratio", guard.phase_two_ratio))
		guard.phase_three_ratio = float(spec.get("phase_three_ratio", guard.phase_three_ratio))
		guard.summons_count = int(spec.get("summons_count", guard.summons_count))

	var route := PackedVector2Array()
	for point in spec["path"]:
		route.append(point)
	guard.patrol_points = route

	guard.position = spec["pos"]
	guard.room = self
	guard.killed.connect(_on_guard_killed)
	guard.spotted.connect(_on_guard_spotted)
	if guard.is_boss:
		guard.phase_changed.connect(_on_boss_phase_changed)
		guard.summons_requested.connect(_on_boss_summons_requested)
		guard.charge_started.connect(func() -> void: boss_charge_started.emit())
	add_child(guard)
	return guard


func _build_motes() -> void:
	for spec in data.get("motes", []):
		var mote := Mote.new()
		mote.name = "Mote"
		mote.colour = spec["color"]
		mote.position = spec["pos"]
		motes.append(mote)
		add_child(mote)


# ---------------------------------------------------------------------------
# Per-frame rules
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	time_in_room += delta
	if player == null or _cleared:
		return
	_update_camouflage()
	_update_boss_windows()
	_resolve_strikes()
	_resolve_motes()
	_update_waves(delta)


## Work out how visible the spark is right now, and store it on the player so
## both the drawing and the HUD can show it.
func _update_camouflage() -> void:
	var ground: Color = ground_colour_at(player.position)
	var vis: float = ColorTheory.visibility(player.colour, ground, player.hide_tolerance_deg)
	player.visibility_now = vis
	# visibility() returns exactly 0 when the hues match inside the tolerance,
	# so "hidden" and "the guards cannot build detection" are the same fact.
	player.is_hidden = vis <= 0.0


## The Champion is only killable while the player's hue is on his complement.
func _update_boss_windows() -> void:
	if boss == null or boss.dead:
		return
	boss.vulnerable = ColorTheory.is_complement(player.colour, boss.colour, boss_kill_tolerance_deg)
	if boss.vulnerable != _last_boss_vulnerable:
		_last_boss_vulnerable = boss.vulnerable
		boss_vulnerable_changed.emit(boss.vulnerable)


## A landed swing is the only thing that wounds a knight. The blade cuts a
## WEDGE in front of the player (strike_half_deg either side of the swing) and
## the hue rule decides how hard: a complement SHATTERS the armour, a matching
## hue is ABSORBED. Guards swing back with their own attacks (guard.gd).
func _resolve_strikes() -> void:
	if _player_gone or not player.is_striking():
		return
	var half: float = player.strike_half_rad()
	for guard in guards.duplicate():
		if guard.dead:
			continue
		var to_guard: Vector2 = guard.position - player.position
		var reach: float = player.body_radius + guard.body_radius + player.strike_reach_now()
		if to_guard.length() > reach:
			continue
		# The blade cuts a wedge, not a circle: a knight at your back survives.
		if absf(_angle_delta(to_guard.angle(), player.strike_angle())) > half:
			continue
		if guard.is_boss and not guard.vulnerable:
			# The stolen wheel turns the blade aside, unless the hues cancel.
			guard.clang()
			continue
		var kind: int = ColorTheory.hit_kind(player.colour, guard.colour)
		var damage: float = player.strike_damage_now() * ColorTheory.hit_multiplier(kind)
		if guard.take_hit(damage, kind == ColorTheory.Hit.SHATTER, player.strike_is_heavy(),
				player.global_position, player.strike_serial):
			strike_landed.emit(kind, guard.position)


## Scripted kills (and the test suite's short-cut for them) land here. Every
## way a guard can die now goes through die(), so the accounting only has to
## happen in one place: _on_guard_killed below.
func _kill_guard(guard: Guard) -> void:
	guard.die()


## The guard announced its death - however it happened (the player's blade, a
## test calling _kill_guard). The room does the accounting here, so no path
## can kill a guard without spilling its colour or feeding the player's hue.
func _on_guard_killed(guard: Guard) -> void:
	# 1. The stolen colour hits the floor, in the guard's own hue.
	#    A boss throws a much larger splat, which also fills the restore bar fast.
	paint.spawn(guard.position, guard.colour, 2.2 if guard.is_boss else 1.0)
	# 2. The spark DRINKS the colour. This is what makes the stealth loop work:
	#    the paint you just made matches the hue you now are, so the ground you
	#    are standing on hides you from whoever is left.
	#    (A previous version of this file forgot this line, and the test suite
	#     caught it - the player stayed white and could never hide.)
	player.absorb_colour(guard.colour)
	# 3. Then the guard leaves the field.
	guards.erase(guard)
	guard_killed.emit(guard)
	if _cleared or not guards.is_empty():
		return
	# The floor is silent. If another pack is waiting, the arena holds its
	# breath for a moment and then calls it in; otherwise the room is done.
	if _has_queued_wave():
		intermission_left = intermission_seconds
		wave_cleared.emit(current_wave)
	else:
		_cleared = true
		room_cleared.emit()


# ---------------------------------------------------------------------------
# Waves
# ---------------------------------------------------------------------------

## Countdown between waves: when it runs out, the next pack steps in.
func _update_waves(delta: float) -> void:
	if intermission_left <= 0.0:
		return
	intermission_left = maxf(intermission_left - delta, 0.0)
	if intermission_left <= 0.0:
		_call_next_wave()


## Deferred form of wave_started for the first pack (see _build_guards).
func _announce_wave(wave_num: int, count: int) -> void:
	wave_started.emit(wave_num, waves_total, count)


## Wake the next wave. Wave numbers are dense (the test suite checks the
## data), but this skips a gap rather than deadlocking if one ever appears.
func _call_next_wave() -> void:
	var count: int = 0
	while count == 0 and _has_queued_wave() and current_wave < waves_total:
		current_wave += 1
		for guard in _reserve.get(current_wave, []):
			if is_instance_valid(guard) and not guard.dead:
				guard.wake_for_wave()
				guards.append(guard)
				count += 1
		_reserve.erase(current_wave)
	if count > 0:
		wave_started.emit(current_wave, waves_total, count)
	elif guards.is_empty():
		_cleared = true
		room_cleared.emit()


## True while any knight is still hidden away, waiting for a later wave.
func _has_queued_wave() -> bool:
	for wave_guards in _reserve.values():
		for guard in wave_guards:
			if is_instance_valid(guard) and not guard.dead:
				return true
	return false


## March every waiting pack onto the field at once. The game itself never does
## this - it calls waves in on the intermission timer - but the tests use it
## to stage a room's full cast without sitting through the pauses.
func release_all_waves() -> void:
	intermission_left = 0.0
	var released: int = 0
	for wave_num in range(current_wave + 1, waves_total + 1):
		for guard in _reserve.get(wave_num, []):
			if is_instance_valid(guard) and not guard.dead:
				guard.wake_for_wave()
				guards.append(guard)
				released += 1
		_reserve.erase(wave_num)
	if released > 0:
		current_wave = waves_total
		wave_started.emit(current_wave, waves_total, released)


## True while any knight still wears the just-arrived ring (see _draw).
func _wave_ring_active() -> bool:
	for guard in guards:
		if is_instance_valid(guard) and guard.spawn_grace_until > time_in_room:
			return true
	return false


## Touching a mote drinks it: the spark takes its hue outright, and the mote
## fades away. Same distance test as the guards, so it cannot be missed by
## tunnelling through it on a lunge.
func _resolve_motes() -> void:
	if _player_gone:
		return
	for mote in motes:
		if not is_instance_valid(mote) or mote.taken:
			continue
		if player.position.distance_to(mote.position) <= player.body_radius + mote.radius:
			mote.taken = true
			player.drink(mote.colour)


func _on_player_died() -> void:
	_player_gone = true
	player_died.emit()


## The spark swung the blade. Two jobs, in order:
##   1. GENTLE AUTO-AIM: if a knight already stands inside the swing's soft
##      arc (auto_aim_deg either side of where the player pointed), the swing
##      turns to face them. It never fires at a knight behind the player, so
##      it assists the aim without ever playing the game for you.
##   2. NOISE: a swung blade sings. Every knight close enough to hear it comes
##      to look - attacking still costs you your hiding place.
func _on_player_struck(direction: Vector2) -> void:
	if player == null or _player_gone:
		return
	var target: Guard = _nearest_guard_in_arc(direction.angle(),
		deg_to_rad(player.auto_aim_deg), player.body_radius + player.strike_reach_now() + 34.0)
	if target != null:
		player.aim_strike_at(target.global_position)
	for guard in guards:
		if is_instance_valid(guard) and not guard.dead \
				and guard.global_position.distance_to(player.global_position) <= hear_radius:
			guard.hear(player.global_position)


## Nearest living knight within `half` radians of `direction` and closer than
## `max_dist`. Used to pull a swing onto a target already in front of the
## player.
func _nearest_guard_in_arc(direction: float, half: float, max_dist: float) -> Guard:
	var best: Guard = null
	var best_dist: float = max_dist
	for guard in guards:
		if not is_instance_valid(guard) or guard.dead:
			continue
		var to_guard: Vector2 = guard.position - player.position
		var d: float = to_guard.length()
		if d > best_dist or absf(_angle_delta(to_guard.angle(), direction)) > half:
			continue
		best = guard
		best_dist = d
	return best


## Shortest signed distance between two angles (radians), wrapped to -PI..PI.
func _angle_delta(a: float, b: float) -> float:
	return fposmod(a - b + PI, TAU) - PI


## One guard locking on raises the alarm: nearby allies come to help.
func _on_guard_spotted(pos: Vector2) -> void:
	for guard in guards:
		if is_instance_valid(guard) and not guard.dead \
				and guard.global_position.distance_to(pos) <= shout_radius:
			guard.hear(pos)


# ---------------------------------------------------------------------------
# The Champion's phases
# ---------------------------------------------------------------------------

## Phase II and III are announced here so the game only has to listen once.
func _on_boss_phase_changed(phase: int) -> void:
	boss_phase_changed.emit(phase)


## The Champion called for help: the next `count` entries of the room's
## "summons" list march onto the floor. They join `guards`, so the arena is
## not clear until they are down, and they get the same arrival grace every
## wave gets - an Aspirant never appears already swinging.
func _on_boss_summons_requested(count: int) -> void:
	var specs: Array = data.get("summons", [])
	var spawned: int = 0
	for i in mini(count, specs.size()):
		var guard: Guard = _make_guard(specs[i])
		guard.spawn_grace_until = time_in_room + LevelData.SPAWN_GRACE
		guards.append(guard)
		spawned += 1
	if spawned > 0:
		boss_summons_spawned.emit(spawned)


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


## Living knights left in the arena overall: the ones on the floor plus the
## ones still waiting to march in.
func remaining_guard_count() -> int:
	var n: int = 0
	for guard in guards:
		if is_instance_valid(guard) and not guard.dead:
			n += 1
	for wave_guards in _reserve.values():
		for guard in wave_guards:
			if is_instance_valid(guard) and not guard.dead:
				n += 1
	return n


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

	# The arena's own mark on the sand, under the walls.
	if arena_floor:
		ArenaArt.draw_mark(self, data, time_in_room)

	# Walls, drawn on top of the floor and the mark.
	if arena_floor:
		ArenaArt.draw_walls(self, _walls, _wall_tint)
	else:
		for r in _walls:
			_draw_wall(r)

	# The stands and the fires that light the sand. Decoration only: nothing in
	# here is solid, so it can never block a fight.
	if arena_floor:
		var accent: Color = data.get("accent", UiStyle.GOLD)
		ArenaArt.draw_braziers(self, data.get("braziers", []), time_in_room, accent)
		ArenaArt.draw_stands(self, data, time_in_room)
		ArenaArt.draw_dust(self, time_in_room, accent)

	# The spawn ring: a visible countdown telling you the guards are still
	# waking up, so the first second of a level is never a surprise death.
	if time_in_room < LevelData.SPAWN_GRACE:
		var left: float = 1.0 - time_in_room / LevelData.SPAWN_GRACE
		draw_arc(spawn_point, 30.0 + 26.0 * (1.0 - left), 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, 0.45 * left), 2.0, true)

	# A ring around every knight that just marched in, in that knight's own
	# colour: wave arrivals read as arrivals, never as pop-ins.
	for guard in guards:
		if not is_instance_valid(guard):
			continue
		var arrived: float = (guard.spawn_grace_until - time_in_room) / LevelData.SPAWN_GRACE
		if arrived <= 0.0:
			continue
		draw_arc(guard.position, 30.0 + 26.0 * (1.0 - arrived), 0.0, TAU, 48,
			Color(guard.colour.r, guard.colour.g, guard.colour.b, 0.45 * arrived), 2.0, true)


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


## The floor under everything. Prefers the baked arena sand and falls back to
## the original flat grey wash if the arena art could not be baked.
func _draw_floor(size: Vector2) -> void:
	if arena_floor:
		var tex: Texture2D = ArenaArt.floor_texture(data)
		if tex != null:
			# The bake is half resolution; stretching it gives the sand its grain.
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
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
