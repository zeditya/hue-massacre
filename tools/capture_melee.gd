extends SceneTree
##
## Dev tool: capture the three new reads of the melee, one picture each, so the
## guard, the parry and the marked overhead can be judged as pictures:
##     godot --path . --script res://tools/capture_melee.gd
##
## Writes build/capture/melee/*.png (gitignored). HUD and darkness stay ON: the
## point is the frame the player actually sees.
##
##   * guard     - the ward arc, and the window's bright edge
##   * parry     - a blow turned: the white ring, and the attacker opened up
##   * perilous  - the marked overhead: the red wedge and the pack's hazard sign

const OUT_DIR := "res://build/capture/melee"

var _game: Node = null
var _f: int = 0
var _knight: Guard = null


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scene: PackedScene = load("res://scenes/main.tscn")
	_game = scene.instantiate()
	root.add_child(_game)


func _snap(name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT_DIR, name])
	print("captured ", name)


## Both feet on the sand, facing the camera-right, one knight in front.
func _stand(guard_raise: bool) -> void:
	var room: Room = _game.room
	if room == null or room.guards.is_empty():
		return
	_knight = room.guards[0]
	_knight.dead = false
	_knight.hp = _knight.max_hp
	_knight.stagger_left = 0.0
	_knight.velocity = Vector2.ZERO
	var p: Player = room.player
	p.hp = p.max_hp
	p.velocity = Vector2.ZERO
	p.hitstun_left = 0.0
	p.invuln_left = 0.0
	p._facing = 0.0
	p.global_position = Vector2(560.0, 470.0)
	_knight.global_position = p.global_position + Vector2(58.0, -6.0)
	_knight._facing = PI
	if guard_raise:
		# Hold the REAL input, not just the flag: the player's own physics looks
		# at the action every frame, so a programmatic raise would be dropped
		# before the frame is ever drawn (and the capture would show no ward).
		Input.action_press("guard")
	else:
		Input.action_release("guard")
		p.end_guard()


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		6:
			# The build boots into the story's opening: dismiss it the way a
			# player would - SKIP hands straight over to the run.
			if _game.opening != null:
				_game.opening.skip()
			else:
				_game.start_run()
		90:
			_stand(true)
		93:
			_snap("guard")
		# A parry: the window is open, a real blow arrives from the knight, and
		# the room hands out the stagger. Frame 96 catches the flash itself.
		96:
			_stand(true)
		97:
			# The window is open (the raise happened on frame 96), and a real
			# blow arrives from the knight's direction: the room then hands out
			# the stagger, the flash and the hit-stop.
			_knight._swings_since_perilous = 0
			_knight.attack_state = Guard.Attack.NONE
			_knight._attack_cooldown_left = 0.0
			_game.room.player.take_damage(12.0, _knight.global_position)
		100:
			# The flash lasts a third of a second, so read it a couple of frames
			# later: force_draw can catch a frame mid-composition, and a parry
			# ring that is still 90% lit is the same picture to the eye.
			_snap("parry")
		# The marked overhead, frozen two thirds through its windup.
		130:
			_stand(false)
		131:
			_knight._swings_since_perilous = _knight.perilous_every
			_knight._start_windup()
			_knight._attack_left = _knight._windup_len * 0.35
		133:
			_snap("perilous")
		136:
			_snap("perilous_b")
		139:
			quit(0)
	return false
