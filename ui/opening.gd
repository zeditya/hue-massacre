class_name Opening
extends Node2D
##
## OPENING - the story's first scene, and the only place it is allowed to take
## its time.
##
## One dusk, one gate, one knight lying in the sand. He was chosen first. He
## failed. He has been waiting a long time for someone with nothing to lose, and
## when they arrive he gives them the one art that matters: hue absorption.
## Then he asks them to take up a sword that has lain in the sand since the day
## he dropped it, and lets go.
##
## HOW IT IS BUILT (read this before changing anything)
##   * It is ONE Node2D. There are no child sprites: an actor is a SpriteFrames
##     plus a frame counter and a position, drawn by hand in _draw(). That means
##     the draw order of the whole scene is decided in one place, and nothing
##     can ever end up behind the dialogue box.
##   * The SHOT is a camera position and zoom that eases towards whatever the
##     current beat wants to look at, so the scene is cut like a film: wide on
##     the gate, close on the two of them, wide again when the hall answers.
##   * The SCRIPT is a list of entries, each one of:
##       {"nar": "..."}                    a narrated line
##       {"who": "knight", "text": "..."}  a spoken line
##       {"beat": "gift"}                  something that HAPPENS, timed
##       {"beat": "title", "hold": true}   a card that waits for a keypress
##     Beats are stage directions: they fire, they last as long as they last,
##     and the script moves on by itself (unless the entry says hold).
##   * SPACE (or a click) advances a line; a second press skips the typewriter.
##     ESC skips the whole opening. Everything is skippable, always.
##   * Actors are planted by their FEET inside their sprite cell - the numbers
##     below were measured off the baked art, the same way the game's own
##     SpriteBank plants a knight.

signal finished

const VIEW := Vector2(1280.0, 720.0)

# --- the stage -------------------------------------------------------------
## Everything is drawn in "stage" coordinates: a painting roughly 2400x1500 with
## the gate in the middle. The camera moves over it; nothing else does.
const HORIZON_Y: float = 300.0
const STAGE_LEFT: float = -560.0
const STAGE_RIGHT: float = 1840.0
## The sky only has to reach as high as the camera ever looks. Keeping it short
## is what makes the dawn readable: a gradient squeezed over 260 pixels shows
## violet, magenta and amber all at once, where 800 pixels of it would put the
## whole visible band in the reds.
const STAGE_TOP: float = -260.0
const STAGE_BOTTOM: float = 1000.0

## The three things on the sand. The knight lies on his side with his head
## towards the sword he dropped: his last reach points at the blade the player
## is about to pick up, which is the whole scene in one line.
const KNIGHT_POS := Vector2(462.0, 508.0)
const KNIGHT_ROT: float = 1.02
const KNIGHT_START := Vector2(800.0, 542.0)
const SWORD_POS := Vector2(652.0, 522.0)
## Where the Unsworn stands after walking to the sword.
const SWORD_STAND := Vector2(708.0, 530.0)
const GATE_DOOR := Vector2(600.0, 316.0)

# --- the shot --------------------------------------------------------------
enum Shot { WIDE, CLOSE, GIFT, SWORD, GATE }

const SHOTS := {
	Shot.WIDE:  {"centre": Vector2(640.0, 396.0), "zoom": 0.88},
	Shot.CLOSE: {"centre": Vector2(608.0, 462.0), "zoom": 1.52},
	Shot.GIFT:  {"centre": Vector2(610.0, 448.0), "zoom": 1.62},
	Shot.SWORD: {"centre": Vector2(676.0, 496.0), "zoom": 1.30},
	Shot.GATE:  {"centre": Vector2(620.0, 392.0), "zoom": 0.92},
}

# --- who is speaking -------------------------------------------------------
## Avatars are the pack's 25 portraits: five factions x five faces, numbered in
## sheet order. The Unsworn and the fallen knight are both from the grey
## (hueless) row - they are the only two people in the world with no colour, and
## the story can show that instead of saying it.
const SPEAKERS := {
	"knight": {"name": "THE ONE BEFORE",   "avatar": 25, "colour": Color(0.70, 0.74, 0.86)},
	"you":    {"name": "THE UNSWORN",      "avatar": 24, "colour": Color(0.93, 0.95, 1.00)},
	"warden": {"name": "THE SUN'S WARDEN", "avatar": 7,  "colour": Color(0.98, 0.42, 0.34)},
}

# ---------------------------------------------------------------------------
# THE SCRIPT
# ---------------------------------------------------------------------------
const SCRIPT: Array = [
	{"beat": "title", "hold": true},

	# --- what the world is ------------------------------------------------
	{"nar": "Before the wheel was broken, it was light."},
	{"nar": "When it broke, the last four quarters of it were locked into four halls, and the sworn were set to keep them."},
	{"nar": "A hundred years of keeping has drained the keepers grey. They will not let go. They are right not to."},
	{"nar": "So a knight with no colour of their own has come to the gate of the first hall."},
	{"nar": "There is somebody lying in the sand."},

	# --- the fallen one ---------------------------------------------------
	{"who": "knight", "text": "...You came. They told me one would come.", "shot": Shot.CLOSE},
	{"who": "you", "text": "You are one of the sworn."},
	{"who": "knight", "text": "I was. I was chosen first - chosen the way you were, and I stood at this gate wearing a colour of my own."},
	{"who": "knight", "text": "The halls took it off me. I have been this ever since."},
	{"who": "you", "text": "Then why send for me?"},
	{"who": "knight", "text": "Because you have nothing left for them to take. A knight with no colour is the one key that fits every door in this place."},
	{"who": "knight", "text": "Four halls, four quarters of the wheel. What burns in there is the last colour in the world, and the sworn will die grey before they hand over a drop of it."},
	{"who": "you", "text": "And what would I do with four quarters of anything?"},
	{"who": "knight", "text": "Carry them. Wear them. My steel drank the colour of everything it killed - that is the art of it, the hue absorption - and it is yours now."},

	{"beat": "gift", "shot": Shot.GIFT},

	{"who": "knight", "text": "Wear a hall's own colour and the hall cannot pick you out of it. Wear its opposite and everything it carries will break."},
	{"who": "you", "text": "And when I have all four?"},
	{"who": "knight", "text": "Then remember the one thing the halls never say out loud: to hold every colour is to own none."},
	{"who": "knight", "text": "Mixed together, the four are light. That is the hope they buried. Do not keep it. Mix it, and give it back."},
	{"who": "knight", "text": "Now take up the steel. It has been lying in this sand since the day I dropped it."},

	{"beat": "walk", "shot": Shot.SWORD},
	{"beat": "take", "hold": true, "prompt": "SPACE  -  TAKE UP THE STEEL"},

	{"who": "you", "text": "I have no name yet."},
	{"who": "you", "text": "Then I had better earn one."},

	{"beat": "gate", "shot": Shot.GATE, "hold": true,
		"prompt": "SPACE  -  ENTER THE SUN'S HALL"},
	{"who": "warden", "text": "Turn around, hueless. There is nothing behind this door that belongs to you."},
	{"who": "you", "text": "I know."},
	{"who": "you", "text": "That is why I am taking it."},

	{"beat": "done"},
]

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The game's synthesised sound bank (borrowed, not owned).
var audio: AudioBank = null
## Turned on by the capture harness: no waiting, the script reads itself.
var auto_advance: bool = false

