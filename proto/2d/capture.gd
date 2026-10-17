extends SceneTree
##
## Capture tool for the camera comparison (proto/2d/). Renders the same room in
## the three camera modes and saves screenshots to build/proto_camera/, the
## same way tools/capture.gd does. Needs a display.
##
##     godot --path . --script res://proto/2d/capture.gd

const OUT_DIR := "res://build/proto_camera"
const HOLD := 16

var _scene: Node = null
var _frame: int = 0
var _hold: int = 0
var _step: int = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_scene = (load("res://proto/2d/proto_camera.tscn") as PackedScene).instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 8:
		return false
	_hold += 1
	if _hold < HOLD:
		return false
	_hold = 0

	match _step:
		0:
			_scene.snap(0, Vector2(640.0, 430.0), 1.0)
		1:
			_shot("00_topdown.png")
		2:
			_scene.snap(1, Vector2(620.0, 450.0), 1.5)
		3:
			_shot("01_zoom.png")
		4:
			_scene.snap(2, Vector2(620.0, 450.0), 1.5)
		5:
			_shot("02_tilt.png")
		6:
			# Close to the left-middle pillar, with the green knight standing
			# just behind it - the y-sort / fake-height money shot.
			_scene.snap(2, Vector2(462.0, 420.0), 2.0)
		7:
			_shot("03_tilt_closeup.png")
		8:
			quit(0)
			return true
	_step += 1
	return false


func _shot(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s" % [OUT_DIR, name])
	print("captured %s" % name)
