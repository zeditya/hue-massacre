extends SceneTree
##
## Capture tool for the 3D billboard prototype (camera track A).
##
## Renders the prototype scene and saves screenshots to build/proto_3d/, the
## same way tools/capture.gd does for the real game. Needs a display - the
## headless engine cannot render.
##
##     godot --path . --script res://proto/3d/capture.gd
##
## Raw frames land in build/ (gitignored). The final shots are copied into
## docs/proto/3d_billboard/ for the camera comparison.

const OUT_DIR := "res://build/proto_3d"
## Frames to wait after a scene change before shooting (lighting and shadow
## updates settle within a frame or two, this is generous on purpose).
const HOLD := 20

var _scene: Node = null
var _frame: int = 0
var _hold: int = 0
var _step: int = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_scene = (load("res://proto/3d/proto_3d.tscn") as PackedScene).instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 10:
		return false
	_hold += 1
	if _hold < HOLD:
		return false
	_hold = 0

	match _step:
		0:
			_scene.place_player_px(Vector2(640.0, 420.0))
			_scene.set_camera(0.0, -55.0, 19.0)
		1:
			_shot("01_overview.png")
		2:
			_scene.place_player_px(Vector2(516.0, 470.0))
			_scene.set_camera(0.0, -55.0, 9.0)
		3:
			_shot("02_closeup.png")
		4:
			_scene.place_player_px(Vector2(640.0, 420.0))
			_scene.set_camera(35.0, -50.0, 13.0)
		5:
			_shot("03_alt_angle.png")
		6:
			_scene.place_player_px(Vector2(600.0, 470.0))
			_scene.set_camera(-18.0, -52.0, 8.0)
		7:
			_shot("04_hero.png")
		8:
			quit(0)
			return true
	_step += 1
	return false


func _shot(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s" % [OUT_DIR, name])
	print("captured %s" % name)