var _script: Array = SCRIPT
var _index: int = -1
var _entry: Dictionary = {}

enum Phase { TYPING, TYPED, BEAT }
var _phase: int = Phase.TYPING

var _time: float = 0.0
var _beat_left: float = 0.0
var _beat_total: float = 0.0
var _beat_name: String = ""
var _beat_hold: bool = false
var _beat_ran: bool = false
var _auto_mark: float = 0.0

var _cam_pos: Vector2 = SHOTS[Shot.WIDE]["centre"]
var _cam_zoom: float = SHOTS[Shot.WIDE]["zoom"]
var _shot: int = Shot.WIDE
var _shot_punch: float = 0.0

# --- typewriter ------------------------------------------------------------
var _chars: float = 0.0
const CHARS_PER_SEC: float = 44.0
var _line: String = ""
var _speaker: String = ""
var _title_alpha: float = 0.0

# --- the actors ------------------------------------------------------------
var _knight_frames: SpriteFrames = null
var _player_frames: SpriteFrames = null
var _knight_time: float = 0.0
var _player_time: float = 0.0
var _player_anim: String = "idle_left"
var _player_pos: Vector2 = KNIGHT_START
var _player_flip: bool = true          # facing left, towards the knight
var _gift_done: bool = false
var _gift_sent: bool = false
var _gift_landed: bool = false
var _sword_glow: float = 0.0
var _sword_lift: float = 0.0
var _has_sword: bool = false
var _gate_open: float = 0.0
var _knight_gone: float = 0.0
var _flash: float = 0.0

# --- the world's little life ----------------------------------------------
var _motes: Array = []
var _stars: Array = []
var _speckle: Array = []
var _fx: Array = []
var _rng := RandomNumberGenerator.new()

## Dev flag: draws crosses at the stage anchors so a capture can prove the
## stage-to-screen mapping by eye. Never set in the game.
var debug_marks: bool = false

# --- assets ----------------------------------------------------------------
var _tex: Dictionary = {}
var _banner: Texture2D = null
## The transform the stage is drawn with (kept so per-actor transforms can be
## undone inside _draw without losing the camera).
var _stage_xform := Transform2D.IDENTITY


func _ready() -> void:
	_rng.seed = 20261018
	z_index = 100
	_load_assets()
	_build_world()
	_enter(0)


func _load_assets() -> void:
	_knight_frames = SpriteBank.unit("knight")
	_player_frames = SpriteBank.adventurer()
	for i in 8:
		_tex["cloud_%02d" % (i + 1)] = load("res://assets/ui/clouds/cloud_%02d.png" % (i + 1))
	for name in ["Archery", "Barracks", "Castle", "House1", "House2", "House3", "Monastery", "Tower"]:
		_tex["black_%s" % name] = load("res://assets/ui/buildings/black/%s.png" % name)
		_tex["red_%s" % name] = load("res://assets/ui/buildings/red/%s.png" % name)
	for i in 25:
		_tex["avatar_%02d" % (i + 1)] = load("res://assets/ui/avatars/avatar_%02d.png" % (i + 1))
	for i in 4:
		_tex["rock%d" % (i + 1)] = load("res://assets/props/rock%d.png" % (i + 1))
		_tex["tool%d" % (i + 1)] = load("res://assets/props/tool%d.png" % (i + 1))
	# The bushs and trees are animated strips: bush/tree are the first shapes,
	# then 2, 3 and 4 (the bake keeps the pack's own numbering for those).
	_tex["bush0"] = load("res://assets/props/bush.png")
	_tex["bush1"] = load("res://assets/props/bush2.png")
	_tex["bush2"] = load("res://assets/props/bush3.png")
	_tex["tree0"] = load("res://assets/props/tree.png")
	_tex["tree1"] = load("res://assets/props/tree2.png")
	_tex["tree2"] = load("res://assets/props/tree3.png")
	_tex["stump"] = load("res://assets/props/stump1.png")
	_tex["gold"] = load("res://assets/props/gold1.png")
	_tex["wood"] = load("res://assets/props/wood.png")
	_tex["statue_soldier"] = load("res://assets/props/statue_soldier.png")
	_tex["statue_orc"] = load("res://assets/props/statue_orc.png")
	_tex["paper"] = load("res://assets/ui/paper.png")
	_tex["absorb"] = load("res://assets/fx/absorb.png")
	_tex["sparkle"] = load("res://assets/fx/sparkle.png")
	_tex["drain"] = load("res://assets/fx/drain.png")
	_banner = load("res://assets/ui/banner.png")


func _build_world() -> void:
	# Stars, sand speckles and drifting motes: fixed by the seed, so the scene
	# is the same painting every time the game is opened.
	for i in 120:
		_stars.append({
			"p": Vector2(_rng.randf_range(STAGE_LEFT, STAGE_RIGHT),
				_rng.randf_range(STAGE_TOP, 150.0)),
			"r": _rng.randf_range(0.8, 2.0),
			"ph": _rng.randf_range(0.0, TAU),
		})
	for i in 340:
		_speckle.append({
			"p": Vector2(_rng.randf_range(STAGE_LEFT, STAGE_RIGHT),
				_rng.randf_range(HORIZON_Y + 20.0, STAGE_BOTTOM)),
			"r": _rng.randf_range(0.7, 2.4),
			"a": _rng.randf_range(0.03, 0.12),
		})
	for i in 26:
		_motes.append({
			"p": Vector2(_rng.randf_range(200.0, 1100.0), _rng.randf_range(140.0, 900.0)),
			"sp": _rng.randf_range(6.0, 22.0),
			"ph": _rng.randf_range(0.0, TAU),
			"r": _rng.randf_range(1.0, 2.6),
		})


# ---------------------------------------------------------------------------
# The script machine
# ---------------------------------------------------------------------------

