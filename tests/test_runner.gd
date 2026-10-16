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
##   B. LEVEL GEOMETRY- proves no guard patrol route clips through a wall,
##                      which is the classic hand-built-level mistake.
##   C. INTEGRATION   - boots the real main.tscn and plays it: kills guards,
##                      triggers a combo, hides in paint, dies, kills the boss.
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
		for spec in spec_list:
			if not reach.has(_cell_key(Vector2(spec["pos"]))):
				routes_ok = false
			for p in spec["path"]:
				if not reach.has(_cell_key(Vector2(p))):
					routes_ok = false
		check(routes_ok, "%s: every guard waypoint can be walked to" % name)


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

	check(_game.state == Game.State.TITLE, "the game boots to the title screen")
	check(_game.screens != null and _game.screens.mode == Screens.Mode.TITLE,
		"the title page is showing")
	check(_game.room == null, "no room is built while on the title screen")

	# --- the start menu ---------------------------------------------------
	check(Screens.MENU_ITEMS.size() == 3, "the start menu has three rows")
	check(_game.screens.mode == Screens.Mode.TITLE, "booting shows the start menu")
	check(_game.screens.menu_index == 0, "the start menu opens with START GAME selected")
	_game.screens.menu_move(-1)
	check(_game.screens.menu_index == Screens.MENU_ITEMS.size() - 1,
		"moving up from the top row wraps to the bottom", "index %d" % _game.screens.menu_index)
	_game.screens.menu_move(1)
	check(_game.screens.menu_index == 0, "and moving down wraps back to the top")
	# The HOW TO PLAY row opens the rules page, and ESC returns to the menu.
	_game.screens.menu_index = 1
	_game.screens.advance()
	check(_game.screens.mode == Screens.Mode.HOWTO, "the HOW TO PLAY row opens the rules page")
	_game.screens.back()
	check(_game.screens.mode == Screens.Mode.TITLE, "and ESC goes back to the menu")
	_game.screens.menu_index = 0

	# --- the story scene, then the story cards ---------------------------
	_game._on_start_requested()
	check(_game.state == Game.State.INTRO, "requesting start moves to the intro")
	check(_game.screens.mode == Screens.Mode.STORY,
		"start first shows the story scene (the spark in the grey city)")
	check(Screens.STORY_LINE == "We have to bring the colours back.",
		"the story line is the one the brief asked for")
	# Advancing the story hands off to the five rhyme cards.
	_game.screens.advance()
	check(_game.screens.mode == Screens.Mode.INTRO, "the story scene leads into the rhyme cards")

	check(Screens.CARDS.size() == 5, "the intro has exactly 5 story cards")
	var card_ok: bool = true
	for card in Screens.CARDS:
		if (card["lines"] as Array).size() != 2 or (card["colours"] as Array).size() != 2:
			card_ok = false
	check(card_ok, "every story card has 2 rhyming lines, each with its own tint")

	# The cards refuse to advance for card_min_time, so wait past it honestly
	# instead of poking at the private timer.
	await get_tree().create_timer(0.6).timeout
	_game.screens.card_index = 4
	_game.screens.advance()
	check(_game.state == Game.State.PLAY, "finishing the cards starts the run")

	# --- room 1 -----------------------------------------------------------
	await _frames(2)
	check(_game.room != null, "room 1 is built")
	check(_game.room.guards.size() == 2, "room 1 has 2 guards", "found %d" % _game.room.guards.size())
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

	# --- clearing the room advances --------------------------------------
	_game.room._kill_guard(_game.room.guards[0])
	await _frames(2)
	check(_game._busy, "clearing the last guard starts the room-clear sequence")
	await get_tree().create_timer(2.4).timeout
	await _frames(2)
	check(_game.room_index == 1, "the game advanced to room 2", "index %d" % _game.room_index)
	check(_game.room.guards.size() == 3, "room 2 has 3 guards")

	# --- the complement combo --------------------------------------------
	_game.load_room(2)
	await _frames(3)
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
	_game.room.player.kill()
	await _frames(3)
	check(_game.state == Game.State.DEAD, "touching a guard kills the player")
	check(_game.deaths == deaths_before + 1, "the death counter went up")
	check(_game.screens.mode == Screens.Mode.DEAD, "the restart prompt is on screen")
	await get_tree().create_timer(1.3).timeout
	await _frames(3)
	check(_game.state == Game.State.PLAY, "the room restarts by itself after a death")
	check(_game.room_index == room_before, "and restarts the SAME room")

	# --- the boss ---------------------------------------------------------
	_game.load_room(3)
	await _frames(3)
	check(_game.room.boss != null, "the boss room has a Collector")
	check(_game.room.boss.hue_speed != 0.0, "the Collector's hue rotates")
	check(_game.room.player.colour == Color(1.0, 0.0, 0.0),
		"the spark enters the boss room burning pure red (no soft lock)")

	var boss: Guard = _game.room.boss
	var hue_before: float = boss.colour.h
	await _physics_frames(10)
	check(absf(boss.colour.h - hue_before) > 0.0001, "the Collector's hue actually moves over time")

	# Wrong hue: dashing in must NOT kill him.
	boss.colour = RED
	await _physics_frames(2)
	check(not boss.vulnerable, "with the player red, a red Collector is NOT vulnerable")

	# Right hue: give the player his exact complement and let the room notice.
	_game.room.player.colour = ColorTheory.complement(boss.colour)
	await _physics_frames(2)
	check(boss.vulnerable, "putting the player on the Collector's complement opens the kill window")

	# A mistimed lunge at an invulnerable Collector must kill the player.
	_game.load_room(3)
	await _frames(3)
	var boss2: Guard = _game.room.boss
	boss2.colour = RED
	_game.room.player.colour = RED
	_game.room.player.position = boss2.position
	_game.room.player.dash_left = 0.10
	await _physics_frames(2)
	check(_game.state == Game.State.DEAD,
		"lunging at an un-cancelled Collector kills YOU instead")

	# A well-timed lunge must win the game.
	await get_tree().create_timer(1.3).timeout
	await _frames(3)
	_game.load_room(3)
	await _frames(3)
	var boss3: Guard = _game.room.boss
	boss3.colour = RED
	# Kills the two small guards too so the room genuinely clears.
	_game.room.player.colour = ColorTheory.complement(boss3.colour)
	await _physics_frames(2)
	check(boss3.vulnerable, "the kill window is open on the second boss attempt")
	_game.room.player.position = boss3.position
	_game.room.player.dash_left = 0.10
	await _physics_frames(2)
	check(boss3.dead, "the complement lunge kills the Collector")

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
	# D. STEALTH, DARKNESS AND LEVEL ELEMENTS
	# =====================================================================
	# The game is now sitting in a clean room 1, which makes a good sandbox.
	print("\n--- D. STEALTH, DARKNESS AND LEVEL ELEMENTS")

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

	# A lunge is loud enough to be heard by a guard standing nearby (but not so
	# close that simply standing there would count as a contact kill).
	ag.state = Guard.State.PATROL
	ag.position = _game.room.player.position + Vector2(120.0, 0.0)
	_game.room._on_player_dashed(Vector2.RIGHT)
	check(ag.state == Guard.State.INVESTIGATE, "a lunge is heard by a guard standing nearby")

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
