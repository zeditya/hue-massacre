extends Node
class_name Game
##
## GAME - the conductor. This is the script on the one tiny scene, main.tscn.
##
## It owns everything that is not the room itself:
##   * the four layers (world, HUD, screens, full-screen effects)
##   * the state machine: TITLE -> INTRO -> PLAY -> (DEAD | WIN)
##   * the score and the COMPLEMENT COMBO
##   * the juice: screen shake, screen flash and hit stop
##
## It is also the only script that knows about colour theory ACROSS rooms,
## because the combo is defined by two kills from different guards.
##
## Nothing here is built in the editor. Every node is created in _ready(), which
## means there is exactly one file to read to understand the whole game shell.

enum State { TITLE, INTRO, PLAY, DEAD, WIN }

@export_group("Colour rules")
## Hue distance (degrees) under which floor paint hides the player.
@export var hide_tolerance_deg: float = 26.0
## Half-width of the "these two hues cancel" window for the combo.
##
## 25 is chosen so the rule stays honest: YELLOW 60 <-> BLUE 240 (180 apart)
## and GREEN 120 <-> PURPLE 285 (165 apart) both score, while ORANGE 30 <->
## BLUE 240 (only 150 apart) does NOT. See the table in level_data.gd.
@export var complement_tolerance_deg: float = 25.0
## Half-width of the Collector's kill window.
@export var boss_kill_tolerance_deg: float = 25.0

@export_group("Score")
## Points for one kill, before the multiplier.
@export var base_kill_score: int = 100
## Highest multiplier the combo chain can reach.
@export var max_multiplier: int = 8
## Flat bonus for putting the Collector down.
@export var boss_kill_bonus: int = 1000
## Bonus for clearing a room without ever being chased.
@export var stealth_room_bonus: int = 500

@export_group("Combo")
## Two complementary kills must land inside this many seconds to chain.
@export var combo_window: float = 3.0

@export_group("Feedback")
## How fast screen shake decays. Higher = snappier.
@export var shake_decay: float = 5.5
@export var dash_shake: float = 3.0
@export var kill_shake: float = 9.0
@export var combo_shake: float = 16.0
@export var death_shake: float = 20.0
## Hard cap so a big combo cannot throw the world off screen.
@export var max_shake: float = 26.0
## Seconds of near-freeze on a kill. Real-world time, not game time.
@export var hit_stop_seconds: float = 0.05
## How long the death prompt stays up before the room reloads by itself.
@export var restart_delay: float = 0.9
## How fast a full-screen colour flash fades.
@export var flash_fade_speed: float = 2.6

@export_group("Layout")
@export var world_origin: Vector2 = Vector2.ZERO

var state: State = State.TITLE
var room: Room = null
var room_index: int = 0

var score: int = 0
var deaths: int = 0
var multiplier: int = 1
var combo_chain: int = 0
var combo_time_left: float = 0.0
var run_time: float = 0.0

var world_root: Node2D = null
var hud: Hud = null
var screens: Screens = null
var audio: AudioBank = null
var flash: ColorRect = null

var _hud_layer: CanvasLayer = null
var _screens_layer: CanvasLayer = null
var _fx_layer: CanvasLayer = null

var _shake: float = 0.0
var _hit_stop_until_msec: int = 0
var _has_last_kill: bool = false
var _last_kill_colour: Color = Color.WHITE
## Real-world clock (seconds) of the previous kill. Deliberately NOT a
## countdown variable: a lone kill sets combo_time_left to 0, and reading the
## countdown to decide whether two kills are close enough in time was a bug.
var _last_kill_time: float = -100.0
var _spotted_this_room: bool = false
var _busy: bool = false    # true while a room-clear or death sequence is running


func _ready() -> void:
	# Keeps working even if the window loses focus, and keeps the run smooth.
	randomize()
	_build_layers()
	audio = AudioBank.new()
	audio.name = "Audio"
	add_child(audio)
	start_title()


func _process(delta: float) -> void:
	_update_shake(delta)
	_update_hit_stop()
	_update_flash(delta)

	if state == State.PLAY:
		run_time += delta
		if combo_time_left > 0.0:
			combo_time_left = maxf(combo_time_left - delta, 0.0)
			if combo_time_left <= 0.0:
				_reset_combo()
		if room != null and _any_guard_chasing():
			_spotted_this_room = true

	_sync_hud()