func _enter(index: int) -> void:
	_index = index
	if _index >= _script.size():
		_finish()
		return
	_entry = _script[_index]
	_beat_name = ""
	_beat_ran = false

	if _entry.has("shot"):
		_shot = int(_entry["shot"])
		_shot_punch = 0.7

	if _entry.has("beat"):
		_start_beat(str(_entry["beat"]))
		return

	_line = str(_entry.get("text", _entry.get("nar", "")))
	_speaker = str(_entry.get("who", ""))
	_chars = 0.0
	_phase = Phase.TYPING
	if _speaker == "knight" and audio != null:
		audio.play("pulse", randf_range(0.92, 1.05), -6.0)


func _advance() -> void:
	if _phase == Phase.TYPING:
		# First press: dump the whole line. The player is allowed to read fast.
		_chars = float(_line.length())
		_phase = Phase.TYPED
		return
	if _phase == Phase.BEAT:
		if _beat_left > 0.0:
			return                       # it is still happening
		if _beat_ran:
			return                       # it already fired; it is timing out now
		_beat_ran = true
		_run_beat_action(_beat_name)
		return
	_enter(_index + 1)


## Fire one beat. A beat either times out by itself or waits for the press.
func _start_beat(name: String) -> void:
	_phase = Phase.BEAT
	_beat_name = name
	_beat_hold = bool(_entry.get("hold", false))
	_beat_left = 0.0
	_beat_total = 0.0
	match name:
		"title":
			_title_alpha = 0.0
			_shot = Shot.WIDE
		"gift":
			_beat_total = 2.10
			_beat_left = 2.10
			_gift_done = true
			if audio != null:
				audio.play("gift")
				audio.play("named", 1.15, -6.0)
		"walk":
			_beat_total = 1.35
			_beat_left = 1.35
		"take", "gate":
			pass                          # held: the press starts the action
		"done":
			_finish()


## The timed part of a beat, called each frame while it runs (t = 0..1).
func _beat_progress(name: String, t: float) -> void:
	match name:
		"gift":
			# The knight's last colour leaves him, crosses the sand and lands:
			# one burst that travels, then the sparkle where it arrives.
			if not _gift_sent:
				_gift_sent = true
				_spawn_fx("absorb", KNIGHT_POS + Vector2(52.0, -30.0),
					Color(0.88, 0.92, 1.0), 1.5, 20.0, _player_pos + Vector2(0.0, -24.0))
			if t > 0.62 and not _gift_landed:
				_gift_landed = true
				_spawn_fx("sparkle", _player_pos + Vector2(0.0, -22.0),
					Color(1.0, 0.96, 0.86), 1.5, 20.0)
			if t > 0.92 and _flash <= 0.0:
				_flash = 0.75
		"walk":
			var e: float = t * t * (3.0 - 2.0 * t)
			_player_pos = KNIGHT_START.lerp(SWORD_STAND, e)
			_player_flip = true
			_player_anim = "run_left"
			if t >= 1.0:
				_player_anim = "idle_left"
				_player_pos = SWORD_STAND
		"take":
			_sword_lift = t
			if t >= 1.0:
				_has_sword = true
		"gate":
			_gate_open = t


## A held beat's one-shot action, run on the keypress.
func _run_beat_action(name: String) -> void:
	match name:
		"take":
			# The pull: the blade comes up out of the sand onto the Unsworn's
			# shoulder, and the sand it stood in is the only mark left.
			_beat_total = 0.85
			_beat_left = 0.85
			_beat_hold = false
			_player_anim = "attack_left"
			_player_time = 0.0
			_spawn_fx("sparkle", SWORD_POS + Vector2(0.0, -14.0), Color(1.0, 0.94, 0.72), 1.6, 20.0)
			if audio != null:
				audio.play("sword")
				audio.play("clang", 0.80, -4.0)
		"gate":
			# The hall answers: the door opens and warm light comes out of it.
			_beat_total = 1.50
			_beat_left = 1.50
			_beat_hold = false
			if audio != null:
				audio.play("gate")
				audio.play("wave", 0.85, -3.0)
		_:
			# A card with nothing to do: the press is the whole action.
			_enter(_index + 1)


func _finish() -> void:
	if not is_inside_tree():
		return
	finished.emit()


func _process(delta: float) -> void:
	_time += delta
	_knight_time += delta * 0.6
	_player_time += delta
	_flash = maxf(_flash - delta * 1.6, 0.0)
	if _beat_name == "title":
		_title_alpha = minf(_title_alpha + delta * 1.4, 1.0)

	_cam_update(delta)

	if _phase == Phase.TYPING:
		_chars = minf(_chars + delta * CHARS_PER_SEC, float(_line.length()))
		if int(_chars) >= _line.length():
			_phase = Phase.TYPED
	elif _phase == Phase.TYPED and auto_advance and _time - _auto_mark > 0.30:
		_auto_mark = _time
		_advance()

	if _phase == Phase.BEAT:
		if _beat_left > 0.0:
			_beat_left = maxf(_beat_left - delta, 0.0)
			_beat_progress(_beat_name, 1.0 - _beat_left / maxf(_beat_total, 0.001))
			if _beat_left <= 0.0:
				_beat_progress(_beat_name, 1.0)
				if not _beat_hold:
					_enter(_index + 1)
		elif auto_advance and _time - _auto_mark > 0.40:
			_auto_mark = _time
			_advance()

	if _gift_done:
		_sword_glow = minf(_sword_glow + delta * 0.9, 1.0)
	if _knight_gone > 0.0 and _knight_gone < 1.0:
		_knight_gone = minf(_knight_gone + delta * 0.16, 1.0)
	if _has_sword and _knight_gone < 0.35:
		# The moment the steel leaves the sand, the knight lets go of the rest.
		_knight_gone = maxf(_knight_gone, 0.001)

	_update_fx(delta)
	_update_motes(delta)
	queue_redraw()


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

func _cam_update(delta: float) -> void:
	var want: Dictionary = SHOTS[_shot]
	var target: Vector2 = want["centre"]
	if _shot == Shot.CLOSE or _shot == Shot.GIFT:
		# A slow drift so a held close-up is a living shot, not a photograph.
		target += Vector2(sin(_time * 0.21) * 8.0, sin(_time * 0.17) * 4.0)
	var k: float = 1.0 - exp(-3.0 * delta)
	_cam_pos = _cam_pos.lerp(target, k)
	_cam_zoom = lerpf(_cam_zoom, float(want["zoom"]), k)
	_shot_punch = maxf(_shot_punch - delta * 2.4, 0.0)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if auto_advance:
		return
	var pressed: bool = event is InputEventKey and event.pressed and not event.echo \
		and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER \
			or event.keycode == KEY_KP_ENTER)
	pressed = pressed or (event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT)
	pressed = pressed or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_advance()


