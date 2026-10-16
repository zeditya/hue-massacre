extends SceneTree
##
## Dev tool: render one frame of each room (with the darkness layer on) and save
## it as a PNG, so the look can be checked without playing. Run it with:
##     godot --path . --script res://tools/capture.gd
##
## Writes to build/capture/ (gitignored). Not part of the game.

const OUT_DIR := "res://build/capture"

var _game: Node = null
var _frame: int = 0
var _room: int = 0
var _warmup: int = 0
var _shot_taken: bool = false


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scene: PackedScene = load("res://scenes/main.tscn")
	_game = scene.instantiate()
	root.add_child(_game)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 6:
		return false

	# Enter play and load the first room once.
	if _game.state != _game.State.PLAY:
		_game.start_run()
		return false

	_warmup += 1
	if _warmup < 8:
		return false

	if not _shot_taken:
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/room_%02d.png" % [OUT_DIR, _room + 1])
		print("captured room %d" % (_room + 1))
		_shot_taken = true
		_warmup = 0
		return false

	_room += 1
	if _room >= 4:
		quit(0)
		return true
	_game.load_room(_room)
	_shot_taken = false
	return false
