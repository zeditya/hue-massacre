class_name Room
extends Node2D
##
## ROOM - builds one level from LevelData and runs its rules.
##
## Draw order inside the room is explicit and fixed:
##     room itself (floor pass)     z = 0   flagstones, mark, light pools, shadows
##     PaintLayer (the splats)      z = -2
##     BloodField (the gore)        z = -1  (just above the paint)
##     everything solid             z = 0, sorted by its ground line:
##         wall blocks, props, guards, the player, motes
##     RoomFront (crowd, weather)   z = 10  may never be hidden
## Anything with a higher z_index is drawn later, i.e. on top, and the y-sort
## inside a z layer is what makes a knight vanish behind a pillar.
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
## A blow was turned on a freshly raised guard. `staggered` is false when there
## was nobody close enough to blame - the parry still happened.
signal player_parried(at: Vector2, staggered: bool)
## A hit on the player left real damage (feedback and crowd reactions).
signal player_hurt(at: Vector2)

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
@export var wall_colour: Color = Color(0.30, 0.29, 0.32)
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

## How long a PARRY leaves the attacker open. Longer than any hit's flinch,
## because the parry cost the player the risk of standing still on the beat.
@export var parry_stagger: float = 1.15
## How close to the turned blow the attacker has to be to be held responsible.
@export var parry_blame_radius: float = 90.0

## A wave room holds its breath for this long after the last knight of a wave
## falls, then the next pack marches in.
@export var intermission_seconds: float = 2.0

## Which entry of LevelData.ROOMS to build. Set this before adding the room.
var room_index: int = 0
## The dictionary this room was built from.
var data: Dictionary = {}
var paint: PaintLayer = null
## The look of the fight's blood: sprays, stains and pools. Purely cosmetic -
## the RULES read `paint` for floor colour, so blood can never change a rule.
var blood: BloodField = null
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
var _wall_tint: Color = Color(0.30, 0.29, 0.32)
## The front layer: crowd, dust, weather and combat flashes, above everything.
var front: RoomFront = null
## Where the arena's fires burn, for the floor pass's light pools.
var _lights: Array = []
## The crowd's excitement this frame, published by game.gd. Read in _process so
## the draw code never has to go looking for the game.
var _excitement: float = 0.0
var _player_gone: bool = false
var _cleared: bool = false
var _last_boss_vulnerable: bool = false
## Once per room, the sworn notice the Unsworn is nearly finished and say so.
var _blood_tasted: bool = false


func _ready() -> void:
	# Resolve strikes AFTER the actors have moved. Godot processes a parent
	# before its children, so without this the room would read the blade state
	# from before this frame's swing: the first frame of every cut would whiff.
	process_physics_priority = 1

	# The arena has DEPTH: its wall blocks, props and fighters are all sorted by
	# the ground line they stand on, so a knight who walks behind a pillar is
	# actually hidden by it. The flat layers opt out through their z_index,
	# which is checked before the y-sort.
	y_sort_enabled = true

	var all_rooms: Array = LevelData.ROOMS
	room_index = clampi(room_index, 0, all_rooms.size() - 1)
	data = all_rooms[room_index]

	# Walls = the generated border plus whatever this room lists.
	_walls = LevelData.border_walls()
	for extra in data["walls"]:
		_walls.append(extra)
	_wall_tint = data.get("wall_color", wall_colour)

	_build_wall_bodies()
	_build_walls_visual()

	# The paint layer is a picture ON THE FLOOR: it lies below every sorted
	# object, so a fighter can never be drawn under a splat.
	paint = PaintLayer.new()
	paint.name = "Paint"
	add_child(paint)

	# The gore layer sits just above the paint: same tile of the world, but only
	# a picture. Nothing reads it, so it can never break a colour rule.
	blood = BloodField.new()
	blood.name = "Blood"
	add_child(blood)

	_build_player()
	_build_guards()
	_build_motes()
	_build_props()

	# The front layer: anything that may never be hidden - the crowd leaning
	# over the parapet, the dust, the weather, the combat flashes.
	front = RoomFront.new()
	front.name = "Front"
	front.room = self
	front.z_index = 10
	add_child(front)

	spawn_point = player.position
	queue_redraw()


func _process(_delta: float) -> void:
	# The arena is never a still image: the torches flicker, the crowd sways and
	# the arena mark breathes, so the room redraws every frame.
	queue_redraw()
	_excitement = _read_crowd_excitement()


