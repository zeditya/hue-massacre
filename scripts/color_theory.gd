class_name ColorTheory
extends RefCounted
##
## COLOUR THEORY - the heart of the whole game.
##
## Every mechanic in Hue Massacre is one idea from colour theory:
##
##   HUE DIFFERENCE (hue_gap)
##      "Does the floor colour match me?"  A matching floor hides you, a
##      contrasting floor exposes you. This is *simultaneous contrast*.
##
##   COMPLEMENTS (is_complement)
##      Two hues ~180 degrees apart cancel each other out. They drive the
##      score combo AND the boss kill window.
##
##   MIXING (mix / blend)
##      Absorbing a guard's colour and averaging overlapping paint both happen
##      on the hue wheel, not in RGB, so red + blue gives violet instead of mud.
##
##   NAMING (color_name)
##      The HUD prints the human name of a hue so the player learns the wheel.
##
## Everything here is `static`, so you never have to create a node to use it.
## Call it like: ColorTheory.is_complement(Color.RED, Color.CYAN, 30.0)

## Below this saturation a colour reads as "grey" (no usable hue). The drained
## world floor sits well under it, the spark and the guards sit well above it.
const GREY_SATURATION: float = 0.18

## The drained world floor colour. Deliberately desaturated AND mid-value so
## that a coloured player always pops against it.
const FLOOR_GREY: Color = Color(0.30, 0.30, 0.33)

## Names of the 12 standard hues, 30 degrees apart starting at red.
## Used by the HUD so the player can literally read the wheel.
const HUE_NAMES: PackedStringArray = [
	"RED", "ORANGE", "YELLOW", "CHARTREUSE",
	"GREEN", "SPRING", "CYAN", "AZURE",
	"BLUE", "INDIGO", "VIOLET", "ROSE",
]


# ---------------------------------------------------------------------------
# HUE MATHS
# ---------------------------------------------------------------------------

## Shortest distance between two angles in degrees, always 0..180.
## 350 and 10 are 20 apart (not 340) because the colour wheel is a circle.
static func hue_gap(a_deg: float, b_deg: float) -> float:
	return absf(fposmod(a_deg - b_deg + 180.0, 360.0) - 180.0)


## Same thing but taking two Colors and reading their hue.
static func hue_gap_color(a: Color, b: Color) -> float:
	return hue_gap(a.h * 360.0, b.h * 360.0)


## True when two colours sit roughly opposite each other on the wheel.
## `tol_deg` is the half-width of the window, so 30 means "180 +/- 30".
static func is_complement(a: Color, b: Color, tol_deg: float) -> bool:
	return absf(hue_gap_color(a, b) - 180.0) <= tol_deg


## The complement of a colour: its hue rotated 180 degrees.
static func complement(c: Color) -> Color:
	return Color.from_hsv(fposmod(c.h + 0.5, 1.0), maxf(c.s, 0.7), maxf(c.v, 0.85), 1.0)


## True when this colour carries no usable hue (white, grey, black).
static func is_grey(c: Color) -> bool:
	return c.s < GREY_SATURATION


# ---------------------------------------------------------------------------
# CONTRAST / CAMOUFLAGE - the "can the guard see me?" question
# ---------------------------------------------------------------------------

## How strongly `subject_colour` stands out from the `ground` colour under it.
##
##   0.0 = perfectly camouflaged (hues match within tolerance)
##   1.0 = maximum contrast (standing on plain grey, or a wildly different hue)
##
## A grey floor has no hue to match, so a coloured spark always stands out:
## that is exactly why the first room feels dangerous.
static func visibility(subject_colour: Color, ground: Color, tolerance_deg: float) -> float:
	if is_grey(ground):
		# No stolen colour in the floor here, so there is nothing to hide inside.
		# A grey player on a grey floor also counts as "different enough" because
		# of the brightness difference, so we still return full contrast.
		return 1.0
	var gap: float = hue_gap_color(subject_colour, ground)
	if is_grey(subject_colour):
		# You cannot be the same colour as the floor if you have no colour.
		return 1.0
	if gap <= tolerance_deg:
		return 0.0
	# Ramp from 0 at the tolerance edge up to 1 at the far side of the wheel.
	var span: float = maxf(180.0 - tolerance_deg, 0.001)
	return clampf((gap - tolerance_deg) / span, 0.0, 1.0)


# ---------------------------------------------------------------------------
# MIXING
# ---------------------------------------------------------------------------

