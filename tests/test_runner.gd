extends Node
##
## TEST RUNNER - the automated half of TESTING.md.
##
## Run it with:
##     godot --headless --path . res://tests/test_runner.tscn
## It prints one line per check and exits non-zero if anything failed.
##
## Three layers, because they catch different things:
##   A. COLOUR MATHS  - the pure functions that the whole game rests on.
##   B. LEVEL GEOMETRY- proves no knight patrol route, mote or Aspirant spawn
##                      clips through a wall or is sealed off, which is the
##                      classic hand-built-level mistake.
##   C. INTEGRATION   - boots the real main.tscn and plays it: kills knights,
##                      runs the waves, triggers a combo, dies and restarts, and
##                      fights the Champion through all three of his phases.
##
## What this CANNOT check: anything that only happens in _draw(), because the
## headless build has no renderer. Those are covered by the manual checklist.

const YELLOW: Color = Color(1.0, 1.0, 0.0)      # 60 deg
const BLUE: Color = Color(0.0, 0.0, 1.0)        # 240 deg
const RED: Color = Color(1.0, 0.0, 0.0)         # 0 deg
const ORANGE: Color = Color(1.0, 0.5, 0.0)      # 30 deg
const GREEN: Color = Color(0.0, 1.0, 0.0)       # 120 deg
const PURPLE: Color = Color(0.75, 0.0, 1.0)     # 285 deg

var passed: int = 0
var failed: int = 0
var _game: Node = null


func _ready() -> void:
	print("=========================================================")
	print("HUE MASSACRE - automated test runner")
	print("Godot ", Engine.get_version_info()["string"])
	print("=========================================================")

	_section("A. COLOUR THEORY MATHS")
	_test_colour_theory()

	_section("B. LEVEL GEOMETRY")
	_test_levels()

	_section("C. INTEGRATION (real scene, scripted playthrough)")
	await _test_integration()

	print("=========================================================")
	print("RESULT: %d passed, %d failed" % [passed, failed])
	print("=========================================================")
	if _game != null and is_instance_valid(_game):
		remove_child(_game)
		_game.free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failed > 0 else 0)


# ---------------------------------------------------------------------------
# Tiny assertion helpers
# ---------------------------------------------------------------------------

func _section(title: String) -> void:
	print("\n--- %s" % title)


func check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		print("  FAIL  %s   %s" % [label, detail])


func check_approx(value: float, expected: float, tolerance: float, label: String) -> void:
	var ok: bool = absf(value - expected) <= tolerance
	check(ok, label, "expected %.2f +/- %.2f but got %.2f" % [expected, tolerance, value])


# ---------------------------------------------------------------------------
# A. Colour theory
# ---------------------------------------------------------------------------

func _test_colour_theory() -> void:
	# --- hue distance wraps around the wheel ------------------------------
	check_approx(ColorTheory.hue_gap(10.0, 350.0), 20.0, 0.01, "hue_gap wraps through 0 (10 vs 350 = 20)")
	check_approx(ColorTheory.hue_gap(0.0, 180.0), 180.0, 0.01, "hue_gap maxes at 180 (0 vs 180)")

	# --- the guard colours really are the hues we claim -------------------
	check_approx(RED.h * 360.0, 0.0, 0.5, "RED is 0 degrees")
	check_approx(ORANGE.h * 360.0, 30.0, 0.5, "ORANGE is 30 degrees")
	check_approx(YELLOW.h * 360.0, 60.0, 0.5, "YELLOW is 60 degrees")
	check_approx(GREEN.h * 360.0, 120.0, 0.5, "GREEN is 120 degrees")
	check_approx(BLUE.h * 360.0, 240.0, 0.5, "BLUE is 240 degrees")
	check_approx(PURPLE.h * 360.0, 285.0, 0.5, "PURPLE is 285 degrees")

	# --- complements, with the game's real 25 degree tolerance ------------
	check(ColorTheory.is_complement(YELLOW, BLUE, 25.0), "YELLOW <-> BLUE is a complement (exactly 180)")
	check(ColorTheory.is_complement(GREEN, PURPLE, 25.0), "GREEN <-> PURPLE is a complement (165)")
	check(not ColorTheory.is_complement(ORANGE, BLUE, 25.0), "ORANGE <-> BLUE is NOT (only 150 apart)")
	check(not ColorTheory.is_complement(RED, BLUE, 25.0), "RED <-> BLUE is NOT (only 120 apart)")
	check(not ColorTheory.is_complement(RED, GREEN, 25.0), "RED <-> GREEN is NOT (only 120 apart)")
	# NOTE: a tolerance of exactly 0.0 fails here, and that is expected rather
	# than a bug. Colors are 32-bit floats, so 60.0 and 240.00001 are both
	# "exactly 180 apart" to about 1e-5 of a degree. That is precisely why the
	# game never compares hues for equality and always uses a tolerance.
	check(ColorTheory.is_complement(YELLOW, BLUE, 0.5),
		"YELLOW <-> BLUE survives even a near-zero tolerance (float-safe)")

	# --- camouflage: the hiding rule -------------------------------------
	check_approx(ColorTheory.visibility(RED, RED, 26.0), 0.0, 0.001, "grey-free floor: RED on RED paint is INVISIBLE")
	check_approx(ColorTheory.visibility(YELLOW, BLUE, 26.0), 1.0, 0.001, "YELLOW on BLUE paint is fully exposed")
	check_approx(ColorTheory.visibility(RED, ColorTheory.FLOOR_GREY, 26.0), 1.0, 0.001,
		"bare grey floor always exposes you")
	# Inside the tolerance you are invisible; outside it the tell ramps up.
	check_approx(ColorTheory.visibility(ColorTheory.wheel(70.0), YELLOW, 26.0), 0.0, 0.001,
		"10 degrees off is still inside the 26 degree hide tolerance")
	var partial: float = ColorTheory.visibility(ColorTheory.wheel(100.0), YELLOW, 26.0)
	check(partial > 0.0 and partial < 1.0, "a 40 degree hue difference is a PARTIAL tell",
		"got %.3f" % partial)
	check_approx(ColorTheory.visibility(ColorTheory.wheel(240.0), YELLOW, 26.0), 1.0, 0.001,
		"a complementary floor exposes you completely (60 vs 240 = 180 apart)")
	check_approx(ColorTheory.visibility(Color(1.0, 1.0, 1.0), RED, 26.0), 1.0, 0.001,
		"a COLOURLESS spark can never hide in coloured paint")

	# --- mixing: hue-space, not RGB --------------------------------------
	var violet: Color = ColorTheory.blend([RED, BLUE], [1.0, 1.0])
	check_approx(violet.h * 360.0, 300.0, 1.5, "equal overlap of RED and BLUE paint averages to VIOLET (300)")

	# Two exactly opposite hues cancel out: the blend must not produce NaN.
	var cancelled: Color = ColorTheory.blend([YELLOW, BLUE], [1.0, 1.0])
	check(cancelled is Color and not is_nan(cancelled.h),
		"opposite hues that cancel still return a usable colour")
	var single: Color = ColorTheory.blend([], [])
	check(single == ColorTheory.FLOOR_GREY, "blending nothing gives back the bare floor grey")

	# --- absorption ------------------------------------------------------
	var from_white: Color = ColorTheory.absorb(Color(1.0, 1.0, 1.0), RED, 0.5)
	check_approx(from_white.h * 360.0, 0.0, 1.0, "a white spark takes the guard's hue outright")
	check(from_white.s >= 0.8, "and takes it at full saturation", "s=%.2f" % from_white.s)

	var red_then_blue: Color = ColorTheory.absorb(RED, BLUE, 0.5)
	check_approx(red_then_blue.h * 360.0, 300.0, 1.5, "absorbing BLUE into RED lands on VIOLET (300)")

	var red_then_yellow: Color = ColorTheory.absorb(RED, YELLOW, 0.5)
	check_approx(red_then_yellow.h * 360.0, 30.0, 1.5, "absorbing YELLOW into RED lands on ORANGE (30)")

	# --- naming ----------------------------------------------------------
	check(ColorTheory.color_name(ColorTheory.wheel(300.0)) == "VIOLET", "300 degrees is named VIOLET")
	check(ColorTheory.color_name(ColorTheory.FLOOR_GREY) == "GREY", "the bare floor is named GREY")

	# --- striking: the hue gap decides the damage -------------------------
	check(ColorTheory.hit_kind(RED, ColorTheory.complement(RED)) == ColorTheory.Hit.SHATTER,
		"a complement strike SHATTERS the armour")
	check(ColorTheory.hit_kind(RED, RED) == ColorTheory.Hit.ABSORBED,
		"a strike in the same hue is ABSORBED")
	check(ColorTheory.hit_kind(RED, GREEN) == ColorTheory.Hit.NEUTRAL,
		"everything in between is a plain CUT")
	check(ColorTheory.hit_kind(Color.WHITE, RED) == ColorTheory.Hit.NEUTRAL,
		"a colourless blade always deals a plain CUT")
	check_approx(ColorTheory.hit_multiplier(ColorTheory.Hit.SHATTER), 2.5, 0.001,
		"shatter deals x2.5 damage")
	check_approx(ColorTheory.hit_multiplier(ColorTheory.Hit.ABSORBED), 0.2, 0.001,
		"absorbed deals x0.2 damage")
	check_approx(ColorTheory.hit_multiplier(ColorTheory.Hit.NEUTRAL), 1.0, 0.001,
		"a cut deals x1 damage")


