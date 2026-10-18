class_name TileBank
extends RefCounted
##
## TILE BANK - turns the "Modern Interiors" tileset into the room's floor.
##
## WHY THIS EXISTS
##   The floor used to be a single flat grey rectangle. It is now a real tiled
##   floor taken from the 16x16 tileset in `assets/tiles/`, which gives the
##   arena floor some texture instead of a blank wash of grey.
##
## THE RULE THAT MATTERS
##   `room.gd` must still "look like" the colour the game logic believes the
##   floor is (`ColorTheory.FLOOR_GREY`), because a guard decides whether it can
##   see the player by comparing the *bare floor* to the player's hue. So the
##   tile is dark-multiplied by FLOOR_MODULATE until its average lands on that
##   exact grey. The picture and the maths stay one thing.
##
## COST
##   The whole 1280x720 floor is baked ONCE per process into an ImageTexture and
##   shared by every room, so drawing the floor is a single `draw_texture` call
##   rather than thousands of little tile blits every frame.
##
## LICENCE: see `assets/ATTRIBUTION.md`. The Modern Interiors free version is
## NON-COMMERCIAL ONLY, which is fine for this assignment build.

const SHEET_PATH: String = "res://assets/tiles/room_builder_16x16.png"
const TILE: int = 16

## Tile cell (column, row) in the sheet used for the floor fill. This one is a
## flat, fully opaque grey with a faint "+=+=" paver relief, so it tiles without
## any obvious seams or stray objects.
const FLOOR_TILE: Vector2i = Vector2i(14, 5)

## Multiplied over the tile when it is drawn. Tuned so the tiled floor's average
## colour lands on ColorTheory.FLOOR_GREY (0.30, 0.30, 0.33) - the floor is still
## "the bare grey", just with texture.
const FLOOR_MODULATE: Color = Color(0.54, 0.58, 0.65)

## Built once and reused: the floor is identical in every room.
static var _floor_tex: ImageTexture = null


## The baked, tiled floor for the whole playfield. null if the sheet is missing,
## which lets the room fall back to its old flat grey.
static func floor_texture() -> ImageTexture:
	if _floor_tex == null:
		_floor_tex = _bake_tiled(FLOOR_TILE)
	return _floor_tex


static func _bake_tiled(tile: Vector2i) -> ImageTexture:
	var sheet_tex: Texture2D = load(SHEET_PATH)
	if sheet_tex == null:
		push_warning("TileBank: missing tileset %s" % SHEET_PATH)
		return null
	var sheet: Image = sheet_tex.get_image()
	if sheet == null:
		return null
	if sheet.get_format() != Image.FORMAT_RGBA8:
		sheet.convert(Image.FORMAT_RGBA8)

	var w: int = int(LevelData.PLAYFIELD.x)
	var h: int = int(LevelData.PLAYFIELD.y)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var src: Rect2i = Rect2i(tile.x * TILE, tile.y * TILE, TILE, TILE)

	# 1280 / 16 = 80 and 720 / 16 = 45 exactly, so the playfield is a whole
	# number of tiles and nothing is left unfilled.
	var ty: int = 0
	while ty < h:
		var tx: int = 0
		while tx < w:
			img.blit_rect(sheet, src, Vector2i(tx, ty))
			tx += TILE
		ty += TILE

	return ImageTexture.create_from_image(img)
