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

enum State { TITLE, INTRO, PLAY, PAUSED, DEAD, WIN }

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
@export var roll_shake: float = 3.0
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

@export_group("Camera")
## The view is zoomed in so the figures read big (Soul Knight framing: the
## room scrolls past instead of fitting on one screen). 1.5 is the value the
## camera comparison picked in docs/proto/2d_camera/.
@export var camera_zoom: float = 1.5
## How fast the camera catches up to the player, per second (exponential ease).
## Higher = tighter and snappier, lower = floatier.
@export var camera_follow_speed: float = 7.0

@export_group("Darkness")
## The drained city is dark; the spark's own light cone shows the way, like a
## torch in a blacked-out hallway. It is dark, but the ground at your feet and
## the guards' lanterns stay readable - the dark is atmosphere, never a keyhole.
## Set this false for the original daylight look.
@export var darkness_enabled: bool = true
## Half-width of the player's light cone, in degrees. A torch throws a fairly
## narrow beam, so this is deliberately tighter than a full floodlight. The cone
## follows WASD.
@export var light_cone_deg: float = 50.0
## How far the light cone reaches, in pixels. Long enough to see down a hallway.
@export var light_range: float = 720.0
## A small always-lit circle around the spark so they never lose themselves.
@export var light_near_radius: float = 95.0
## A dim pool of visibility around the spark in every direction, so the ground
## right next to you is always readable even when you are not pointing at it.
## Kept short and weak so the forward cone still reads as a torch beam.
@export var light_ambient_range: float = 150.0
@export_range(0.0, 1.0) var light_ambient_strength: float = 0.30
## How far each guard's lantern reaches. Guards glow with their stolen colour.
@export var guard_lantern_range: float = 150.0
## 0 = daylight, 1 = pitch black outside the light. Set high enough that the
## world genuinely reads as a dark hallway, but the ambient pool keeps it fair.
@export_range(0.0, 1.0) var darkness_amount: float = 0.74
## How many guards get a lantern (nearest first). Must match MAX_LIGHTS in the
## shader. Extra guards simply go unlit.
@export var guard_light_count: int = 8

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
## Full-screen darkness with the player's light cone cut out of it.
var darkness: ColorRect = null

## The zoom-follow camera. Deliberately NOT a child of world_root: screen
## shake is applied as a jitter on this node, so the world itself never moves.
var camera: Camera2D = null
## The smoothed, clamped follow position. camera.position = this + shake.
var _camera_follow: Vector2 = LevelData.PLAYFIELD * 0.5

var _hud_layer: CanvasLayer = null
var _screens_layer: CanvasLayer = null
var _fx_layer: CanvasLayer = null
var _dark_layer: CanvasLayer = null

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

## Advances forever; drives the torch flicker in the darkness shader.
var _torch_time: float = 0.0


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
	_update_camera(delta)
	_update_hit_stop()
	_update_flash(delta)
	_torch_time += delta

	if state == State.PLAY:
		run_time += delta
		if combo_time_left > 0.0:
			combo_time_left = maxf(combo_time_left - delta, 0.0)
			if combo_time_left <= 0.0:
				_reset_combo()
		if room != null and _any_guard_chasing():
			_spotted_this_room = true

	_sync_hud()
	_sync_darkness()


# ---------------------------------------------------------------------------
# Layers
# ---------------------------------------------------------------------------

