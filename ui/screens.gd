class_name Screens
extends Control
##
## SCREENS - every full-screen page that is not the game itself.
##
##   TITLE  the pitch, the controls, and a strip of the hue wheel
##   INTRO  the five story cards, two rhyming lines each, fading in one by one
##   WIN    the victory couplet plus the run's score and rank
##   DEAD   a 0.9 second "you are grey again" prompt before the room reloads
##
## TYPOGRAPHY: the story lines are drawn word by word so the LAST WORD of every
## couplet can be tinted with the colour it is talking about ("hue," is gold,
## "blue." is blue, "red," is red). That is the one bit of typographic styling
## that actually carries meaning, so it is worth the extra drawing code.

signal start_requested
signal intro_finished
signal restart_requested
signal title_requested

enum Mode { NONE, TITLE, INTRO, WIN, DEAD }

# --- the story, exactly as specified --------------------------------------
# "colour" is the tint of the final word of each line.
const CARDS: Array = [
	{
		"lines": ["The city once wore every hue,", "from morning gold to evening blue."],
		"colours": [Color(1.00, 0.78, 0.22), Color(0.30, 0.60, 1.00)],
	},
	{
		"lines": ["Then Collectors crept in at night", "and drank the rainbow out of sight."],
		"colours": [Color(0.38, 0.32, 0.88), Color(0.45, 0.46, 0.52)],
	},
	{
		"lines": ["Now streets lie gray and skies lie still,", "and no one dreams, and no one will."],
		"colours": [Color(0.55, 0.60, 0.72), Color(0.38, 0.38, 0.44)],
	},
	{
		"lines": ["But one small spark still holds the red,", "a stubborn flame that won't be dead."],
		"colours": [Color(1.00, 0.20, 0.20), Color(0.55, 0.10, 0.16)],
	},
	{
		"lines": ["So draw your blade and paint the floor,", "and take back what they stole before."],
		"colours": [Color(1.00, 0.45, 0.00), Color(1.00, 0.90, 0.45)],
	},
]

const TITLE_MAIN: String = "HUE MASSACRE"
const TITLE_SUB: String = "take back the bright, and paint the dark with light."

const WIN_LINES: Array = ["The last hue shatters, gold and green,", "the brightest dawn the world has seen."]
const WIN_COLOURS: Array = [Color(0.35, 1.00, 0.45), Color(1.00, 0.86, 0.35)]

## Kill flashes, chosen at random. Here so the wording lives in one place.
const KILL_FLASHES: Array = [
	"Blue breaks free.",
	"Red remembers, red returns.",
	"One by one, the colors burn.",
]

@export_group("Timing")
## Seconds each story card takes to fade in.
@export var card_fade_time: float = 0.7
## Seconds before a card can be advanced (stops accidental double clicks).
@export var card_min_time: float = 0.35

var mode: Mode = Mode.NONE

var card_index: int = 0
var _card_fade: float = 0.0
var _card_age: float = 0.0
var _fade: float = 0.0        # 0..1 overlay fade for TITLE / WIN
var _time: float = 0.0

# --- win stats ------------------------------------------------------------
var win_score: int = 0
var win_deaths: int = 0
var win_seconds: float = 0.0
var win_rank: String = "C"

# --- death info -----------------------------------------------------------
var dead_room: String = ""
var dead_restart_in: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if mode == Mode.NONE:
		return

	# Fade the overlay itself in.
	if mode == Mode.INTRO:
		_fade = minf(_fade + delta * 2.0, 1.0)
		_card_fade = minf(_card_fade + delta / maxf(card_fade_time, 0.01), 1.0)
		_card_age += delta
	else:
		_fade = minf(_fade + delta * 4.0, 1.0)

	if mode == Mode.DEAD:
		dead_restart_in = maxf(dead_restart_in - delta, 0.0)

	queue_redraw()


## True while a screen owns the input, so game.gd knows not to drive the player.
func is_blocking() -> bool:
	return mode != Mode.NONE


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func show_title() -> void:
	mode = Mode.TITLE
	visible = true
	_fade = 0.0


func show_intro() -> void:
	mode = Mode.INTRO
	visible = true
	card_index = 0
	_card_fade = 0.0
	_card_age = 0.0
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


func hide_all() -> void:
	mode = Mode.NONE
	visible = false
	_fade = 0.0


## The input handler for every screen. game.gd calls this on click / SPACE / R.
func advance() -> void:
	match mode:
		Mode.TITLE:
			start_requested.emit()
		Mode.INTRO:
			# A short lock-out stops one click from skipping two cards.
			if _card_age < card_min_time:
				return
			card_index += 1
			_card_fade = 0.0
			_card_age = 0.0
			if card_index >= CARDS.size():
				intro_finished.emit()
		Mode.WIN, Mode.DEAD:
			restart_requested.emit()
		_:
			pass


