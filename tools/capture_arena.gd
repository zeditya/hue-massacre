extends SceneTree
##
## Dev tool: one FULL-ARENA capture per room, camera unlocked, HUD off, so the
## level design and the art can be judged as a whole instead of through the
## follow camera. Run it with:
##     godot --path . --script res://tools/capture_arena.gd
##
## Writes to build/capture/arena_XX.png (gitignored). Not part of the game.
##
## The camera is parked at the middle of the playfield with zoom 1, which makes
## one captured pixel exactly one world pixel - the same frame the level data is
## written in, so a wall rect in level_data.gd can be measured against the shot.

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


func _snap(path: String) -> void:
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("captured ", path)


func _park_camera() -> void:
	# Centre of the playfield, one world pixel per screen pixel. The game's own
	# follow camera recomputes from the player every frame, so the cheapest way
	# to park it is to park the player and snap.
	_game.camera_zoom = 1.0
	_game.camera.zoom = Vector2(1.0, 1.0)
	if _game.room != null and is_instance_valid(_game.room.player):
		_game.room.player.position = LevelData.PLAYFIELD * 0.5
		_game._snap_camera()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 6:
		return false

	if _game.state != _game.State.PLAY:
		# The build boots into the story's opening: dismiss it the way a player
		# would - SKIP hands straight over to the run.
		if _game.opening != null:
			_game.opening.skip()
		else:
			_game.start_run()
		return false

	_warmup += 1
	if _warmup < 8:
		return false

	if _game.hud != null:
		_game.hud.visible = false
	# The darkness overlay is for play; for judging the art the arena is shown
	# in plain light, or every level-design pass would be a guess.
	if _game.darkness != null:
		_game.darkness.visible = false
	_park_camera()

	# A parked camera is not applied until the NEXT frame (Camera2D updates its
	# transform in the frame step, not when the position is written), so the
	# shot waits two frames or it shows the previous view with wrong framing.
	if _warmup < 10:
		return false

	if not _shot_taken:
		_snap("%s/arena_%02d.png" % [OUT_DIR, _room + 1])
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