# ---------------------------------------------------------------------------
# Layers
# ---------------------------------------------------------------------------

func _build_layers() -> void:
	# 1. The world. Shaking this node shakes the game but not the interface,
	#    which is exactly why the HUD lives on its own CanvasLayer.
	world_root = Node2D.new()
	world_root.name = "World"
	world_root.position = world_origin
	add_child(world_root)

	# 2. The HUD, above the world.
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 1
	add_child(_hud_layer)
	hud = Hud.new()
	hud.name = "Hud"
	_hud_layer.add_child(hud)

	# 3. The full-screen pages (title, story, win, death).
	_screens_layer = CanvasLayer.new()
	_screens_layer.name = "ScreensLayer"
	_screens_layer.layer = 2
	add_child(_screens_layer)
	screens = Screens.new()
	screens.name = "Screens"
	screens.start_requested.connect(_on_start_requested)
	screens.intro_finished.connect(_on_intro_finished)
	screens.restart_requested.connect(_on_screen_restart)
	screens.title_requested.connect(start_title)
	_screens_layer.add_child(screens)

	# 4. Effects that must sit on top of EVERYTHING, including the pages.
	_fx_layer = CanvasLayer.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.layer = 3
	add_child(_fx_layer)
	flash = ColorRect.new()
	flash.name = "Flash"
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.add_child(flash)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton \
		and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	# Full-screen pages swallow input first.
	if screens.is_blocking():
		if event.is_action_pressed("ui_accept") or clicked:
			screens.advance()
			return
		if event.is_action_pressed("to_title") or event.is_action_pressed("ui_cancel"):
			screens.back()
			return
		return

	if state != State.PLAY:
		return

	if event.is_action_pressed("restart"):
		restart_room()
	elif event.is_action_pressed("to_title") or event.is_action_pressed("ui_cancel"):
		start_title()


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

func start_title() -> void:
	Engine.time_scale = 1.0
	_hit_stop_until_msec = 0
	_clear_room()
	state = State.TITLE
	_busy = false
	score = 0
	deaths = 0
	run_time = 0.0
	_reset_combo()
	screens.show_title()
	if hud != null:
		hud.visible = false
		hud.clear_messages()


func _on_start_requested() -> void:
	state = State.INTRO
	screens.show_intro()


func _on_intro_finished() -> void:
	start_run()


## Begin a fresh run at room 1 with a clean score.
func start_run() -> void:
	Engine.time_scale = 1.0
	score = 0
	deaths = 0
	run_time = 0.0
	_reset_combo()
	screens.hide_all()
	if hud != null:
		hud.visible = true
	state = State.PLAY
	load_room(0)


## Build the room at `index`, throwing away whatever was there before.
func load_room(index: int) -> void:
	_clear_room()
	Engine.time_scale = 1.0
	_hit_stop_until_msec = 0
	_busy = false
	_spotted_this_room = false
	_has_last_kill = false
	_last_kill_time = -100.0
	room_index = clampi(index, 0, LevelData.room_count() - 1)

	room = Room.new()
	room.name = "Room"
	room.room_index = room_index
	room.hide_tolerance_deg = hide_tolerance_deg
	room.boss_kill_tolerance_deg = boss_kill_tolerance_deg
	room.guard_killed.connect(_on_guard_killed)
	room.player_died.connect(_on_player_died)
	room.room_cleared.connect(_on_room_cleared)
	room.boss_vulnerable_changed.connect(_on_boss_vulnerable_changed)
	world_root.add_child(room)

	if hud != null:
		hud.clear_messages()
		hud.room_name = room.data["name"]
		hud.room_title = room.data["title"]
		hud.room_lesson = room.data["lesson"]
		hud.boss_tolerance_deg = boss_kill_tolerance_deg
		hud.boss_hue = -1.0
		hud.boss_vulnerable = false
		hud.show_hint(room.data["hint"], 9.0)
	_sync_hud()


func _clear_room() -> void:
	if room != null and is_instance_valid(room):
		room.queue_free()
	room = null


