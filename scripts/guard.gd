class_name Guard
extends CharacterBody2D
##
## GUARD - a Collector's thug carrying one stolen colour.
##
## THE DETECTION RULE (this is the colour theory exam question):
## a guard can only fill its detection meter when ALL THREE are true:
##
##   1. the player is inside the vision cone (an angle test), AND
##   2. there is clear line of sight - no wall between them, AND
##   3. the player's hue CONTRASTS with the colour of the floor under them.
##
## Condition 3 is the interesting one. `ColorTheory.visibility()` returns 0
## when the paint you are standing in matches your own hue, and that is
## simultaneous contrast: same hue side by side = the edge between them
## disappears. Standing on bare grey floor always returns 1.0, because a grey
## floor has no hue to match, so you are always visible in an unpainted room.
##
## States: PATROL -> INVESTIGATE (walk to where it last saw you) -> PATROL,
## with CHASE taking over the moment detection hits 1.0.
##
## Every tunable is an @export below.

signal killed(guard: Guard)
## Emitted the moment this guard locks on. The room uses it to spread the alarm.
signal spotted(pos: Vector2)

enum State { PATROL, INVESTIGATE, CHASE }
## Swing state machine: NONE -> WINDUP -> RECOVER -> NONE.
enum Attack { NONE, WINDUP, RECOVER }

## Things guards say. "%s" is replaced with the guard's own colour name, so a
## blue guard shouts about the blue one, and the banter teaches the wheel.
const BARKS := {
	"alert": [
		"...a colour?",
		"Who's there?",
		"What was that?",
		"I saw something move.",
	],
	"spotted": [
		"There - the %s one!",
		"Stop, %s!",
		"I see %s!",
		"Got you, %s thief!",
	],
	"lost": [
		"Where did it go?",
		"Must have slipped past.",
		"...gone.",
	],
	"investigate": [
		"I know you're here.",
		"Come out, come out...",
		"Just a rat... maybe.",
		"Keep looking.",
	],
	"stagger": [
		"My hue - it cracks!",
		"No! Not my colour!",
		"The wheel hates me...",
	],
}

@export_group("Colour")
## The stolen colour this guard carries. It becomes the splat on death.
@export var colour: Color = Color(1.0, 0.0, 0.0)
## Degrees/second the colour rotates around the wheel. Only the boss uses this.
@export var hue_speed: float = 0.0
## True for the Collector: bigger body, drawn ring of the whole hue wheel.
@export var is_boss: bool = false

@export_group("Body")
@export var body_radius: float = 14.0
## Guards double as the room's grammar, so they turn rather than snap.
@export var turn_speed_deg: float = 260.0

@export_group("Patrol")
@export var patrol_points: PackedVector2Array = PackedVector2Array()
@export var patrol_speed: float = 75.0
## Seconds spent looking around at each end of the route.
@export var wait_at_point: float = 0.7
## How close counts as "arrived at the waypoint".
@export var arrive_radius: float = 7.0

@export_group("Chase")
@export var chase_speed: float = 165.0
## Seconds of not seeing the player before giving up and searching.
@export var lose_time: float = 2.0
## Longest a guard will spend walking to where it last saw you before it gives
## up and goes back to its patrol. Without this a guard whose last-seen spot sits
## behind a wall walks into that wall forever and never patrols again.
@export var investigate_time: float = 5.0

@export_group("Combat")
## Health. 60 means a basic knight dies to two neutral cuts, or one complement
## shatter plus any follow-up.
@export var max_hp: float = 60.0
## Damage one swing deals to the player.
@export var damage: float = 12.0
## How close the player must be before the windup starts.
@export var attack_range: float = 46.0
## How far the swing actually reaches when the blade falls.
@export var attack_reach: float = 60.0
## Half-angle of the swing arc, in degrees.
@export var attack_half_deg: float = 65.0
## Seconds of windup before the blade falls. This is the whole read.
@export var attack_windup: float = 0.55
## Seconds of recovery after a swing: the player's punish window.
@export var attack_recover: float = 0.55
## Seconds between swings.
@export var attack_cooldown: float = 1.0
## Seconds knocked silly by a complement shatter (armour break).
@export var stagger_time: float = 1.0