func _input(event: InputEvent) -> void:
	# ESC skips the whole thing. A submission has to survive a second viewing.
	if auto_advance:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_skip()


## Jump straight to the first hall.
func _skip() -> void:
	_enter(_script.size())


## Public skip, for the test harness.
func skip() -> void:
	_skip()


# ---------------------------------------------------------------------------
# FX
# ---------------------------------------------------------------------------

## Spawn an animated strip effect. The strip's frames are square: the cell size
## is simply the strip's height. Pass `to` and the burst TRAVELS - that is how
## the knight's last colour crosses the sand into the Unsworn.
func _spawn_fx(sheet: String, pos: Vector2, tint: Color, scale: float, fps: float,
		to: Vector2 = Vector2.INF) -> void:
	var tex: Texture2D = _tex.get(sheet, null)
	if tex == null:
		return
	var cell: int = tex.get_height()
	var frames: int = maxi(int(tex.get_width() / float(cell)), 1)
	_fx.append({"tex": tex, "cell": cell, "frames": frames, "pos": pos, "to": to,
		"tint": tint, "scale": scale, "fps": fps, "t": 0.0})


func _update_fx(delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		var fx: Dictionary = _fx[i]
		fx["t"] = float(fx["t"]) + delta
		if float(fx["t"]) >= float(fx["frames"]) / float(fx["fps"]):
			_fx.remove_at(i)


func _update_motes(delta: float) -> void:
	for m in _motes:
		var p: Vector2 = m["p"]
		p.y -= float(m["sp"]) * delta
		p.x += sin(_time * 0.6 + float(m["ph"])) * 6.0 * delta
		if p.y < HORIZON_Y - 60.0:
			p.y = STAGE_BOTTOM
			p.x = _rng.randf_range(140.0, 1140.0)
		m["p"] = p


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	# --- the stage -------------------------------------------------------
	var punch := Vector2.ZERO
	if _shot_punch > 0.0:
		punch = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shot_punch * 1.5
	_stage_xform = Transform2D(Vector2(_cam_zoom, 0.0), Vector2(0.0, _cam_zoom),
		VIEW * 0.5 - _cam_pos * _cam_zoom + punch)
	draw_set_transform_matrix(_stage_xform)
	_draw_sky()
	_draw_stars()
	_draw_sun()
	_draw_clouds()
	_draw_skyline()
	_draw_gate()
	_draw_ground()
	_draw_scatter()
	_draw_motes()
	_draw_knight_pool()
	_draw_fallen()
	_draw_player()
	_draw_sword()
	_draw_fx()
	if debug_marks:
		_draw_marks()

	# --- the screen ------------------------------------------------------
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_letterbox()
	_draw_vignette()
	_draw_title()
	_draw_prompt()
	_draw_dialogue()


func _draw_sky() -> void:
	# Bands rather than a gradient texture: 44 steps is smooth at this size,
	# costs nothing, and the palette stays readable as code - this IS the dusk.
	var steps: int = 44
	for i in steps:
		var t: float = float(i) / float(steps)
		var c: Color = _sky_colour(t)
		var y0: float = lerpf(STAGE_TOP, HORIZON_Y, t)
		var y1: float = lerpf(STAGE_TOP, HORIZON_Y, float(i + 1) / float(steps)) + 1.0
		draw_rect(Rect2(STAGE_LEFT, y0, STAGE_RIGHT - STAGE_LEFT, y1 - y0), c)


func _sky_colour(t: float) -> Color:
	var stops: Array = [
		{"t": 0.00, "c": Color(0.075, 0.065, 0.170)},
		{"t": 0.34, "c": Color(0.185, 0.115, 0.290)},
		{"t": 0.58, "c": Color(0.400, 0.150, 0.330)},
		{"t": 0.78, "c": Color(0.720, 0.260, 0.300)},
		{"t": 0.92, "c": Color(0.910, 0.470, 0.280)},
		{"t": 1.00, "c": Color(0.980, 0.700, 0.420)},
	]
	for i in range(stops.size() - 1):
		var a: Dictionary = stops[i]
		var b: Dictionary = stops[i + 1]
		if t <= float(b["t"]):
			var span: float = maxf(float(b["t"]) - float(a["t"]), 0.0001)
			var k: float = clampf((t - float(a["t"])) / span, 0.0, 1.0)
			return (a["c"] as Color).lerp(b["c"] as Color, k)
	return stops[stops.size() - 1]["c"]


func _draw_stars() -> void:
	for s in _stars:
		var tw: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 1.3 + float(s["ph"])))
		var fade: float = clampf(1.0 - (float(s["p"].y) - 150.0) / 240.0, 0.0, 1.0)
		draw_circle(s["p"], float(s["r"]), Color(1.0, 0.97, 0.90, 0.55 * tw * fade))


func _draw_sun() -> void:
	# The sun comes up behind the hall of the first quarter, which is the whole
	# reason this hall is called the Sun's Hall.
	var s := Vector2(596.0, HORIZON_Y - 4.0)
	for i in range(5, 0, -1):
		draw_circle(s, 26.0 + float(i) * 18.0, Color(1.0, 0.62, 0.32, 0.030 * float(i)))
	draw_circle(s, 34.0, Color(1.0, 0.78, 0.45, 0.95))
	draw_circle(s, 27.0, Color(1.0, 0.90, 0.66, 0.95))


func _draw_clouds() -> void:
	for i in 8:
		var tex: Texture2D = _tex["cloud_%02d" % (i + 1)]
		if tex == null:
			continue
		var depth: float = 0.55 + 0.45 * float((i * 7) % 5) / 4.0
		var speed: float = 5.0 + 12.0 * (1.0 - depth)
		var x: float = fposmod(240.0 + float(i) * 190.0 + _time * speed, 2400.0) - 700.0
		var y: float = 40.0 - depth * 240.0 + sin(_time * 0.08 + float(i)) * 6.0
		var tint: Color = Color(0.62, 0.42, 0.58).lerp(Color(0.95, 0.60, 0.42), 1.0 - depth)
		tint.a = 0.42 + 0.28 * (1.0 - depth)
		var size: Vector2 = tex.get_size() * (0.85 + 0.5 * (1.0 - depth))
		draw_texture_rect(tex, Rect2(Vector2(x, y), size), false, tint)


