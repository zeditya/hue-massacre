extends SceneTree
## Dev tool: one frame of the opening with debug crosses drawn at the stage
## anchors, so the stage-to-screen mapping can be checked by eye. Pick the beat
## with DBG_SHOT (title | talk | gift | take | gate), default talk:
##     DBG_SHOT=gate godot --path . --script res://tools/dbg_opening.gd
## Writes build/capture/dbg_opening.png (gitignored). Not part of the game.

var _o: Opening = null
var _f: int = 0
var _which: String = "talk"


func _init() -> void:
	_which = OS.get_environment("DBG_SHOT")
	if _which == "":
		_which = "talk"
	_o = Opening.new()
	_o.debug_marks = true
	root.add_child(_o)


func _idx(kind: String, value: String) -> int:
	for i in _o._script.size():
		var e: Dictionary = _o._script[i]
		if kind == "beat" and str(e.get("beat", "")) == value:
			return i
		if kind == "line" and str(e.get("text", e.get("nar", ""))).begins_with(value):
			return i
	return -1


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		match _which:
			"title":
				_o._enter(0)
			"gift":
				_o._enter(_idx("beat", "gift"))
				_o._beat_left = _o._beat_total * 0.66
				_o._beat_progress("gift", 0.34)
			"take":
				_o._enter(_idx("beat", "take"))
				_o._run_beat_action("take")
				_o._beat_left = _o._beat_total * 0.55
				_o._beat_progress("take", 0.45)
			"gate":
				_o._enter(_idx("beat", "gate"))
				_o._run_beat_action("take")
				_o._has_sword = true
				_o._gate_open = 0.9
			_:
				_o._enter(_idx("line", "...You came"))
				if _o._phase == Opening.Phase.TYPING:
					_o._chars = float(_o._line.length())
					_o._phase = Opening.Phase.TYPED
		var want: Dictionary = Opening.SHOTS[_o._shot]
		_o._cam_pos = want["centre"]
		_o._cam_zoom = float(want["zoom"])
		_o._shot_punch = 0.0
		print("shot=", _o._shot, " cam=", _o._cam_pos, " zoom=", _o._cam_zoom)
		print("knight (556,486) -> ", (_o.KNIGHT_POS - _o._cam_pos) * _o._cam_zoom
			+ Opening.VIEW * 0.5)
		print("sword  (652,528) -> ", (_o.SWORD_POS - _o._cam_pos) * _o._cam_zoom
			+ Opening.VIEW * 0.5)
		print("player ", _o._player_pos, " -> ", (_o._player_pos - _o._cam_pos) * _o._cam_zoom
			+ Opening.VIEW * 0.5)
	if _f < 12:
		return false
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://build/capture/dbg_opening.png")
	print("captured dbg_opening.png  (", _which, ")")
	return true
