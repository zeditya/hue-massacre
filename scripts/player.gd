class_name Player
extends CharacterBody2D
##
## PLAYER - "the spark".
##
## Three things make this node interesting:
##   1. Movement is plain WASD, but the only attack is the LUNGE-DASH, which is
##      also the only way to move fast. That is the whole risk/reward loop:
##      the same button that kills is the button that gets you seen.
##   2. `colour` is the player's current hue. It starts white/grey and is
##      re-mixed with every guard that dies (ColorTheory.absorb).
##   3. `visibility_now` is written by the room each frame. 0 means the floor
##      under the spark matches their hue, so guards cannot build detection.
##
## All the numbers worth tuning are the @export variables right below.

signal died
signal dashed(direction: Vector2)

@export_group("Movement")
## Walking speed in pixels/second. Guards patrol slower than this but chase
## faster than this for the first moment, so you must commit to a dash.
@export var move_speed: float = 235.0
## How quickly the spark reaches walking speed (pixels/second/second).
@export var acceleration: float = 2800.0
## How quickly the spark stops.
@export var friction: float = 2400.0
## Physics radius. Must match the collision shape built in _ready().
@export var body_radius: float = 12.0

@export_group("Lunge dash")
## Speed of the lunge. Roughly 3.5x walking speed.
@export var dash_speed: float = 820.0
## How long the lunge lasts. Short enough to feel like a stab, not a sprint.
@export var dash_duration: float = 0.15
## Seconds between lunges. Keep it long enough that spam is punished.
@export var dash_cooldown: float = 0.50
## Fading copies left behind during the lunge (pure visual juice).
@export var afterimage_count: int = 5
## Seconds between afterimage samples.
@export var afterimage_interval: float = 0.022

@export_group("Colour")
## Current hue of the spark. White going in; a mix of everything you kill.
@export var colour: Color = Color(1.0, 1.0, 1.0)
## How far each kill pulls the spark's hue towards the guard's hue (0..1).
@export var absorb_amount: float = 0.5
## Hue distance (degrees) under which the floor counts as "a match" and the
## spark is invisible. Also used by the HUD to explain hiding.
@export var hide_tolerance_deg: float = 26.0

## -1 when ready, 0..dash_duration while lunging.
var dash_left: float = 0.0
## Counts down to 0; the lunge is allowed when this hits 0.
var dash_cooldown_left: float = 0.0
## 0..1 how camouflaged the spark is (written by the room every frame).
var visibility_now: float = 1.0
## True when standing in paint that matches the spark's hue.
var is_hidden: bool = false
## Frozen while the death animation plays.
var frozen: bool = false

var _dash_dir: Vector2 = Vector2.RIGHT
var _facing: float = 0.0
var _trail: Array = []
var _trail_timer: float = 0.0


func _ready() -> void:
	# Actors live on layer 2 but only collide with layer 1 (the walls), so the
	# player and guards pass through each other. Touching is detected by
	# distance in room.gd, which is far more predictable than physics contacts.
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	# Top of the room's draw order so the spark is never hidden by a cone.
	z_index = 3


func _physics_process(delta: float) -> void:
	dash_left = maxf(dash_left - delta, 0.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)

	if frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# --- reading input -----------------------------------------------------
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# --- starting a lunge --------------------------------------------------
	var wants_dash: bool = Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("dash_aim")
	if wants_dash and dash_left <= 0.0 and dash_cooldown_left <= 0.0:
		if Input.is_action_just_pressed("dash_aim"):
			# Left click lunges TOWARDS THE MOUSE. This is the precise option.
			var to_mouse: Vector2 = get_global_mouse_position() - global_position
			_dash_dir = to_mouse.normalized() if to_mouse.length() > 4.0 else Vector2.RIGHT.rotated(_facing)
		else:
			# Space lunges the way you are already facing. This is the fast option.
			_dash_dir = Vector2.RIGHT.rotated(_facing)
		dash_left = dash_duration
		dash_cooldown_left = dash_cooldown
		_trail.clear()
		dashed.emit(_dash_dir)

	# --- moving ------------------------------------------------------------
	if dash_left > 0.0:
		velocity = _dash_dir * dash_speed
		# Leave a fading copy of ourselves behind roughly every 22ms.
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = afterimage_interval
			_trail.append({"pos": global_position, "age": 0.0})
			if _trail.size() > afterimage_count:
				_trail.pop_front()
	else:
		var target: Vector2 = input * move_speed
		if input.length() > 0.01:
			velocity = velocity.move_toward(target, acceleration * delta)
			_facing = input.angle()
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# Safety net: if a wall is ever missed, never let the spark leave the room.
	global_position.x = clampf(global_position.x, LevelData.PLAYER_RADIUS, LevelData.PLAYFIELD.x - LevelData.PLAYER_RADIUS)
	global_position.y = clampf(global_position.y, LevelData.PLAYER_RADIUS, LevelData.PLAYFIELD.y - LevelData.PLAYER_RADIUS)

	# Age the afterimages.
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i]["age"] = float(_trail[i]["age"]) + delta
		if float(_trail[i]["age"]) > 0.25:
			_trail.remove_at(i)


