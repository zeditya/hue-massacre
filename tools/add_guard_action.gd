extends SceneTree
## One-off tool: registers the `guard` action (right mouse button, or SHIFT) in
## the project input map and saves project.godot in Godot's own format.
##     godot --headless --path . --script res://tools/add_guard_action.gd
## Delete this file once the action is in project.godot.

func _init() -> void:
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	var action := {
		"deadzone": 0.2,
		"events": [mouse, shift],
	}
	ProjectSettings.set_setting("input/guard", action)
	var err: int = ProjectSettings.save()
	print("guard action saved: ", err, " (", error_string(err), ")")
	quit(0)