@export_group("Vision")
## How far the cone reaches, in pixels.
@export var cone_length: float = 310.0
## Full width of the cone in degrees. Half of this is the half-angle.
@export var cone_angle_deg: float = 64.0
## Seconds of full contrast needed to go from unaware to chasing.
@export var detect_time: float = 0.45
## How fast the meter drains when the guard cannot see you.
@export var detect_decay: float = 1.15
## Number of rays used to clip the drawn cone against walls. Purely visual.
@export var cone_rays: int = 22
## Must match Player.hide_tolerance_deg, or the drawing would lie about the rules.
@export var hide_tolerance_deg: float = 26.0

## Written by the room; needed for walls and for reading the player.
var room: Node2D = null

var state: State = State.PATROL
## 0..1, how close this guard is to spotting the player.
var detection: float = 0.0
## True on the frame the boss is inside the player's kill window (boss only).
var vulnerable: bool = false
var dead: bool = false

## Current health. Reaching 0 runs the normal die() path.
var hp: float = 60.0
## 0..1 flash when a strike lands (white hit pop).
var hit_flash: float = 0.0
## 0..1 flash for a strike that glanced off without doing anything.
var clang_flash: float = 0.0
## Seconds of shatter-stagger left: no moving, no attacking, no watching.
var stagger_left: float = 0.0
## Which beat of a swing this guard is on.
var attack_state: Attack = Attack.NONE
## Counts down inside WINDUP and RECOVER.
var _attack_left: float = 0.0
## Counts down between swings.
var _attack_cooldown_left: float = 0.0
## 0..1 fade of the swing arc drawn right after the blade falls.
var _swing_flash: float = 0.0
## Serial of the last lunge that hit this guard, so one lunge hits once.
var _last_dash_serial: int = -1

var _facing: float = 0.0
var _point_index: int = 0
var _point_dir: int = 1
var _wait_left: float = 0.0
var _last_seen: Vector2 = Vector2.ZERO
var _lost_timer: float = 0.0
## Counts down while investigating; hitting 0 abandons the search.
var _investigate_left: float = 0.0
var _sight_quality: float = 0.0
var _death_left: float = 0.0
var _time: float = 0.0
## Walk cycle position, 0..TAU. Driven by the guard's ACTUAL speed, so the
## stride length can never disagree with how fast it is really moving.
var _walk_phase: float = 0.0
## 0..1, a short pop when detection jumps. Purely the "I've been spotted"
## reaction - it gives the player a fraction of a second of warning.
var _alert_pop: float = 0.0
## The character sprite, built in _ready() and tinted to this guard's hue.
var _sprite: AnimatedSprite2D = null
## Which way the guard faces: "down" / "up" / "left" / "right".
var _dir: String = "down"
## The line this guard is currently saying, and how long it has left to say it.
## Public because the HUD draws the bubbles (above the darkness layer).
var bark_text: String = ""
var bark_left: float = 0.0
var bark_total: float = 2.0
var bark_colour: Color = Color(1.0, 1.0, 1.0)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	# Above the paint, below the player.
	z_index = 2
	# Face the first waypoint so the cone does not start pointing at nothing.
	if patrol_points.size() >= 2:
		_facing = (patrol_points[1] - patrol_points[0]).angle()

	# A real human figure, tinted to the stolen colour this guard carries. The
	# hue is the whole point of the game, so the art is recoloured rather than
	# drawn in its own fixed palette.
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = SpriteBank.adventurer()
	_sprite.centered = true
	_sprite.material = SpriteBank.tint_material(colour)
	add_child(_sprite)
	hp = max_hp
	_update_animation()


