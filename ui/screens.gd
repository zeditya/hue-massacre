class_name Screens
extends Control
##
## SCREENS - every full-screen page that is not the game itself.
##
##   TITLE  the start menu: START GAME / HOW TO PLAY / QUIT, plus a strip of
##          the hue wheel
##   HOWTO  the controls and the one rule, so the menu can stay clean
##   STORY  one scene: the spark standing in the grey city, deciding to act
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
signal quit_requested
## Pause-menu choices.
signal resume_requested
signal room_restart_requested

enum Mode { NONE, TITLE, HOWTO, STORY, PAUSE, INTRO, WIN, DEAD }

## The start menu, in order. Kept as data so the drawing and the input handling
## can never disagree about how many items there are.
const MENU_ITEMS: Array = ["START GAME", "HOW TO PLAY", "QUIT"]

## The pause menu, in order.
const PAUSE_ITEMS: Array = ["RESUME", "RESTART ROOM", "QUIT TO MENU"]

## The single line of narration on the story scene, before the rhyme cards.
const STORY_LINE: String = "We have to bring the colours back."
const STORY_SUB: String = "- the last spark, standing in the grey"

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

## Which start-menu row is highlighted.
var menu_index: int = 0
## Which pause-menu row is highlighted.
var pause_index: int = 0
## 0..1 fade for the story scene's narration line.
var _story_reveal: float = 0.0

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

	# Fade the overlay itself in.
	if mode == Mode.INTRO:
		_fade = minf(_fade + delta * 2.0, 1.0)
		_card_fade = minf(_card_fade + delta / maxf(card_fade_time, 0.01), 1.0)
		_card_age += delta
	elif mode == Mode.STORY:
		_fade = minf(_fade + delta * 1.6, 1.0)
		# The narration arrives a beat after the scene, like a held breath.
		_story_reveal = minf(_story_reveal + delta * 0.7, 1.0)
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
	menu_index = 0
	_fade = 0.0


## The story scene, a single held shot before the rhyme cards.
func show_story() -> void:
	mode = Mode.STORY
	visible = true
	_story_reveal = 0.0
	_fade = 0.0


func show_howto() -> void:
	mode = Mode.HOWTO
	visible = true
	_fade = 0.0


func show_pause() -> void:
	mode = Mode.PAUSE
	visible = true
	pause_index = 0
	_fade = 0.0


func show_intro() -> void:
	mode = Mode.INTRO
	visible = true
	card_index = 0
	_card_fade = 0.0
	_card_age = 0.0
	_fade = 0.0


## Move the highlighted row by `dir` (-1 up, +1 down), wrapping round. Works for
## both the start menu and the pause menu.
func menu_move(dir: int) -> void:
	match mode:
		Mode.TITLE:
			menu_index = posmod(menu_index + dir, MENU_ITEMS.size())
		Mode.PAUSE:
			pause_index = posmod(pause_index + dir, PAUSE_ITEMS.size())
		_:
			pass


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


