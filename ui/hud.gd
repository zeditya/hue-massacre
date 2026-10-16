class_name Hud
extends Control
##
## HUD - everything the player is allowed to know, drawn as text and shapes.
##
## The star of the layout is the HUE WHEEL STRIP. It is a 0-360 degree slice of
## the colour wheel drawn as 360 one-pixel columns, and it teaches the whole
## assignment at a glance:
##
##    * a white tick shows YOUR current hue
##    * a second tick shows the BOSS's hue (only in the boss room)
##    * a shaded band shows where the boss's hue has to be for you to kill him,
##      which is your hue plus 180 degrees
##
## Watching those two ticks close in on each other is the boss fight, and it is
## complementary colour theory made visible instead of explained.
##
## All coordinates are hard-coded for a 1280x720 viewport. That is safe here
## because project.godot uses stretch mode "canvas_items" with aspect "keep",
## so the viewport is ALWAYS exactly 1280x720 no matter how the window is sized.

# --- layout constants (1280x720 authoring space) --------------------------
const TOP_LEFT_X: float = 24.0
const TOP_RIGHT_EDGE: float = 1256.0
const MARGIN: float = 24.0
const BAR_WIDTH: float = 340.0

# --- live state, written by game.gd every frame ---------------------------
var room_name: String = ""
var room_title: String = ""
var room_lesson: String = ""
var score: int = 0
var multiplier: int = 1
var combo_chain: int = 0
var combo_time_left: float = 0.0
var combo_window: float = 3.0
var deaths: int = 0
var guards_left: int = 0
var restore: float = 0.0

var player_colour: Color = Color(1.0, 1.0, 1.0)
var player_hidden: bool = false
var player_visibility: float = 1.0
## The blended floor colour under the player, written by game.gd. The combo
## readout is drawn in its complement, so the score demonstrates complementary
## contrast while you play rather than merely describing it.
var floor_colour: Color = ColorTheory.FLOOR_GREY

## Degrees of the boss's hue, or -1.0 when there is no boss in the room.
var boss_hue: float = -1.0
var boss_vulnerable: bool = false
var boss_tolerance_deg: float = 25.0

var spotted: bool = false

# --- transient messages ---------------------------------------------------
var flash_text: String = ""
var flash_colour: Color = UiStyle.PAPER
var flash_left: float = 0.0
var flash_total: float = 2.0

var banner_text: String = ""
var banner_sub: String = ""
var banner_colour: Color = UiStyle.GOLD
var banner_left: float = 0.0
var banner_total: float = 2.0

var hint_text: String = ""
var hint_left: float = 0.0
var hint_total: float = 8.0

## Speech bubbles pushed in by game.gd every frame. Each entry is a Dictionary:
## { "pos": Vector2, "text": String, "alpha": float, "colour": Color }. Drawn
## here (above the darkness layer) so a guard's line is readable even when the
## guard itself is outside the player's light cone.
var barks: Array = []

var _time: float = 0.0


func _ready() -> void:
	# Fill the whole viewport and never eat mouse clicks meant for the game.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	flash_left = maxf(flash_left - delta, 0.0)
	banner_left = maxf(banner_left - delta, 0.0)
	hint_left = maxf(hint_left - delta, 0.0)
	# The HUD changes every frame (timers, bars), so just redraw every frame.
	queue_redraw()


# ---------------------------------------------------------------------------
# Public message API
# ---------------------------------------------------------------------------

## Small one-line note in the centre, e.g. "Blue breaks free."
func show_flash(text: String, colour: Color, seconds: float = 2.2) -> void:
	flash_text = text
	flash_colour = colour
	flash_left = seconds
	flash_total = seconds


## Big announcement, e.g. "ROOM CLEARED" or "COMPLEMENT x3".
func show_banner(text: String, sub: String, colour: Color, seconds: float = 2.2) -> void:
	banner_text = text
	banner_sub = sub
	banner_colour = colour
	banner_left = seconds
	banner_total = seconds


