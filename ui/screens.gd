class_name Screens
extends Control
##
## SCREENS - the full-screen pages that interrupt the melee. Only three exist,
## on purpose: the game boots straight into the arena, so there is no menu and
## no story sequence to click through.
##
##   PAUSE  the melee holds: RESUME / RESTART RUN / QUIT GAME
##   WIN    the Champion is down, the crowd names you, the run is scored
##   DEAD   a short "the sand takes you" beat before the arena reloads
##
## TYPOGRAPHY: headings are wide-tracked gold, body text is tight cool grey, and
## every string is drawn with a dark outline (UiStyle.text) because the
## background behind it is either a live arena or a red wash.
##
## The rules the player needs are taught in the HUD: every arena prints its
## lesson as a hint when it loads, so cutting the menu did not cut the tutorial.

signal restart_requested
signal quit_requested
## Pause-menu choices.
signal resume_requested
signal room_restart_requested
## Start the whole run again from the first arena.
signal run_restart_requested

enum Mode { NONE, PAUSE, WIN, DEAD }

## The pause menu, in order. Kept as data so the drawing and the input handling
## can never disagree about how many items there are.
const PAUSE_ITEMS: Array = ["RESUME", "RESTART RUN", "QUIT GAME"]

## Kill flashes, chosen at random. Here so the wording lives in one place.
const KILL_FLASHES: Array = [
	"Colour spills; the sand drinks it.",
	"A hue is loose in the arena.",
	"The crowd tastes a new colour.",
]

const WIN_TITLE: String = "THE UNSWORN IS NAMED"
const WIN_LINES: Array = [
	"The Champion kneels, the crowd is still,",
	"one nameless knight has drunk the wheel.",
]
const WIN_COLOURS: Array = [Color(1.00, 0.82, 0.25), Color(0.55, 0.80, 1.00)]

@export_group("Timing")
## Seconds the death wash takes to settle.
@export var death_wash_time: float = 0.35

var mode: Mode = Mode.NONE

## Which pause-menu row is highlighted.
var pause_index: int = 0
## 0..1 overlay fade, so pages arrive instead of snapping on.
var _fade: float = 0.0
var _time: float = 0.0

# --- win stats ------------------------------------------------------------
var win_score: int = 0
var win_deaths: int = 0
var win_seconds: float = 0.0
var win_rank: String = "C"

# --- death info -----------------------------------------------------------
var dead_room: String = ""
var dead_restart_in: float = 0.0
## The full restart delay, so the red wash scales with the exported value
## instead of a hard-coded 0.9.
var dead_total: float = 0.9


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if mode == Mode.NONE:
		return
	_fade = minf(_fade + delta * 4.0, 1.0)
	if mode == Mode.DEAD:
		dead_restart_in = maxf(dead_restart_in - delta, 0.0)
	queue_redraw()


## True while a page owns the input, so game.gd knows not to drive the player.
func is_blocking() -> bool:
	return mode != Mode.NONE


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func show_pause() -> void:
	mode = Mode.PAUSE
	visible = true
	pause_index = 0
	_fade = 0.0


func show_win(score: int, deaths: int, seconds: float, rank: String) -> void:
	mode = Mode.WIN
	visible = true
	_fade = 0.0
	win_score = score
	win_deaths = deaths
	win_seconds = seconds
	win_rank = rank


func show_dead(room_label: String, restart_in: float) -> void:
	mode = Mode.DEAD
	visible = true
	_fade = 0.0
	dead_room = room_label
	dead_restart_in = restart_in
	dead_total = maxf(restart_in, 0.001)


func hide_all() -> void:
	mode = Mode.NONE
	visible = false
	_fade = 0.0


## Move the highlighted row by `dir` (-1 up, +1 down), wrapping round.
func menu_move(dir: int) -> void:
	if mode == Mode.PAUSE:
		pause_index = posmod(pause_index + dir, PAUSE_ITEMS.size())


## The input handler for every page. game.gd calls this on click / SPACE / R.
func advance() -> void:
	match mode:
		Mode.PAUSE:
			match pause_index:
				0:
					resume_requested.emit()
				1:
					run_restart_requested.emit()
				2:
					quit_requested.emit()
		Mode.WIN, Mode.DEAD:
			restart_requested.emit()
		_:
			pass


func back() -> void:
	match mode:
		Mode.PAUSE:
			resume_requested.emit()
		_:
			pass


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if mode == Mode.NONE:
		return
	match mode:
		Mode.PAUSE:
			_draw_pause()
		Mode.WIN:
			_draw_win()
		Mode.DEAD:
			_draw_dead()


