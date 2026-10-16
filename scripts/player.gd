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
@export var move_speed: float = 240.0
## How quickly the spark reaches walking speed (pixels/second/second).
## High values = the spark answers the keys on the same frame you press them,
## which is what keeps the stealth feel tight instead of floaty.
@export var acceleration: float = 4200.0
## How quickly the spark stops when you let go of the keys.
@export var friction: float = 3800.0
## Below this speed with no keys held, the spark snaps to a dead stop so it
## never drifts a few pixels past where you meant to stand.
@export var stop_snap_speed: float = 14.0
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
## Walk cycle position, 0..1. Creates a bobbing squash feeling when moving.
var _walk_cycle: float = 0.0
## Squash factor when moving (0 = normal, 0.2 = squashed).
var _squash: float = 0.0
## The character sprite, built in _ready() from the Adventurer sheets.
var _sprite: AnimatedSprite2D = null
## Which way the character faces: "down" / "up" / "left" / "right".
var _dir: String = "down"


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

	# The character itself: a real animated figure instead of the old dot, with
	# a hue-tint shader so the artwork can show the player's current colour.
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = SpriteBank.adventurer()
	_sprite.centered = true
	_sprite.material = SpriteBank.tint_material(colour)
	add_child(_sprite)
	_update_animation()


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
	# ONE input, ONE direction: the lunge goes the way you are STEERING, so the
	# light cone, the walk and the blade all agree. If you are standing still it
	# goes where you last faced. There is deliberately no separate mouse aim -
	# the controls stay entirely on the keyboard so they never fight each other.
	var wants_dash: bool = Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("dash_aim")
	if wants_dash and dash_left <= 0.0 and dash_cooldown_left <= 0.0:
		if input.length() > 0.01:
			_dash_dir = input.normalized()
			_facing = _dash_dir.angle()
		else:
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
			# Face the way you steer. This is also the direction the light cone
			# shines, so WASD alone drives movement, facing AND sight.
			_facing = input.angle()
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			if velocity.length() <= stop_snap_speed:
				velocity = Vector2.ZERO

	# --- walk cycle ------------------------------------------------------
	# Creates a bobbing squash feeling. Faster movement = faster cycle. The
	# cosine keeps the bob smooth and seamless as the phase wraps back to 0.
	var spd: float = velocity.length()
	if spd > 50.0:
		_walk_cycle = fposmod(_walk_cycle + delta * spd / 80.0, 1.0)
		_squash = 0.5 - 0.5 * cos(_walk_cycle * TAU)
	else:
		_squash = 0.0

	move_and_slide()

	# Safety net: if a wall is ever missed, never let the spark leave the room.
	global_position.x = clampf(global_position.x, LevelData.PLAYER_RADIUS, LevelData.PLAYFIELD.x - LevelData.PLAYER_RADIUS)
	global_position.y = clampf(global_position.y, LevelData.PLAYER_RADIUS, LevelData.PLAYFIELD.y - LevelData.PLAYER_RADIUS)

	# Age the afterimages.
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i]["age"] = float(_trail[i]["age"]) + delta
		if float(_trail[i]["age"]) > 0.25:
			_trail.remove_at(i)

	_update_animation()


func _process(_delta: float) -> void:
	queue_redraw()


## Pick the animation that matches what the character is doing right now:
##   dashing -> attack_<dir>    moving -> run_<dir>    still -> idle_<dir>
func _update_animation() -> void:
	if _sprite == null:
		return
	# Apply the walk bob: a subtle vertical squash plus a small lift, so the
	# spark reads as walking even now that it is a real sprite and not a dot.
	var squash: float = _squash * 0.16
	_sprite.scale = Vector2(1.0 + squash, 1.0 - squash)
	_sprite.position = Vector2(0.0, -2.0 * _squash)
	var want: String
	if is_dashing():
		_dir = SpriteBank.dir_from_angle(_dash_dir.angle())
		want = "attack_%s" % _dir
	elif velocity.length() > 30.0:
		_dir = SpriteBank.dir_from_vector(velocity)
		want = "run_%s" % _dir
	else:
		want = "idle_%s" % _dir
	if _sprite.animation != want:
		_sprite.play(want)


## Point the tint shader at the current hue. Called whenever colour changes.
func _apply_tint() -> void:
	if _sprite != null:
		SpriteBank.set_tint(_sprite.material, colour)


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
	# The sprite is tinted by `colour`, so it has to be told the hue changed.
	_apply_tint()


## Called once by the room on touching a hostile guard.
func kill() -> void:
	if frozen:
		return
	frozen = true
	died.emit()


func get_facing() -> float:
	return _facing


## Direction the light cone points. This is simply the way the spark faces,
## which is driven entirely by WASD: the torch IS your movement direction, so
## there is no separate aiming to learn and nothing to fight the keyboard.
func aim_angle() -> float:
	return _facing


## Take on the whole hue of a colour mote. Unlike a kill, a mote is a full
## drink of colour rather than a 50% blend, because the mote is already made of
## pure hue and there is nothing to mix it with.
func drink(mote_colour: Color) -> void:
	colour = Color.from_hsv(mote_colour.h, clampf(maxf(mote_colour.s, 0.85), 0.0, 1.0),
		clampf(maxf(mote_colour.v, 0.92), 0.0, 1.0), 1.0)
	_apply_tint()


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

	# --- ground shadow -----------------------------------------------------
	# Drawn UNDER the sprite so the figure does not look like it is floating.
	draw_circle(Vector2(0.0, body_radius * 1.1), body_radius * 0.95, Color(0.0, 0.0, 0.0, 0.30))

	# --- glow --------------------------------------------------------------
	# The glow fades out when camouflaged, which is the player's clearest
	# "I am safe right now" signal. This is colour theory as game feedback.
	# It sits behind the sprite, so it reads as an aura around the figure.
	if not is_hidden:
		draw_circle(Vector2.ZERO, body_radius * 3.1, Color(colour.r, colour.g, colour.b, 0.13))
	else:
		draw_circle(Vector2.ZERO, body_radius * 1.7, Color(colour.r, colour.g, colour.b, 0.09))

	# --- dash readiness ring ----------------------------------------------
	# A thin ring that fills as the lunge recharges and closes into a full circle
	# when it is ready again. Without it the only feedback is "nothing happened".
	var ready: float = 1.0 - clampf(dash_cooldown_left / maxf(dash_cooldown, 0.01), 0.0, 1.0)
	if ready < 1.0:
		draw_arc(Vector2.ZERO, body_radius * 2.0, -PI * 0.5, -PI * 0.5 + TAU * ready, 24,
			Color(1.0, 1.0, 1.0, 0.40), 2.0, true)
	else:
		draw_arc(Vector2.ZERO, body_radius * 2.0, 0.0, TAU, 24,
			Color(colour.r, colour.g, colour.b, 0.22), 1.5, true)