## The room's teaching line, shown once when the room loads and then fading.
func show_hint(text: String, seconds: float = 9.0) -> void:
	hint_text = text
	hint_left = seconds
	hint_total = seconds


func clear_messages() -> void:
	flash_text = ""
	banner_text = ""
	banner_sub = ""
	hint_text = ""
	flash_left = 0.0
	banner_left = 0.0
	hint_left = 0.0


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_top_left()
	_draw_top_right()
	_draw_player_panel()
	_draw_barks()
	_draw_centre_messages()
	_draw_threat_vignette()


## Speech bubbles for any guard that is talking. Positioned in world space, so
## the world's shake offset is added by game.gd when it fills this list.
func _draw_barks() -> void:
	var f: Font = ThemeDB.fallback_font
	if f == null:
		return
	for entry in barks:
		var text: String = str(entry.get("text", ""))
		if text == "":
			continue
		var alpha: float = clampf(float(entry.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = entry.get("pos", Vector2.ZERO)
		var colour: Color = entry.get("colour", UiStyle.PAPER)
		var size: int = 13
		var text_w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pad: float = 9.0
		var bubble := Rect2(pos.x - text_w * 0.5 - pad, pos.y - 66.0, text_w + pad * 2.0, 24.0)
		draw_rect(bubble, Color(0.02, 0.02, 0.04, 0.88 * alpha), true)
		draw_rect(bubble, Color(colour.r, colour.g, colour.b, 0.95 * alpha), false, 1.5)
		# A little tail pointing down at the speaker.
		draw_colored_polygon(PackedVector2Array([
			Vector2(pos.x - 5.0, bubble.end.y),
			Vector2(pos.x + 5.0, bubble.end.y),
			Vector2(pos.x, bubble.end.y + 8.0),
		]), Color(0.02, 0.02, 0.04, 0.88 * alpha))
		draw_string(f, Vector2(bubble.position.x + pad, bubble.position.y + 16.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 1.0, 1.0, alpha))


func _draw_top_left() -> void:
	# --- room identity ----------------------------------------------------
	UiStyle.text(self, UiStyle.tracked(room_name), Vector2(TOP_LEFT_X, 30.0), 21, UiStyle.GOLD)
	UiStyle.text(self, UiStyle.tracked(room_title, 1), Vector2(TOP_LEFT_X, 50.0), 13, UiStyle.PAPER)
	if room_lesson != "":
		UiStyle.text(self, room_lesson, Vector2(TOP_LEFT_X, 66.0), 12, UiStyle.DIM)

	# --- the hue wheel strip ---------------------------------------------
	var wheel_rect := Rect2(TOP_LEFT_X, 78.0, BAR_WIDTH, 16.0)
	_draw_wheel_strip(wheel_rect)
	UiStyle.text(self, UiStyle.tracked("HUE WHEEL"), Vector2(TOP_LEFT_X + BAR_WIDTH + 12.0, 91.0), 11, UiStyle.DIM)

	# --- colour restored --------------------------------------------------
	var restore_rect := Rect2(TOP_LEFT_X, 108.0, BAR_WIDTH, 14.0)
	# The bar's own colour rides the wheel as the room fills back up, so the
	# progress indicator is itself part of the colour theory.
	var fill: Color = ColorTheory.wheel(120.0 * restore + 30.0, 0.85, 1.0)
	UiStyle.bar(self, restore_rect, restore, fill)
	UiStyle.text(self, "COLOUR RESTORED  %d%%" % int(round(restore * 100.0)),
		Vector2(TOP_LEFT_X, 138.0), 12, UiStyle.DIM)


func _draw_top_right() -> void:
	var box_x: float = TOP_RIGHT_EDGE - 356.0
	UiStyle.text(self, "SCORE", Vector2(box_x, 24.0), 12, UiStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 356.0)
	var score_colour: Color = UiStyle.GOLD if multiplier > 1 else UiStyle.PAPER
	UiStyle.text(self, UiStyle.tracked(UiStyle.pad_score(score), 1), Vector2(box_x, 52.0), 28, score_colour,
		HORIZONTAL_ALIGNMENT_RIGHT, 356.0)

	# Multiplier plus the shrinking window in which the next complement counts.
	# Drawn in the complement of the floor colour under the player, which is
	# complementary contrast used as a live readout.
	var mult_text: String = "MULTIPLIER  x%d" % multiplier
	var mult_colour: Color = ColorTheory.complement(floor_colour) if multiplier > 1 else UiStyle.DIM
	UiStyle.text(self, UiStyle.tracked(mult_text), Vector2(box_x, 76.0), 13, mult_colour,
		HORIZONTAL_ALIGNMENT_RIGHT, 356.0)
	if combo_time_left > 0.0 and multiplier > 1:
		var ratio: float = clampf(combo_time_left / maxf(combo_window, 0.01), 0.0, 1.0)
		var bar_rect := Rect2(TOP_RIGHT_EDGE - 176.0, 84.0, 176.0, 6.0)
		UiStyle.bar(self, bar_rect, ratio, mult_colour)

	# Status counts.
	var status: String = "GUARDS LEFT %d   /   DEATHS %d" % [guards_left, deaths]
	UiStyle.text(self, status, Vector2(box_x, 112.0), 13, UiStyle.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 356.0)


func _draw_player_panel() -> void:
	var panel_rect := Rect2(12.0, 626.0, 212.0, 70.0)
	# The panel border takes the player's own hue: a constant, readable reminder
	# of what colour you currently are.
	UiStyle.panel(self, panel_rect, player_colour)
	UiStyle.swatch(self, Rect2(22.0, 636.0, 50.0, 50.0), player_colour)

	UiStyle.text(self, UiStyle.tracked("YOUR HUE"), Vector2(82.0, 646.0), 10, UiStyle.DIM)
	UiStyle.text(self, "%s %d" % [ColorTheory.color_name(player_colour), ColorTheory.hue_degrees(player_colour)],
		Vector2(82.0, 666.0), 17, UiStyle.PAPER)
	if player_hidden:
		UiStyle.text(self, "CAMOUFLAGED", Vector2(82.0, 684.0), 11, UiStyle.SAFE)
	else:
		UiStyle.text(self, "CONTRAST %d%%" % int(round(player_visibility * 100.0)),
			Vector2(82.0, 684.0), 11, UiStyle.ALERT.lerp(UiStyle.SAFE, 1.0 - player_visibility))


## The 0-360 degree hue bar. Drawn as 360 thin columns: simple, exact, and it
## cannot get out of sync with the maths because it uses the same wheel()
## function the game itself uses.
func _draw_wheel_strip(rect: Rect2) -> void:
	var step: float = rect.size.x / 360.0
	for i in 360:
		var c: Color = ColorTheory.wheel(float(i), 0.80, 1.0)
		draw_rect(Rect2(rect.position.x + float(i) * step, rect.position.y, step + 1.0, rect.size.y), c, true)

	# The kill window: the boss must be within +/- tolerance of your complement.
	if boss_hue >= 0.0:
		var centre: float = fposmod(float(ColorTheory.hue_degrees(player_colour)) + 180.0, 360.0)
		var from: float = centre - boss_tolerance_deg
		var span: float = boss_tolerance_deg * 2.0
		var band: Color = Color(1.0, 1.0, 1.0, 0.55) if boss_vulnerable else Color(0.0, 0.0, 0.0, 0.45)
		for i in 360:
			if fposmod(float(i) - from, 360.0) <= span:
				draw_rect(Rect2(rect.position.x + float(i) * step, rect.position.y, step + 1.0, rect.size.y), band, true)

	# The player's hue marker: a bright white tick.
	var px: float = rect.position.x + (float(ColorTheory.hue_degrees(player_colour)) / 360.0) * rect.size.x
	draw_rect(Rect2(px - 1.5, rect.position.y - 7.0, 3.0, rect.size.y + 14.0), Color(1.0, 1.0, 1.0, 0.95), true)

	# The boss's hue marker: a black chevron so it is never confused with yours.
	if boss_hue >= 0.0:
		var bx: float = rect.position.x + (fposmod(boss_hue, 360.0) / 360.0) * rect.size.x
		var marker: Color = UiStyle.PAPER if boss_vulnerable else Color(0.05, 0.05, 0.07, 0.95)
		draw_rect(Rect2(bx - 2.0, rect.position.y - 11.0, 4.0, rect.size.y + 22.0), marker, true)
		if boss_vulnerable:
			draw_arc(Vector2(bx, rect.position.y + rect.size.y * 0.5), 15.0, 0.0, TAU, 20, UiStyle.PAPER, 2.0, true)

	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.35), false, 1.0)
	if boss_vulnerable:
		draw_rect(rect.grow(3.0), UiStyle.PAPER, false, 2.0)