func _draw_pause() -> void:
	# Dim the frozen arena rather than hiding it, so you keep your bearings.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.02, 0.02, 0.04, 0.82 * _fade), true)

	var cx: float = 640.0
	_hue_strip(Rect2(440.0, 196.0, 400.0, 5.0))
	UiStyle.text(self, UiStyle.tracked("THE MELEE HOLDS", 4), Vector2(cx - 480.0, 262.0), 44, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)
	UiStyle.text(self, "the crowd is waiting", Vector2(cx - 480.0, 294.0), 16, UiStyle.DIM,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	var item_h: float = 44.0
	var menu_w: float = 360.0
	var menu_x: float = cx - menu_w * 0.5
	var menu_y: float = 352.0

	var panel := Rect2(menu_x - 20.0, menu_y - 24.0, menu_w + 40.0, float(PAUSE_ITEMS.size()) * item_h + 40.0)
	UiStyle.panel(self, panel, Color(1.0, 1.0, 1.0, 0.20))
	for i in PAUSE_ITEMS.size():
		var y: float = menu_y + float(i) * item_h
		var selected: bool = i == pause_index
		var label: String = str(PAUSE_ITEMS[i])
		if selected:
			var pulse: float = 0.75 + 0.25 * sin(_time * 4.0)
			draw_rect(Rect2(menu_x - 10.0, y - 23.0, menu_w + 20.0, 34.0),
				Color(UiStyle.GOLD.r, UiStyle.GOLD.g, UiStyle.GOLD.b, 0.10 * pulse), true)
			UiStyle.text(self, ">", Vector2(menu_x - 4.0, y), 22, UiStyle.GOLD)
			UiStyle.text(self, UiStyle.tracked(label, 2), Vector2(menu_x + 22.0, y), 24, UiStyle.GOLD)
		else:
			UiStyle.text(self, UiStyle.tracked(label, 2), Vector2(menu_x + 22.0, y), 22,
				Color(UiStyle.DIM.r, UiStyle.DIM.g, UiStyle.DIM.b, 0.9))

	UiStyle.text(self, UiStyle.tracked("W / S TO CHOOSE   -   SPACE OR ESC TO RESUME", 1),
		Vector2(cx - 440.0, 636.0), 14, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, 880.0)


func _draw_win() -> void:
	_full_backdrop(0.94)

	# Everything on the win page is warm: this is the moment the wheel is named.
	UiStyle.text(self, UiStyle.tracked(WIN_TITLE, 4), Vector2(160.0, 214.0), 46, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	var y: float = 292.0
	for i in WIN_LINES.size():
		UiStyle.text(self, WIN_LINES[i], Vector2(160.0, y), 28, WIN_COLOURS[i],
			HORIZONTAL_ALIGNMENT_CENTER, 960.0)
		y += 44.0

	_hue_strip(Rect2(340.0, 388.0, 600.0, 6.0))

	var box := Rect2(400.0, 432.0, 480.0, 128.0)
	UiStyle.panel(self, box, UiStyle.GOLD)
	var left_x: float = box.position.x + 26.0
	var right_x: float = box.end.x - 26.0
	var rank_label: String = "%s  -  NAMED" % win_rank if win_rank == "S" else win_rank
	var rows: Array = [
		["SCORE", UiStyle.pad_score(win_score)],
		["DEATHS", str(win_deaths)],
		["TIME", _format_time(win_seconds)],
		["RANK", rank_label],
	]
	var ry: float = box.position.y + 34.0
	for row in rows:
		UiStyle.text(self, UiStyle.tracked(row[0]), Vector2(left_x, ry), 13, UiStyle.DIM)
		var value_colour: Color = UiStyle.GOLD if row[0] == "RANK" else UiStyle.PAPER
		UiStyle.text(self, row[1], Vector2(right_x - 300.0, ry), 20, value_colour,
			HORIZONTAL_ALIGNMENT_RIGHT, 300.0)
		ry += 26.0

	var pulse: float = 0.55 + 0.45 * sin(_time * 3.4)
	var prompt: Color = UiStyle.PAPER
	prompt.a = pulse
	UiStyle.text(self, UiStyle.tracked("PRESS R OR CLICK TO FIGHT AGAIN", 2), Vector2(340.0, 620.0), 18,
		prompt, HORIZONTAL_ALIGNMENT_CENTER, 600.0)


func _draw_dead() -> void:
	# A red wash, dark enough to read the text but not a full blackout, because
	# the arena reloads just under a second later.
	var wipe: float = clampf((dead_total - dead_restart_in) / maxf(death_wash_time, 0.01), 0.0, 1.0)
	var wash: float = 0.22 + 0.30 * wipe
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.32, 0.02, 0.03, wash * _fade), true)

	UiStyle.text(self, UiStyle.tracked("THE SAND TAKES YOU", 3), Vector2(240.0, 318.0), 40, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 800.0)
	UiStyle.text(self, "the melee goes on without you", Vector2(240.0, 354.0), 17, UiStyle.DIM,
		HORIZONTAL_ALIGNMENT_CENTER, 800.0)

	var seconds: String = "%.1f" % maxf(dead_restart_in, 0.0)
	UiStyle.text(self, UiStyle.tracked("%s  -  BACK IN %s" % [dead_room, seconds], 2),
		Vector2(240.0, 406.0), 15, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 800.0)

	var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
	var prompt: Color = UiStyle.PAPER
	prompt.a = pulse
	UiStyle.text(self, UiStyle.tracked("PRESS R TO RISE NOW", 2), Vector2(340.0, 454.0), 17, prompt,
		HORIZONTAL_ALIGNMENT_CENTER, 600.0)


# ---------------------------------------------------------------------------
# Small drawing helpers
# ---------------------------------------------------------------------------

func _full_backdrop(alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)),
		Color(UiStyle.INK.r, UiStyle.INK.g, UiStyle.INK.b, alpha * _fade), true)


## A bar showing every hue in order, left to right.
func _hue_strip(rect: Rect2) -> void:
	var segments: int = 240
	var step: float = rect.size.x / float(segments)
	for i in segments:
		var c: Color = ColorTheory.wheel(float(i) * (360.0 / float(segments)), 0.85, 1.0)
		draw_rect(Rect2(rect.position.x + float(i) * step, rect.position.y, step + 1.0, rect.size.y), c, true)


func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## Pick one of the kill flashes at random.
static func random_kill_flash() -> String:
	return KILL_FLASHES[randi() % KILL_FLASHES.size()]