## R key during play: reload the current room without counting a death.
func restart_room() -> void:
	if state != State.PLAY:
		return
	_flash(Color(1.0, 1.0, 1.0), 0.18)
	load_room(room_index)


func _restart_after_death() -> void:
	screens.hide_all()
	state = State.PLAY
	load_room(room_index)


# ---------------------------------------------------------------------------
# Room events
# ---------------------------------------------------------------------------

func _on_guard_killed(guard: Guard) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	# A COMBO is two guards whose hues sit opposite each other on the wheel,
	# killed inside combo_window seconds of one another.
	var linked: bool = _has_last_kill \
		and (now - _last_kill_time) <= combo_window \
		and ColorTheory.is_complement(_last_kill_colour, guard.colour, complement_tolerance_deg)

	if linked:
		combo_chain += 1
		multiplier = mini(1 + combo_chain, max_multiplier)
		combo_time_left = combo_window
	else:
		combo_chain = 0
		multiplier = 1
		combo_time_left = 0.0

	var points: int = base_kill_score * multiplier
	if guard.is_boss:
		points += boss_kill_bonus
	score += points

	_has_last_kill = true
	_last_kill_colour = guard.colour
	_last_kill_time = now

	_add_shake(kill_shake)
	_set_hit_stop()
	audio.play("kill", randf_range(0.90, 1.12))
	if hud != null:
		hud.show_flash(Screens.random_kill_flash(), guard.colour, 2.2)

	if linked:
		_trigger_combo(guard.colour)

	if guard.is_boss:
		_add_shake(combo_shake)
		_flash(guard.colour, 0.75)
		audio.play("boss_down")
		if hud != null:
			hud.show_banner("THE COLLECTOR FALLS", "the last stolen hue pours out of him", guard.colour, 2.4)


## The complement payoff: a white flash, a hard shake and a bigger multiplier.
func _trigger_combo(colour: Color) -> void:
	_add_shake(combo_shake)
	# Two complementary colours average to white, so the flash is white.
	_flash(Color(1.0, 1.0, 1.0), 0.55)
	audio.play("combo")
	if hud != null:
		var sub: String = "%s and %s sit opposite each other on the wheel" % [
			ColorTheory.color_name(_last_kill_colour), ColorTheory.color_name(colour)]
		hud.show_banner("COMPLEMENT  x%d" % multiplier, sub, UiStyle.GOLD, 2.0)


func _on_player_died() -> void:
	deaths += 1
	_reset_combo()
	_add_shake(death_shake)
	_flash(Color(1.0, 0.15, 0.15), 0.45)
	audio.play("die")
	state = State.DEAD
	_busy = true
	if room != null:
		room.freeze()
	if hud != null:
		hud.spotted = false
	screens.show_dead(room.data["name"] if room != null else "ROOM", restart_delay)
	# Automatic instant restart. Pressing R just skips the wait.
	await get_tree().create_timer(restart_delay).timeout
	if state == State.DEAD:
		_busy = false
		_restart_after_death()


func _on_room_cleared() -> void:
	if _busy:
		return
	_busy = true
	Engine.time_scale = 1.0
	_reset_combo()
	audio.play("room_clear")

	var bonus_text: String = ""
	if not _spotted_this_room:
		score += stealth_room_bonus
		bonus_text = "+%d unspotted bonus" % stealth_room_bonus

	if hud != null:
		hud.show_banner("ROOM CLEARED", bonus_text if bonus_text != "" else "colour is coming back", UiStyle.GOLD, 2.2)

	var last_room: bool = room_index >= LevelData.room_count() - 1
	await get_tree().create_timer(2.1).timeout

	# The player may have died (impossible here) or hit ESC during the wait.
	if state != State.PLAY:
		return

	if last_room:
		_win()
	else:
		_busy = false
		load_room(room_index + 1)


func _on_boss_vulnerable_changed(is_vulnerable: bool) -> void:
	if not is_vulnerable:
		return
	audio.play("vulnerable")
	if hud != null:
		hud.show_flash("his complement - strike now", UiStyle.PAPER, 1.4)