## Mix two colours in HSV, walking the SHORT way around the hue wheel.
## t = 0 returns `a`, t = 1 returns `b`, t = 0.5 is the midpoint hue.
## Mixing in hue space is what makes red + blue give violet instead of brown.
static func mix(a: Color, b: Color, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var ha: float = a.h * 360.0
	var hb: float = b.h * 360.0
	# Signed shortest step from a to b, in -180..180 degrees.
	var step: float = fposmod(hb - ha + 180.0, 360.0) - 180.0
	var h: float = fposmod(ha + step * t, 360.0) / 360.0
	return Color.from_hsv(h, lerpf(a.s, b.s, t), lerpf(a.v, b.v, t), 1.0)


## The player's colour after killing a guard.
##
## A colourless spark (white) simply TAKES the guard's hue - otherwise every
## mix would drag it towards red (the hue of pure white) which looks wrong.
## Once the spark already has a hue, it is pulled `amount` of the way towards
## the guard's hue, and only the brightness is averaged.
static func absorb(player_colour: Color, guard_colour: Color, amount: float) -> Color:
	if is_grey(player_colour):
		# First kill: inherit the stolen colour outright, but keep it vivid.
		return Color.from_hsv(guard_colour.h, maxf(guard_colour.s, 0.80), 1.0, 1.0)
	var out: Color = mix(player_colour, guard_colour, amount)
	# Keep saturation high so the spark never turns to mud, and average the
	# brightness so the sphere still reads as "mixed".
	out.s = clampf(maxf(player_colour.s, guard_colour.s), 0.0, 1.0)
	out.v = clampf(lerpf(player_colour.v, guard_colour.v, amount), 0.55, 1.0)
	out.a = 1.0
	return out


## Average a pile of colours, weighting each one, using a CIRCULAR MEAN of hue.
##
## This is how overlapping paint puddles blend on the floor. A plain arithmetic
## average would say "red (0) and blue (240) average to 120 = green", which is
## nonsense on a colour wheel. Summing unit vectors instead gives 300 = violet,
## which is what your eye actually sees where red and blue paint overlap.
##
## `colours` and `weights` must be the same length. Pass an empty array to get
## back the plain floor grey.
static func blend(colours: Array, weights: Array) -> Color:
	var n: int = min(colours.size(), weights.size())
	if n == 0:
		return FLOOR_GREY
	if n == 1:
		return colours[0]

	var acc_x: float = 0.0   # sum of cos(hue) * weight
	var acc_y: float = 0.0   # sum of sin(hue) * weight
	var acc_s: float = 0.0
	var acc_v: float = 0.0
	var acc_w: float = 0.0
	var best_w: float = -1.0
	var best_colour: Color = colours[0]

	for i in n:
		var c: Color = colours[i]
		var w: float = maxf(float(weights[i]), 0.0)
		if w <= 0.0:
			continue
		var rad: float = c.h * TAU
		acc_x += cos(rad) * w
		acc_y += sin(rad) * w
		acc_s += c.s * w
		acc_v += c.v * w
		acc_w += w
		if w > best_w:
			best_w = w
			best_colour = c

	if acc_w <= 0.0:
		return FLOOR_GREY

	# Undefined hue: the vectors cancelled out. Fall back to the strongest
	# puddle, which is the edge case for two exactly opposite hues (e.g. an
	# equal mix of yellow and blue paint).
	if absf(acc_x) < 0.000001 and absf(acc_y) < 0.000001:
		return best_colour

	var hue: float = fposmod(atan2(acc_y, acc_x) / TAU, 1.0)
	return Color.from_hsv(hue, clampf(acc_s / acc_w, 0.0, 1.0), clampf(acc_v / acc_w, 0.0, 1.0), 1.0)


# ---------------------------------------------------------------------------
# PRESENTATION HELPERS (used by the HUD)
# ---------------------------------------------------------------------------

## Human name of a hue, e.g. "VIOLET". Lets the HUD teach the wheel.
static func color_name(c: Color) -> String:
	if is_grey(c):
		# Brightness bands. 0.12 matters: the drained floor sits at v = 0.33,
		# which must read as GREY, not BLACK, or the HUD would lie about the
		# one colour the whole game is played against.
		if c.v > 0.75:
			return "WHITE"
		if c.v > 0.12:
			return "GREY"
		return "BLACK"
	var idx: int = int(round(fposmod(c.h * 360.0, 360.0) / 30.0)) % 12
	return HUE_NAMES[idx]


## Hue in whole degrees, 0..359, for on-screen labels like "RED 0 deg".
static func hue_degrees(c: Color) -> int:
	return int(round(fposmod(c.h * 360.0, 360.0))) % 360


## "#rrggbb" for tooltips and debug text.
static func hex(c: Color) -> String:
	return "#" + c.to_html(false)


## Pick black or white text so it stays readable on top of `background`.
static func readable_on(background: Color) -> Color:
	return Color(0.05, 0.05, 0.07) if background.get_luminance() > 0.45 else Color(0.98, 0.98, 1.0)


## The colour at `deg` on the wheel, for drawing hue bars and wheels in the HUD.
static func wheel(deg: float, saturation: float = 0.85, value: float = 1.0) -> Color:
	return Color.from_hsv(fposmod(deg, 360.0) / 360.0, saturation, value, 1.0)