# ---------------------------------------------------------------------------
# B. Level geometry
# ---------------------------------------------------------------------------

## Shortest distance from a point to a rectangle (0 when inside it).
static func _point_rect_distance(p: Vector2, r: Rect2) -> float:
	var closest := Vector2(
		clampf(p.x, r.position.x, r.end.x),
		clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(closest)


## Grid resolution used by the reachability flood-fill, in pixels.
const CELL: float = 6.0


static func _cell_key(p: Vector2) -> Vector2i:
	return Vector2i(int(p.x / CELL), int(p.y / CELL))


static func _clear_of_walls(p: Vector2, walls: Array, clearance: float) -> bool:
	for r in walls:
		if _point_rect_distance(p, r) < clearance:
			return false
	return true


## Every grid cell the player can actually walk to, starting from the spawn and
## treating anything within the player's radius of a wall as solid. This is what
## catches content sealed behind geometry - a mote or a waypoint the player can
## see but never reach, which no per-point clearance check can detect.
static func _reachable_cells(room: Dictionary, walls: Array) -> Dictionary:
	var cols: int = int(LevelData.PLAYFIELD.x / CELL)
	var rows: int = int(LevelData.PLAYFIELD.y / CELL)
	var clearance: float = LevelData.PLAYER_RADIUS
	var free: Array = []
	for rr in rows:
		var row: Array = []
		for cc in cols:
			var p := Vector2((float(cc) + 0.5) * CELL, (float(rr) + 0.5) * CELL)
			row.append(_clear_of_walls(p, walls, clearance))
		free.append(row)

	var start: Vector2 = room["start"]
	var sc: int = clampi(int(start.x / CELL), 0, cols - 1)
	var sr: int = clampi(int(start.y / CELL), 0, rows - 1)

	var seen: Dictionary = {}
	var queue: Array = []
	# Seed a small patch around the spawn so the fill starts from open ground
	# even if the spawn's own cell centre happens to sit near a wall.
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c: int = sc + dx
			var r: int = sr + dy
			if c < 0 or r < 0 or c >= cols or r >= rows:
				continue
			if free[r][c]:
				seen[Vector2i(c, r)] = true
				queue.append(Vector2i(c, r))

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + off
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= cols or nxt.y >= rows:
				continue
			if seen.has(nxt) or not free[nxt.y][nxt.x]:
				continue
			seen[nxt] = true
			queue.append(nxt)
	return seen


func _test_levels() -> void:
	var rooms: Array = LevelData.ROOMS
	check(rooms.size() == 4, "there are 4 rooms (3 teaching + boss)", "found %d" % rooms.size())

	for room in rooms:
		# Read the walls through LevelData.walls_for() - the SAME function
		# room.gd builds the level with. Testing against a different wall list
		# than the game runs with would make every check below meaningless.
		var walls: Array = LevelData.walls_for(room)

		var name: String = room["name"]

		# --- the player's spawn must be standable -------------------------
		var start: Vector2 = room["start"]
		var start_clear: float = INF
		for r in walls:
			start_clear = minf(start_clear, _point_rect_distance(start, r))
		check(start_clear >= LevelData.PLAYER_RADIUS + 2.0,
			"%s: player spawn is clear of walls" % name,
			"clearance %.1f" % start_clear)

		# --- guard spawns and patrol routes ------------------------------
		var spec_list: Array = room["guards"]
		check(spec_list.size() >= 1, "%s: has guards" % name)
		for i in spec_list.size():
			var spec: Dictionary = spec_list[i]
			var radius: float = float(spec.get("radius", LevelData.GUARD_RADIUS))
			var route: Array = spec["path"]
			var worst: float = INF
			var worst_point: Vector2 = Vector2.ZERO

			# Walk every leg of the route in 4px steps and keep the closest
			# approach to any wall. This is what catches a patrol route that
			# would drag a guard's body through a pillar.
			var previous: Vector2 = Vector2(spec["pos"])
			var to_check: Array = [previous]
			for p in route:
				to_check.append(Vector2(p))
			for k in range(1, to_check.size()):
				var a: Vector2 = to_check[k - 1]
				var b: Vector2 = to_check[k]
				var length: float = a.distance_to(b)
				var steps: int = maxi(int(length / 4.0), 1)
				for s in steps + 1:
					var sample: Vector2 = a.lerp(b, float(s) / float(steps))
					for r in walls:
						var d: float = _point_rect_distance(sample, r)
						if d < worst:
							worst = d
							worst_point = sample

			var needed: float = radius + 2.0
			var inside: bool = (
				worst_point.x > 0.0 and worst_point.x < LevelData.PLAYFIELD.x
				and worst_point.y > 0.0 and worst_point.y < LevelData.PLAYFIELD.y)
			check(worst >= needed and inside,
				"%s: guard %d route clears every wall" % [name, i],
				"closest approach %.1f at %s (needs %.1f)" % [worst, str(worst_point), needed])

			check(route.size() >= 2, "%s: guard %d has a real patrol route" % [name, i])

		# --- the Champion's Aspirants must arrive somewhere standable -----
		# They are spawned mid-fight, so a summon point buried in a wall would
		# drop a knight into the stonework at the worst possible moment.
		for i in room.get("summons", []).size():
			var sspec: Dictionary = room["summons"][i]
			var sradius: float = float(sspec.get("radius", LevelData.GUARD_RADIUS))
			var sworst: float = INF
			var sroute: Array = [Vector2(sspec["pos"])]
			for p in sspec["path"]:
				sroute.append(Vector2(p))
			for k in range(1, sroute.size()):
				var sa: Vector2 = sroute[k - 1]
				var sb: Vector2 = sroute[k]
				var slen: float = sa.distance_to(sb)
				var ssteps: int = maxi(int(slen / 4.0), 1)
				for s in ssteps + 1:
					var sample: Vector2 = sa.lerp(sb, float(s) / float(ssteps))
					for r in walls:
						sworst = minf(sworst, _point_rect_distance(sample, r))
			check(sworst >= sradius + 2.0,
				"%s: aspirant %d's arrival route clears every wall" % [name, i],
				"closest approach %.1f" % sworst)

		# --- the Champion's Aspirants must arrive on open ground ----------
		# Summons are spawned at runtime, so they never pass through the guard
		# route checks above. Give them the same treatment: their spawn point
		# and every patrol leg have to clear the walls, and the flood-fill
		# below proves the player can walk to them.
		var summon_specs: Array = room.get("summons", [])
		for i in summon_specs.size():
			var sspec: Dictionary = summon_specs[i]
			var sradius: float = float(sspec.get("radius", LevelData.GUARD_RADIUS))
			var sworst: float = INF
			var spoints: Array = [Vector2(sspec["pos"])]
			for p in sspec["path"]:
				spoints.append(Vector2(p))
			for k in range(1, spoints.size()):
				var a: Vector2 = spoints[k - 1]
				var b: Vector2 = spoints[k]
				var steps: int = maxi(int(a.distance_to(b) / 4.0), 1)
				for s in steps + 1:
					var sample: Vector2 = a.lerp(b, float(s) / float(steps))
					for r in walls:
						sworst = minf(sworst, _point_rect_distance(sample, r))
			check(sworst >= sradius + 2.0,
				"%s: Aspirant %d route clears every wall" % [name, i],
				"closest approach %.1f" % sworst)

		# --- waves: numbered 1..N with knights in every one -----------------
		var spec_waves: Array = []
		for wspec in spec_list:
			var w: int = int(wspec.get("wave", 1))
			if not spec_waves.has(w):
				spec_waves.append(w)
		spec_waves.sort()
		var declared: int = maxi(int(room.get("waves", 1)), 1)
		var dense: bool = spec_waves.size() == declared
		for k in spec_waves.size():
			if spec_waves[k] != k + 1:
				dense = false
		check(dense, "%s: waves are numbered 1..%d with knights in each" % [name, declared],
			"found %s" % str(spec_waves))
		if int(room["id"]) == 3:
			check(declared == 1, "%s: the boss hall fights its whole cast at once" % name)
		else:
			check(declared >= 2, "%s: teaching arenas feed their knights in waves" % name)

		# --- the colour motes must be reachable --------------------------
		# A mote buried inside a wall is a small lie: the room shows a light you
		# can never touch. Check every one sits in open ground.
		for mote in room.get("motes", []):
			var mp: Vector2 = mote["pos"]
			var in_field: bool = (
				mp.x > LevelData.WALL and mp.x < LevelData.PLAYFIELD.x - LevelData.WALL
				and mp.y > LevelData.WALL and mp.y < LevelData.PLAYFIELD.y - LevelData.WALL)
			var clear: float = INF
			for r in walls:
				clear = minf(clear, _point_rect_distance(mp, r))
			check(in_field and clear >= 18.0,
				"%s: mote at %s is reachable" % [name, str(mp)],
				"clearance %.1f" % clear)

		# --- and nothing is sealed off behind a wall ----------------------
		# Clearance proves a point is not inside a wall; it does NOT prove the
		# player can walk there. Flood-fill the floor from the spawn so a mote
		# or a waypoint hidden in a sealed pocket fails loudly.
		var reach: Dictionary = _reachable_cells(room, walls)
		var motes_ok: bool = true
		for mote in room.get("motes", []):
			if not reach.has(_cell_key(Vector2(mote["pos"]))):
				motes_ok = false
		check(motes_ok, "%s: every colour mote can be walked to" % name)

		var routes_ok: bool = true
		for spec in spec_list + room.get("summons", []):
			if not reach.has(_cell_key(Vector2(spec["pos"]))):
				routes_ok = false
			for p in spec["path"]:
				if not reach.has(_cell_key(Vector2(p))):
					routes_ok = false
		check(routes_ok, "%s: every guard waypoint can be walked to" % name)

		var summons_ok: bool = true
		for sspec in room.get("summons", []):
			if not reach.has(_cell_key(Vector2(sspec["pos"]))):
				summons_ok = false
			for p in sspec["path"]:
				if not reach.has(_cell_key(Vector2(p))):
					summons_ok = false
		check(summons_ok, "%s: every aspirant can be walked to" % name)


# ---------------------------------------------------------------------------
# C. Integration
# ---------------------------------------------------------------------------

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _test_integration() -> void:
	# --- the character sprite system -------------------------------------
	# The characters are real animated figures now, not coloured dots, so the
	# sheet layout and the facing maths are worth checking explicitly.
	var bank: SpriteFrames = SpriteBank.adventurer()
	check(bank != null, "the character sprite bank builds")
	if bank != null:
		check(bank.get_animation_names().size() == 12,
			"the character has 12 animations (idle/run/attack x 4 facings)",
			"found %d" % bank.get_animation_names().size())
		var faces_ok: bool = true
		var frames_ok: bool = true
		for dir in SpriteBank.DIRECTIONS:
			for prefix in ["idle_", "run_", "attack_"]:
				var anim: String = prefix + dir
				if not bank.has_animation(anim):
					faces_ok = false
					continue
				if bank.get_frame_count(anim) != SpriteBank.FRAME_COUNT:
					frames_ok = false
		check(faces_ok, "every facing has idle, run and attack animations")
		check(frames_ok, "every animation is 8 frames (the sheet layout)")
	check(SpriteBank.dir_from_angle(0.0) == "right", "facing angle 0 points right")
	check(SpriteBank.dir_from_angle(PI * 0.5) == "down", "facing angle 90 points down")
	check(SpriteBank.dir_from_angle(PI) == "left", "facing angle 180 points left")
	check(SpriteBank.dir_from_angle(-PI * 0.5) == "up", "facing angle 270 points up")

	var scene: PackedScene = load("res://scenes/main.tscn")
	check(scene != null, "main.tscn loads")
	if scene == null:
		return
	_game = scene.instantiate()
	add_child(_game)
	await _frames(3)

	# --- the game opens IN the arena --------------------------------------
	# The start menu and the story cards were deliberately cut: the build boots
	# straight into round one of the melee, with no page to click through.
	check(_game.state == Game.State.PLAY, "the game boots straight into play")
	check(_game.screens != null and _game.screens.mode == Screens.Mode.NONE,
		"and no page is blocking the arena")
	check(_game.room != null, "the first arena is built on boot")
	check(_game.room_index == 0, "and it is the first arena")
	check(_game.hud != null and _game.hud.visible, "the fight HUD is up from the first frame")

	# There is no menu left to navigate, and no story text anywhere: only the
	# three interruption pages exist at all.
	check(Screens.PAUSE_ITEMS.size() == 3, "the pause page has three rows")

	await _frames(2)
	check(_game.room != null, "room 1 is built")
	check(_game.room.guards.size() == 2, "arena 1 fields 2 knights on its first wave",
		"active %d" % _game.room.guards.size())
	check(_game.room.remaining_guard_count() == 6, "with 4 more waiting in the later waves",
		"remaining %d" % _game.room.remaining_guard_count())
	check(_game.room.waves_total == 3, "so the arena is a three-wave fight")
	check(_game.room.player.colour == Color(1.0, 1.0, 1.0), "the spark starts colourless (white)")

	# --- the characters are real sprites, not dots -----------------------
	var player_sprite: AnimatedSprite2D = _game.room.player.get_node_or_null("Sprite")
	check(player_sprite != null, "the player is drawn as an animated character sprite")
	if player_sprite != null:
		check(player_sprite.animation == "idle_down",
			"and idles facing down when the room starts",
			"animation=%s" % player_sprite.animation)
		check(player_sprite.material is ShaderMaterial,
			"and is re-coloured by the hue-tint shader (colour theory stays the core)")
	var guard_sprite: AnimatedSprite2D = _game.room.guards[0].get_node_or_null("Sprite")
	check(guard_sprite != null, "guards are drawn as animated character sprites too")

	# --- colour absorption through a real kill ---------------------------
	var first_guard: Guard = _game.room.guards[0]
	var guard_colour: Color = first_guard.colour
	_game.room._kill_guard(first_guard)
	await _frames(2)
	check(_game.room.guards.size() == 1, "killing a guard removes it from the room")
	# Saturation must be checked as well as hue: pure white and pure red both
	# report a hue of 0 degrees, so a hue-only assertion would pass even if the
	# spark had absorbed nothing at all.
	check(_game.room.player.colour.s > ColorTheory.GREY_SATURATION,
		"the spark is no longer colourless after a kill",
		"colour=%s s=%.2f" % [ColorTheory.hex(_game.room.player.colour), _game.room.player.colour.s])
	check_approx(_game.room.player.colour.h * 360.0, guard_colour.h * 360.0, 1.0,
		"the spark absorbs the dead guard's hue")
	check(_game.score == _game.base_kill_score, "one kill scores the base amount",
		"score %d" % _game.score)

	# --- paint appears and the floor starts restoring --------------------
	check(_game.room.paint.blobs.size() > 0, "the kill left paint on the floor")
	var ground: Color = _game.room.ground_colour_at(first_guard.position)
	# Comparing HUE alone is not enough here: pure RED and the bare grey floor
	# both report a hue of 0 degrees. Saturation is what separates them.
	check(ground.s > ColorTheory.GREY_SATURATION,
		"the floor under the kill is PAINTED, not bare grey",
		"ground=%s s=%.2f" % [ColorTheory.hex(ground), ground.s])
	check_approx(ground.h * 360.0, guard_colour.h * 360.0, 2.0, "and it is the guard's hue")
	check(_game.room.restore_ratio() > 0.0, "the restore bar started filling")

	# --- hiding: stand in matching paint ---------------------------------
	_game.room.player.position = first_guard.position
	await _physics_frames(2)
	check(_game.room.player.is_hidden, "standing in paint of your own hue HIDES you",
		"player at %s colour=%s (hue %d) ground=%s (hue %d, s=%.2f) visibility=%.2f" % [
			str(_game.room.player.position),
			ColorTheory.hex(_game.room.player.colour),
			ColorTheory.hue_degrees(_game.room.player.colour),
			ColorTheory.hex(_game.room.ground_colour_at(_game.room.player.position)),
			ColorTheory.hue_degrees(_game.room.ground_colour_at(_game.room.player.position)),
			_game.room.ground_colour_at(_game.room.player.position).s,
			_game.room.player.visibility_now])
	check_approx(_game.room.player.visibility_now, 0.0, 0.001, "and reports zero contrast")

	# --- exposure: stand on bare floor -----------------------------------
	_game.room.player.position = Vector2(200.0, 660.0)
	await _physics_frames(2)
	check(not _game.room.player.is_hidden, "stepping onto bare grey floor EXPOSES you")
	check_approx(_game.room.player.visibility_now, 1.0, 0.001, "and reports full contrast")

	# --- waves: arenas feed their knights in packs ------------------------
	# (One of wave 1's two knights already fell to the absorption test above.)
	for g in _game.room.guards.duplicate():
		_game.room._kill_guard(g)
	await _frames(2)
	check(not _game.room._cleared, "clearing wave 1 does NOT clear the arena")
	check(_game.room.intermission_left > 0.0, "it starts the intermission instead")
	check(_game.room.guards.is_empty(), "the floor stands empty while the next wave is called")
	check(_game.room.remaining_guard_count() == 4, "the reserved knights still count as left")
	check(_game.hud.guards_left == 4, "and the HUD counts them too", "hud %d" % _game.hud.guards_left)

	# The next wave marches in when the pause runs out, and it gets the same
	# blind moment every knight gets at room start: no ambush arrivals.
	await get_tree().create_timer(_game.room.intermission_seconds - 0.5).timeout
	await _frames(2)
	check(_game.room.current_wave == 1, "until the pause runs out, no wave arrives")
	await get_tree().create_timer(0.7).timeout
	await _physics_frames(2)
	check(_game.room.current_wave == 2, "then wave 2 marches in",
		"current_wave %d" % _game.room.current_wave)
	check(_game.room.guards.size() == 2, "with both of its knights on the floor")
	check(_game.room.remaining_guard_count() == 4, "and only the third wave still in reserve")

	var arrived: Guard = _game.room.guards[0]
	var facing: float = (arrived.patrol_points[1] - arrived.patrol_points[0]).angle()
	var ahead: Vector2 = Vector2.from_angle(facing)
	_game.room.player.colour = Color(1.0, 1.0, 1.0)
	# Far enough ahead that the walking knight cannot pass the spark before
	# the grace is over.
	_game.room.player.position = arrived.position + ahead * 200.0
	await _physics_frames(6)
	check(arrived.detection == 0.0, "a just-arrived knight is blind for its grace period",
		"detection %.2f" % arrived.detection)
	# Once the grace runs out, the same knight in the same cone must see the
	# spark again: the blind moment is a delay, not a disarm.
	await get_tree().create_timer(LevelData.SPAWN_GRACE).timeout
	_game.room.player.position = arrived.position + ahead * 150.0
	await _physics_frames(40)
	check(arrived.detection > 0.0, "and once the grace ends, the knight can see again",
		"detection %.2f" % arrived.detection)

	# --- clearing the arena advances --------------------------------------
	# Wave 3 is still in the wings; pull it in rather than sitting through
	# another intermission, then take the floor.
	for g in _game.room.guards.duplicate():
		_game.room._kill_guard(g)
	await _frames(2)
	check(not _game.room._cleared, "clearing wave 2 still does not clear a three-wave arena")
	_game.room.release_all_waves()
	await _frames(2)
	for g in _game.room.guards.duplicate():
		_game.room._kill_guard(g)
	await _frames(2)
	check(_game.room._cleared, "beating the last wave clears the arena")
	check(_game._busy, "clearing the last guard starts the room-clear sequence")
	await get_tree().create_timer(2.4).timeout
	await _frames(2)
	check(_game.room_index == 1, "the game advanced to room 2", "index %d" % _game.room_index)
	check(_game.room.guards.size() == 2, "arena 2 opens with its first wave of 2")
	check(_game.room.remaining_guard_count() == 5, "and 3 more knights wait in reserve")

	# --- the complement combo --------------------------------------------
	_game.load_room(2)
	await _frames(3)
	# This room fights in waves too; the tests are not the intermission timer,
	# so pull every pack onto the floor at once before picking the pair.
	_game.room.release_all_waves()
	await _frames(2)
	check(_game.room.guards.size() == 5, "room 3 has 5 guards")

	# Find the exact complementary pair and kill it in the right order.
	var yellow: Guard = null
	var blue: Guard = null
	for g in _game.room.guards:
		if absf(g.colour.h * 360.0 - 60.0) < 2.0:
			yellow = g
		elif absf(g.colour.h * 360.0 - 240.0) < 2.0:
			blue = g
	check(yellow != null and blue != null, "room 3 contains the YELLOW/BLUE complement pair")

	var score_before: int = _game.score
	_game.room._kill_guard(yellow)
	await _frames(2)
	check(_game.multiplier == 1, "the first kill of a chain is unscored-by-combo (x1)")
	_game.room._kill_guard(blue)
	await _frames(2)
	check(_game.multiplier == 2, "the complementary kill doubles the multiplier",
		"multiplier x%d" % _game.multiplier)
	check(_game.score - score_before == 100 + 200, "the combo paid 100 then 200",
		"got %d" % (_game.score - score_before))
	check(_game.combo_time_left > 0.0, "the combo window is now ticking for the HUD")

	# --- a non-complement pair must NOT combo ----------------------------
	_game.load_room(2)
	await _frames(3)
	_game.room.release_all_waves()
	await _frames(2)
	var red2: Guard = null
	var green2: Guard = null
	for g in _game.room.guards:
		if g.colour.h < 0.01 or g.colour.h > 0.99:
			red2 = g
		elif absf(g.colour.h * 360.0 - 120.0) < 2.0:
			green2 = g
	if red2 != null and green2 != null:
		_game.room._kill_guard(red2)
		await _frames(2)
		_game.room._kill_guard(green2)
		await _frames(2)
		check(_game.multiplier == 1, "RED then GREEN does NOT combo (120 apart, not 180)",
			"multiplier x%d" % _game.multiplier)
	else:
		check(false, "could not find RED and GREEN in room 3 to test a non-combo")

	# --- death and instant restart ---------------------------------------
	_game.load_room(0)
	await _frames(3)
	var room_before: int = _game.room_index
	var deaths_before: int = _game.deaths
	_game.room.player.take_damage(999.0, _game.room.player.position + Vector2(10.0, 0.0))
	await _frames(3)
	check(_game.room.player.hp <= 0.0, "a lethal hit drops the spark to 0 vigour")
	check(_game.state == Game.State.DEAD, "and 0 vigour is the death the run remembers")
	check(_game.deaths == deaths_before + 1, "the death counter went up")
	check(_game.screens.mode == Screens.Mode.DEAD, "the restart prompt is on screen")
	await get_tree().create_timer(1.3).timeout
	await _frames(3)
	check(_game.state == Game.State.PLAY, "the room restarts by itself after a death")
	check(_game.room_index == room_before, "and restarts the SAME room")

	# --- combat: vigour, hue strikes, the strike + dodge split ------------
	# The old one-touch kills are gone: the spark has HP, knights have HP, and
	# the hue gap decides how hard a swing lands (complements SHATTER).
	_game.load_room(0)
	await _frames(3)
	var p_combat: Player = _game.room.player
	var knight: Guard = _game.room.guards[0]

	# The verbs are the spec's: strike on J / left mouse, dodge on space. If
	# the old lunge action lingered in the input map, the panel would lie.
	check(InputMap.has_action("strike") and InputMap.has_action("dodge"),
		"the strike and dodge verbs are in the input map")
	check(not InputMap.has_action("dash") and not InputMap.has_action("dash_aim"),
		"the old lunge-dash verbs are gone")

	check_approx(p_combat.hp, 100.0, 0.001, "the spark starts on full vigour (100 HP)")
	check_approx(knight.hp, 60.0, 0.001, "a basic knight starts on 60 HP")

	# A full neutral chain: 12 / 12 / 20. The third swing is the heavy one.
	p_combat.colour = Color.WHITE
	knight.colour = RED
	knight.position = Vector2(440.0, 500.0)
	p_combat.position = Vector2(400.0, 500.0)
	p_combat.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check_approx(knight.hp, 48.0, 0.6, "swing 1 of a neutral chain deals x1 (60 - 12 = 48)")
	# The blade stays out for whole frames; it must still only cut once.
	await _physics_frames(4)
	check_approx(knight.hp, 48.0, 0.001, "one swing hits once, however long the blade is out")

	knight.position = Vector2(440.0, 500.0)
	p_combat.position = Vector2(400.0, 500.0)
	p_combat.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check_approx(knight.hp, 36.0, 0.6, "swing 2 continues the chain (48 - 12 = 36)")

	knight.position = Vector2(440.0, 500.0)
	p_combat.position = Vector2(400.0, 500.0)
	p_combat.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check_approx(knight.hp, 16.0, 0.6, "swing 3 is the heavy hit (36 - 20 = 16)")
	check(knight.stagger_left > 0.2, "the heavy third swing knocks the knight back")

	# A complement SHATTERS: x2.5. Two shatters in one chain break 60 HP.
	p_combat.colour = RED
	knight.colour = ColorTheory.complement(RED)
	knight.hp = 60.0
	knight.position = Vector2(440.0, 500.0)
	p_combat.position = Vector2(400.0, 500.0)
	p_combat.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check_approx(knight.hp, 30.0, 0.6, "a complement SHATTERS: x2.5 (60 - 30 = 30)")
	knight.position = Vector2(440.0, 500.0)
	p_combat.position = Vector2(400.0, 500.0)
	p_combat.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check(knight.dead, "the next shatter of the chain breaks the armour for good")

	# A matching hue is absorbed: x0.2, barely a scratch.
	_game.load_room(0)
	await _frames(3)
	var p_absorb: Player = _game.room.player
	var knight_absorb: Guard = _game.room.guards[0]
	p_absorb.colour = knight_absorb.colour
	knight_absorb.position = Vector2(440.0, 500.0)
	p_absorb.position = Vector2(400.0, 500.0)
	p_absorb.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check_approx(knight_absorb.hp, 60.0 - 12.0 * 0.2, 0.6,
		"the same hue is ABSORBED: x0.2 damage (60 - 2.4 = 57.6)")

	# --- the dodge roll: the defensive verb --------------------------------
	# Space rolls the way you steer and the first frames cannot be hit. It is
	# the answer to a wind-up - and the reason the strike can live on J.
	p_absorb.hitstun_left = 0.0
	p_absorb.invuln_left = 0.0
	p_absorb.roll_cooldown_left = 0.0
	p_absorb.position = Vector2(300.0, 560.0)
	knight_absorb.position = Vector2(150.0, 560.0)
	var before_x: float = p_absorb.position.x
	var hp_before_roll: float = p_absorb.hp
	p_absorb.begin_roll(Vector2.RIGHT)
	check(p_absorb.is_rolling(), "space starts a dodge roll")
	check(p_absorb.roll_cooldown_left > 0.0, "and the roll goes on cooldown")
	check(not p_absorb.take_damage(50.0, p_absorb.position + Vector2(40.0, 0.0)),
		"a hit during the roll's i-frames does nothing")
	check_approx(p_absorb.hp, hp_before_roll, 0.001, "the dodged hit costs no vigour")
	await _physics_frames(4)
	check(p_absorb.position.x > before_x + 20.0, "the roll covers ground in a hurry")
	await get_tree().create_timer(p_absorb.roll_duration + 0.1).timeout
	await _physics_frames(1)
	check(not p_absorb.is_rolling(), "the roll ends after its short burst")

	# The INPUT PATH itself, not just the API: a real J keypress (fed through
	# the same pipeline as hardware) must swing, and a real space must roll -
	# otherwise the input map and the code have drifted apart.
	var key_j := InputEventKey.new()
	key_j.physical_keycode = KEY_J
	key_j.pressed = true
	p_absorb.strike_cooldown_left = 0.0
	Input.parse_input_event(key_j)
	await _physics_frames(2)
	key_j = InputEventKey.new()
	key_j.physical_keycode = KEY_J
	key_j.pressed = false
	Input.parse_input_event(key_j)
	check(p_absorb.is_striking(), "pressing J swings the blade")
	p_absorb.strike_left = 0.0

	var key_space := InputEventKey.new()
	key_space.physical_keycode = KEY_SPACE
	key_space.pressed = true
	p_absorb.roll_cooldown_left = 0.0
	Input.parse_input_event(key_space)
	await _physics_frames(2)
	key_space = InputEventKey.new()
	key_space.physical_keycode = KEY_SPACE
	key_space.pressed = false
	Input.parse_input_event(key_space)
	check(p_absorb.is_rolling(), "pressing SPACE rolls")
	p_absorb.roll_left = 0.0
	p_absorb.invuln_left = 0.0

	# --- the chain bookkeeping and the gentle auto-aim ---------------------
	# A pause past the combo window restarts the chain at the first swing.
	p_absorb.combo_left = 0.0
	p_absorb.begin_strike(Vector2.RIGHT)
	check(p_absorb.strike_index == 0 and p_absorb.strike_damage_now() == 12.0,
		"a swing after the combo window starts a fresh chain")
	p_absorb.begin_strike(Vector2.RIGHT)
	p_absorb.begin_strike(Vector2.RIGHT)
	check(p_absorb.strike_index == 2 and p_absorb.strike_damage_now() == 20.0 and p_absorb.strike_is_heavy(),
		"the third swing of the chain is the heavy one")
	check(p_absorb.strike_half_rad() > deg_to_rad(p_absorb.strike_half_deg),
		"and its cleave is wider than the two quick swings")
	p_absorb.begin_strike(Vector2.RIGHT)
	check(p_absorb.strike_index == 0, "and the chain wraps back to the first swing")

	# Auto-aim: a swing turns onto a knight standing inside its arc, and
	# never spins the player around to hit something behind them.
	knight_absorb.position = p_absorb.position + Vector2(30.0, 8.0)
	p_absorb.begin_strike(Vector2.RIGHT)
	check_approx(p_absorb.strike_angle(), (knight_absorb.position - p_absorb.position).angle(), 0.001,
		"a swing turns onto a knight standing inside its arc")
	knight_absorb.position = p_absorb.position + Vector2(-40.0, 0.0)
	p_absorb.begin_strike(Vector2.RIGHT)
	check_approx(p_absorb.strike_angle(), 0.0, 0.001,
		"and it never spins the player around to hit what is behind")
	# The blade cuts a WEDGE, not a circle: a knight right at the player's
	# back, well inside reach, must still survive the swing aimed away.
	knight_absorb.position = p_absorb.position + Vector2(-30.0, 0.0)
	var hp_behind_before: float = knight_absorb.hp
	p_absorb.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check_approx(knight_absorb.hp, hp_behind_before, 0.001,
		"a knight behind the swing is not cut")

	# The knight swings back: windup, then the arc lands. Being hit costs
	# vigour now; it does not end the run.
	p_absorb.strike_left = 0.0
	p_absorb.velocity = Vector2.ZERO
	p_absorb.position = Vector2(400.0, 560.0)
	knight_absorb.position = Vector2(430.0, 560.0)
	# Skip the tail of the absorbed hit's flinch so the swing is what we test.
	knight_absorb.stagger_left = 0.0
	knight_absorb.state = Guard.State.CHASE
	knight_absorb.detection = 1.0
	await _physics_frames(2)
	check(knight_absorb.attack_state == Guard.Attack.WINDUP,
		"a knight in range winds up instead of touching you to death")
	var player_hp_before: float = p_absorb.hp
	await get_tree().create_timer(knight_absorb.attack_windup + 0.2).timeout
	await _physics_frames(2)
	check(p_absorb.hp < player_hp_before, "the telegraphed swing lands and costs vigour",
		"hp %.0f -> %.0f" % [player_hp_before, p_absorb.hp])
	check(_game.state == Game.State.PLAY, "and taking a hit no longer ends the run")

	# --- the boss ---------------------------------------------------------
	_game.load_room(3)
	await _frames(3)
	check(_game.room.waves_total == 1, "the boss hall is one fight, not a wave arena")
	check(_game.room.boss != null, "the boss room has a Collector")
	check(_game.room.boss.hue_speed != 0.0, "the Collector's hue rotates")
	check(_game.room.player.colour == Color(1.0, 0.0, 0.0),
		"the spark enters the boss room burning pure red (no soft lock)")

	var boss: Guard = _game.room.boss
	var hue_before: float = boss.colour.h
	await _physics_frames(10)
	check(absf(boss.colour.h - hue_before) > 0.0001, "the Collector's hue actually moves over time")

	# Wrong hue: swinging in must NOT kill him.
	boss.colour = RED
	await _physics_frames(2)
	check(not boss.vulnerable, "with the player red, a red Collector is NOT vulnerable")

	# Right hue: give the player his exact complement and let the room notice.
	_game.room.player.colour = ColorTheory.complement(boss.colour)
	await _physics_frames(2)
	check(boss.vulnerable, "putting the player on the Collector's complement opens the kill window")

	# A mistimed swing at an invulnerable Collector must clang off harmlessly.
	_game.load_room(3)
	await _frames(3)
	var boss2: Guard = _game.room.boss
	boss2.colour = RED
	_game.room.player.colour = RED
	_game.room.player.position = boss2.position + Vector2(-40.0, 0.0)
	_game.room.player.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check(not boss2.dead, "striking an un-cancelled Collector does not wound him")
	check_approx(boss2.hp, boss2.max_hp, 0.001, "his stolen wheel takes exactly zero damage")
	check(_game.state == Game.State.PLAY, "and the clang no longer kills you: nobody dies")

	# --- the Champion's three phases --------------------------------------
	# Phase I sweeps, phase II adds the telegraphed charge, phase III calls the
	# Aspirants and spins the wheel faster. Each is driven by HP thresholds, so
	# each is testable without waiting for a real duel.
	_game.load_room(3)
	await _frames(3)
	var champ: Guard = _game.room.boss
	var base_hue_speed: float = champ.hue_speed
	var cast_before: int = _game.room.guards.size()
	check(champ.boss_phase == 1, "the Champion starts in phase I")
	check(_game.room.guards.size() == 3, "phase I is the Champion plus his two escorts")

	# Two neutral cuts take him from 400 to 100 HP: past both thresholds.
	champ.take_hit(150.0, false, false, champ.position + Vector2(-40.0, 0.0), 70001)
	check(champ.boss_phase == 2, "dropping below two-thirds of his vigour opens phase II")
	check_approx(champ.hue_speed, base_hue_speed, 0.001,
		"and phase II does not touch the speed of the wheel")
	check(_game.room.guards.size() == cast_before, "phase II calls no new knights (it adds the charge)")

	champ.take_hit(150.0, false, false, champ.position + Vector2(-40.0, 0.0), 70002)
	check(champ.boss_phase == 3, "dropping below a third opens phase III")
	check(champ.hue_speed > base_hue_speed * 1.5,
		"and phase III spins the wheel markedly faster",
		"%.1f -> %.1f deg/s" % [base_hue_speed, champ.hue_speed])
	check(_game.room.guards.size() == cast_before + 2, "phase III calls two Aspirants")
	var summons: Array = _game.room.guards.slice(cast_before)
	var summon_grace: bool = true
	var summon_hues: Array = []
	for g in summons:
		if g.spawn_grace_until <= _game.room.time_in_room:
			summon_grace = false
		summon_hues.append(g.colour)
	check(summon_grace, "and every Aspirant arrives with the same blind grace a wave gets")
	check(ColorTheory.is_complement(summon_hues[0], summon_hues[1], 25.0),
		"the two Aspirants are a complementary pair - killing them shifts your hue")

	# The window must still reopen after the phase change, or the faster wheel
	# would turn the duel into a soft lock.
	champ.colour = RED
	_game.room.player.colour = ColorTheory.complement(RED)
	await _physics_frames(2)
	check(champ.vulnerable, "the kill window still opens in phase III (no soft lock)")

	# --- the telegraphed charging dash ------------------------------------
	# Phase II's charge is a locked lane: a windup, then a committed sprint.
	_game.load_room(3)
	await _frames(3)
	var charger: Guard = _game.room.boss
	charger.take_hit(150.0, false, false, charger.position + Vector2(-40.0, 0.0), 70003)
	# The hit also flinches him; skip that flinch so the charge is what we test.
	charger.stagger_left = 0.0
	check(charger.boss_phase == 2, "a fresh Champion reaches phase II for the charge test")
	# Put the duel in the middle of the arena's open lane, 220px apart.
	charger.position = Vector2(620.0, 110.0)
	charger.velocity = Vector2.ZERO
	charger.state = Guard.State.CHASE
	charger.detection = 1.0
	charger._charge_cooldown_left = 0.0
	_game.room.player.position = Vector2(620.0, 330.0)
	await _physics_frames(3)
	check(charger.charge_state == Guard.Charge.WINDUP,
		"phase II winds up a charging dash instead of walking in")
	var player_hp_charge: float = _game.room.player.hp
	await get_tree().create_timer(charger.charge_windup + 0.10).timeout
	check(charger.charge_state == Guard.Charge.DASH, "the lane locks in and the dash begins")
	await get_tree().create_timer(charger.charge_duration + 0.15).timeout
	await _physics_frames(2)
	check(_game.room.player.hp < player_hp_charge, "the dash lands and costs vigour",
		"hp %.0f -> %.0f" % [player_hp_charge, _game.room.player.hp])
	check(charger.charge_state == Guard.Charge.RECOVER or charger.charge_state == Guard.Charge.NONE,
		"and the Champion is left open for a punish after the charge")

	# A well-timed swing must win the game. (A fresh load of the boss room.)
	_game.load_room(3)
	await _frames(3)
	var boss3: Guard = _game.room.boss
	boss3.colour = RED
	# Kills the two small guards too so the room genuinely clears.
	_game.room.player.colour = ColorTheory.complement(boss3.colour)
	await _physics_frames(2)
	check(boss3.vulnerable, "the kill window is open on the second boss attempt")
	# The real Champion takes several windows (400 HP, x2.5 shatters). Drop him
	# below one shatter swing so this test proves the killing blow lands.
	boss3.hp = 25.0
	_game.room.player.position = boss3.position + Vector2(-40.0, 0.0)
	_game.room.player.begin_strike(Vector2.RIGHT)
	await _physics_frames(2)
	check(boss3.dead, "a complement strike inside the window kills the Collector")
	check(boss3.kneeling, "the beaten Champion does not vanish: he kneels on the sand")
	check(boss3.is_boss and is_instance_valid(_game.room.boss),
		"and the kneeling body is still the room's boss for the victory beat")

	# Clear the remaining small guards to finish the room.
	for g in _game.room.guards.duplicate():
		if not g.dead:
			_game.room._kill_guard(g)
	await _frames(3)
	await get_tree().create_timer(2.4).timeout
	await _frames(4)
	check(_game.state == Game.State.WIN, "clearing the boss room wins the game",
		"state=%d" % _game.state)
	check(_game.screens.mode == Screens.Mode.WIN, "the win page is on screen")
	check(_game.screens.win_seconds >= 0.0 and _game.screens.win_rank != "",
		"the win screen received a rank and a run time")

	# --- restart from the win screen -------------------------------------
	_game._on_screen_restart()
	await _frames(3)
	check(_game.state == Game.State.PLAY and _game.room_index == 0,
		"restarting from the win screen begins a fresh run at room 1")
	check(_game.score == 0 and _game.deaths == 0, "and resets the score and the death count")

	# =====================================================================
	# D. LIGHT, WAVES AND LEVEL ELEMENTS
	# =====================================================================
	# The game is now sitting in a clean arena 1, which makes a good sandbox.
	print("\n--- D. LIGHT, WAVES AND LEVEL ELEMENTS")

	# --- darkness is wired and follows the player ------------------------
	check(_game.darkness != null, "the darkness layer exists")
	var dark_mat: ShaderMaterial = null
	if _game.darkness != null:
		dark_mat = _game.darkness.material as ShaderMaterial
	check(dark_mat != null, "the darkness layer runs the light-cone shader")
	check(_game.darkness.visible, "darkness is drawn during play")
	if dark_mat != null:
		check_approx(float(dark_mat.get_shader_parameter("cone_deg")), _game.light_cone_deg, 0.01,
			"the shader receives the player's cone width")
		check_approx(float(dark_mat.get_shader_parameter("darkness_amount")), _game.darkness_amount, 0.01,
			"the shader receives the darkness level")
		var lc: int = int(dark_mat.get_shader_parameter("light_count"))
		check(lc >= 0, "the guard lantern count is passed to the shader")
		var gpos: PackedVector2Array = dark_mat.get_shader_parameter("light_pos")
		check(gpos != null and gpos.size() == 8,
			"the lantern array is always the fixed 8 the shader expects",
			"size %d" % (gpos.size() if gpos != null else -1))
		if gpos != null and gpos.size() == 8:
			# With the camera in play the shader positions are SCREEN pixels:
			# every live guard lantern must land where world_to_screen says.
			# Settle the shake first so the read cannot race the camera jitter.
			_game._shake = 0.0
			await _frames(2)
			gpos = dark_mat.get_shader_parameter("light_pos")
			var matched: int = 0
			var live: int = 0
			for guard in _game.room.guards:
				if not is_instance_valid(guard) or guard.dead:
					continue
				live += 1
				var want: Vector2 = _game.world_to_screen(guard.global_position)
				for i in int(dark_mat.get_shader_parameter("light_count")):
					if gpos[i].distance_to(want) < 2.0:
						matched += 1
						break
			check(live > 0 and matched == live,
				"every guard lantern reaches the shader in screen space (world->camera->canvas)",
				"%d/%d matched" % [matched, live])

	# --- the zoom-follow camera ------------------------------------------
	check(_game.camera != null, "the follow camera exists")
	check_approx(_game.camera.zoom.x, _game.camera_zoom, 0.001,
		"the view is zoomed in for Soul-Knight framing")
	check_approx(_game.camera.zoom.y, _game.camera.zoom.x, 0.001, "and the zoom is uniform")

	# The view may never leave the playfield: at 1.5x the camera centre is
	# confined to the middle of the arena, so the border walls are always
	# exactly the frame of the screen.
	var clamped: Vector2 = _game._clamp_camera(Vector2(-500.0, -500.0))
	check_approx(clamped.x, LevelData.PLAYFIELD.x * 0.5 / _game.camera_zoom, 0.01,
		"the camera clamps at the west wall instead of showing out of bounds")
	check_approx(clamped.y, LevelData.PLAYFIELD.y * 0.5 / _game.camera_zoom, 0.01,
		"and at the north wall")

	# A point under the camera lands at the middle of the 1280x720 canvas.
	var centre_px: Vector2 = _game.world_to_screen(_game.camera.position)
	check(centre_px.distance_to(LevelData.PLAYFIELD * 0.5) < 0.01,
		"world_to_screen puts the camera focus at the centre of the screen")

	# A corner spawn clamps the camera target into the corner: this is what
	# load_room() snaps to, so a new room never slides in from the old one.
	var saved_pos: Vector2 = _game.room.player.position
	_game.room.player.position = Vector2(120.0, 640.0)
	check(_game._clamp_camera(_game._camera_target()).distance_to(Vector2(426.67, 480.0)) < 0.1,
		"a corner spawn clamps the camera target to the arena corner")
	_game._snap_camera()
	check(_game._camera_follow.distance_to(Vector2(426.67, 480.0)) < 0.1,
		"and the snap puts the follow position exactly there")
	_game.room.player.position = saved_pos
	_game._snap_camera()

	# The light points the way the spark faces, driven by steering, not a mouse.
	_game.room.player._facing = 1.25
	check_approx(_game.room.player.aim_angle(), 1.25, 0.001,
		"the light cone follows the spark's facing (WASD), not the mouse")

	# --- hearing: a noise pulls a patrolling guard off its route ---------
	var hg: Guard = _game.room.guards[0]
	hg.state = Guard.State.PATROL
	hg.hear(Vector2(400.0, 300.0))
	check(hg.state == Guard.State.INVESTIGATE, "a heard noise sends a guard to investigate")
	check(hg._investigate_left > 0.0, "and starts the give-up countdown")

	hg.state = Guard.State.CHASE
	hg.hear(Vector2(10.0, 10.0))
	check(hg.state == Guard.State.CHASE, "a guard already chasing the player ignores a mere noise")

	hg.state = Guard.State.INVESTIGATE
	hg._last_seen = Vector2(9990.0, 9990.0)
	hg._investigate_left = 0.0
	await _physics_frames(2)
	check(hg.state == Guard.State.PATROL,
		"a guard abandons an unreachable search instead of walking into a wall forever")

	# --- the alarm spreads ------------------------------------------------
	var ag: Guard = _game.room.guards[1]
	ag.state = Guard.State.PATROL
	_game.room._on_guard_spotted(ag.global_position)
	check(ag.state == Guard.State.INVESTIGATE,
		"when one guard locks on, nearby allies come to help")

	# A swung blade is loud enough to be heard by a guard standing nearby (but
	# not so close that simply standing there would count as combat).
	ag.state = Guard.State.PATROL
	ag.position = _game.room.player.position + Vector2(120.0, 0.0)
	_game.room._on_player_struck(Vector2.RIGHT)
	check(ag.state == Guard.State.INVESTIGATE, "a swung blade is heard by a guard standing nearby")

	# --- guard speech -----------------------------------------------------
	ag._say("spotted")
	check(ag.bark_text != "", "a guard says a line when it spots the player")
	check(ag.bark_text.find(" ") > 0, "the line is real words, not an empty tag",
		"line '%s'" % ag.bark_text)
	check(ag.bark_left > 0.0, "a spoken line has a lifetime on screen")
	var before_bark: float = ag.bark_left
	await _frames(3)
	check(ag.bark_left < before_bark, "the spoken line fades over time")

	# Park the guards in a far corner so the mote test measures the mote, not a
	# guard wandering into the player and killing them mid-check.
	for g in _game.room.guards:
		g.set_physics_process(false)
		g.position = Vector2(1220.0, 80.0)
	await _physics_frames(1)

	# --- colour motes: the new level element -----------------------------
	var rooms_with_motes: int = 0
	for r in LevelData.ROOMS:
		if (r.get("motes", []) as Array).size() > 0:
			rooms_with_motes += 1
	check(rooms_with_motes == LevelData.ROOMS.size(),
		"every room has colour motes to find", "%d of %d" % [rooms_with_motes, LevelData.ROOMS.size()])
	check(_game.room.motes.size() >= 1, "room 1 builds its motes into the world")

	var mote: Mote = _game.room.motes[0]
	var mote_hue: float = mote.colour.h * 360.0
	_game.room.player.colour = Color(1.0, 1.0, 1.0)
	_game.room.player.position = mote.position
	await _physics_frames(3)
	check(mote.taken, "standing on a mote drinks it")
	check(_game.room.player.colour.s > ColorTheory.GREY_SATURATION,
		"drinking a mote gives the spark a colour",
		"colour=%s" % ColorTheory.hex(_game.room.player.colour))
	check_approx(_game.room.player.colour.h * 360.0, mote_hue, 2.0,
		"and it is the mote's own hue")

	# --- the richer rooms are still clean geometry -----------------------
	# (Section B measures this too; this is a cheap end-to-end re-check that
	#  every room really built its new cover and motes.)
	var built_ok: bool = true
	for i in LevelData.ROOMS.size():
		_game.load_room(i)
		await _frames(2)
		if _game.room == null or _game.room.guards.is_empty():
			built_ok = false
	check(built_ok, "all four enriched rooms still build with guards present")

	# --- pause menu -------------------------------------------------------
	check(Screens.PAUSE_ITEMS.size() == 3, "the pause menu has three rows")
	_game.pause_game()
	check(_game.state == Game.State.PAUSED, "ESC pauses the run")
	check(get_tree().paused, "and the tree really is paused (the room is frozen)")
	check(_game.screens.mode == Screens.Mode.PAUSE, "the pause page is on screen")
	# RESTART ROOM resumes and rebuilds the same room.
	_game.screens.pause_index = 1
	_game.screens.advance()
	check(_game.state == Game.State.PLAY and not get_tree().paused, "RESTART ROOM resumes the game")
	check(_game.room != null and _game.room.time_in_room < 0.5, "and rebuilds the room from the top")
	# ESC / back resumes without touching the run.
	_game.pause_game()
	_game.screens.back()
	check(_game.state == Game.State.PLAY and not get_tree().paused, "ESC from the pause page resumes")
	check(_game.screens.mode == Screens.Mode.NONE, "and clears the page")