## The crowd's excitement, published by game.gd once per frame (0 when nothing
## publishes it - e.g. in the test scenes).
func _read_crowd_excitement() -> float:
	if get_tree() == null or get_tree().root == null:
		return 0.0
	var root: Window = get_tree().root
	if root.has_node("Game"):
		var game_instance: Game = root.get_node("Game")
		return game_instance.get_crowd_excitement()
	return 0.0


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


## One WallNode per wall rect: the block with height that actually gets drawn.
## The four border walls (which `LevelData.walls_for` always returns first) are
## heavy - a tall face and a deep lift - and the interior obstacles are lower,
## because the border is the arena's outer wall and the rest is furniture.
func _build_walls_visual() -> void:
	const BORDER_WALLS: int = 4
	for i in _walls.size():
		var r: Rect2 = _walls[i]
		if r.size.x < 3.0 or r.size.y < 3.0:
			continue
		var heavy: bool = i < BORDER_WALLS
		var lift: float = 12.0 if heavy else 8.0
		var face: float = 18.0 if heavy else clampf(r.size.y * 0.55, 6.0, 15.0)
		var node := WallNode.new()
		node.name = "Wall%d" % i
		add_child(node)
		node.setup(r, _wall_tint, lift, face)


## The arena's furniture: the braziers from the room data, watch-fire torches
## along the long walls, and whatever dressing the room lists under "props".
## Every one is drawn from its base, so they sort against the fighters.
func _build_props() -> void:
	var accent: Color = data.get("accent", Color(1.0, 0.82, 0.25))

	# The braziers: the arena's official fires. Their pools join the floor
	# pass; their flames are props like any other.
	for b in data.get("braziers", []):
		var pos: Vector2 = b
		var brazier := PropNode.new()
		brazier.name = "Brazier%d" % _lights.size()
		add_child(brazier)
		brazier.place(pos, "brazier", accent)
		_lights.append(pos)

	# Watch-fire torches on the long interior walls - the ring of fire that
	# lights the reference battlefields. Placed just outside the wall's face so
	# both torch and pool stay visible.
	const BORDER_WALLS: int = 4
	for i in _walls.size():
		if i < BORDER_WALLS:
			continue
		var r: Rect2 = _walls[i]
		var horizontal: bool = r.size.x >= r.size.y
		var span: float = r.size.x if horizontal else r.size.y
		if span < 140.0:
			continue
		var count: int = clampi(int(span / 200.0), 1, 3)
		for t in count:
			var f: float = (float(t) + 0.5) / float(count)
			var at: Vector2 = Vector2(r.position.x + r.size.x * f, r.end.y + 3.0)
			if not horizontal:
				at = Vector2(r.end.x + 4.0, r.position.y + r.size.y * f)
			var torch := PropNode.new()
			torch.name = "Torch%d" % _lights.size()
			add_child(torch)
			torch.place(at, "torch", accent)
			_lights.append(at)

	# Loose dressing: rubble, bones, herald pillars. Purely a picture - the
	# solid ones (plinths) are wall rects in the level data, not props.
	var dressing: Array = data.get("props", [])
	for j in dressing.size():
		var p: Dictionary = dressing[j]
		var prop := PropNode.new()
		prop.name = "Prop%d" % j
		add_child(prop)
		prop.place(p.get("pos", Vector2.ZERO), p.get("kind", "rubble"), accent, float(p.get("scale", 1.0)))


