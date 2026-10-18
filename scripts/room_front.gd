class_name RoomFront
extends Node2D
##
## ROOM FRONT - everything that may never be hidden: the weather, the dust in
## the air, the vignette and the combat flashes.
##
## The room's own drawings and its wall/prop nodes all live at ground level, so
## they can be covered by whatever stands in front of them. This layer sits at
## z=10, above every one of them, and asks the room to draw its front pass.
## Its `_draw` is refreshed every frame, because weather and flashes move.

var room: Room = null


func _process(_delta: float) -> void:
	if room != null:
		queue_redraw()


func _draw() -> void:
	if room != null:
		room.draw_front(self)