## The input handler for every screen. game.gd calls this on click / SPACE / R.
func advance() -> void:
	match mode:
		Mode.TITLE:
			# The menu row decides what SPACE / click does.
			match menu_index:
				0:
					start_requested.emit()
				1:
					show_howto()
				2:
					quit_requested.emit()
		Mode.HOWTO:
			show_title()
		Mode.PAUSE:
			match pause_index:
				0:
					resume_requested.emit()
				1:
					room_restart_requested.emit()
				2:
					title_requested.emit()
		Mode.STORY:
			show_intro()
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
	# ESC always steps back one page, and from the menu it leaves the game.
	# HOWTO is a sub-page of the title, so it can return without asking the game
	# controller to rebuild anything; the others need a clean start_title().
	match mode:
		Mode.HOWTO:
			show_title()
		Mode.PAUSE:
			resume_requested.emit()
		Mode.STORY, Mode.INTRO, Mode.WIN, Mode.DEAD:
			title_requested.emit()
		Mode.TITLE:
			quit_requested.emit()
		_:
			pass


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if mode == Mode.NONE:
		return
	match mode:
		Mode.TITLE:
			_draw_title()
		Mode.HOWTO:
			_draw_howto()
		Mode.PAUSE:
			_draw_pause()
		Mode.STORY:
			_draw_story()
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
	_hue_strip(Rect2(240.0, 150.0, 800.0, 8.0))
	UiStyle.text(self, "0 deg", Vector2(240.0, 178.0), 11, UiStyle.DIM)
	UiStyle.text(self, "360", Vector2(1000.0, 178.0), 11, UiStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 40.0)

	UiStyle.text(self, UiStyle.tracked(TITLE_MAIN, 4), Vector2(cx - 480.0, 262.0), 66, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)
	UiStyle.text(self, TITLE_SUB, Vector2(cx - 480.0, 296.0), 19, UiStyle.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	# --- the menu ---------------------------------------------------------
	# A proper list with a moving highlight, rather than a "press SPACE" wall of
	# text. The selected row gets the gold arrow and the brighter ink.
	var item_h: float = 46.0
	var menu_w: float = 380.0
	var menu_x: float = cx - menu_w * 0.5
	var menu_y: float = 372.0
	var panel := Rect2(menu_x - 22.0, menu_y - 26.0, menu_w + 44.0, float(MENU_ITEMS.size()) * item_h + 40.0)
	UiStyle.panel(self, panel, Color(1.0, 1.0, 1.0, 0.20))

	for i in MENU_ITEMS.size():
		var y: float = menu_y + float(i) * item_h
		var selected: bool = i == menu_index
		var label: String = str(MENU_ITEMS[i])
		if selected:
			var pulse: float = 0.75 + 0.25 * sin(_time * 4.0)
			draw_rect(Rect2(menu_x - 12.0, y - 24.0, menu_w + 24.0, 36.0),
				Color(UiStyle.GOLD.r, UiStyle.GOLD.g, UiStyle.GOLD.b, 0.10 * pulse), true)
			UiStyle.text(self, ">", Vector2(menu_x - 6.0, y), 24, UiStyle.GOLD)
			UiStyle.text(self, UiStyle.tracked(label, 2), Vector2(menu_x + 24.0, y), 26, UiStyle.GOLD)
		else:
			UiStyle.text(self, UiStyle.tracked(label, 2), Vector2(menu_x + 24.0, y), 24,
				Color(UiStyle.DIM.r, UiStyle.DIM.g, UiStyle.DIM.b, 0.9))

	# --- the rule, in one line -------------------------------------------
	var rule: String = "A guard sees you only when your hue CONTRASTS with the colour of the floor you stand on."
	UiStyle.text(self, rule, Vector2(cx - 480.0, 618.0), 14, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	# --- prompt -----------------------------------------------------------
	var pulse2: float = 0.55 + 0.45 * sin(_time * 3.4)
	var prompt: Color = UiStyle.PAPER
	prompt.a = pulse2
	UiStyle.text(self, UiStyle.tracked("W / S TO CHOOSE   -   SPACE OR CLICK TO SELECT", 1), Vector2(cx - 440.0, 662.0),
		15, prompt, HORIZONTAL_ALIGNMENT_CENTER, 880.0)


func _draw_howto() -> void:
	_full_backdrop(0.94)

	var cx: float = 640.0
	UiStyle.text(self, UiStyle.tracked("HOW TO PLAY", 3), Vector2(cx - 480.0, 130.0), 40, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)
	_hue_strip(Rect2(340.0, 150.0, 600.0, 6.0))

	# --- controls ---------------------------------------------------------
	var box := Rect2(210.0, 184.0, 400.0, 250.0)
	UiStyle.panel(self, box, UiStyle.GOLD)
	UiStyle.text(self, UiStyle.tracked("CONTROLS", 2), Vector2(box.position.x + 22.0, box.position.y + 32.0),
		14, UiStyle.GOLD)
	var rows: Array = [
		["W A S D / ARROWS", "move - and point your light"],
		["SPACE / CLICK", "lunge-dash the way you steer"],
		["R", "restart the room"],
		["ESC", "back to the menu"],
	]
	var y: float = box.position.y + 66.0
	for row in rows:
		UiStyle.text(self, row[0], Vector2(box.position.x + 22.0, y), 14, UiStyle.PAPER)
		UiStyle.text(self, row[1], Vector2(box.position.x + 22.0, y + 18.0), 13, UiStyle.DIM)
		y += 46.0

	# --- the rules --------------------------------------------------------
	var box2 := Rect2(670.0, 184.0, 400.0, 250.0)
	UiStyle.panel(self, box2, Color(1.0, 1.0, 1.0, 0.22))
	UiStyle.text(self, UiStyle.tracked("THE RULES", 2), Vector2(box2.position.x + 22.0, box2.position.y + 32.0),
		14, UiStyle.GOLD)
	var rules: Array = [
		"Guards kill on touch. So does your blade.",
		"You are hidden only where the floor",
		"matches your hue - within 26 deg.",
		"Complements (180 deg apart) cancel:",
		"kill one, then its opposite, to combo.",
	]
	var ry: float = box2.position.y + 62.0
	for line in rules:
		UiStyle.text(self, line, Vector2(box2.position.x + 22.0, ry), 14, UiStyle.PAPER)
		ry += 26.0

	# --- the loop, in one line -------------------------------------------
	UiStyle.text(self,
		"watch the cone  ->  lunge  ->  take the colour  ->  hide in your own paint  ->  repeat",
		Vector2(cx - 480.0, 480.0), 15, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	UiStyle.text(self, "Motes drifting in the rooms hand you a whole colour for free;",
		Vector2(cx - 480.0, 516.0), 14, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, 960.0)
	UiStyle.text(self, "the gold-wheel boss only dies under his complement.",
		Vector2(cx - 480.0, 538.0), 14, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	var pulse: float = 0.55 + 0.45 * sin(_time * 3.4)
	var prompt: Color = UiStyle.PAPER
	prompt.a = pulse
	UiStyle.text(self, UiStyle.tracked("PRESS SPACE OR ESC TO GO BACK", 2), Vector2(cx - 400.0, 640.0), 18,
		prompt, HORIZONTAL_ALIGNMENT_CENTER, 800.0)


func _draw_pause() -> void:
	# Dim the frozen game rather than hiding it, so you keep your bearings.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.02, 0.02, 0.04, 0.82 * _fade), true)

	var cx: float = 640.0
	UiStyle.text(self, UiStyle.tracked("PAUSED", 4), Vector2(cx - 480.0, 250.0), 44, UiStyle.PAPER,
		HORIZONTAL_ALIGNMENT_CENTER, 960.0)

	var item_h: float = 44.0
	var menu_w: float = 360.0
	var menu_x: float = cx - menu_w * 0.5
	var menu_y: float = 340.0
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
		Vector2(cx - 440.0, 628.0), 14, UiStyle.DIM, HORIZONTAL_ALIGNMENT_CENTER, 880.0)


## The story scene: one held shot of the spark in the grey city, deciding.
func _draw_story() -> void:
	_full_backdrop(1.0)

	var cx: float = 640.0
	var a: float = _fade

	# --- the grey city ----------------------------------------------------
	# A dead sky, a band of near-black buildings at different heights, and a
	# strip of cracked ground. All of it colourless except one red figure.
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.07, 0.07, 0.095, a), true)
	draw_rect(Rect2(0.0, 430.0, 1280.0, 290.0), Color(0.045, 0.045, 0.06, a), true)
	var buildings: Array = [
		Rect2(40.0, 250.0, 130.0, 180.0), Rect2(190.0, 180.0, 90.0, 250.0),
		Rect2(300.0, 300.0, 150.0, 130.0), Rect2(470.0, 220.0, 110.0, 210.0),
		Rect2(600.0, 160.0, 120.0, 270.0), Rect2(740.0, 260.0, 140.0, 170.0),
		Rect2(900.0, 200.0, 100.0, 230.0), Rect2(1020.0, 300.0, 200.0, 130.0),
	]
	var shades: Array = [0.085, 0.10, 0.075, 0.11, 0.07, 0.095, 0.08, 0.105]
	for i in buildings.size():
		var s: float = shades[i]
		draw_rect(buildings[i], Color(s, s, s + 0.01, a), true)

	# A few dead windows, so the buildings read as a city rather than blocks.
	for b in [buildings[0], buildings[3], buildings[5], buildings[7]]:
		var r: Rect2 = b
		var wx: float = r.position.x + 22.0
		while wx < r.end.x - 16.0:
			var wy: float = r.position.y + 24.0
			while wy < r.end.y - 16.0:
				draw_rect(Rect2(wx, wy, 10.0, 14.0), Color(0.16, 0.16, 0.20, a * 0.8), true)
				wy += 34.0
			wx += 34.0

	# --- the spark --------------------------------------------------------
	# The one figure in colour, drawn from the same sheet the game uses and
	# tinted red so it is unmistakably the thing that still holds the red.
	var sf: SpriteFrames = SpriteBank.adventurer()
	if sf != null and sf.has_animation("idle_down"):
		var tex: Texture2D = sf.get_frame_texture("idle_down", 0)
		if tex != null:
			var w: float = SpriteBank.FRAME_W * 3.0
			var h: float = SpriteBank.FRAME_H * 3.0
			var glow: float = 0.5 + 0.5 * sin(_time * 2.2)
			draw_circle(Vector2(cx, 520.0), 90.0 + 12.0 * glow, Color(1.0, 0.25, 0.2, 0.10 * a))
			draw_texture_rect(tex, Rect2(cx - w * 0.5, 520.0 - h * 0.5, w, h), false,
				Color(1.0, 0.35, 0.3, a))

	# --- the narration ----------------------------------------------------
	# Fades in a beat after the scene, so it lands like a thought.
	var ra: float = _story_reveal * a
	UiStyle.text(self, STORY_LINE, Vector2(cx - 560.0, 250.0), 40,
		Color(1.0, 0.86, 0.5, ra), HORIZONTAL_ALIGNMENT_CENTER, 1120.0)
	UiStyle.text(self, STORY_SUB, Vector2(cx - 560.0, 292.0), 18,
		Color(UiStyle.DIM.r, UiStyle.DIM.g, UiStyle.DIM.b, ra), HORIZONTAL_ALIGNMENT_CENTER, 1120.0)

	var pulse: float = 0.65 + 0.35 * sin(_time * 3.4)
	var prompt: Color = UiStyle.PAPER
	prompt.a = a * pulse * maxf(_story_reveal, 0.3)
	UiStyle.text(self, UiStyle.tracked("CLICK OR PRESS SPACE", 2), Vector2(cx - 300.0, 664.0), 16,
		prompt, HORIZONTAL_ALIGNMENT_CENTER, 600.0)


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
	var wash: float = (1.0 - clampf(dead_restart_in / dead_total, 0.0, 1.0)) * 0.55 + 0.25
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
