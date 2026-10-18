class_name Mote
extends Node2D
##
## MOTE - a floating shard of loose colour you can pick up.
##
## Every knight carries a house hue; a mote is a chip of the wheel that
## has come loose and is drifting around the room. Touch one and you DRINK it:
## your hue snaps straight to the mote's hue, the way killing a guard would.
##
## Motes exist for three reasons:
##   1. They make the rooms read as places with things in them, not empty boxes.
##   2. They are LIGHT in a dark city. A mote glows, so it doubles as a landmark
##      and as a safe-ish thing to head for when the room is dim.
##   3. They are a second, quieter way to change your hue. In the boss room in
##      particular, a mote lets you move your complement target without having
##      to walk the whole arena to reach a small guard.
##
## A mote is consumed on pickup and does not come back until the room restarts,
## so choosing which one to take is a real decision.

## Radius of the mote's glow, in pixels. The room reads this to decide pickups.
@export var radius: float = 16.0
## The hue this mote gives you. Set by the room before the mote is added.
var colour: Color = Color.WHITE
## True once drunk; a taken mote fades out and stops being collectable.
var taken: bool = false
# Counts up for the bob + pulse, and down after being taken for the fade.
var _time: float = 0.0
var _fade: float = 1.0


func _ready() -> void:
	# Above the floor and paint (z=1), below the guards (z=2).
	z_index = 1
	# Start the bob at a random phase so a row of motes does not pulse in unison.
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	if taken:
		_fade = maxf(_fade - delta * 3.0, 0.0)
		if _fade <= 0.0:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	# A gentle bob so the mote reads as floating rather than pinned to the floor.
	var bob: float = sin(_time * 2.0) * 3.0
	var pulse: float = 0.6 + 0.4 * sin(_time * 3.0)
	var c: Color = colour
	var a: float = _fade

	# Soft outer glow: this is what makes a mote visible from across a dark room.
	draw_circle(Vector2(0.0, bob), radius * (1.5 + 0.15 * pulse),
		Color(c.r, c.g, c.b, 0.10 * a))
	draw_circle(Vector2(0.0, bob), radius * 1.1,
		Color(c.r, c.g, c.b, 0.22 * a))
	# A thin gold ring so it reads as a collectible, not just a light.
	draw_arc(Vector2(0.0, bob), radius * 0.85, 0.0, TAU, 24,
		Color(1.0, 0.85, 0.35, 0.75 * a), 2.0, true)
	# The bright core.
	draw_circle(Vector2(0.0, bob), radius * 0.42,
		Color(c.r, c.g, c.b, minf(a + 0.15, 1.0)))
	draw_circle(Vector2(0.0, bob), radius * 0.20,
		Color(1.0, 1.0, 1.0, 0.9 * a))
