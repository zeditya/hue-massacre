extends Node
class_name Game
##
## GAME - the conductor. This is the script on the one tiny scene, main.tscn.
##
## It owns everything that is not the room itself:
##   * the four layers (world, HUD, screens, full-screen effects)
##   * the state machine: PLAY -> (PAUSED | DEAD | WIN)
##   * the score and the COMPLEMENT COMBO
##   * the juice: screen shake, screen flash and hit stop
##
## There is no menu and no story sequence: the game boots straight into the
## first arena. The only pages are pause, victory and defeat.
##
## It is also the only script that knows about colour theory ACROSS rooms,
## because the combo is defined by two kills from different guards.
##
## Nothing here is built in the editor. Every node is created in _ready(), which
## means there is exactly one file to read to understand the whole game shell.

enum State { PLAY, PAUSED, DEAD, WIN }

@export_group("Colour rules")
## Hue distance (degrees) under which floor paint hides the player.
@export var hide_tolerance_deg: float = 26.0
## Half-width of the "these two hues cancel" window for the combo.
##
## 25 is chosen so the rule stays honest: YELLOW 60 <-> BLUE 240 (180 apart)
## and GREEN 120 <-> PURPLE 285 (165 apart) both score, while ORANGE 30 <->
## BLUE 240 (only 150 apart) does NOT. See the table in level_data.gd.
@export var complement_tolerance_deg: float = 25.0
## Half-width of the Champion's kill window.
@export var boss_kill_tolerance_deg: float = 25.0

@export_group("Score")
## Points for one kill, before the multiplier.
@export var base_kill_score: int = 100
## Highest multiplier the combo chain can reach.
@export var max_multiplier: int = 8
## Flat bonus for putting the Champion down.
@export var boss_kill_bonus: int = 1000
## Bonus for clearing an arena without ever being chased. The spec calls this
## the flawless bonus.
@export var flawless_room_bonus: int = 250
## Bonus per aura shattered (see room.strike_landed). The shatter is the
## colour-theory payoff, so it pays on its own as well as through the combo.
@export var shatter_bonus: int = 150

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
## room scrolls past instead of fitting on one screen). 2.0 is the value that
## keeps the pixel grid honest: the floor bake is half resolution, so at zoom
## 2.0 one baked pixel lands on exactly 4x4 screen pixels - no shimmer when
## the camera moves, which is what a laid-stone floor needs.
@export var camera_zoom: float = 2.0
## How fast the camera catches up to the player, per second (exponential ease).
## Higher = tighter and snappier, lower = floatier.
@export var camera_follow_speed: float = 7.0

@export_group("Darkness")
## The arena is in the last light of the day; the Unsworn's own torch shows
## the way. The dark is a mood, never a keyhole: the painted floor, the
## masonry and the guests on the rim all have to stay readable under it.
## Set this false for the original daylight look.
@export var darkness_enabled: bool = true
## Half-width of the player's light cone, in degrees. A torch throws a fairly
## narrow beam, so this is deliberately tighter than a full floodlight. The cone
## follows WASD.
@export var light_cone_deg: float = 50.0
## How far the light cone reaches, in pixels. Long enough to see down a hallway.
@export var light_range: float = 850.0
## A small always-lit circle around the Unsworn so they never lose themselves.
@export var light_near_radius: float = 120.0
## A dim pool of visibility around the Unsworn in every direction, so the ground
## right next to you is always readable even when you are not pointing at it.
## Kept short and weak so the forward cone still reads as a torch beam.
@export var light_ambient_range: float = 190.0
@export_range(0.0, 1.0) var light_ambient_strength: float = 0.50
## How far each knight's lantern reaches. Knights glow with their own hue.
@export var guard_lantern_range: float = 165.0
## 0 = daylight, 1 = pitch black outside the light. Set low enough that the
## painted floor, the arena rim and the combat all stay readable at a glance -
## the dark is a mood here, not the game. The braziers and the knights'
## lanterns still pool light on the sand.
@export_range(0.0, 1.0) var darkness_amount: float = 0.34
## How many guards get a lantern (nearest first). Must match MAX_LIGHTS in the
## shader. Extra guards simply go unlit.
@export var guard_light_count: int = 8

var state: State = State.PLAY
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
## Crowd excitement level (0..1) - drives crowd animations, banner waving, cheering
var crowd_excitement: float = 0.0
## Decay rate for crowd excitement
const CROWD_EXCITEMENT_DECAY: float = 0.15  # per second


