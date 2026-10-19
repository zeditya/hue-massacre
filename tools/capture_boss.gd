extends SceneTree
##
## Dev tool: capture Hall I's Sun's Warden, the first true boss, one read at a
## time:
##     godot --path . --script res://tools/capture_boss.gd
##
## Writes build/capture/boss/*.png (gitignored). HUD and darkness stay ON: the
## point is the frame the player actually sees.
##
##   * warden_intro  - the herald names him, and the boss bar comes up
##   * shield_stance - the wall: the arc that blocks, drawn in his own hue
##   * shield_broken - the parry/heavy answer: the broken arc and the opening
##   * phase_two     - half vigour: the shield falls for good
##   * slam_windup   - the disc that hurts, exactly the radius that hurts
##   * slam_landed   - the shockwave
##   * warden_kneels - the defeat beat, and the hall beginning to drain
##
## The tool drives the same public/api paths the game does (release_all_waves,
## break_shield, _update_boss_phase, _slam_land) rather than inventing a
## separate picture-only path, so a capture cannot show a state the game
## cannot reach.

const OUT_DIR := "res://build/capture/boss"

var _game: Node = null
var _f: int = 0
var _warden: Guard = null
var _player: Player = null


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scene: PackedScene = load("res://scenes/main.tscn")
	_game = scene.instantiate()
	root.add_child(_game)


func _snap(name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, name])
	print("captured ", name)


## Put the duel on the sand in one spot: the player facing east, the warden
## facing the player, everybody else switched off so the frame is about the
## warden alone.
func _place_duel() -> void:
	_warden = _game.room.boss
	if _warden == null:
		return
	_player = _game.room.player
	for g in _game.room.guards:
		if is_instance_valid(g) and g != _warden:
			g.set_physics_process(false)
	_warden.set_physics_process(false)
	_warden.dead = false
	_warden.kneeling = false
	_warden.boss_phase = 1
	_warden.has_shield_stance = true
	_warden.shield_up = true
	_warden.stagger_left = 0.0
	_warden._shield_broken_left = 0.0
	_warden.attack_state = Guard.Attack.NONE
	_warden.hp = _warden.max_hp
	_warden.velocity = Vector2.ZERO
	_warden.global_position = Vector2(660.0, 430.0)
	_warden._facing = PI
	_player.global_position = Vector2(596.0, 436.0)
	_player._facing = 0.0
	_player.hp = _player.max_hp
	_player.velocity = Vector2.ZERO
	_player.hitstun_left = 0.0
	_player.invuln_left = 0.0
	_player.end_guard()
	_warden.queue_redraw()


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		6:
			# The build boots into the story's opening: skip it the way a
			# player does, then the first hall is on the sand.
			if _game.opening != null:
				_game.opening.skip()
			else:
				_game.start_run()
		30:
			# Hall I's warden leads the last wave. Pull the waves in rather than
			# playing three of them, so the capture is about him.
			_game.room.release_all_waves()
		38:
			# The intro banner is still up: the name in his own hue, the bar.
			_snap("warden_intro")
		50:
			_place_duel()
		54:
			_snap("shield_stance")
		58:
			# The parry answer: the wall comes open for the free swing.
			if _warden != null:
				_game.room._on_player_parried(_warden.global_position)
		62:
			_snap("shield_broken")
		68:
			# Half vigour: the wall falls for good. The phase banner lands too.
			if _warden != null:
				_warden.has_shield_stance = true
				_warden.shield_up = true
				_warden.hp = _warden.max_hp * 0.45
				_warden._update_boss_phase()
		76:
			_snap("phase_two")
		82:
			# The ground strike, frozen in its telegraph. The disc drawn here is
			# exactly `slam_radius`, which is exactly what will hurt.
			if _warden != null:
				_player.global_position = _warden.global_position + Vector2(0.0, 60.0)
				_player.hp = _player.max_hp
				_warden.attack_state = Guard.Attack.SLAM
				_warden._slam_left = _warden.slam_windup * 0.32
				_warden._slam_ring = 0.0
				_warden.queue_redraw()
		88:
			_snap("slam_windup")
		92:
			# The ring erupts through the player: still no camera shake, by the
			# game's own shake policy; the flash and the ring carry it.
			if _warden != null:
				_warden._slam_left = 0.0
				_warden._slam_land(_player)
		96:
			_snap("slam_landed")
		104:
			# The defeat beat: he kneels, the quarter is taken, the hall drains.
			if _warden != null and not _warden.dead:
				_warden.hp = 1.0
				_game.room._kill_guard(_warden)
		# Wait for the boss-death colour flash to fade before taking the shot:
		# the flash is the game's reaction, not the picture we are judging, and
		# a frame washed in ember would hide the kneel and the greying sand.
		140:
			_snap("warden_kneels")
		152:
			quit(0)
	return false
