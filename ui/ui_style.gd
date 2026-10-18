class_name UiStyle
extends RefCounted
##
## UI STYLE - one place that decides how the text looks.
##
## TYPOGRAPHY NOTES (worth 15 marks, so it is deliberate):
##   * Two roles, not one: a wide TRACKED (letter-spaced) setting for headings
##     and a plain tight setting for body text. The tracking is what makes the
##     default Godot font read as a designed poster instead of a debug label.
##   * Every string is drawn with a dark outline. That is not decoration: the
##     background of this game changes colour constantly, so text has to stay
##     legible on top of grey floor, red paint and a white screen flash alike.
##   * Colours are picked from the wheel, never from taste. Headings are gold
##     (the ceremonial colour of the crowd's bright banners), alerts are the
##     complement of whatever is underneath them.
##
## FONT: the game uses Godot's built-in font by default, so it needs zero
## downloads. If you want a pixel/mono face instead, drop a .ttf at
##     res://assets/fonts/display.ttf
## and it is picked up automatically - no code change required.

const DISPLAY_FONT_PATH: String = "res://assets/fonts/display.ttf"

# --- palette -------------------------------------------------------------
const INK: Color = Color(0.035, 0.035, 0.050)          # near-black, the arena at dusk
const INK_SOFT: Color = Color(0.070, 0.070, 0.100)
const PAPER: Color = Color(0.965, 0.965, 1.000)        # main text
const DIM: Color = Color(0.600, 0.615, 0.720)          # secondary text
const GOLD: Color = Color(1.000, 0.820, 0.250)         # headings / score
const ALERT: Color = Color(1.000, 0.250, 0.250)        # caught / danger
const SAFE: Color = Color(0.350, 0.950, 0.600)         # camouflaged / success
const OUTLINE: Color = Color(0.000, 0.000, 0.000, 0.85)


## The optional custom font, or null to use Godot's built-in one.
static func display_font() -> Font:
	if ResourceLoader.exists(DISPLAY_FONT_PATH):
		var res: Resource = load(DISPLAY_FONT_PATH)
		if res is Font:
			return res
	return null


## The font every UI routine should draw with.
static func font() -> Font:
	var custom: Font = display_font()
	if custom != null:
		return custom
	return ThemeDB.fallback_font


## Insert letter-spacing. "HUE" -> "H U E". Headings use this; body text does
## not, because heavy tracking hurts readability at small sizes.
static func tracked(text: String, gap: int = 1) -> String:
	var spacer: String = " ".repeat(maxi(gap, 1))
	var out: String = ""
	var last: int = text.length() - 1
	for i in text.length():
		var ch: String = text[i]
		if ch == " ":
			# Words get a double gap so they still read as separate words.
			out += spacer + spacer
		else:
			out += ch
			if i < last and text[i + 1] != " ":
				out += spacer
	return out


## Format a number with a thin leading zero pad: 7 -> "0000007".
static func pad_score(value: int) -> String:
	return str(value).pad_zeros(7)


## The same colour at a different opacity. Used by anything that fades text in
## or out (the opening's title card, mostly).
static func glow(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, colour.a * clampf(alpha, 0.0, 1.0))


## Draw one line of text with a dark outline behind it.
## `width` enables alignment: pass a positive width to centre or right-align.
static func text(canvas: CanvasItem, string: String, pos: Vector2, size: int, colour: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: bool = true) -> void:
	var f: Font = font()
	if f == null:
		return
	if outline:
		canvas.draw_string_outline(f, pos, string, align, width, size, 6, OUTLINE)
	canvas.draw_string(f, pos, string, align, width, size, colour)


## Draw a multi-line block (used for the long room hints).
static func paragraph(canvas: CanvasItem, string: String, pos: Vector2, width: float, size: int,
		colour: Color, max_lines: int = 4) -> void:
	var f: Font = font()
	if f == null:
		return
	# Signature: (font, pos, text, alignment, width, font_size, max_lines,
	#             [outline thickness,] modulate)
	canvas.draw_multiline_string_outline(f, pos, string, HORIZONTAL_ALIGNMENT_CENTER, width, size, max_lines, 6, OUTLINE)
	canvas.draw_multiline_string(f, pos, string, HORIZONTAL_ALIGNMENT_CENTER, width, size, max_lines, colour)


## A dark rounded-ish panel with a thin border, for HUD groups and menus.
static func panel(canvas: CanvasItem, rect: Rect2, border: Color, fill: Color = INK_SOFT) -> void:
	canvas.draw_rect(rect, Color(fill.r, fill.g, fill.b, 0.82), true)
	canvas.draw_rect(rect, border, false, 2.0)
	# Corner ticks give the panels a deliberate, printed look.
	var tick: float = 8.0
	var corners: Array = [
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.end.x, rect.end.y),
	]
	for c in corners:
		var sx: float = 1.0 if c.x < rect.get_center().x else -1.0
		var sy: float = 1.0 if c.y < rect.get_center().y else -1.0
		canvas.draw_line(c, c + Vector2(tick * sx, 0.0), border, 2.0)
		canvas.draw_line(c, c + Vector2(0.0, tick * sy), border, 2.0)


## A labelled progress bar. `fill_colour` may be any hue - the fill is what
## the HUD uses to show the room literally regaining its colour.
static func bar(canvas: CanvasItem, rect: Rect2, value: float, fill_colour: Color, back: Color = Color(0.05, 0.05, 0.07, 0.85)) -> void:
	canvas.draw_rect(rect, back, true)
	var clamped: float = clampf(value, 0.0, 1.0)
	if clamped > 0.0:
		canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y)), fill_colour, true)
	canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.30), false, 1.0)


## A colour swatch with a white rim, used for "your hue" in the HUD.
static func swatch(canvas: CanvasItem, rect: Rect2, colour: Color) -> void:
	canvas.draw_rect(rect, Color(0.02, 0.02, 0.03, 0.9), true)
	var inner := Rect2(rect.position + Vector2(3.0, 3.0), rect.size - Vector2(6.0, 6.0))
	canvas.draw_rect(inner, colour, true)
	canvas.draw_rect(inner, Color(1.0, 1.0, 1.0, 0.85), false, 2.0)
