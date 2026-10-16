extends SceneTree
##
## Dev tool: draw a floor-plan sheet of all four rooms - walls, every guard
## patrol route (in the guard's own hue) and the spawn - and save it to
## docs/level_plans.png so the README image always matches level_data.gd.
##
## Run it with:
##     godot --path . --script res://tools/make_floor_plans.gd
##
## Needs a real (non-headless) renderer, because it captures the drawn frame.

const OUT_PATH := "res://docs/level_plans.png"
const PANEL := Vector2(640.0, 360.0)
const SCALE := 0.5


class PlanDrawer:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.06, 0.06, 0.08), true)
		var rooms: Array = LevelData.ROOMS
		for i in rooms.size():
			_draw_room(i, rooms[i])

	func _origin(i: int) -> Vector2:
		return Vector2(float(i % 2) * PANEL.x, float(i / 2) * PANEL.y)

	func _draw_room(i: int, room: Dictionary) -> void:
		var o: Vector2 = _origin(i)

		# The floor and its frame.
		draw_rect(Rect2(o, PANEL), Color(0.10, 0.10, 0.13), true)

		# Walls (border + interior), scaled into the panel.
		for r in LevelData.walls_for(room):
			draw_rect(Rect2(o + r.position * SCALE, r.size * SCALE), Color(0.34, 0.34, 0.40), true)

		# Every guard route, in that guard's own colour, with a dot per waypoint.
		for spec in room["guards"]:
			var col: Color = spec["color"]
			var pts: Array = [Vector2(spec["pos"])]
			for p in spec["path"]:
				pts.append(Vector2(p))
			for k in range(1, pts.size()):
				draw_line(o + pts[k - 1] * SCALE, o + pts[k] * SCALE, col, 1.6, true)
			# A route is drawn as a closed shape, because the guard walks it out
			# and back - the outline is the area it patrols, not a one-way trip.
			if pts.size() >= 3:
				draw_line(o + pts[pts.size() - 1] * SCALE, o + pts[0] * SCALE, col, 1.6, true)
			for p in pts:
				draw_circle(o + p * SCALE, 2.0, col)

		# The spawn: a small green ring, as in the README legend.
		draw_arc(o + Vector2(room["start"]) * SCALE, 4.5, 0.0, TAU, 20, Color(0.40, 1.0, 0.50), 1.6, true)

		# Frame + room name.
		draw_rect(Rect2(o, PANEL), Color(0.26, 0.26, 0.32), false, 1.0)
		var f: Font = ThemeDB.fallback_font
		if f != null:
			draw_string(f, o + Vector2(9.0, 18.0), str(room["name"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.82, 0.88))


var _drawer: Node2D = null
var _frames: int = 0


func _init() -> void:
	_drawer = PlanDrawer.new()
	root.add_child(_drawer)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(OUT_PATH)
	if err == OK:
		print("wrote %s (%dx%d)" % [OUT_PATH, img.get_width(), img.get_height()])
	else:
		print("FAILED to write %s (err %d)" % [OUT_PATH, err])
	quit(0 if err == OK else 1)
	return true