func _draw_skyline() -> void:
	# The village every hall keeps around itself. Black-faction buildings read
	# as silhouettes against the dawn, laid out by hand so the gate stays the
	# one thing in the middle of the frame.
	var row: Array = [
		{"name": "black_Tower", "x": 70.0, "s": 1.10},
		{"name": "black_House2", "x": 168.0, "s": 0.95},
		{"name": "black_Archery", "x": 280.0, "s": 1.05},
		{"name": "black_House1", "x": 398.0, "s": 0.90},
		{"name": "black_Monastery", "x": 486.0, "s": 1.22},
		{"name": "black_House3", "x": 892.0, "s": 0.98},
		{"name": "black_Barracks", "x": 1002.0, "s": 1.16},
		{"name": "black_House2", "x": 1120.0, "s": 0.92},
		{"name": "black_Archery", "x": 1232.0, "s": 1.02},
		{"name": "black_Tower", "x": 1330.0, "s": 1.05},
	]
	for item in row:
		var tex: Texture2D = _tex[item["name"]]
		if tex == null:
			continue
		var s: float = float(item["s"])
		var size: Vector2 = tex.get_size() * s
		var pos := Vector2(float(item["x"]) - size.x * 0.5, HORIZON_Y - size.y + 12.0)
		# A dusk wash, not a flat black: the roofs still read as roofs.
		draw_texture_rect(tex, Rect2(pos, size), false, Color(0.44, 0.36, 0.54, 0.96))


func _draw_gate() -> void:
	# The hall's own gate: red-faction masonry, lit warm from the open door.
	var glow: float = _gate_open
	if glow > 0.0:
		for i in range(5, 0, -1):
			draw_circle(GATE_DOOR, (40.0 + float(i) * 30.0) * (0.4 + glow),
				Color(1.0, 0.82, 0.45, 0.05 * glow))
	var castle: Texture2D = _tex["red_Castle"]
	if castle != null:
		var s: float = 1.95
		var size: Vector2 = castle.get_size() * s
		var pos := Vector2(GATE_DOOR.x - size.x * 0.5, HORIZON_Y - size.y + 30.0)
		draw_texture_rect(castle, Rect2(pos, size), false, Color(0.92, 0.84, 0.96, 1.0))
		# The doorway itself: a dark arch that turns gold when the hall opens.
		var door := Rect2(GATE_DOOR.x - 26.0, HORIZON_Y - 76.0, 52.0, 76.0)
		var door_col: Color = Color(0.06, 0.05, 0.09, 0.92).lerp(
			Color(1.0, 0.86, 0.52, 1.0), clampf(glow * 1.4, 0.0, 1.0))
		draw_rect(door, door_col)
		if glow > 0.02:
			draw_rect(door.grow(-5.0), Color(1.0, 0.95, 0.80, 0.35 * glow))
	for tw in [{"x": 466.0, "s": 1.36}, {"x": 734.0, "s": 1.28}]:
		var tex: Texture2D = _tex["red_Tower"]
		if tex == null:
			continue
		var s2: float = float(tw["s"])
		var size2: Vector2 = tex.get_size() * s2
		var pos2 := Vector2(float(tw["x"]) - size2.x * 0.5, HORIZON_Y - size2.y + 20.0)
		draw_texture_rect(tex, Rect2(pos2, size2), false, Color(0.90, 0.80, 0.94, 1.0))
	# The hall's banner, planted on the sand beside the gate: red for the Sun's
	# Hall, hanging from a spear because nobody has taken it down in a hundred
	# years.
	if _banner != null:
		var pole := Vector2(GATE_DOOR.x + 164.0, HORIZON_Y + 78.0)
		draw_line(pole, pole + Vector2(0.0, -92.0), Color(0.32, 0.26, 0.24, 0.95), 3.0)
		draw_circle(pole + Vector2(0.0, -94.0), 4.0, Color(0.80, 0.62, 0.30, 0.95))
		var size3: Vector2 = _banner.get_size() * 0.5
		var pos3 := Vector2(pole.x + 2.0, pole.y - 88.0)
		draw_texture_rect(_banner, Rect2(pos3, size3), false, Color(0.95, 0.35, 0.30, 0.95))


func _draw_ground() -> void:
	var steps: int = 26
	for i in steps:
		var t: float = float(i) / float(steps)
		var c: Color = Color(0.235, 0.170, 0.190).lerp(Color(0.100, 0.082, 0.110), t)
		var y0: float = lerpf(HORIZON_Y, STAGE_BOTTOM, t)
		var y1: float = lerpf(HORIZON_Y, STAGE_BOTTOM, float(i + 1) / float(steps)) + 1.0
		draw_rect(Rect2(STAGE_LEFT, y0, STAGE_RIGHT - STAGE_LEFT, y1 - y0), c)
	# The road up to the gate: paler, worn, narrowing as it climbs.
	var road := PackedVector2Array([
		GATE_DOOR + Vector2(-150.0, -8.0),
		GATE_DOOR + Vector2(150.0, -8.0),
		Vector2(GATE_DOOR.x + 420.0, STAGE_BOTTOM),
		Vector2(GATE_DOOR.x - 420.0, STAGE_BOTTOM),
	])
	draw_colored_polygon(road, Color(0.30, 0.24, 0.24, 0.45))
	if _gate_open > 0.0:
		# The light the hall throws down the sand.
		var spread: float = 60.0 + 300.0 * _gate_open
		var pts := PackedVector2Array([
			GATE_DOOR + Vector2(-30.0, 6.0),
			GATE_DOOR + Vector2(30.0, 6.0),
			GATE_DOOR + Vector2(spread, 360.0),
			GATE_DOOR + Vector2(-spread, 360.0),
		])
		draw_colored_polygon(pts, Color(1.0, 0.74, 0.40, 0.14 * _gate_open))
	for s in _speckle:
		draw_circle(s["p"], float(s["r"]), Color(1.0, 0.92, 0.80, float(s["a"])))