func _process(_delta: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------------------
# Public API used by the room
# ---------------------------------------------------------------------------

## True while the blade is out and able to kill a guard.
func is_dashing() -> bool:
	return dash_left > 0.0


## Fly forward at the moment of a kill (a tiny lunge extension).
func get_blade_direction() -> Vector2:
	return _dash_dir if dash_left > 0.0 else Vector2.RIGHT.rotated(_facing)


## Take on `guard_colour` using HSV hue blending.
func absorb_colour(guard_colour: Color) -> void:
	colour = ColorTheory.absorb(colour, guard_colour, absorb_amount)


## Called once by the room on touching a hostile guard.
func kill() -> void:
	if frozen:
		return
	frozen = true
	died.emit()


func get_facing() -> float:
	return _facing


# ---------------------------------------------------------------------------
# Drawing - everything is vector shapes so there are no art assets
# ---------------------------------------------------------------------------

func _draw() -> void:
	# --- dash afterimages --------------------------------------------------
	# Local space equals world space offset from global_position because the
	# node is never rotated or scaled, so we can subtract the offset and draw.
	for t in _trail:
		var age: float = float(t["age"])
		var fade: float = clampf(1.0 - age / 0.25, 0.0, 1.0)
		var local: Vector2 = (t["pos"] as Vector2) - global_position
		draw_circle(local, body_radius * (1.0 - 0.3 * (1.0 - fade)), Color(colour.r, colour.g, colour.b, fade * 0.35))

	# --- glow --------------------------------------------------------------
	# The glow fades out when camouflaged, which is the player's clearest
	# "I am safe right now" signal. This is colour theory as game feedback.
	if not is_hidden:
		draw_circle(Vector2.ZERO, body_radius * 2.6, Color(colour.r, colour.g, colour.b, 0.14))
		draw_circle(Vector2.ZERO, body_radius * 1.7, Color(colour.r, colour.g, colour.b, 0.20))
	else:
		draw_circle(Vector2.ZERO, body_radius * 1.35, Color(colour.r, colour.g, colour.b, 0.10))

	# --- body --------------------------------------------------------------
	draw_circle(Vector2.ZERO, body_radius + 2.0, Color(0.03, 0.03, 0.05, 0.9))
	draw_circle(Vector2.ZERO, body_radius, colour)
	# A bright core so the spark always reads as "light", whatever its hue.
	draw_circle(Vector2.ZERO, body_radius * 0.35, Color(1.0, 1.0, 1.0, 0.95))

	# --- rim ---------------------------------------------------------------
	# White rim = exposed. Grey rim = camouflaged. Readable at a glance.
	var rim: Color = Color(0.62, 0.62, 0.70, 0.55) if is_hidden else Color(1.0, 1.0, 1.0, 0.95)
	draw_arc(Vector2.ZERO, body_radius + 1.0, 0.0, TAU, 28, rim, 2.0, true)

	# --- facing wedge ------------------------------------------------------
	var fwd: Vector2 = Vector2.RIGHT.rotated(_facing)
	var side: Vector2 = fwd.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		fwd * (body_radius + 7.0),
		fwd * (body_radius - 1.0) + side * 4.5,
		fwd * (body_radius - 1.0) - side * 4.5,
	]), Color(1.0, 1.0, 1.0, 0.9))

	# --- the blade ---------------------------------------------------------
	# Only drawn during the lunge, so it doubles as the cooldown indicator.
	if is_dashing():
		var blade_dir: Vector2 = _dash_dir
		var blade_side: Vector2 = blade_dir.orthogonal()
		var tip: Vector2 = blade_dir * (body_radius + 26.0)
		draw_colored_polygon(PackedVector2Array([
			tip,
			blade_dir * (body_radius + 2.0) + blade_side * 7.0,
			blade_dir * (body_radius + 2.0) - blade_side * 7.0,
		]), Color(0.92, 0.96, 1.0, 0.95))
		# A thin white slash arc sells the swing.
		draw_arc(Vector2.ZERO, body_radius + 20.0,
			blade_dir.angle() - 0.65, blade_dir.angle() + 0.65, 14,
			Color(1.0, 1.0, 1.0, 0.55), 3.0, true)