func _ready() -> void:
	# Keeps working even if the window loses focus, and keeps the run smooth.
	randomize()
	_build_layers()
	audio = AudioBank.new()
	audio.name = "Audio"
	add_child(audio)
	# Straight into the melee. No title page, no story cards: the arena is the
	# whole opening. The controls and the rule live in the HUD hints.
	start_run()


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

	# Decay crowd excitement and publish it: the arena's living rim reads it
	# back through ArenaArt.get_crowd_excitement().
	if crowd_excitement > 0.0:
		crowd_excitement = maxf(crowd_excitement - CROWD_EXCITEMENT_DECAY * delta, 0.0)
	if room != null:
		ArenaArt.set_crowd_excitement(room_index, crowd_excitement)

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
	screens.restart_requested.connect(_on_screen_restart)
	screens.quit_requested.connect(_on_quit_requested)
	screens.resume_requested.connect(_on_resume_requested)
	screens.room_restart_requested.connect(_on_pause_restart_room)
	screens.run_restart_requested.connect(start_run)
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

## The QUIT row on the pause page. On the web build there is no process to
## quit, so this simply tries and lets the engine refuse.
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


## Begin a fresh run at room 1 with a clean score. This is also what boots the
## game, so it must work before any room has ever existed.
func start_run() -> void:
	get_tree().paused = false
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
	room.boss_phase_changed.connect(_on_boss_phase_changed)
	room.boss_summons_spawned.connect(_on_boss_summons_spawned)
	room.boss_charge_started.connect(_on_boss_charge_started)
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
		# The house announces itself: a verse, the lesson, and its sigil.
		hud.sigil_style = str(room.data.get("floor_style", ""))
		hud.sigil_accent = room.data.get("accent", UiStyle.GOLD)
		hud.show_verse(str(room.data.get("verse", "")), 9.0)
		hud.show_hint(room.data["hint"], 10.0)
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
		var before: int = multiplier
		multiplier = mini(1 + combo_chain, max_multiplier)
		combo_time_left = combo_window
		# The readout punches as it climbs. Every rung of a chain should be felt,
		# not just read - the score is the reward, the pulse is the punctuation.
		if hud != null and multiplier > before:
			hud.pulse_multiplier(multiplier - before)
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

	# Crowd excitement: kills get the crowd going
	crowd_excitement = minf(crowd_excitement + 0.15, 1.0)

	if linked:
		_trigger_combo(guard.colour)

	if guard.is_boss:
		_add_shake(combo_shake)
		_flash(guard.colour, 0.75)
		audio.play("boss_down")
		# The victory beat: he kneels, the crowd goes silent, and the Unsworn
		# is finally named. It runs while the room-clear sequence holds the
		# win page back, so the duel ends on a held shot rather than a cut.
		_boss_victory_beat()


## Three held beats after the Champion falls, timed to land inside the 2.1 s
## room-clear pause before the win page appears.
func _boss_victory_beat() -> void:
	if hud != null:
		hud.show_banner("THE CHAMPION KNEELS", "the crowd falls silent", UiStyle.GOLD, 1.5)
	await get_tree().create_timer(0.9).timeout
	if hud != null:
		hud.show_flash("the sand remembers every hue you spilled", UiStyle.PAPER, 1.2)
	await get_tree().create_timer(0.7).timeout
	if hud != null:
		hud.show_banner("THE UNSWORN IS NAMED", "a house of one, and every colour his", UiStyle.GOLD, 1.6)
	audio.play("named")


## Phase II adds the charging dash; phase III calls the Aspirants. Each is a
## herald's line, in the same voice as the wave banners.
func _on_boss_phase_changed(phase: int) -> void:
	audio.play("wave", 0.75)
	_add_shake(kill_shake)
	# The wheel spins up: the Champion's own hue flares around him as he takes
	# the next turn of it. A phase change is never a surprise.
	if room != null:
		for guard in room.guards:
			if guard.is_boss:
				room.queue_fx("magic", guard.global_position, guard.colour, 1.6)
				break
	if hud == null:
		return
	var title: String = "PHASE II - THE CHARGE" if phase == 2 else "PHASE III - THE ASPIRANTS"
	var sub: String = "he plants his feet and comes for you" if phase == 2 else "he calls the melee and spins the wheel faster"
	hud.show_banner(title, sub, UiStyle.GOLD, 2.0)
	if phase >= 3:
		hud.show_flash("his hue is turning faster now", UiStyle.ALERT, 1.6)
	# Crowd roars for phase changes
	crowd_excitement = minf(crowd_excitement + (0.25 if phase == 2 else 0.35), 1.0)


## The Champion's Aspirants have arrived. They are extra knights in the same
## fight, not a new wave, so the banner says so.
func _on_boss_summons_spawned(count: int) -> void:
	audio.play("wave", 1.25)
	_add_shake(roll_shake)
	if hud == null:
		return
	var noun: String = "Aspirant" if count == 1 else "Aspirants"
	hud.show_flash("%d %s enter the arena" % [count, noun], UiStyle.PAPER, 1.6)
	# Crowd goes wild for summons
	crowd_excitement = minf(crowd_excitement + 0.2, 1.0)