func _draw_scatter() -> void:
	# Props from the packs, dark and small: the sand is walked on.
	_prop("tree2", Vector2(150.0, 660.0), 1.8, Color(0.30, 0.24, 0.34, 0.85), true)
	_prop("tree0", Vector2(1160.0, 700.0), 1.6, Color(0.30, 0.24, 0.34, 0.85), true)
	_prop("bush0", Vector2(330.0, 600.0), 1.4, Color(0.34, 0.27, 0.36, 0.80), true)
	_prop("bush1", Vector2(900.0, 640.0), 1.3, Color(0.34, 0.27, 0.36, 0.80), true)
	_prop("rock1", Vector2(430.0, 740.0), 1.5, Color(0.42, 0.40, 0.48, 0.70))
	_prop("rock2", Vector2(780.0, 780.0), 1.3, Color(0.42, 0.40, 0.48, 0.70))
	_prop("rock3", Vector2(1000.0, 552.0), 1.1, Color(0.42, 0.40, 0.48, 0.70))
	_prop("stump", Vector2(250.0, 500.0), 1.2, Color(0.38, 0.30, 0.32, 0.80))
	# The road to the gate is marked the way this world marks roads: with its
	# own old stone.
	_prop("statue_soldier", GATE_DOOR + Vector2(104.0, 76.0), 0.95,
		Color(0.62, 0.62, 0.72, 0.88))
	_prop("statue_orc", Vector2(356.0, 770.0), 0.90, Color(0.56, 0.56, 0.66, 0.88))
	# What is left of the camp of a knight who has been lying here a while: one
	# log, one axe he will not lift again, and the pay he never spent.
	_prop("wood", KNIGHT_POS + Vector2(-96.0, 22.0), 1.15, Color(0.54, 0.46, 0.40, 0.85))
	_prop("tool2", KNIGHT_POS + Vector2(-56.0, 34.0), 0.95, Color(0.64, 0.58, 0.54, 0.80))
	_prop("gold", KNIGHT_POS + Vector2(-126.0, 40.0), 0.95, Color(0.82, 0.72, 0.52, 0.80))
	# The things someone dropped the day this gate was last walked through.
	_prop("tool3", GATE_DOOR + Vector2(-150.0, 150.0), 0.95, Color(0.68, 0.62, 0.58, 0.75))
	_prop("gold", GATE_DOOR + Vector2(128.0, 172.0), 0.95, Color(0.78, 0.68, 0.48, 0.75))


## Draw one prop texture with its base at `base`. Bushes and trees are baked as
## animated STRIPS (eight cells in a row), so this draws one cell of them -
## otherwise a single tree would tile its whole strip across the sand - and
## sways through the frames with the clock.
func _prop(key: String, base: Vector2, scale: float, tint: Color, sway: bool = false) -> void:
	var tex: Texture2D = _tex.get(key, null)
	if tex == null:
		return
	var cell := Vector2(tex.get_width(), tex.get_height())
	var frame: int = 0
	if key.begins_with("bush") or key.begins_with("tree"):
		cell.x = tex.get_width() / 8.0
		if sway:
			frame = int(_time * 5.0) % 8
	var size: Vector2 = cell * scale
	draw_texture_rect_region(tex,
		Rect2(base - Vector2(size.x * 0.5, size.y - 6.0), size),
		Rect2(cell.x * float(frame), 0.0, cell.x, cell.y), tint)


func _draw_motes() -> void:
	for m in _motes:
		var a: float = 0.20 + 0.30 * (0.5 + 0.5 * sin(_time * 1.7 + float(m["ph"])))
		draw_circle(m["p"], float(m["r"]), Color(1.0, 0.86, 0.55, a))


func _draw_knight_pool() -> void:
	# What he is lying in: a dark pool, and a little of the colour the hall took
	# off him, still faintly there under the body. The pool sits under the BODY,
	# not under his boots, or the figure looks laid out on top of a hole.
	var body: Vector2 = KNIGHT_POS + Vector2(52.0, -32.0)
	draw_circle(body + Vector2(-6.0, 6.0), 54.0, Color(0.05, 0.04, 0.06, 0.50))
	draw_circle(body + Vector2(-14.0, 2.0), 33.0, Color(0.30, 0.20, 0.34, 0.30))
	if _knight_gone > 0.0:
		draw_circle(body + Vector2(-6.0, 6.0), 54.0 * _knight_gone,
			Color(0.06, 0.05, 0.08, 0.5 * _knight_gone))


func _draw_fallen() -> void:
	# He lies on his side. Being half dead is drawn by rotating the idle figure
	# onto its shoulder and letting the chest rise just enough to read as
	# breathing - the player has to believe he is dying, not already a prop.
	if _knight_gone >= 1.0:
		return
	var a: float = 1.0 - _knight_gone
	var breathe: float = 1.0 + 0.02 * sin(_time * 1.5) * (1.0 - _knight_gone)
	var tex: Texture2D = _knight_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	_cell(tex, KNIGHT_POS, 96.0, 96.0, 1.42 * breathe,
		Color(0.62, 0.65, 0.76, 0.96 * a), KNIGHT_ROT, false)


## A rotated, scaled frame whose ORIGIN IS KEPT.
##
## Godot's `Transform2D.scaled()` pre-multiplies - it scales the ORIGIN as well
## as the axes - so a "scale this transform about its own point" has to be
## written out. Getting that wrong drags the whole stage towards the top-left
## corner by the zoom factor, which is invisible at zoom 0.88 and glaring in a
## close-up. Both the camera transform and every planted actor use this.
func _actor_xform(base: Vector2, rot: float, sx: float, sy: float) -> Transform2D:
	var c: float = cos(rot)
	var s: float = sin(rot)
	return Transform2D(Vector2(c * sx, s * sx), Vector2(-s * sy, c * sy), base)


## Draw one sprite cell planted by its feet, rotated about that point, with an
## optional horizontal flip. Restores the stage transform before returning.
func _cell(tex: Texture2D, base: Vector2, cell_w: float, cell_h: float,
		scale: float, tint: Color, rot: float = 0.0, flip: bool = false) -> void:
	if tex == null:
		return
	var origin: Vector2 = base
	draw_set_transform_matrix(_stage_xform * _actor_xform(origin, rot,
		scale * (-1.0 if flip else 1.0), scale))
	draw_texture_rect(tex, Rect2(Vector2(-cell_w * 0.5, -cell_h), Vector2(cell_w, cell_h)),
		false, tint)
	draw_set_transform_matrix(_stage_xform)


func _draw_player() -> void:
	var frame: int = _frame_of(_player_frames, _player_anim, _player_time,
		4.0 if _player_anim.begins_with("idle") else 13.0)
	var tex: Texture2D = _player_frames.get_frame_texture(_player_anim, frame)
	if tex == null:
		return
	var p: Vector2 = _player_pos
	draw_circle(p + Vector2(0.0, 2.0), 13.0, Color(0.0, 0.0, 0.0, 0.35))
	# A faint white aura once the absorption is in them: the only light they
	# carry is the ability to take light.
	if _gift_done:
		for i in range(3, 0, -1):
			draw_circle(p + Vector2(0.0, -18.0), 8.0 + float(i) * 5.0,
				Color(0.85, 0.92, 1.0, 0.030 + 0.02 * (0.5 + 0.5 * sin(_time * 3.0))))
	# The Unsworn's own art, untinted: this is the one knight in the world with
	# no colour of their own, and the finished frames already say so.
	_cell(tex, p, 96.0, 80.0, 1.22, Color(1.0, 1.0, 1.0), 0.0, _player_flip)
	if _has_sword:
		# The steel rides on the back, tip up and away from the face: a quiet
		# mark that it is theirs now.
		var hilt: Vector2 = p + Vector2(6.0 if _player_flip else -6.0, -36.0)
		_draw_blade(hilt, 0.5, 0.55 if _player_flip else -0.55, Color(0.82, 0.86, 0.94, 0.92))