func _build_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.body_radius = LevelData.PLAYER_RADIUS
	player.colour = data["start_color"]
	player.hide_tolerance_deg = hide_tolerance_deg
	# The room sits at the origin, so position and global_position agree here.
	player.position = data["start"]
	player.died.connect(_on_player_died)
	# Blood on the player: a real hit leaves a spray of their own hue behind.
	player.hurt.connect(_on_player_hurt)
	# A swung blade is loud: nearby guards hear it and come to look. The same
	# signal also runs the room's gentle auto-aim (see _on_player_struck).
	player.struck.connect(_on_player_struck)
	# A parried blow leaves the attacker wide open: the room is the only place
	# that knows who swung it, so the reward is handed out here.
	player.parried.connect(_on_player_parried)
	# Reference to blood field for footprints
	player.blood = blood
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
	guard.sight_range = float(spec.get("sight", 310.0))
	guard.sight_arc_deg = float(spec.get("sight_arc", 64.0))
	guard.hue_speed = float(spec.get("hue_speed", 0.0))
	guard.hide_tolerance_deg = hide_tolerance_deg
	# Which armour this one wears. A spec may name it outright ("unit"), which
	# is how the Champion's summons march in as the stands' axe hands; failing
	# that it is read off the build - the heavy carries the shield, the fast
	# and fragile one is out of the crowd with a knife.
	var unit_kind: String = str(spec.get("unit", ""))
	if unit_kind.is_empty():
		if guard.is_boss:
			unit_kind = "champion"
		elif guard.body_radius > LevelData.GUARD_RADIUS + 1.5:
			unit_kind = "warden"
		elif float(spec.get("hp", 60.0)) <= 50.0:
			unit_kind = "harrier"
		else:
			unit_kind = "knight"
	guard.unit = unit_kind
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
	_update_blood_taste()
	_resolve_strikes()
	_resolve_motes()
	_update_waves(delta)


## The hall can taste a dying knight: the first time the Unsworn drops below a
## third of their vigour, every sworn hunting them says so. Once per hall.
func _update_blood_taste() -> void:
	if _blood_tasted or player.hp > player.max_hp * 0.34:
		return
	_blood_tasted = true
	for guard in guards:
		if is_instance_valid(guard) and not guard.dead:
			guard.taste_blood()


## Work out how visible the Unsworn is right now, and store it on the player so
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
			# The turning wheel turns the blade aside, unless the hues cancel.
			guard.clang()
			continue
		var kind: int = ColorTheory.hit_kind(player.colour, guard.colour)
		var damage: float = player.strike_damage_now() * ColorTheory.hit_multiplier(kind)
		var is_heavy: bool = player.strike_is_heavy()
		var is_shatter: bool = (kind == ColorTheory.Hit.SHATTER)
		if guard.take_hit(damage, is_shatter, is_heavy,
				player.global_position, player.strike_serial):
			strike_landed.emit(kind, guard.position)
			report_strike_effect(kind, guard.position, player.colour, guard.colour, is_heavy)			# Every hit bleeds. A heavy swing sprays harder than a graze.
			# Shatter hits spray dramatically more (arterial).
			if blood != null:
				var power: float = 1.0
				if is_heavy:
					power = 1.8
				if is_shatter:
					power = 2.5
				blood.spray(guard.global_position, guard.global_position - player.global_position,
					guard.colour, power, is_heavy, is_shatter)


## Scripted kills (and the test suite's short-cut for them) land here. Every
## way a guard can die now goes through die(), so the accounting only has to
## happen in one place: _on_guard_killed below.
func _kill_guard(guard: Guard) -> void:
	guard.die()


## The guard announced its death - however it happened (the player's blade, a
## test calling _kill_guard). The room does the accounting here, so no path
## can kill a guard without spilling its colour or feeding the player's hue.
func _on_guard_killed(guard: Guard) -> void:
	# 1. The knight's hue hits the sand, in his own colour.
	#    A boss throws a much larger splat, which also fills the restore bar fast.
	paint.spawn(guard.position, guard.colour, 2.2 if guard.is_boss else 1.0)
	# A pool of blood spreads under the body - permanent-ish on the sand,
	# so the arena grows more butchered as the melee goes on.
	if blood != null:
		var pool_scale: float = 3.0 if guard.is_boss else 1.0
		blood.pool(guard.position, guard.colour, pool_scale)
		# Wall splatter if guard dies near a wall
		for wall in _walls:
			var dist: float = _point_to_rect_dist(guard.position, wall)
			if dist < 60.0:
				# Find closest point on wall
				var closest: Vector2 = Vector2(
					clampf(guard.position.x, wall.position.x, wall.end.x),
					clampf(guard.position.y, wall.position.y, wall.end.y)
				)
				var to_wall: Vector2 = (closest - guard.position).normalized()
				# Wall normal pointing inward
				var wall_normal: Vector2
				if abs(closest.x - wall.position.x) < 5.0:
					wall_normal = Vector2.RIGHT
				elif abs(closest.x - wall.end.x) < 5.0:
					wall_normal = Vector2.LEFT
				elif abs(closest.y - wall.position.y) < 5.0:
					wall_normal = Vector2.DOWN
				else:
					wall_normal = Vector2.UP
				blood.splatter_on_wall(closest, to_wall, guard.colour, wall_normal)

	# 2. The Unsworn DRINKS the colour. This is what makes the camouflage loop work:
	#    the paint you just made matches the hue you now are, so the ground you
	#    are standing on hides you from whoever is left.
	#    (A previous version of this file forgot this line, and the test suite
	#     caught it - the player stayed white and could never hide.)
	player.absorb_colour(guard.colour)
	# The colour changing hands is visible: the Unsworn takes the hue with a
	# burst of it, right where the knight fell.
	queue_fx("splash", guard.position, guard.colour, 0.9 if not guard.is_boss else 1.6)
	report_kill_effect(guard.position, guard.colour)
	# 3. Then the guard leaves the field. Every sworn in earshot sees an ally's
	#    colour go out, and says so - the hall is a place with people in it, not
	#    a spawner, and the barks are how the player hears that.
	guards.erase(guard)
	for other in guards:
		if is_instance_valid(other) and not other.dead \
				and other.global_position.distance_to(guard.global_position) <= shout_radius:
			other.grieve(guard.colour)
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