func _process(delta: float) -> void:
	_time += delta
	bark_left = maxf(bark_left - delta, 0.0)
	hit_flash = maxf(hit_flash - delta * 4.0, 0.0)
	clang_flash = maxf(clang_flash - delta * 4.0, 0.0)
	_swing_flash = maxf(_swing_flash - delta * 3.5, 0.0)
	# A staggered knight reels visibly, so the armour break cannot be missed.
	if _sprite != null:
		_sprite.rotation = sin(_time * 34.0) * 0.22 if stagger_left > 0.0 else 0.0
	if dead:
		_death_left = maxf(_death_left - delta, 0.0)
		if _death_left <= 0.0:
			queue_free()
		queue_redraw()
		return

	# --- walk cycle ------------------------------------------------------
	# Stride frequency is speed / stride-length, which is what makes a walking
	# guard and a sprinting guard look like different animations instead of the
	# same one played faster. Idle guards get a slow breathing sway so they are
	# never a completely static sprite.
	var spd: float = velocity.length()
	if spd > 1.0:
		_walk_phase = fposmod(_walk_phase + delta * (TAU * spd / 110.0), TAU)
	else:
		_walk_phase = fposmod(_walk_phase + delta * 1.6, TAU)

	# --- spotted reaction -------------------------------------------------
	# Pops up the instant detection starts filling, then eases back down.
	_alert_pop = maxf(_alert_pop - delta * 3.0, 0.0)
	_update_animation()
	# The Collector drags its hue around the wheel, so its sprite has to be
	# re-tinted as the hue moves. Only the boss does this.
	if not is_zero_approx(hue_speed):
		SpriteBank.set_tint(_sprite.material, colour)
	queue_redraw()


## Pick the animation for what the guard is doing. A moving guard runs, a
## standing one idles, and either way it faces where its vision cone points.
func _update_animation() -> void:
	if _sprite == null:
		return
	_dir = SpriteBank.dir_from_angle(_facing)
	var want: String = ("run_%s" if velocity.length() > 5.0 else "idle_%s") % _dir
	if _sprite.animation != want:
		_sprite.play(want)


