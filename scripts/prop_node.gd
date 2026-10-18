class_name PropNode
extends Node2D
##
## PROP NODE - the arena's furniture: braziers, herald pillars, rubble, bones
## and the little watch-fire torches that stand along the ring wall.
##
## A prop is drawn with its ORIGIN AT ITS BASE, the same convention the fighters
## use, so the room's y-sorting puts it in front of or behind them by ground
## line - a knight walking behind a pillar is hidden by it, a knight walking in
## front stands over it. Props that are solid also appear as a rect in the
## room's wall list; props that are clutter (rubble, bones) are picture only.
##
## Animated props (anything with fire or cloth) redraw every frame; the rest
## draw once. All art lives in ArenaArt.

## "brazier", "torch", "pillar", "rubble", "bones", and the pack dressing -
## "rock", "stump", "gold", "tool", "wood", "meat", "bush", "sheep", "tree",
## "statue_soldier", "statue_orc" (see ArenaArt.DECOR).
var kind: String = "rubble"
## The house colour, for flames and cloth.
var accent: Color = Color(1.0, 0.82, 0.25)
## Size multiplier for the bigger/smaller variants.
var prop_scale: float = 1.0
## Shared clock, so flicker is smooth instead of per-prop-random.
var time: float = 0.0


## Put the prop down: where its BASE sits, what it is, and in whose colour.
func place(at: Vector2, prop_kind: String, colour: Color, size_scale: float = 1.0) -> void:
	position = at
	kind = prop_kind
	accent = colour
	prop_scale = size_scale
	set_process(_animates())


func _animates() -> bool:
	if kind == "brazier" or kind == "torch":
		return true
	# A pack prop that has frames of its own (a bush in the wind, a grazing
	# sheep) keeps redrawing; a rock draws once.
	return ArenaArt.DECOR.has(kind) and int(ArenaArt.DECOR[kind].get("frames", 1)) > 1


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		"brazier":
			ArenaArt.draw_brazier(self, Vector2.ZERO, time, accent)
		"torch":
			ArenaArt.draw_torch(self, Vector2.ZERO, time, accent)
		"pillar":
			ArenaArt.draw_pillar(self, Vector2.ZERO, prop_scale, accent)
		"rubble":
			ArenaArt.draw_rubble(self, Vector2.ZERO, prop_scale)
		"bones":
			ArenaArt.draw_bones(self, Vector2.ZERO)
		_:
			# Everything else is a pack prop: one table, one call.
			ArenaArt.draw_decor(self, Vector2.ZERO, kind, time, prop_scale)
