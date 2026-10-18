extends SceneTree
##
## Dev tool: captures the OPENING scene at each of its beats, so the staging,
## the portrait box, the typewriter and the FX can be judged as pictures instead
## of guessed at from the code. Run it with:
##     godot --path . --script res://tools/capture_opening.gd
##
## Writes to build/capture/opening_XX_*.png (gitignored). Not part of the game.
##
## Two rules make the shots faithful to the real sequence:
##   * beats are found by SEARCHING the script, never by index, so reordering
##     the story cannot silently capture the wrong frame;
##   * the camera uses the shot that is IN FORCE at that entry (the last "shot"
##     key above it), because the flow inherits framing from earlier lines.

const OUT_DIR := "res://build/capture"

var _opening: Opening = null
var _frame: int = 0
var _shots: Array = []
var _shot: int = 0
var _settle: int = 0
var _armed: bool = false


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_opening = Opening.new()
	root.add_child(_opening)
	_shots = [
		{"name": "opening_01_title", "beat": "title"},
		{"name": "opening_02_arrive", "line": "So a knight with no colour"},
		{"name": "opening_03_meet", "line": "...You came"},
		{"name": "opening_04_reasons", "line": "Because you have nothing"},
		{"name": "opening_05_gift", "beat": "gift", "progress": 0.30},
		{"name": "opening_06_gift_late", "beat": "gift", "progress": 0.70},
		{"name": "opening_07_take", "beat": "take", "take": 0.45, "stand": true},
		{"name": "opening_08_earned", "line": "I have no name", "stand": true, "sword": true},
		{"name": "opening_09_gate", "beat": "gate", "stand": true, "sword": true, "gate": 0.9},
		{"name": "opening_10_warden", "line": "Turn around", "stand": true, "sword": true,
			"gate": 1.0},
	]
	_settle = 0
	_arm()


func _find(kind: String, value: String) -> int:
	for i in _opening._script.size():
		var entry: Dictionary = _opening._script[i]
		if kind == "line" and str(entry.get("text", entry.get("nar", ""))).begins_with(value):
			return i
		if kind == "beat" and str(entry.get("beat", "")) == value:
			return i
	return -1


## The shot that is in force at entry `index`: the last one declared at or above
## it. This is what the running game would be framing.
func _shot_for(index: int) -> int:
	for i in range(index, -1, -1):
		var entry: Dictionary = _opening._script[i]
		if entry.has("shot"):
			return int(entry["shot"])
	return Opening.Shot.WIDE


## Put the opening into the state this shot wants, camera included.
func _arm() -> void:
	if _shot >= _shots.size():
		return
	var shot: Dictionary = _shots[_shot]
	var index: int = -1
	if shot.has("line"):
		index = _find("line", str(shot["line"]))
	elif shot.has("beat"):
		index = _find("beat", str(shot["beat"]))
	if index < 0:
		push_warning("capture_opening: could not find %s" % str(shot))
		_shot += 1
		_arm()
		return
	_opening._enter(index)
	# A line capture wants the whole line already typed out.
	if _opening._phase == Opening.Phase.TYPING:
		_opening._chars = float(_opening._line.length())
		_opening._phase = Opening.Phase.TYPED
	# The walk has happened by the time these beats come round, so the Unsworn
	# is standing at the sword and carrying it from "take" onwards.
	if bool(shot.get("stand", false)):
		_opening._player_pos = Opening.SWORD_STAND
		_opening._player_anim = "idle_left"
	if bool(shot.get("sword", false)):
		_opening._has_sword = true
	# Park timed beats at a chosen moment (0..1) so an FX can be caught
	# mid-burst, and freeze them: no beat may finish during the settle frames.
	if shot.has("progress"):
		_opening._beat_left = float(_opening._beat_total) * (1.0 - float(shot["progress"]))
		_opening._beat_progress(_opening._beat_name, float(shot["progress"]))
	if shot.has("take"):
		_opening._run_beat_action("take")
		_opening._beat_left = float(_opening._beat_total) * (1.0 - float(shot["take"]))
		_opening._beat_progress("take", float(shot["take"]))
		if float(shot["take"]) >= 1.0:
			_opening._has_sword = true
	if shot.has("gate"):
		_opening._gate_open = float(shot["gate"])
	_opening._beat_hold = true
	# The camera is eased over time, so teleport it for the capture.
	_opening._shot = _shot_for(index)
	var want: Dictionary = Opening.SHOTS[_opening._shot]
	_opening._cam_pos = want["centre"]
	_opening._cam_zoom = float(want["zoom"])
	_opening._shot_punch = 0.0
	_settle = 0
	_armed = true


func _snap(path: String) -> void:
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("captured ", path)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 4 or not _armed:
		return false
	_settle += 1
	if _settle < 10:
		return false
	_snap("%s/%s.png" % [OUT_DIR, str(_shots[_shot]["name"])])
	_shot += 1
	if _shot >= _shots.size():
		quit(0)
		return true
	_arm()
	return false
