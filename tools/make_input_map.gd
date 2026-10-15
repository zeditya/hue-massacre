extends SceneTree
##
## One-shot tool: writes the game's input actions into project.godot so the
## Input Map panel in the editor is populated and the actions are versioned in
## the repo. Run it with:
##     godot --headless --path . --script res://tools/make_input_map.gd
##
## (It is kept in the repo because it documents exactly which keys the game
## listens to, and it can be re-run safely at any time.)

const KEY_ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"dash": [KEY_SPACE],
	"restart": [KEY_R],
	"to_title": [KEY_ESCAPE],
}


func _init() -> void:
	for action_name in KEY_ACTIONS:
		var events: Array = []
		for keycode in KEY_ACTIONS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			events.append(ev)
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": events})

	# Left mouse also lunges, aimed at the cursor.
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	ProjectSettings.set_setting("input/dash_aim", {"deadzone": 0.2, "events": [mouse]})

	var err: int = ProjectSettings.save()
	print("input map written, ProjectSettings.save() returned ", err)
	quit()