func _win() -> void:
	state = State.WIN
	_busy = false
	Engine.time_scale = 1.0
	# Freeze the world behind the win page so the player cannot keep walking
	# around while the victory text is on screen.
	if room != null and is_instance_valid(room):
		room.freeze()
	_flash(Color(1.0, 1.0, 1.0), 0.9)
	audio.play("room_clear")
	if hud != null:
		hud.visible = false
	screens.show_win(score, deaths, run_time, _rank())


## Rank is a simple, honest measure of how carefully the run was played.
func _rank() -> String:
	if deaths == 0:
		return "S"
	if deaths <= 2:
		return "A"
	if deaths <= 5:
		return "B"
	if deaths <= 9:
		return "C"
	return "D"


## The win or death page asks to play again.
func _on_screen_restart() -> void:
	match state:
		State.DEAD:
			_busy = false
			_restart_after_death()
		State.WIN:
			start_run()
		_:
			pass


# ---------------------------------------------------------------------------
# Combo bookkeeping
# ---------------------------------------------------------------------------

func _reset_combo() -> void:
	combo_chain = 0
	multiplier = 1
	combo_time_left = 0.0


func _any_guard_chasing() -> bool:
	if room == null or not is_instance_valid(room):
		return false
	for guard in room.guards:
		if is_instance_valid(guard) and guard.state == Guard.State.CHASE:
			return true
	return false


# ---------------------------------------------------------------------------
# Juice
# ---------------------------------------------------------------------------

func _add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, max_shake)


func _update_shake(delta: float) -> void:
	if world_root == null:
		return
	if _shake > 0.0:
		# Decay faster the bigger the shake, so a huge hit settles quickly.
		_shake = maxf(_shake - shake_decay * delta * (1.0 + _shake * 0.06), 0.0)
		world_root.position = world_origin + Vector2(
			randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		world_root.position = world_origin


## A few milliseconds of near-freeze on a kill. Cheap, and it makes the blade
## feel like it has weight. Measured in real time so it cannot be re-entered.
func _set_hit_stop() -> void:
	if hit_stop_seconds <= 0.0:
		return
	Engine.time_scale = 0.08
	_hit_stop_until_msec = Time.get_ticks_msec() + int(hit_stop_seconds * 1000.0)


func _update_hit_stop() -> void:
	if _hit_stop_until_msec > 0 and Time.get_ticks_msec() >= _hit_stop_until_msec:
		Engine.time_scale = 1.0
		_hit_stop_until_msec = 0


func _flash(colour: Color, strength: float) -> void:
	if flash == null:
		return
	flash.color = Color(colour.r, colour.g, colour.b, strength)


func _update_flash(delta: float) -> void:
	if flash == null:
		return
	var c: Color = flash.color
	if c.a <= 0.0:
		return
	c.a = maxf(c.a - flash_fade_speed * delta, 0.0)
	flash.color = c


# ---------------------------------------------------------------------------
# HUD sync (the HUD is a dumb display; the game pushes state into it)
# ---------------------------------------------------------------------------

func _sync_hud() -> void:
	if hud == null:
		return
	hud.score = score
	hud.multiplier = multiplier
	hud.combo_chain = combo_chain
	hud.combo_time_left = combo_time_left
	hud.combo_window = combo_window
	hud.deaths = deaths

	if room == null or not is_instance_valid(room):
		hud.guards_left = 0
		hud.restore = 0.0
		hud.spotted = false
		hud.player_colour = Color.WHITE
		hud.player_hidden = false
		hud.player_visibility = 1.0
		hud.boss_hue = -1.0
		hud.boss_vulnerable = false
		return

	hud.guards_left = room.alive_guard_count()
	hud.restore = room.restore_ratio()
	hud.spotted = _any_guard_chasing()

	if room.player != null and is_instance_valid(room.player):
		hud.player_colour = room.player.colour
		hud.player_hidden = room.player.is_hidden
		hud.player_visibility = room.player.visibility_now

	if room.boss != null and is_instance_valid(room.boss) and not room.boss.dead:
		hud.boss_hue = float(ColorTheory.hue_degrees(room.boss.colour))
		hud.boss_vulnerable = room.boss.vulnerable
	else:
		hud.boss_hue = -1.0
		hud.boss_vulnerable = false
