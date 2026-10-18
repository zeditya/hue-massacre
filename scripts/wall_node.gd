class_name WallNode
extends Node2D
##
## WALL NODE - one solid wall of the arena, drawn as a raised block of stone.
##
## The ROOM owns the collision (one StaticBody2D, one rect per wall); this node
## owns the picture. Its position is the wall's ground line - the south edge of
## its footprint - because that is the y-sort key. A block whose ground line is
## below a fighter's feet is drawn after that fighter, so the block's lit top
## surface covers whoever is standing behind it. That single rule is what gives
## the arena depth: step behind the ring wall and your shoulders vanish under
## its stones, exactly like the reference battlefields.
##
## The art itself lives in ArenaArt.draw_block(); this node only holds the
## numbers and the transform.

## World-space footprint of the wall (this is the collision, not the picture).
var rect: Rect2 = Rect2()
## Base tone of the stone. Per-arena, from "wall_color" in level data.
var tint: Color = Color(0.40, 0.36, 0.32)
## How far the lit top slab is lifted north of the footprint, in world px.
var lift: float = 9.0
## Height of the dark face that looks at the camera, in world px.
var face_h: float = 14.0


## Place the block. `world_rect` is the collision footprint; `lift_px` and
## `face_px` are the fake height that turns it into an object.
func setup(world_rect: Rect2, colour: Color, lift_px: float, face_px: float) -> void:
	rect = world_rect
	tint = colour
	lift = lift_px
	face_h = face_px
	position = Vector2(world_rect.position.x + world_rect.size.x * 0.5, world_rect.end.y)


func _draw() -> void:
	# The room can ask a block to hide (used by the flat fallback look).
	if not visible:
		return
	var local: Rect2 = Rect2(rect.position - position, rect.size)
	ArenaArt.draw_block(self, local, tint, lift, face_h)