func _draw_centre_messages() -> void:
	var width: float = 900.0
	var x: float = (1280.0 - width) * 0.5

	# Room hints fade out slowly - long enough to read while sneaking.
	if hint_left > 0.0 and hint_text != "":
		var a: float = clampf(hint_left / maxf(hint_total * 0.35, 0.01), 0.0, 1.0)
		var colour := UiStyle.PAPER
		colour.a = a
		UiStyle.paragraph(self, hint_text, Vector2(x, 560.0), width, 17, colour, 4)

	# The big banner: room cleared, combo, victory.
	if banner_left > 0.0 and banner_text != "":
		var t: float = clampf(banner_left / maxf(banner_total * 0.25, 0.01), 0.0, 1.0)
		var pulse: float = 1.0 + 0.03 * sin(_time * 10.0)
		var text_colour: Color = banner_colour
		text_colour.a = t
		UiStyle.text(self, UiStyle.tracked(banner_text, 2), Vector2(x, 300.0), int(38.0 * pulse),
			text_colour, HORIZONTAL_ALIGNMENT_CENTER, width)
		if banner_sub != "":
			var sub_colour: Color = UiStyle.PAPER
			sub_colour.a = t
			UiStyle.text(self, banner_sub, Vector2(x, 330.0), 15, sub_colour, HORIZONTAL_ALIGNMENT_CENTER, width)

	# The kill flash line.
	if flash_left > 0.0 and flash_text != "":
		var ft: float = clampf(flash_left / maxf(flash_total * 0.3, 0.01), 0.0, 1.0)
		var flash: Color = flash_colour
		flash.a = ft
		UiStyle.text(self, flash_text, Vector2(x, 372.0), 20, flash, HORIZONTAL_ALIGNMENT_CENTER, width)


