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

	# --- story cards ------------------------------------------------------
	_game._on_start_requested()
	check(_game.state == Game.State.INTRO, "requesting start moves to the intro")
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