func _frame_of(frames: SpriteFrames, anim: String, time: float, fps: float) -> int:
	if not frames.has_animation(anim):
		return 0
	var count: int = frames.get_frame_count(anim)
	if count <= 0:
		return 0
	return int(time * fps) % count


func _draw_sword() -> void:
	if _has_sword and _sword_lift <= 0.0:
		return
	var lift: float = _sword_lift
	var a: float = 1.0 - lift
	var p: Vector2 = SWORD_POS + Vector2(0.0, -30.0 * lift)
	if lift < 0.5:
		draw_circle(SWORD_POS + Vector2(2.0, 4.0), 15.0, Color(0.05, 0.04, 0.06, 0.45))
	var glow: float = _sword_glow * (1.0 - lift)
	if glow > 0.0:
		for i in range(4, 0, -1):
			draw_circle(p + Vector2(0.0, -30.0), 6.0 + float(i) * 7.0,
				Color(1.0, 0.90, 0.60, 0.045 * glow))
	_draw_blade(p, 1.0, -0.10 + lift * 0.30, Color(0.86, 0.90, 0.98, a))


## One sword, drawn from primitives: blade, crossguard, grip, pommel. The same
## sword rides small on the Unsworn's back once it is theirs.
func _draw_blade(base: Vector2, scale: float, tilt: float, tint: Color) -> void:
	var blade := PackedVector2Array()
	for v in [Vector2(0.0, -6.0), Vector2(4.0, -11.0), Vector2(3.4, -62.0),
			Vector2(0.0, -74.0), Vector2(-3.4, -62.0), Vector2(-4.0, -11.0)]:
		blade.append(base + (v * scale).rotated(tilt))
	draw_colored_polygon(blade, Color(tint.r * 0.88, tint.g * 0.90, tint.b * 0.96, tint.a))
	# The edge catching the dawn light.
	var edge := PackedVector2Array([
		base + (Vector2(0.0, -6.0) * scale).rotated(tilt),
		base + (Vector2(2.4, -58.0) * scale).rotated(tilt),
		base + (Vector2(0.0, -72.0) * scale).rotated(tilt),
	])
	draw_polyline(edge, Color(1.0, 1.0, 1.0, 0.5 * tint.a), 1.2)
	# Crossguard: bronze, the only warm metal in the frame.
	var guard := PackedVector2Array()
	for v in [Vector2(-13.0, -9.0), Vector2(13.0, -9.0), Vector2(13.0, -3.0), Vector2(-13.0, -3.0)]:
		guard.append(base + (v * scale).rotated(tilt))
	draw_colored_polygon(guard, Color(0.72, 0.52, 0.26, tint.a))
	var grip := PackedVector2Array()
	for v in [Vector2(-3.0, -3.0), Vector2(3.0, -3.0), Vector2(3.0, 10.0), Vector2(-3.0, 10.0)]:
		grip.append(base + (v * scale).rotated(tilt))
	draw_colored_polygon(grip, Color(0.26, 0.18, 0.14, tint.a))
	draw_circle(base + (Vector2(0.0, 12.0) * scale).rotated(tilt), 4.0 * scale,
		Color(0.80, 0.62, 0.30, tint.a))


func _draw_fx() -> void:
	for fx in _fx:
		var tex: Texture2D = fx["tex"]
		var cell: float = float(fx["cell"])
		var frame: int = int(float(fx["t"]) * float(fx["fps"])) % int(fx["frames"])
		var scale: float = float(fx["scale"])
		var life: float = float(fx["frames"]) / maxf(float(fx["fps"]), 0.001)
		var at: Vector2 = fx["pos"]
		var to: Vector2 = fx["to"]
		if to != Vector2.INF:
			# It flies: eased so it leaves slowly, crosses fast, lands slowly.
			var k: float = clampf(float(fx["t"]) / life, 0.0, 1.0)
			at = at.lerp(to, k * k * (3.0 - 2.0 * k))
		var pos: Vector2 = at - Vector2(cell, cell) * 0.5 * scale
		draw_texture_rect_region(tex, Rect2(pos, Vector2(cell, cell) * scale),
			Rect2(float(frame) * cell, 0.0, cell, cell), fx["tint"])


## Dev only (see `debug_marks`): crosses at the stage anchors, so a capture can
## prove the stage-to-screen mapping by eye instead of by arithmetic.
func _draw_marks() -> void:
	var anchors: Array = [
		{"p": KNIGHT_POS, "c": Color(1.0, 0.2, 0.9)},
		{"p": SWORD_POS, "c": Color(0.2, 1.0, 0.3)},
		{"p": GATE_DOOR, "c": Color(0.3, 0.7, 1.0)},
		{"p": Vector2(640.0, 396.0), "c": Color(1.0, 1.0, 0.2)},
	]
	for a in anchors:
		var p: Vector2 = a["p"]
		draw_line(p - Vector2(22.0, 0.0), p + Vector2(22.0, 0.0), a["c"], 2.0)
		draw_line(p - Vector2(0.0, 22.0), p + Vector2(0.0, 22.0), a["c"], 2.0)
		draw_circle(p, 4.0, a["c"])


# --- the screen-space layer ------------------------------------------------

func _draw_letterbox() -> void:
	var h: float = 58.0
	draw_rect(Rect2(0.0, 0.0, VIEW.x, h), Color(0.02, 0.02, 0.03, 0.94))
	draw_rect(Rect2(0.0, VIEW.y - h, VIEW.x, h), Color(0.02, 0.02, 0.03, 0.94))


func _draw_vignette() -> void:
	for i in 6:
		var a: float = 0.045 - float(i) * 0.006
		var t: float = float(i) * 15.0
		draw_rect(Rect2(0.0, 0.0, VIEW.x, t + 15.0), Color(0.0, 0.0, 0.0, a))
		draw_rect(Rect2(0.0, VIEW.y - t - 15.0, VIEW.x, t + 15.0), Color(0.0, 0.0, 0.0, a))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(1.0, 0.98, 0.92, 0.40 * _flash))