## The dash is committed: a shove of the camera and a low whoosh, so the lane
## is felt as well as seen.
func _on_boss_charge_started() -> void:
	_add_shake(combo_shake * 0.45)
	audio.play("charge")
	# Crowd holds breath for the charge
	crowd_excitement = minf(crowd_excitement + 0.15, 1.0)


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
	# Crowd goes wild for combos
	crowd_excitement = minf(crowd_excitement + 0.2, 1.0)


## The room's blade report: a strike landed, kill or not. A complement SHATTER
## gets the strong juice, an absorbed hit a dull clang, an ordinary cut a whack.
func _on_strike_landed(kind: int, _at: Vector2) -> void:
	match kind:
		ColorTheory.Hit.SHATTER:
			# Breaking an oath-aura pays on its own, before any kill: the shatter
			# IS the colour-theory payoff, so it should not depend on the kill
			# landing (spec section 6).
			score += shatter_bonus
			_add_shake(combo_shake * 0.55)
			_flash(Color(1.0, 1.0, 1.0), 0.16)
			_set_hit_stop()
			audio.play("shatter", randf_range(0.92, 1.08))
			# Crowd reacts to shatters
			crowd_excitement = minf(crowd_excitement + 0.08, 1.0)
		ColorTheory.Hit.ABSORBED:
			_add_shake(kill_shake * 0.2)
			audio.play("clang", randf_range(0.75, 0.90))
			# The blade bounced: no freeze at all, or the dodge that follows a
			# wrong swing would eat the punish window.
			_set_hit_stop(0.0)
		_:
			_add_shake(kill_shake * 0.45)
			# A third of a stop. The chain is three swings at 0.28s apart; a
			# full stop on every cut would make the third swing feel late.
			_set_hit_stop(0.34)
			audio.play("hit", randf_range(0.95, 1.15))
			# Small excitement for normal hits
			crowd_excitement = minf(crowd_excitement + 0.02, 1.0)


## A dodge roll has no victim to play feedback for, so it gets its own small
## juice: a shove of the camera, the old air-puff sound pitched up a touch, and
## a kick of sand where the boots dig in.
func _on_player_rolled(_direction: Vector2) -> void:
	_add_shake(roll_shake)
	audio.play("dash", randf_range(1.05, 1.20))
	if room != null:
		room.queue_fx("dust", room.player.global_position + Vector2(0.0, 6.0),
			Color(0.86, 0.80, 0.68), 0.85)
	# Crowd likes a good dodge
	crowd_excitement = minf(crowd_excitement + 0.03, 1.0)


func _on_player_died() -> void:
	deaths += 1
	_reset_combo()
	_add_shake(death_shake)
	_flash(Color(1.0, 0.15, 0.15), 0.45)
	audio.play("die")
	# Crowd gasps
	crowd_excitement = minf(crowd_excitement + 0.1, 1.0)
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
	# Crowd cheers for arena clear
	crowd_excitement = minf(crowd_excitement + 0.3, 1.0)

	var bonus_text: String = ""
	if not _spotted_this_room:
		score += flawless_room_bonus
		bonus_text = "+%d flawless arena" % flawless_room_bonus

	if hud != null:
		hud.show_banner("ARENA CLEARED", bonus_text if bonus_text != "" else "the sand remembers", UiStyle.GOLD, 2.2)

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


## The spec's end-of-run rank is earned by SCORE, not survival: shatters,
## complement chains and flawless arenas are what an "S - Named" run is made
## of. Thresholds are tuned against a clean four-arena run.
func _rank() -> String:
	if score >= 9000:
		return "S"
	if score >= 6000:
		return "A"
	if score >= 3000:
		return "B"
	return "C"


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


## Get current crowd excitement level (for room drawing)
func get_crowd_excitement() -> float:
	return crowd_excitement


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


## A few milliseconds of near-freeze, so the blade feels like it has weight.
## Measured in real time so it cannot be re-entered. `weight` scales it: a kill
## or a shatter asks for the full stop, an ordinary cut takes a third of one
## (enough to land the impact, not enough to interrupt a three-swing chain),
## and a glance off a shield asks for none.
func _set_hit_stop(weight: float = 1.0) -> void:
	if hit_stop_seconds <= 0.0 or weight <= 0.0:
		return
	# Never shorter than the real-time release, or the freeze outlives the hit.
	var seconds: float = hit_stop_seconds * clampf(weight, 0.0, 2.0)
	Engine.time_scale = 0.08
	# A longer stop is always the later deadline, so a kill during a cut's
	# micro-stop extends it rather than cutting it short.
	_hit_stop_until_msec = maxi(_hit_stop_until_msec,
		Time.get_ticks_msec() + int(seconds * 1000.0))


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
		hud.boss_phase = 1
		hud.sigil_style = ""
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
		hud.boss_phase = room.boss.boss_phase
	else:
		hud.boss_hue = -1.0
		hud.boss_vulnerable = false
		hud.boss_phase = 1


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