func _build_layers() -> void:
	# 1. The world. The camera below is what moves for follow and shake; the
	#    HUD stays on its own CanvasLayer so it is never scaled or shaken.
	world_root = Node2D.new()
	world_root.name = "World"
	world_root.position = world_origin
	# The world is pausable; the shell (this node, the pages and the effects)
	# keeps running so the pause menu can draw and read input while the game
	# underneath is frozen solid.
	world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_root)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 1b. The camera: flat top-down, zoomed ~1.5x, following the player and
	#     clamped to the playfield. It lives OUTSIDE world_root so shake is a
	#     jitter of the camera, not a wobble of the whole simulation.
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	camera.position = _camera_follow
	add_child(camera)

	# 2. Darkness, over the world but under the interface. The player's light
	#    cone is a hole cut in this black layer by darkness.gdshader.
	_dark_layer = CanvasLayer.new()
	_dark_layer.name = "DarkLayer"
	_dark_layer.layer = 1
	_dark_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_dark_layer)
	darkness = ColorRect.new()
	darkness.name = "Darkness"
	# The shader writes COLOR outright, so this value is only a safety net: if the
	# shader ever failed to compile, the default canvas shader would draw this
	# rect, and a transparent fill means the screen stays visible rather than
	# turning white or black.
	darkness.color = Color(0.0, 0.0, 0.0, 0.0)
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dark_mat := ShaderMaterial.new()
	dark_mat.shader = load("res://scripts/darkness.gdshader")
	darkness.material = dark_mat
	_dark_layer.add_child(darkness)

	# 3. The HUD, above the dark world.
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 2
	add_child(_hud_layer)
	hud = Hud.new()
	hud.name = "Hud"
	_hud_layer.add_child(hud)

	# 4. The full-screen pages (title, story, win, death).
	_screens_layer = CanvasLayer.new()
	_screens_layer.name = "ScreensLayer"
	_screens_layer.layer = 3
	add_child(_screens_layer)
	screens = Screens.new()
	screens.name = "Screens"
	screens.start_requested.connect(_on_start_requested)
	screens.intro_finished.connect(_on_intro_finished)
	screens.restart_requested.connect(_on_screen_restart)
	screens.title_requested.connect(start_title)
	screens.quit_requested.connect(_on_quit_requested)
	screens.resume_requested.connect(_on_resume_requested)
	screens.room_restart_requested.connect(_on_pause_restart_room)
	_screens_layer.add_child(screens)

	# 5. Effects that must sit on top of EVERYTHING, including the pages.
	_fx_layer = CanvasLayer.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.layer = 4
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
		# On the start menu, Up/Down (arrow keys, or W/S) move the highlight.
		# These are also the movement actions, but nothing is being driven while
		# a screen is up, so they are free to reuse here.
		if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
			screens.menu_move(-1)
			return
		if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
			screens.menu_move(1)
			return
		# R does the same thing as SPACE on a page, so the "PRESS R TO RETRY NOW"
		# prompt on the death screen actually works. Without this the prompt lied.
		if event.is_action_pressed("restart") or event.is_action_pressed("ui_accept") or clicked:
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
		pause_game()


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

func start_title() -> void:
	get_tree().paused = false
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
	# Start with the story scene (the spark in the grey city), which then hands
	# off to the five rhyme cards, which then hands off to the run.
	screens.show_story()


func _on_intro_finished() -> void:
	start_run()


## The QUIT row on the start menu. On the web build there is no process to
## quit, so this simply returns to the title if the engine refuses.
func _on_quit_requested() -> void:
	get_tree().quit()


## ESC during play. The tree is paused, which freezes the room and every actor
## underneath it, while the pause page and this shell keep running.
func pause_game() -> void:
	if state != State.PLAY or _busy:
		return
	state = State.PAUSED
	get_tree().paused = true
	if hud != null:
		hud.spotted = false
	screens.show_pause()


func _on_resume_requested() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	screens.hide_all()
	state = State.PLAY


func _on_pause_restart_room() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	screens.hide_all()
	state = State.PLAY
	_busy = false
	load_room(room_index)


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
	get_tree().paused = false
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
	room.strike_landed.connect(_on_strike_landed)
	room.wave_started.connect(_on_wave_started)
	room.wave_cleared.connect(_on_wave_cleared)
	world_root.add_child(room)
	# The dodge roll belongs to the player alone, so its feedback (a shove of
	# the camera, the air-puff sound) hangs straight off the player's signal.
	room.player.rolled.connect(_on_player_rolled)
	_snap_camera()

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
## Ignored while a room-clear or death sequence is already running, otherwise
## the pending sequence would then skip straight into the NEXT room.
func restart_room() -> void:
	if state != State.PLAY or _busy:
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


## The room's blade report: a strike landed, kill or not. A complement SHATTER
## gets the strong juice, an absorbed hit a dull clang, an ordinary cut a whack.
func _on_strike_landed(kind: int, _at: Vector2) -> void:
	match kind:
		ColorTheory.Hit.SHATTER:
			_add_shake(combo_shake * 0.55)
			_flash(Color(1.0, 1.0, 1.0), 0.16)
			_set_hit_stop()
			audio.play("shatter", randf_range(0.92, 1.08))
		ColorTheory.Hit.ABSORBED:
			_add_shake(kill_shake * 0.2)
			audio.play("clang", randf_range(0.75, 0.90))
		_:
			_add_shake(kill_shake * 0.45)
			audio.play("hit", randf_range(0.95, 1.15))


