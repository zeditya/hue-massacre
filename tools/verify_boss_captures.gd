extends SceneTree
##
## Dev tool: the machine half of "look at the boss captures".
##
##     godot --path . --script res://tools/capture_boss.gd
##     godot --headless --path . --script res://tools/verify_boss_captures.gd
##
## The headless test suite cannot execute `_draw()`, so the pictures are the
## only evidence for the boss's LOOK. This tool reads the frames capture_boss.gd
## just wrote and checks the specific things the eye was asked to confirm - the
## shield arc is painted in the warden's hue, the slam's disc is really on the
## sand, the defeat frame is not washed out by the death flash, and the boss bar
## is present on the arrival frame. It is not a substitute for looking; it is
## what stops a picture from silently being wrong (a stale frame, a black
## screen, a full-screen flash).
##
## Exits non-zero if any fact is not in the frame.

const DIR := "res://build/capture/boss"

## Ember band of the Sun's Warden's hue (~11 degrees) in degrees.
const EMBER_LOW: float = 5.0
const EMBER_HIGH: float = 25.0

var passed: int = 0
var failed: int = 0


func _init() -> void:
	# Every frame must exist and be a real 1280x720 picture.
	for name in ["warden_intro", "shield_stance", "shield_broken", "phase_two",
			"slam_windup", "slam_landed", "warden_kneels"]:
		_check_frame(name)

	if failed == 0:
		# The shield stance: his hue really is painted along the arc.
		_check_ember("shield_stance", Rect2i(680, 260, 180, 180), 3.0,
			"the shield arc is painted in the warden's hue")
		# Phase II: the wall is down and the duel has announced itself.
		_check_ember("phase_two", Rect2i(680, 260, 180, 180), 8.0,
			"phase II still reads as the warden's hue on the sand")
		# The slam: the disc that hurts fills the ground around him.
		_check_ember("slam_windup", Rect2i(680, 260, 180, 180), 15.0,
			"the ground strike's disc is actually on the sand")
		# The arrival: the boss bar (and the name in his hue) is up.
		_check_ember("warden_intro", Rect2i(380, 640, 520, 60), 4.0,
			"the arrival frame carries the warden's bar and name")
		# The defeat: the boss-death flash must have finished, or the frame is
		# the game's reaction instead of the game. A few scenery pixels in this
		# corner are warm by nature, so the bar is "not a wash" (a live flash
		# covers the whole corner and reads over 50%).
		_check_not_ember("warden_kneels", Rect2i(0, 0, 80, 80), 15.0,
			"the kneel frame is not washed out by the death flash")
		_check_cone_is_faint()

	print("=========================================================")
	print("RESULT: %d passed, %d failed" % [passed, failed])
	print("=========================================================")
	quit(1 if failed > 0 else 0)


func _check(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		print("  FAIL  %s   %s" % [label, detail])


func _load(name: String) -> Image:
	var path: String = ProjectSettings.globalize_path("%s/%s.png" % [DIR, name])
	if not FileAccess.file_exists(path):
		return null
	var img: Image = Image.load_from_file(path)
	return img


## The faint sight cone is the one thing the suite can only assert in numbers.
## In the staged `shield_stance` frame the warden faces west (towards the
## player), so the ground in front of him should carry more of his hue than the
## ground behind him at the same distance - and it must stay dim either way.
func _check_cone_is_faint() -> void:
	var img: Image = _load("shield_stance")
	if img == null:
		_check(false, "the cone is drawn", "missing shield_stance")
		return
	# World (520, 430) sits inside the west-pointing cone; world (860, 430) sits
	# behind him. Both must be on sand, not on the arc itself.
	var front: Color = img.get_pixel(488, 348)
	var behind: Color = img.get_pixel(904, 348)
	_check(front.s > behind.s + 0.08,
		"the cone tints where the warden looks and not behind him",
		"front sat %.2f vs behind %.2f" % [front.s, behind.s])
	_check(front.v < 0.75, "and the cone stays dim instead of painting over the sand",
		"value %.2f" % front.v)


func _check_frame(name: String) -> void:
	var img: Image = _load(name)
	if img == null:
		_check(false, "%s exists" % name, "run capture_boss.gd first")
		return
	var size_ok: bool = img.get_width() == 1280 and img.get_height() == 720
	# A picture that is one flat colour is a stale or blank frame, not a shot.
	var probe: Dictionary = {}
	var step: int = 24
	var y: int = 0
	while y < img.get_height():
		var x: int = 0
		while x < img.get_width():
			probe[img.get_pixel(x, y).to_rgba32()] = true
			x += step
		y += step
	_check(size_ok, "%s is 1280x720" % name, "%dx%d" % [img.get_width(), img.get_height()])
	_check(probe.size() > 24, "%s is a real frame, not a flat colour" % name,
		"%d sampled colours" % probe.size())


## Fraction (0..1) of sampled pixels in `rect` that sit in the ember band with
## real saturation. Sampling every 4px is plenty for a picture this size.
func _ember_fraction(img: Image, rect: Rect2i) -> float:
	var total: int = 0
	var ember: int = 0
	var step: int = 4
	var y: int = rect.position.y
	while y < rect.position.y + rect.size.y:
		var x: int = rect.position.x
		while x < rect.position.x + rect.size.x:
			var c: Color = img.get_pixel(x, y)
			var deg: float = c.h * 360.0
			if deg >= EMBER_LOW and deg <= EMBER_HIGH and c.s > 0.35 and c.v > 0.3:
				ember += 1
			total += 1
			x += step
		y += step
	if total == 0:
		return 0.0
	return float(ember) / float(total)


func _check_ember(name: String, rect: Rect2i, min_percent: float, label: String) -> void:
	var img: Image = _load(name)
	if img == null:
		_check(false, label, "missing %s" % name)
		return
	var percent: float = _ember_fraction(img, rect) * 100.0
	_check(percent >= min_percent, label, "%.1f%% ember (needs %.1f%%)" % [percent, min_percent])


func _check_not_ember(name: String, rect: Rect2i, max_percent: float, label: String) -> void:
	var img: Image = _load(name)
	if img == null:
		_check(false, label, "missing %s" % name)
		return
	var percent: float = _ember_fraction(img, rect) * 100.0
	_check(percent <= max_percent, label, "%.1f%% ember (needs <= %.1f%%)" % [percent, max_percent])