## A red haze around the edges whenever a guard is actively hunting you.
func _draw_threat_vignette() -> void:
	if spotted:
		var pulse: float = 0.35 + 0.25 * sin(_time * 9.0)
		var c: Color = Color(UiStyle.ALERT.r, UiStyle.ALERT.g, UiStyle.ALERT.b, 0.10 * pulse)
		var thickness: float = 22.0
		draw_rect(Rect2(0.0, 0.0, 1280.0, thickness), c, true)
		draw_rect(Rect2(0.0, 720.0 - thickness, 1280.0, thickness), c, true)
		draw_rect(Rect2(0.0, 0.0, thickness, 720.0), c, true)
		draw_rect(Rect2(1280.0 - thickness, 0.0, thickness, 720.0), c, true)
		UiStyle.text(self, UiStyle.tracked("SPOTTED", 2), Vector2(340.0, 176.0), 22, UiStyle.ALERT,
			HORIZONTAL_ALIGNMENT_CENTER, 600.0)

	# Boss window prompt: the single most important instruction in the fight.
	if boss_hue >= 0.0 and boss_vulnerable:
		var pulse2: float = 0.65 + 0.35 * sin(_time * 16.0)
		var strike: Color = UiStyle.PAPER
		strike.a = pulse2
		UiStyle.text(self, UiStyle.tracked("STRIKE NOW", 2), Vector2(340.0, 176.0), 24, strike,
			HORIZONTAL_ALIGNMENT_CENTER, 600.0)