## A dodge roll has no victim to play feedback for, so it gets its own small
## juice: a shove of the camera and the old air-puff sound, pitched up a touch.
func _on_player_rolled(_direction: Vector2) -> void:
	_add_shake(roll_shake)
	audio.play("dash", randf_range(1.05, 1.20))


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


## The herald calls a new pack of knights onto the floor.
func _on_wave_started(wave: int, total: int, count: int) -> void:
	audio.play("wave")
	if hud == null:
		return
	var noun: String = "knight" if count == 1 else "knights"
	var verb: String = "enters" if count == 1 else "enter"
	hud.show_banner("WAVE %d / %d" % [wave, total],
		"%d %s %s the arena" % [count, noun, verb], UiStyle.GOLD, 2.2)


## The floor is clear for the moment; the next pack is already on its way.
func _on_wave_cleared(_wave: int) -> void:
	audio.play("room_clear", 1.35, -5.0)
	if hud != null:
		hud.show_flash("the arena falls quiet", UiStyle.PAPER, 1.2)


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
	if _shake > 0.0:
		# Decay faster the bigger the shake, so a huge hit settles quickly.
		_shake = maxf(_shake - shake_decay * delta * (1.0 + _shake * 0.06), 0.0)


# ---------------------------------------------------------------------------
# Camera (flat top-down, zoomed in, follows the player)
# ---------------------------------------------------------------------------

## The camera wants to look at the player. Without a room (title, pages) it
## rests on the middle of the playfield.
func _camera_target() -> Vector2:
	if room != null and is_instance_valid(room) \
			and room.player != null and is_instance_valid(room.player):
		return room.player.global_position
	return LevelData.PLAYFIELD * 0.5


## Keep the view inside the playfield. At zoom Z the view is PLAYFIELD/Z big,
## so the centre may only travel over the inner rectangle; the border walls
## are then always exactly the frame of the screen.
func _clamp_camera(point: Vector2) -> Vector2:
	var half: Vector2 = LevelData.PLAYFIELD * 0.5 / camera_zoom
	return Vector2(
		clampf(point.x, half.x, LevelData.PLAYFIELD.x - half.x),
		clampf(point.y, half.y, LevelData.PLAYFIELD.y - half.y))


## Snap straight to the clamped target. Called when a room loads so the camera
## never slides in from wherever the previous room left it.
func _snap_camera() -> void:
	_camera_follow = _clamp_camera(_camera_target())
	if camera != null:
		camera.position = _camera_follow


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target: Vector2 = _clamp_camera(_camera_target())
	# Exponential ease: frame-rate independent and it never overshoots.
	_camera_follow = _camera_follow.lerp(target, 1.0 - exp(-camera_follow_speed * delta))
	# Screen shake is a jitter ON TOP of the follow position, so it moves the
	# world on screen without ever disturbing the simulation.
	var jitter: Vector2 = Vector2.ZERO
	if _shake > 0.0:
		jitter = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	camera.position = _camera_follow + jitter


## World point -> the 1280x720 canvas pixel the HUD and the darkness shader
## live in. This is THE world-to-screen conversion; every screen-space effect
## goes through it, so they can never disagree with the camera.
func world_to_screen(world_point: Vector2) -> Vector2:
	if camera == null:
		return world_point
	return (world_point - camera.position) * camera.zoom + LevelData.PLAYFIELD * 0.5


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
		hud.wave = 1
		hud.wave_total = 1
		hud.next_wave_in = 0.0
		hud.player_colour = Color.WHITE
		hud.player_hidden = false
		hud.player_visibility = 1.0
		hud.floor_colour = ColorTheory.FLOOR_GREY
		hud.barks = []
		hud.boss_hue = -1.0
		hud.boss_vulnerable = false
		return

	hud.guards_left = room.remaining_guard_count()
	hud.restore = room.restore_ratio()
	hud.spotted = _any_guard_chasing()
	hud.wave = room.current_wave
	hud.wave_total = room.waves_total
	hud.next_wave_in = room.intermission_left

	# Collect any guard that is mid-line so the HUD can draw the bubble above
	# the darkness layer (where the guard itself might still be hidden).
	var active_barks: Array = []
	for guard in room.guards:
		if is_instance_valid(guard) and guard.bark_left > 0.0 and guard.bark_text != "":
			var alpha: float = clampf(guard.bark_left / maxf(guard.bark_total * 0.3, 0.01), 0.0, 1.0)
			active_barks.append({
				# The bubble is drawn in screen space, above the darkness, so
				# the world->screen camera mapping has to be applied here.
				"pos": world_to_screen(guard.global_position),
				"text": guard.bark_text,
				"alpha": alpha,
				"colour": guard.bark_colour,
			})
	hud.barks = active_barks

	if room.player != null and is_instance_valid(room.player):
		hud.player_colour = room.player.colour
		hud.player_hidden = room.player.is_hidden
		hud.player_visibility = room.player.visibility_now
		hud.player_hp = room.player.hp
		hud.player_max_hp = room.player.max_hp
		# Lets the HUD draw the combo readout in the complement of the floor
		# under the player - colour theory as a live readout, not an assertion.
		hud.floor_colour = room.ground_colour_at(room.player.position)

	if room.boss != null and is_instance_valid(room.boss) and not room.boss.dead:
		hud.boss_hue = float(ColorTheory.hue_degrees(room.boss.colour))
		hud.boss_vulnerable = room.boss.vulnerable
	else:
		hud.boss_hue = -1.0
		hud.boss_vulnerable = false


