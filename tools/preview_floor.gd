extends SceneTree
##
## Dev tool: bake the tiled floor and save a preview so the result can be
## inspected without opening the editor. Run it with:
##     godot --headless --path . --script res://tools/preview_floor.gd
##
## It writes build/floor_preview.png (raw tiles) and build/floor_preview_tinted.png
## (the tiles multiplied by TileBank.FLOOR_MODULATE, i.e. exactly what the game
## draws). build/ is gitignored, so nothing here ships.
##
## It also prints the average colour, which is the number that has to land on
## ColorTheory.FLOOR_GREY (0.30, 0.30, 0.33) for the picture to keep matching
## the rules.

func _init() -> void:
	var tex: ImageTexture = TileBank.floor_texture()
	if tex == null:
		print("PREVIEW: FAILED - TileBank could not build the floor texture")
		quit(1)
		return

	var img: Image = tex.get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	print("PREVIEW: floor texture %dx%d" % [w, h])

	# --- raw tiles -------------------------------------------------------
	_ensure_build_dir()
	var raw_err: int = img.save_png("res://build/floor_preview.png")

	# --- tinted copy, exactly as the game draws it ------------------------
	var tinted: Image = img.duplicate()
	var mod: Color = TileBank.FLOOR_MODULATE
	var acc: Vector3 = Vector3.ZERO
	var holes: int = 0
	for y in h:
		for x in w:
			var c: Color = tinted.get_pixel(x, y)
			if c.a < 0.5:
				holes += 1
			var out := Color(c.r * mod.r, c.g * mod.g, c.b * mod.b, 1.0)
			tinted.set_pixel(x, y, out)
			acc += Vector3(out.r, out.g, out.b)
	var n: float = float(w * h)
	var avg: Vector3 = acc / n
	var tinted_err: int = tinted.save_png("res://build/floor_preview_tinted.png")

	print("PREVIEW: raw save err=%d  tinted save err=%d" % [raw_err, tinted_err])
	print("PREVIEW: transparent holes = %d" % holes)
	print("PREVIEW: tinted average rgb = (%.3f, %.3f, %.3f)" % [avg.x, avg.y, avg.z])
	print("PREVIEW: FLOOR_GREY (the rule) = (%.3f, %.3f, %.3f)" % [
		ColorTheory.FLOOR_GREY.r, ColorTheory.FLOOR_GREY.g, ColorTheory.FLOOR_GREY.b])
	quit(0)


func _ensure_build_dir() -> void:
	if not DirAccess.dir_exists_absolute("res://build"):
		DirAccess.make_dir_recursive_absolute("res://build")
