extends SceneTree
## Dev tool: print where the camera actually is after a run starts, so a capture
## can be read against world coordinates. Deleted as soon as it stops being
## useful.

var _game: Node = null
var _frame: int = 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_game = scene.instantiate()
	root.add_child(_game)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 6:
		_game.start_run()
		return false
	if _frame == 150:
		var vp: Vector2 = root.get_visible_rect().size
		print("viewport: ", vp)
		print("camera_zoom export: ", _game.camera_zoom)
		print("camera.zoom: ", _game.camera.zoom)
		print("camera.position: ", _game.camera.position)
		print("camera.global_position: ", _game.camera.global_position)
		if _game.room != null:
			print("player: ", _game.room.player.global_position)
			print("guard0: ", _game.room.guards[0].global_position)
			print("visible world size: ", vp / _game.camera.zoom)
		return true
	return false