# ---------------------------------------------------------------------------
# Darkness (the player's light cone)
# ---------------------------------------------------------------------------

## Push the player's light cone into the darkness shader. The cone is only
## active during play, so the title/story/win pages are never dimmed.
func _sync_darkness() -> void:
	if darkness == null:
		return
	var on: bool = darkness_enabled and state == State.PLAY \
		and room != null and is_instance_valid(room) \
		and room.player != null and is_instance_valid(room.player)
	darkness.visible = on
	if not on:
		return
	var player: Player = room.player
	var mat: ShaderMaterial = darkness.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("screen_size", LevelData.PLAYFIELD)
	mat.set_shader_parameter("player_pos", world_to_screen(player.global_position))
	mat.set_shader_parameter("facing", player.aim_angle())
	mat.set_shader_parameter("cone_deg", light_cone_deg)
	# A small, slow flicker so the beam reads as a flame rather than a lamp.
	# Only the range flickers: the cone width and the darkness level are
	# asserted by the test suite, so they must stay exactly as exported.
	var flicker: float = 0.93 + 0.05 * sin(_torch_time * 9.0) + 0.03 * sin(_torch_time * 23.0 + 1.3)
	# Every radius is authored in WORLD pixels, but the shader works in screen
	# pixels, so they all scale with the camera zoom.
	mat.set_shader_parameter("light_range", light_range * camera_zoom * flicker)
	mat.set_shader_parameter("near_radius", light_near_radius * camera_zoom)
	mat.set_shader_parameter("ambient_range", light_ambient_range * camera_zoom)
	mat.set_shader_parameter("ambient_strength", light_ambient_strength)
	mat.set_shader_parameter("lantern_range", guard_lantern_range * camera_zoom)
	mat.set_shader_parameter("darkness_amount", darkness_amount)

	# --- guard lanterns ---------------------------------------------------
	# Fill a fixed-size (MAX_LIGHTS = 8) array with the guards nearest the
	# player, padded with the player's own position at zero brightness. The
	# length is always exactly 8 because that is what the shader uniform
	# expects; `light_count` tells the shader how many are real.
	const MAX_LIGHTS: int = 8
	var cap: int = clampi(guard_light_count, 0, MAX_LIGHTS)
	var lit: Array = []
	if cap > 0:
		for guard in room.guards:
			if is_instance_valid(guard) and not guard.dead:
				lit.append(guard)
		lit.sort_custom(func(a, b): return \
			a.global_position.distance_squared_to(player.global_position) \
			< b.global_position.distance_squared_to(player.global_position))
	var pos_arr: PackedVector2Array = PackedVector2Array()
	var col_arr: PackedColorArray = PackedColorArray()
	for i in MAX_LIGHTS:
		if i < mini(lit.size(), cap):
			var g: Guard = lit[i]
			pos_arr.append(world_to_screen(g.global_position))
			col_arr.append(Color(g.colour.r, g.colour.g, g.colour.b, 1.0))
		else:
			pos_arr.append(world_to_screen(player.global_position))
			col_arr.append(Color(0.0, 0.0, 0.0, 1.0))
	mat.set_shader_parameter("light_count", mini(lit.size(), cap))
	mat.set_shader_parameter("light_pos", pos_arr)
	mat.set_shader_parameter("light_col", col_arr)