static func _point_to_rect_dist(point: Vector2, rect: Rect2) -> float:
	var dx: float = maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy: float = maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return sqrt(dx * dx + dy * dy)


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


## Touching a mote drinks it: the Unsworn takes its hue outright, and the mote
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
			# A mote going down the Unsworn's throat: the pack's spell burst, in
			# the mote's own colour, so the hue that is about to be worn is seen
			# before it is worn.
			queue_fx("magic", mote.position, mote.colour, 1.0)


func _on_player_died() -> void:
	_player_gone = true
	player_died.emit()


## The Unsworn took a hit. Spray a little of their own blood behind them.
func _on_player_hurt(amount: float, from_position: Vector2) -> void:
	if blood == null:
		return
	var dir: Vector2 = (player.global_position - from_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	blood.spray(player.global_position, dir, player.colour, amount / 20.0)


## The Unsworn swung the blade. Two jobs, in order:
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


## The Unsworn caught a blow on the blade in the parry window. The blow itself
## is already turned (the player did that); this is where the room hands out
## the reward, because only the room knows WHO swung:
##   * whoever threw it is left open far longer than any hit could leave them,
##   * and they say so, in their own voice.
## A parry with nobody close enough to blame still reads as a parry: the clang
## and the ward are the player's, the stagger is a bonus.
func _on_player_parried(from_position: Vector2) -> void:
	var target: Guard = _nearest_guard_to(from_position, parry_blame_radius)
	var staggered: bool = false
	if target != null:
		# A boss is not floored by one good read, but he IS opened up: this is
		# the player's free swing, and it has to be worth the risk taken.
		var open_time: float = parry_stagger * (0.7 if target.is_boss else 1.0)
		target.stagger_left = maxf(target.stagger_left, open_time)
		target.bark("parried")
		staggered = true
	player_parried.emit(from_position, staggered)


## Closest living guard to a point, within `max_dist`.
func _nearest_guard_to(pos: Vector2, max_dist: float) -> Guard:
	var best: Guard = null
	var best_dist: float = max_dist
	for guard in guards:
		if not is_instance_valid(guard) or guard.dead:
			continue
		var d: float = guard.position.distance_to(pos)
		if d > best_dist:
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
		# An Aspirant does not walk on: he is called. The bolt lands with him,
		# in the hue of the officer whose name he answers.
		queue_fx("lightning", guard.position, guard.colour, 0.9)
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
# Drawing - the living arena
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Collect fighter positions for sunlight shadows
	var fighter_positions: Array[Vector2] = []
	if player != null and is_instance_valid(player):
		fighter_positions.append(player.global_position)
	for guard in guards:
		if is_instance_valid(guard) and not guard.dead:
			fighter_positions.append(guard.global_position)

	# The ground pass: the laid flagstones, the arena's mark, the firelight
	# pools and every fighter's shadow. Under the fighters, under the walls.
	_draw_floor(LevelData.PLAYFIELD)
	if arena_floor:
		ArenaArt.draw_floor_atmosphere(self, data, time_in_room, fighter_positions, _excitement, _lights)
	else:
		for r in _walls:
			_draw_wall(r)

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


## The front pass, called by RoomFront (z = 10): the crowd on the parapet, the
## dust and weather in the air, the vignette, and the combat flashes. None of
## it may ever be covered by a wall or a fighter.
func draw_front(canvas: CanvasItem) -> void:
	if arena_floor:
		ArenaArt.draw_arena_front(canvas, data, time_in_room, _excitement)
	_draw_combat_effects(canvas)


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


# ---------------------------------------------------------------------------
# Combat Effects Queue - visual feedback for hits, shatters, kills
# ---------------------------------------------------------------------------

## How long each pack effect runs, in seconds. Matched to the frame counts in
## ArenaArt.FX so a burst plays exactly once across its life.
const FX_DURATIONS: Dictionary = {
	"impact": 0.38,
	"splatter": 0.55,
	"magic": 0.70,
	"explosion": 0.42,
	"splash": 0.42,
	"dust": 0.40,
	"lightning": 0.42,
}

var _combat_effects: Array = []

## Queue a combat effect to be drawn for a few frames
func queue_combat_effect(effect_type: String, pos: Vector2, colour: Color, intensity: float = 1.0) -> void:
	_combat_effects.append({
		"type": effect_type,
		"pos": pos,
		"colour": colour,
		"intensity": intensity,
		"time": 0.0,
		"duration": 0.5  # seconds
	})


## Queue one of the packs' effects (see ArenaArt.FX): an impact burst, a spray
## of blood, a roll's dust, the magic of a hue changing hands. `colour` is the
## colour the moment belongs to - the attacker's, the victim's, the mote's.
func queue_fx(effect: String, pos: Vector2, colour: Color, scale: float = 1.0) -> void:
	_combat_effects.append({
		"type": "fx",
		"fx": effect,
		"pos": pos,
		"colour": colour,
		"intensity": scale,
		"time": 0.0,
		"duration": float(FX_DURATIONS.get(effect, 0.45)),
	})


func _draw_combat_effects(canvas: CanvasItem) -> void:
	var i: int = _combat_effects.size() - 1
	while i >= 0:
		var effect: Dictionary = _combat_effects[i]
		effect["time"] += get_process_delta_time()
		if effect["time"] >= effect["duration"]:
			_combat_effects.remove_at(i)
		else:
			var t: float = effect["time"] / effect["duration"]
			match effect["type"]:
				"hit":
					ArenaArt.draw_hit_flash(canvas, effect["pos"], effect["colour"], effect["intensity"], t)
				"shatter":
					ArenaArt.draw_shatter_effect(canvas, effect["pos"], effect["colour"], t)
				"kill":
					ArenaArt.draw_kill_effect(canvas, effect["pos"], effect["colour"], t)
				"fx":
					ArenaArt.draw_fx(canvas, effect["fx"], effect["pos"], effect["colour"], t, effect["intensity"])
		i -= 1


## Called from game.gd when strike lands. The drawn flash and the pack's burst
## go down together: the flash is the IMPACT (white core, sparks), the burst is
## the armour being struck, and both take the defender's hue - except on a
## shatter, which is the player's own colour cancelling theirs.
func report_strike_effect(kind: int, at: Vector2, player_colour: Color, guard_colour: Color, is_heavy: bool) -> void:
	var intensity: float = 1.0
	if is_heavy:
		intensity = 1.5
	if kind == ColorTheory.Hit.SHATTER:
		intensity = 2.0
		queue_combat_effect("shatter", at, player_colour, intensity)
		queue_fx("explosion", at, player_colour, 1.25)
	elif kind == ColorTheory.Hit.ABSORBED:
		# Nothing bites: the blade turns on the armour. A small, wrong noise.
		queue_combat_effect("hit", at, guard_colour, 0.7)
		queue_fx("impact", at, guard_colour, 0.62)
	else:
		queue_combat_effect("hit", at, guard_colour, intensity)
		queue_fx("impact", at, guard_colour, 0.85 + 0.25 * (intensity - 1.0))

## Called from game.gd when guard killed
func report_kill_effect(at: Vector2, colour: Color) -> void:
	queue_combat_effect("kill", at, colour, 1.5)
	# The wound is the loudest colour in the game: arterial, and it is his hue.
	queue_fx("splatter", at, colour, 1.15)
