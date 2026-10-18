extends SceneTree
##
## Dev tool: stage a fight in Arena 01 and capture a strip of frames across it,
## so the combat FEEL (swing arc, hit flash, kill choreography, crowd reaction,
## roll afterimages) can be judged without playing.
##     godot --path . --script res://tools/capture_fight.gd
##
## Writes build/capture/fight/*.png (gitignored). The HUD and the darkness
## shader stay ON: this is the real frame the player sees, not a debug view.
##
## The fight is scripted by frame number, which is crude but honest - it is the
## only way to photograph a 0.14s swing from outside the game loop.

const OUT_DIR := "res://build/capture/fight"

var _game: Node = null
var _f: int = 0
var _target: Guard = null


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scene: PackedScene = load("res://scenes/main.tscn")
	_game = scene.instantiate()
	root.add_child(_game)


func _snap(name: String) -> void:
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, name])
	print("captured ", name)


## Put the Unsworn right in front of a knight, blade up, both feet planted.
func _close_in() -> void:
	var room: Room = _game.room
	if room == null or room.guards.is_empty():
		return
	_target = room.guards[0]
	room.player.global_position = _target.global_position + Vector2(0.0, 28.0)
	room.player.velocity = Vector2.ZERO
	room.player.hp = room.player.max_hp


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		6:
			_game.start_run()
		100:
			_close_in()
		104:
			_game.room.player.begin_strike(Vector2.UP)
		105, 106, 107, 109, 112:
			_snap("swing1_%03d" % _f)
		126:
			_close_in()
		128:
			_game.room.player.begin_strike(Vector2.UP)
		129, 131, 134:
			_snap("swing2_%03d" % _f)
		148:
			_close_in()
		150:
			_game.room.player.begin_strike(Vector2.UP)
		151, 153, 156:
			_snap("heavy_%03d" % _f)
		176:
			_close_in()
		178:
			_snap("before_kill")
		180:
			if _target != null and is_instance_valid(_target) and not _target.dead:
				_game.room._kill_guard(_target)
		181, 183, 186, 190, 196, 204:
			_snap("kill_%03d" % _f)
		230:
			var p: Player = _game.room.player
			p.begin_roll(Vector2.RIGHT)
		232, 234, 237:
			_snap("roll_%03d" % _f)
		300:
			quit(0)
			return true
	return false