func _physics_process(delta: float) -> void:
	if dead:
		return

	# --- the Collector drags the stolen wheel around ----------------------
	if not is_zero_approx(hue_speed):
		colour = Color.from_hsv(fposmod(colour.h + (hue_speed / 360.0) * delta, 1.0), colour.s, colour.v, 1.0)

	# --- shatter stagger --------------------------------------------------
	# A complement strike breaks the armour: the knight reels and can do
	# nothing until it recovers. This is the player's reward window, and it
	# also cancels any swing mid-windup.
	if stagger_left > 0.0:
		stagger_left = maxf(stagger_left - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
		if stagger_left <= 0.0:
			attack_state = Attack.NONE
			_attack_left = 0.0
		move_and_slide()
		return

	_perceive(delta)

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.INVESTIGATE:
			_do_investigate(delta)
		State.CHASE:
			_do_chase(delta)

	move_and_slide()


# ---------------------------------------------------------------------------
# Perception
# ---------------------------------------------------------------------------

func _current_speed() -> float:
	return chase_speed if state == State.CHASE else patrol_speed


func _perceive(delta: float) -> void:
	var sees: bool = false
	_sight_quality = 0.0

	var player: Player = _player()
	if player != null and not player.frozen and not dead:
		var in_cone: bool = _inside_cone(player.global_position)
		if in_cone:
			# Wall check: the same line test the cone is drawn with.
			var clear: bool = room == null or room.has_line_of_sight(global_position, player.global_position)
			if clear:
				# The colour test. Ground colour comes from the paint layer.
				var ground: Color = ColorTheory.FLOOR_GREY
				if room != null:
					ground = room.ground_colour_at(player.global_position)
				var vis: float = ColorTheory.visibility(player.colour, ground, hide_tolerance_deg)
				if vis > 0.0:
					sees = true
					_sight_quality = vis
					_last_seen = player.global_position

	# The room gives everybody a moment to get their bearings at the start.
	var awake: bool = room == null or room.time_in_room >= LevelData.SPAWN_GRACE

	if sees and awake:
		var was: float = detection
		detection = clampf(detection + delta * (_sight_quality / maxf(detect_time, 0.01)), 0.0, 1.0)
		# The first frame the meter actually moves is the moment to flinch, so
		# the player gets told they have been seen before the chase begins.
		if was <= 0.001 and detection > 0.001:
			_alert_pop = 1.0
			_say("alert")
		if detection >= 1.0:
			if state != State.CHASE:
				spotted.emit(global_position)
				_say("spotted")
			state = State.CHASE
			_lost_timer = 0.0
		elif state == State.CHASE:
			# Re-acquiring line of sight restarts the give-up countdown, so a
			# guard that keeps glimpsing you through gaps does not suddenly
			# forget you the moment the gap closes again.
			_lost_timer = 0.0
	else:
		detection = clampf(detection - delta * detect_decay, 0.0, 1.0)
		if state == State.CHASE:
			_lost_timer += delta
			if _lost_timer >= lose_time:
				# Give up the chase but go and poke around where we last saw them.
				state = State.INVESTIGATE
				_lost_timer = 0.0
				_wait_left = 0.0
				_investigate_left = investigate_time
				detection = 0.0
				attack_state = Attack.NONE
				_say("lost")


func _player() -> Player:
	if room == null:
		return null
	return room.player


func _inside_cone(point: Vector2) -> bool:
	var to_point: Vector2 = point - global_position
	var dist: float = to_point.length()
	if dist > cone_length:
		return false
	if dist < 1.0:
		return true
	var half: float = deg_to_rad(cone_angle_deg * 0.5)
	return absf(_angle_delta(to_point.angle(), _facing)) <= half


## Signed shortest difference between two angles, wrapped to -PI..PI.
func _angle_delta(a: float, b: float) -> float:
	return fposmod(a - b + PI, TAU) - PI


func _turn_towards(target_angle: float, delta: float, speed_deg: float) -> void:
	var diff: float = _angle_delta(target_angle, _facing)
	var step: float = deg_to_rad(speed_deg) * delta
	if absf(diff) <= step:
		_facing = target_angle
	else:
		_facing = fposmod(_facing + signf(diff) * step, TAU)


# ---------------------------------------------------------------------------
# Behaviours
# ---------------------------------------------------------------------------

func _do_patrol(delta: float) -> void:
	if patrol_points.size() == 0:
		velocity = Vector2.ZERO
		return

	var target: Vector2 = patrol_points[_point_index]
	var to_target: Vector2 = target - global_position

	if to_target.length() <= arrive_radius:
		# Arrived: stop, look around, then head for the next waypoint. The tiny
		# floor keeps a zero `wait_at_point` from deadlocking at the waypoint.
		velocity = Vector2.ZERO
		if _wait_left <= 0.0:
			_wait_left = maxf(wait_at_point, 0.001)
		else:
			_wait_left -= delta
			# Sweep the head slowly while waiting so the cone feels alive.
			_facing = fposmod(_facing + deg_to_rad(38.0) * delta, TAU)
			if _wait_left <= 0.0:
				_advance_point()
		# Face the next waypoint as soon as we start moving again.
		if _wait_left <= 0.0 and patrol_points.size() > 1:
			_turn_towards((patrol_points[_point_index] - global_position).angle(), delta, turn_speed_deg)
		return

	_turn_towards(to_target.angle(), delta, turn_speed_deg)
	velocity = Vector2.RIGHT.rotated(_facing) * patrol_speed


## Walk along the waypoint list, reversing at each end (a ping-pong route).
func _advance_point() -> void:
	if patrol_points.size() <= 1:
		return
	_point_index += _point_dir
	if _point_index >= patrol_points.size():
		_point_index = patrol_points.size() - 2
		_point_dir = -1
	elif _point_index < 0:
		_point_index = 1
		_point_dir = 1


func _do_investigate(delta: float) -> void:
	_investigate_left = maxf(_investigate_left - delta, 0.0)
	var to_target: Vector2 = _last_seen - global_position
	if to_target.length() <= arrive_radius + 6.0:
		velocity = Vector2.ZERO
		# Look around for a beat, then go back to work.
		_facing = fposmod(_facing + deg_to_rad(70.0) * delta, TAU)
		_wait_left += delta
		if _wait_left > 1.4:
			_wait_left = 0.0
			_snap_to_nearest_point()
			state = State.PATROL
		return
	if _investigate_left <= 0.0:
		# Took too long to reach the spot (it is behind a wall, or too far):
		# give up and resume the patrol instead of walking into geometry forever.
		_wait_left = 0.0
		_snap_to_nearest_point()
		state = State.PATROL
		return
	_turn_towards(to_target.angle(), delta, turn_speed_deg * 1.4)
	velocity = Vector2.RIGHT.rotated(_facing) * patrol_speed * 1.15


func _do_chase(delta: float) -> void:
	var player: Player = _player()
	if player == null:
		state = State.PATROL
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	# Snappier turning while hunting: they are locked on now.
	_turn_towards(to_player.angle(), delta, turn_speed_deg * 2.2)

	match attack_state:
		Attack.WINDUP:
			# Braced for the swing: planted, and the telegraph in _draw is
			# the entire read for the player.
			velocity = Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				_swing(player)
		Attack.RECOVER:
			# The blade is heavy: a punish window right after every swing.
			velocity = Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				attack_state = Attack.NONE
		_:
			_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
			if dist <= attack_range and _attack_cooldown_left <= 0.0 and not player.frozen:
				attack_state = Attack.WINDUP
				_attack_left = attack_windup
			elif dist > attack_range * 0.85:
				velocity = Vector2.RIGHT.rotated(_facing) * chase_speed
			else:
				velocity = Vector2.ZERO


## The blade falls: anything still inside the arc takes the hit.
func _swing(player: Player) -> void:
	attack_state = Attack.RECOVER
	_attack_left = attack_recover
	_attack_cooldown_left = attack_cooldown
	_swing_flash = 1.0
	var to_player: Vector2 = player.global_position - global_position
	var inside: bool = to_player.length() <= attack_reach + player.body_radius \
		and absf(_angle_delta(to_player.angle(), _facing)) <= deg_to_rad(attack_half_deg)
	if inside:
		player.take_damage(damage, global_position)


## After a failed search, resume from whichever waypoint is closest.
func _snap_to_nearest_point() -> void:
	var best: int = 0
	var best_d: float = INF
	for i in patrol_points.size():
		var d: float = global_position.distance_squared_to(patrol_points[i])
		if d < best_d:
			best_d = d
			best = i
	_point_index = best
	_point_dir = 1


## A noise was heard at `at` (a lunge nearby, or an ally shouting). Break off
## and go and look, unless already hunting the player for real.
func hear(at: Vector2) -> void:
	if dead or state == State.CHASE:
		return
	state = State.INVESTIGATE
	_last_seen = at
	_wait_left = 0.0
	_investigate_left = investigate_time
	detection = 0.0
	_say("investigate")


## Say a random line for `event`. A "%s" in the line is filled with this
## guard's own colour name.
func _say(event: String) -> void:
	var lines: Array = BARKS.get(event, [])
	if lines.is_empty():
		return
	var line: String = str(lines[randi() % lines.size()])
	if line.find("%s") >= 0:
		line = line % ColorTheory.color_name(colour)
	bark_text = line
	bark_left = 2.0
	bark_total = 2.0
	bark_colour = colour


# ---------------------------------------------------------------------------
# Taking hits
# ---------------------------------------------------------------------------

## The room calls this when the player's blade connects. `amount` is already
## hue-multiplied; `shatter` marks a complement strike. Returns true when the
## strike actually landed.
func take_hit(amount: float, shatter: bool, from_position: Vector2, dash_serial: int) -> bool:
	if dead:
		return false
	# One lunge only hits each guard once, no matter how many physics frames
	# the bodies overlap.
	if dash_serial == _last_dash_serial:
		return false
	_last_dash_serial = dash_serial

	hp = maxf(hp - amount, 0.0)
	hit_flash = 1.0
	# Everything flinches briefly; a shatter knocks the knight down properly.
	stagger_left = maxf(stagger_left, stagger_time if shatter else 0.18)
	var away: Vector2 = global_position - from_position
	if away.length() > 0.001:
		velocity += away.normalized() * (240.0 if shatter else 90.0)
	if shatter:
		_say("stagger")

	if hp <= 0.0:
		die()
	return true


## A strike that glanced off without doing anything (the Collector's shield,
## outside the complement window). Purely feedback.
func clang() -> void:
	clang_flash = 1.0


## Health left as 0..1, for the over-head bar.
func health_ratio() -> float:
	return clampf(hp / maxf(max_hp, 0.01), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Death
# ---------------------------------------------------------------------------

## Called by the room when the blade connects.
func die() -> void:
	if dead:
		return
	dead = true
	detection = 0.0
	attack_state = Attack.NONE
	velocity = Vector2.ZERO
	_death_left = 0.30
	# Stop colliding with anything the moment we are dead.
	set_physics_process(false)
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	killed.emit(self)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if dead:
		# A quick white pop instead of an enemy that simply vanishes.
		var t: float = 1.0 - clampf(_death_left / 0.26, 0.0, 1.0)
		draw_circle(Vector2.ZERO, body_radius * (1.0 + t * 1.6), Color(1.0, 1.0, 1.0, (1.0 - t) * 0.8))
		return

	var body: Color = colour

	# --- the vision cone --------------------------------------------------
	# Drawn from a fan of rays, each one clipped at the first wall it hits, so
	# what you SEE is exactly what the line-of-sight check does.
	var half: float = deg_to_rad(cone_angle_deg * 0.5)
	var steps: int = maxi(cone_rays, 4)
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in steps + 1:
		var a: float = _facing - half + (2.0 * half) * (float(i) / float(steps))
		var dir: Vector2 = Vector2.RIGHT.rotated(a)
		var reach: float = cone_length
		if room != null:
			reach = cone_length * room.raycast_distance(global_position, global_position + dir * cone_length)
		points.append(dir * reach)

	# The cone brightens as the guard notices you - a free tutorial in itself.
	var alert: float = clampf(detection, 0.0, 1.0)
	var cone_fill: Color = Color(body.r, body.g, body.b, 0.16 + 0.18 * alert)
	var cone_edge: Color = Color(body.r, body.g, body.b, 0.50 + 0.45 * alert)
	draw_colored_polygon(points, cone_fill)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(Vector2.ZERO)
	draw_polyline(outline, cone_edge, 1.5)

	# --- swing telegraph and blade arc ------------------------------------
	# The windup wedge grows towards the swing's reach; the flashing wedge
	# right after the blade falls shows exactly where it went. Both are drawn
	# on the ground, so "where will the hit land" is never a guess. The warm
	# gold is deliberately NOT the guard's own hue: the telegraph has to read
	# on top of the vision cone the guard is standing in.
	if attack_state == Attack.WINDUP:
		var wt: float = clampf(1.0 - _attack_left / maxf(attack_windup, 0.01), 0.0, 1.0)
		_draw_wedge(deg_to_rad(attack_half_deg), attack_reach * (0.55 + 0.45 * wt),
			Color(1.0, 0.82, 0.42, 0.10 + 0.24 * wt),
			Color(1.0, 0.70, 0.30, 0.35 + 0.65 * wt))
	if _swing_flash > 0.0:
		_draw_wedge(deg_to_rad(attack_half_deg), attack_reach,
			Color(1.0, 0.95, 0.82, 0.38 * _swing_flash),
			Color(1.0, 1.0, 1.0, 0.55 * _swing_flash))

	# --- ground shadow ----------------------------------------------------
	# The body itself is the character sprite (built in _ready). This just stops
	# the figure from looking like it is floating above the floor.
	draw_circle(Vector2(0.0, body_radius * 1.1), body_radius * 1.05, Color(0.0, 0.0, 0.0, 0.30))

	# --- damage feedback --------------------------------------------------
	# Drawn under the sprite, so each one reads as an aura around the figure.
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, body_radius * 1.5, Color(1.0, 1.0, 1.0, 0.45 * hit_flash))
	if clang_flash > 0.0:
		draw_arc(Vector2.ZERO, body_radius * 1.9, 0.0, TAU, 22,
			Color(0.85, 0.95, 1.0, 0.75 * clang_flash), 3.0, true)
	if stagger_left > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(_time * 30.0)
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 26,
			Color(1.0, 1.0, 1.0, 0.30 + 0.35 * pulse), 2.5, true)

	# --- detection meter --------------------------------------------------
	if detection > 0.01:
		var w: float = 38.0
		var y: float = -body_radius - 16.0
		draw_rect(Rect2(-w * 0.5, y, w, 5.0), Color(0.0, 0.0, 0.0, 0.65))
		var meter: Color = Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.15, 0.15), detection)
		draw_rect(Rect2(-w * 0.5, y, w * detection, 5.0), meter)

	# --- health bar -------------------------------------------------------
	# Shown once damaged (or while hunting) so a fresh room stays clean but a
	# fight reads at a glance.
	if hp < max_hp - 0.001 or state == State.CHASE:
		var hw: float = 34.0
		var hy: float = -body_radius - 42.0
		var ratio: float = health_ratio()
		draw_rect(Rect2(-hw * 0.5 - 1.0, hy - 1.0, hw + 2.0, 6.0), Color(0.0, 0.0, 0.0, 0.65))
		var hp_colour: Color = Color(0.95, 0.25, 0.25).lerp(Color(0.35, 0.90, 0.35), ratio)
		draw_rect(Rect2(-hw * 0.5, hy, hw * ratio, 4.0), hp_colour)

	# --- state marker -----------------------------------------------------
	if state == State.CHASE:
		# A fat red "!" bar so you can read the room at a glance.
		draw_rect(Rect2(-3.0, -body_radius - 34.0, 6.0, 14.0), Color(1.0, 0.2, 0.2))
		draw_circle(Vector2(0.0, -body_radius - 15.0), 2.6, Color(1.0, 0.2, 0.2))
	elif state == State.INVESTIGATE:
		draw_circle(Vector2(0.0, -body_radius - 22.0), 4.0, Color(1.0, 0.85, 0.2, 0.9))

	# --- Collectors' boss extras -----------------------------------------
	if is_boss:
		# A ring of the whole hue wheel, spinning with the boss's hue: a visual
		# reminder that he is the one holding the wheel.
		var segments: int = 24
		var base: float = colour.h * 360.0
		for i in segments:
			var a0: float = (float(i) / float(segments)) * TAU
			var a1: float = (float(i + 1) / float(segments)) * TAU
			var seg_colour: Color = ColorTheory.wheel(base + float(i) * (360.0 / float(segments)))
			draw_arc(Vector2.ZERO, body_radius + 9.0, a0, a1, 4, seg_colour, 5.0, true)
		# The kill window: a hard white halo that ONLY appears when the player's
		# hue is sitting on his complement. Look for this and lunge.
		if vulnerable:
			var pulse: float = 0.6 + 0.4 * sin(_time * 14.0)
			draw_circle(Vector2.ZERO, body_radius + 20.0, Color(1.0, 1.0, 1.0, 0.10 * pulse))
			draw_arc(Vector2.ZERO, body_radius + 17.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.9), 3.0, true)

	# --- floating label (typography that teaches the wheel) --------------
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var label: String = "%s %d" % [ColorTheory.color_name(body), ColorTheory.hue_degrees(body)]
		var label_colour: Color = Color(1.0, 1.0, 1.0, 0.78)
		draw_string(font, Vector2(-60.0, body_radius + 18.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 12, Color(0.0, 0.0, 0.0, 0.6))
		draw_string(font, Vector2(-60.0, body_radius + 17.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 120.0, 12, label_colour)


## A filled pie slice from the guard's centre towards `_facing`, spreading
## `half` radians either side and reaching `reach` pixels. `edge` outlines it
## (pass a zero-alpha colour to skip the outline).
func _draw_wedge(half: float, reach: float, colour: Color, edge: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var steps: int = 10
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in steps + 1:
		var a: float = _facing - half + (2.0 * half) * (float(i) / float(steps))
		pts.append(Vector2.RIGHT.rotated(a) * reach)
	draw_colored_polygon(pts, colour)
	if edge.a > 0.0:
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(Vector2.ZERO)
		draw_polyline(outline, edge, 2.5)