func _draw_title() -> void:
	if _beat_name != "title":
		return
	var a: float = _title_alpha
	var pulse: float = (0.72 + 0.28 * sin(_time * 2.2)) * a
	# The title sits on one of the game's own plates, the same bordered panel
	# the dialogue wears, so the card belongs to the same world as everything
	# after it. No full-screen wash: the village stays visible behind the frame.
	var plate := Rect2(252.0, 128.0, 776.0, 184.0)
	UiStyle.panel(self, plate, UiStyle.glow(UiStyle.GOLD, a),
		UiStyle.glow(Color(0.030, 0.028, 0.045, 0.90), a))
	UiStyle.text(self, UiStyle.tracked("HUE MASSACRE", 1), Vector2(plate.position.x, 212.0),
		_fit(UiStyle.tracked("HUE MASSACRE", 1), plate.size.x - 72.0, 74),
		UiStyle.glow(UiStyle.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
	UiStyle.text(self, UiStyle.tracked("a legend of the broken wheel", 1),
		Vector2(plate.position.x, 252.0),
		_fit(UiStyle.tracked("a legend of the broken wheel", 1), plate.size.x - 160.0, 22),
		UiStyle.glow(UiStyle.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
	UiStyle.text(self, "the last colours in the world are locked in four halls",
		Vector2(plate.position.x, 288.0), 16, UiStyle.glow(UiStyle.DIM, a),
		HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
	UiStyle.text(self, UiStyle.tracked("SPACE  -  BEGIN", 1), Vector2(0.0, 636.0),
		18, Color(1.0, 1.0, 1.0, pulse), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)


## Shrink a line until it fits a width. Titles are drawn with tracking, which
## makes their width hard to predict, and a title that overflows its plate is
## worse than a small one.
func _fit(text: String, width: float, size: int) -> int:
	var f: Font = UiStyle.display_font()
	if f == null:
		return size
	var s: int = size
	while s > 14 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, s).x > width:
		s -= 2
	return s


func _draw_prompt() -> void:
	if _phase != Phase.BEAT or not _entry.has("prompt") or _beat_left > 0.0:
		return
	var pulse: float = 0.70 + 0.30 * sin(_time * 3.0)
	UiStyle.text(self, UiStyle.tracked(str(_entry["prompt"]), 2), Vector2(0.0, 424.0), 22,
		Color(1.0, 0.96, 0.86, pulse), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x)
	if _beat_name == "gate":
		_draw_legend()


## The controls, taught once - on the last card before the first hall, where the
## story has the player's full attention - and then never again on the HUD.
func _draw_legend() -> void:
	var items: Array = [
		{"key": "WASD", "text": "MOVE"},
		{"key": "LMB", "text": "STRIKE  x3"},
		{"key": "RMB", "text": "GUARD  /  PARRY"},
		{"key": "SPACE", "text": "ROLL"},
	]
	var total: float = 4.0 * 250.0
	var x: float = VIEW.x * 0.5 - total * 0.5
	for item in items:
		_key_box(str(item["key"]), Vector2(x, 520.0))
		UiStyle.text(self, str(item["text"]), Vector2(x + 74.0, 539.0), 16, UiStyle.DIM)
		x += 250.0


func _key_box(label: String, pos: Vector2) -> void:
	var f: Font = UiStyle.font()
	if f == null:
		return
	var w: float = maxf(58.0, f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x + 20.0)
	var rect := Rect2(pos, Vector2(w, 28.0))
	draw_rect(rect, Color(0.10, 0.10, 0.14, 0.92))
	draw_rect(rect, Color(0.62, 0.64, 0.74, 0.75), false, 1.5)
	UiStyle.text(self, label, Vector2(rect.position.x, pos.y + 20.0), 15, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, false)


func _draw_dialogue() -> void:
	if not _entry.has("text") and not _entry.has("nar"):
		return
	var narration: bool = not _entry.has("text")
	var rect := Rect2(150.0, 512.0, 980.0, 152.0)
	var sp: Dictionary = SPEAKERS.get(_speaker, {})
	var accent: Color = sp.get("colour", UiStyle.DIM)

	# The panel: a dark plate with the pack's paper grain over it.
	UiStyle.panel(self, rect, accent, Color(0.030, 0.030, 0.048, 0.94))
	var paper: Texture2D = _tex["paper"]
	if paper != null:
		draw_texture_rect(paper, rect.grow(-4.0), true, Color(1.0, 0.96, 0.88, 0.05))

	var text_x: float = rect.position.x + 34.0
	var text_w: float = rect.size.x - 68.0
	var align: int = HORIZONTAL_ALIGNMENT_LEFT
	if sp.has("avatar"):
		var box := Rect2(rect.position.x + 18.0, rect.position.y + 16.0, 116.0, 116.0)
		draw_rect(box, Color(0.06, 0.06, 0.09, 0.95))
		var av: Texture2D = _tex.get("avatar_%02d" % int(sp["avatar"]), null)
		if av != null:
			draw_texture_rect(av, box.grow(-4.0), false, Color(1.0, 1.0, 1.0, 0.96))
		draw_rect(box, Color(accent.r, accent.g, accent.b, 0.55), false, 2.0)
		text_x = box.end.x + 24.0
		text_w = rect.end.x - text_x - 26.0
		UiStyle.text(self, UiStyle.tracked(str(sp.get("name", "")), 2),
			Vector2(text_x, rect.position.y + 34.0), 15, accent)
	else:
		align = HORIZONTAL_ALIGNMENT_CENTER
		text_x = rect.position.x + 60.0
		text_w = rect.size.x - 120.0

	# The line itself: typewritten, and the caret blinks when it has landed.
	var shown: String = _line.substr(0, int(_chars))
	_draw_wrapped(shown, Vector2(text_x, rect.position.y + (62.0 if sp.has("avatar") else 74.0)),
		text_w, 21, Color(UiStyle.PAPER.r, UiStyle.PAPER.g, UiStyle.PAPER.b, 1.0), align)
	if _phase != Phase.TYPING and fmod(_time, 1.0) < 0.62:
		draw_circle(Vector2(rect.end.x - 28.0, rect.end.y - 20.0), 4.0, accent)


## Word-wrapped text with the outline the rest of the game's type wears.
func _draw_wrapped(text: String, pos: Vector2, width: float, size: int, colour: Color,
		align: int) -> void:
	var f: Font = UiStyle.font()
	if f == null:
		return
	var wrapped: String = _wrap(text, width, size)
	draw_multiline_string_outline(f, pos, wrapped, align, width, size, 4, 6, UiStyle.OUTLINE)
	draw_multiline_string(f, pos, wrapped, align, width, size, 4, colour)


## A tiny word wrap. Godot's paragraph helper centres everything, and dialogue
## reads better left-aligned under a portrait, so the break is computed here.
func _wrap(text: String, width: float, size: int) -> String:
	var f: Font = UiStyle.font()
	if f == null:
		return text
	var out: String = ""
	var line: String = ""
	for word in text.split(" "):
		var attempt: String = word if line == "" else line + " " + word
		if f.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > width \
				and line != "":
			out += line + "\n"
			line = word
		else:
			line = attempt
	return out + line
