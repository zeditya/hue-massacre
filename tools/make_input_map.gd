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
	# The strike: J on the keyboard, or the left mouse button below. Two
	# bindings, ONE verb - the sword swings the way you steer, never at the
	# cursor, so the two handles can never disagree about aim.
	"strike": [KEY_J],
	# Space is the DODGE ROLL: the defensive verb, with i-frames.
	"dodge": [KEY_SPACE],
	"restart": [KEY_R],
	"to_title": [KEY_ESCAPE],
}

const MOUSE_ACTIONS := {
	"strike": MOUSE_BUTTON_LEFT,
}

## Verbs from earlier builds. They are removed so the Input Map panel does not
## keep advertising buttons that do nothing: documentation that lies is worse
## than no documentation.
const REMOVED_ACTIONS := ["dash", "dash_aim"]


func _init() -> void:
	for action_name in KEY_ACTIONS:
		var events: Array = []
		for keycode in KEY_ACTIONS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			events.append(ev)
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": events})

	for action_name in MOUSE_ACTIONS:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_ACTIONS[action_name]
		var existing: Dictionary = ProjectSettings.get_setting("input/" + action_name, {"deadzone": 0.2, "events": []})
		existing["events"].append(mouse)
		ProjectSettings.set_setting("input/" + action_name, existing)

	for dead in REMOVED_ACTIONS:
		if ProjectSettings.has_setting("input/" + dead):
			ProjectSettings.clear("input/" + dead)

	var err: int = ProjectSettings.save()
	print("input map written, ProjectSettings.save() returned ", err)
	quit()