func back() -> void:
	if mode == Mode.INTRO:
		# Skipping the intro jumps straight into the game.
		intro_finished.emit()
	elif mode != Mode.NONE:
		title_requested.emit()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if mode == Mode.NONE:
		return
	match mode:
		Mode.TITLE:
			_draw_title()
		Mode.INTRO:
			_draw_intro()
		Mode.WIN:
			_draw_win()
		Mode.DEAD:
			_draw_dead()


func _draw_title() -> void:
	_full_backdrop(0.90)

	var cx: float = 640.0

	# A strip of the whole hue wheel sits above the title: the game's thesis.
	_hue_strip(Rect2(240.0, 168.0, 800.0, 8.0))
	UiStyle.text(self, "0 deg", Vector2(240.0, 196.0), 11, UiStyle.DIM)
	UiStyle.text(self, "360", Vector2(1000.0, 196.0), 11, UiStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 40.0)

	UiStyle.text(self, UiStyle.tracked(TITLE_MAIN, 4), Vector2(cx - 480.0, 272.0), 66, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)
	UiStyle.text(self, TITLE_SUB, Vector2(cx - 480.0, 306.0), 19, UiStyle.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	# --- controls block ---------------------------------------------------
	var box := Rect2(360.0, 356.0, 560.0, 196.0)
	UiStyle.panel(self, box, Color(1.0, 1.0, 1.0, 0.22))
	UiStyle.text(self, UiStyle.tracked("CONTROLS", 2), Vector2(box.position.x + 24.0, box.position.y + 34.0),
		14, UiStyle.GOLD)

	var rows: Array = [
		["WASD  /  ARROWS", "move"],
		["SPACE", "lunge-dash where you face"],
		["LEFT CLICK", "lunge-dash towards the cursor"],
		["R", "restart the room"],
		["ESC", "back to this screen"],
	]
	var y: float = box.position.y + 64.0
	for row in rows:
		UiStyle.text(self, row[0], Vector2(box.position.x + 24.0, y), 15, UiStyle.PAPER)
		UiStyle.text(self, row[1], Vector2(box.position.x + 250.0, y), 15, UiStyle.DIM)
		y += 26.0

	# --- the rule, in one line -------------------------------------------
	var rule: String = "A guard sees you only when your hue CONTRASTS with the colour of the floor you stand on."
	UiStyle.text(self, rule, Vector2(cx - 480.0, 596.0), 14, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	# --- prompt -----------------------------------------------------------
	var pulse: float = 0.55 + 0.45 * sin(_time * 3.4)
	var prompt: Color = UiStyle.PAPER
	prompt.a = pulse
	UiStyle.text(self, UiStyle.tracked("PRESS SPACE OR CLICK TO BEGIN", 2), Vector2(cx - 400.0, 648.0), 20,
		prompt, HORIZONTAL_ALIGNMENT_CENTER, 800.0)


func _draw_intro() -> void:
	_full_backdrop(0.96)

	var card: Dictionary = CARDS[clampi(card_index, 0, CARDS.size() - 1)]
	var lines: Array = card["lines"]
	var colours: Array = card["colours"]
	var a: float = _card_fade * _fade

	# Card number marker, e.g. "II / V".
	UiStyle.text(self, "%d / %d" % [card_index + 1, CARDS.size()], Vector2(640.0 - 60.0, 250.0), 13,
		Color(UiStyle.DIM.r, UiStyle.DIM.g, UiStyle.DIM.b, a), HORIZONTAL_ALIGNMENT_CENTER, 120.0)

	var y: float = 320.0
	for i in lines.size():
		var base: Color = UiStyle.PAPER
		base.a = a
		var tint: Color = colours[i]
		tint.a = a
		_draw_line_with_tinted_last_word(lines[i], 640.0, y, 34, base, tint)
		y += 56.0

	# Progress dots, one per card.
	var dots_y: float = 470.0
	var total: float = float(CARDS.size()) * 26.0
	var dx: float = 640.0 - total * 0.5 + 13.0
	for i in CARDS.size():
		var dot: Color = UiStyle.GOLD if i <= card_index else Color(1.0, 1.0, 1.0, 0.20)
		dot.a *= a
		draw_circle(Vector2(dx + float(i) * 26.0, dots_y), 5.0, dot)

	var pulse: float = 0.5 + 0.5 * sin(_time * 3.4)
	var prompt: Color = UiStyle.DIM
	prompt.a = a * pulse
	UiStyle.text(self, UiStyle.tracked("CLICK OR PRESS SPACE", 2), Vector2(640.0 - 300.0, 632.0), 15,
		prompt, HORIZONTAL_ALIGNMENT_CENTER, 600.0)


func _draw_win() -> void:
	_full_backdrop(0.94)

	# Everything on the win screen is tinted with the colour that just came back.
	UiStyle.text(self, UiStyle.tracked("COLOUR RETURNS", 4), Vector2(160.0, 232.0), 46, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	var y: float = 296.0
	for i in WIN_LINES.size():
		_draw_line_with_tinted_last_word(WIN_LINES[i], 640.0, y, 30, UiStyle.PAPER, WIN_COLOURS[i])
		y += 48.0

	_hue_strip(Rect2(340.0, 396.0, 600.0, 6.0))

	var box := Rect2(400.0, 436.0, 480.0, 128.0)
	UiStyle.panel(self, box, UiStyle.GOLD)
	var left_x: float = box.position.x + 26.0
	var right_x: float = box.end.x - 26.0
	var rows: Array = [
		["SCORE", UiStyle.pad_score(win_score)],
		["DEATHS", str(win_deaths)],
		["TIME", _format_time(win_seconds)],
		["RANK", win_rank],
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
	UiStyle.text(self, UiStyle.tracked("PRESS R OR CLICK TO PLAY AGAIN", 2), Vector2(340.0, 620.0), 18,
		prompt, HORIZONTAL_ALIGNMENT_CENTER, 600.0)
	UiStyle.text(self, "ESC returns to the title screen", Vector2(340.0, 648.0), 13, UiStyle.DIM,
		HORIZONTAL_ALIGNMENT_CENTER, 600.0)


func _draw_dead() -> void:
	# A quick red wash, dark enough to read the text but not a full blackout,
	# because the room reloads just under a second later.
	var wash: float = (1.0 - clampf(dead_restart_in / 0.9, 0.0, 1.0)) * 0.55 + 0.25
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.35, 0.02, 0.03, wash * _fade), true)

	UiStyle.text(self, UiStyle.tracked("YOU ARE GRAY AGAIN", 3), Vector2(240.0, 320.0), 40, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 800.0)
	UiStyle.text(self, "the colour drains back into the floor", Vector2(240.0, 356.0), 17, UiStyle.DIM,
		HORIZONTAL_ALIGNMENT_CENTER, 800.0)

	var seconds: String = "%.1f" % maxf(dead_restart_in, 0.0)
	UiStyle.text(self, UiStyle.tracked("%s  -  RESTARTING %s" % [dead_room, seconds], 2),
		Vector2(240.0, 408.0), 15, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 800.0)

	var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
	var prompt: Color = UiStyle.PAPER
	prompt.a = pulse
	UiStyle.text(self, UiStyle.tracked("PRESS R TO RETRY NOW", 2), Vector2(340.0, 456.0), 17, prompt,
		HORIZONTAL_ALIGNMENT_CENTER, 600.0)


# ---------------------------------------------------------------------------
# Small drawing helpers
# ---------------------------------------------------------------------------

func _full_backdrop(alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(UiStyle.INK.r, UiStyle.INK.g, UiStyle.INK.b, alpha * _fade), true)


## A bar showing every hue in order, left to right.
func _hue_strip(rect: Rect2) -> void:
	var segments: int = 240
	var step: float = rect.size.x / float(segments)
	for i in segments:
		var c: Color = ColorTheory.wheel(float(i) * (360.0 / float(segments)), 0.85, 1.0)
		draw_rect(Rect2(rect.position.x + float(i) * step, rect.position.y, step + 1.0, rect.size.y), c, true)


## Draw one line centred on `centre_x`, with only its LAST WORD tinted.
## Measuring the two halves is what keeps it properly centred.
func _draw_line_with_tinted_last_word(line: String, centre_x: float, y: float, size: int,
		base: Color, tint: Color) -> void:
	var f: Font = UiStyle.font()
	if f == null:
		return
	var split_at: int = line.rfind(" ")
	if split_at < 0:
		UiStyle.text(self, line, Vector2(centre_x - 480.0, y), size, tint, HORIZONTAL_ALIGNMENT_CENTER, 960.0)
		return

	var head: String = line.substr(0, split_at)
	var last: String = line.substr(split_at + 1)
	var head_w: float = f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var space_w: float = f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var last_w: float = f.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var start_x: float = centre_x - (head_w + space_w + last_w) * 0.5

	UiStyle.text(self, head, Vector2(start_x, y), size, base)
	UiStyle.text(self, last, Vector2(start_x + head_w + space_w, y), size, tint)


func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## Pick one of the three kill flashes at random.
static func random_kill_flash() -> String:
	return KILL_FLASHES[randi() % KILL_FLASHES.size()]
