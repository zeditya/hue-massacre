class_name Guard
extends CharacterBody2D
##
## GUARD - a knight of the Grand Melee, carrying one house hue.
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
## Boss only: the Champion crossed into a new phase (2 or 3). The game uses
## this for the herald's announcement.
signal phase_changed(phase: int)
## Boss only: the Champion calls his Aspirants. The room answers by spawning
## the next entries of the room's "summons" list.
signal summons_requested(count: int)
## Boss only: the charge telegraph finished and he is committed to the dash.
signal charge_started()

enum State { PATROL, INVESTIGATE, CHASE }
## Swing state machine: NONE -> WINDUP -> RECOVER -> NONE.
enum Attack { NONE, WINDUP, RECOVER }
## Boss charge state machine: NONE -> WINDUP -> DASH -> RECOVER -> NONE.
enum Charge { NONE, WINDUP, DASH, RECOVER }

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
	# Boss only: the wait before the charging dash, and the summons.
	"charge": [
		"The wheel will not be denied!",
		"Stand and take your colour!",
		"I am the Champion - I do not miss!",
	],
	"summon": [
		"Aspirants! To the Champion!",
		"Let the melee be joined!",
		"Crowd, claim your due!",
	],
}

@export_group("Colour")
## The house hue this knight carries. It becomes the splat on death.
@export var colour: Color = Color(1.0, 0.0, 0.0)
## Degrees/second the colour rotates around the wheel. Only the boss uses this.
@export var hue_speed: float = 0.0
## True for the Champion: bigger body, drawn ring of the whole hue wheel.
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

@export_group("Boss phases")
## HP ratio at or below which the Champion enters phase II (adds the charge).
@export var phase_two_ratio: float = 0.66
## HP ratio at or below which he enters phase III (summons + spins faster).
@export var phase_three_ratio: float = 0.33
## How much faster the wheel spins once he is losing.
@export var phase_three_hue_scale: float = 1.8
## Aspirants called in when phase III begins.
@export var summons_count: int = 2

@export_group("Boss charge")
## The telegraphed dash: a long, locked lane then a committed sprint.
@export var charge_windup: float = 0.65
@export var charge_duration: float = 0.55
@export var charge_recover: float = 0.75
@export var charge_speed: float = 620.0
@export var charge_damage: float = 22.0
## Seconds between charges. Phase III uses this too, so the duel still breathes.
@export var charge_cooldown: float = 3.4
## Only charges if the player is between these distances: too close and a
## normal sweep is the fairer attack, too far and the dash would be uncatchable.
@export var charge_min_range: float = 90.0
@export var charge_range: float = 300.0

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
## True while this knight waits off the field for a later wave (room.gd feeds
## the waves in). Dormant guards are hidden, inert and deaf.
var dormant: bool = false
## Room-time (room.time_in_room) before which this guard cannot see. Set when
## a later wave marches in, so arriving is never an instant ambush.
var spawn_grace_until: float = 0.0

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
## Boss only: which of his three phases he is in. Phases change on HP
## thresholds and never go backwards.
var boss_phase: int = 1
## Boss only: the charging-dash state machine.
var charge_state: Charge = Charge.NONE
## True once the Champion has been beaten: he stays on the floor, kneeling,
## while the crowd goes quiet instead of vanishing in a white pop.
var kneeling: bool = false
## Counts down inside WINDUP and RECOVER.
var _attack_left: float = 0.0
## Counts down between swings.
var _attack_cooldown_left: float = 0.0
## 0..1 fade of the swing arc drawn right after the blade falls.
var _swing_flash: float = 0.0
## Serial of the last lunge that hit this guard, so one lunge hits once.
var _last_strike_serial: int = -1
## Counts down inside Charge.WINDUP / DASH / RECOVER.
var _charge_left: float = 0.0
var _charge_cooldown_left: float = 0.0
## Direction locked in at the end of the windup: the dash cannot be steered.
var _charge_dir: Vector2 = Vector2.RIGHT
## One dash may only hit the player once.
var _charge_hit: bool = false
## The authored rotation speed, so phase III can scale it without compounding.
var _base_hue_speed: float = 0.0

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
## Which sheet of armour this knight wears: "knight" (the 60hp line), "warden"
## (the 140hp heavy, cut bigger), "harrier" (the crowd's knife, fast and
## fragile), "aspirant" (the axe hands the Champion calls up) or "champion"
## (the lancer himself). The room picks it; see SpriteBank.UNITS.
var unit: String = "knight"
## Which way the guard faces: "down" / "up" / "left" / "right".
var _dir: String = "down"
## The attack sheet this swing is using, alternating so a combo is never the
## same animation twice in a row.
var _attack_anim: String = "attack1"
var _attack_toggle: bool = false
## Seconds left of the "blade turned aside" pose (the Champion's shield).
var _guard_pose_left: float = 0.0
## Which way the armour topples when the knight dies: away from the blade.
var _fall_side: float = 1.0
## The line this guard is currently saying, and how long it has left to say it.
## Public because the HUD draws the bubbles (above the darkness layer).
var bark_text: String = ""
var bark_left: float = 0.0
var bark_total: float = 2.0
var bark_colour: Color = Color(1.0, 1.0, 1.0)


## Reference to blood field for bloody footprints
var blood: BloodField = null

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	# Sorted among the walls and props by the ground line they stand on, so a
	# knight really is hidden when it walks behind a pillar.
	z_index = 0
	# Face the first waypoint so the cone does not start pointing at nothing.
	if patrol_points.size() >= 2:
		_facing = (patrol_points[1] - patrol_points[0]).angle()

	# A real human figure, tinted to the hue this knight carries. The
	# hue is the whole point of the game, so the art is recoloured rather than
	# drawn in its own fixed palette.
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = SpriteBank.unit(unit)
	_sprite.centered = true
	_sprite.offset = SpriteBank.unit_offset(unit)
	_sprite.material = SpriteBank.tint_material(colour)
	add_child(_sprite)
	hp = max_hp
	_base_hue_speed = hue_speed
	_update_animation()

	# Get blood field reference from room
	if room != null and room.blood != null:
		blood = room.blood


func _process(delta: float) -> void:
	_time += delta
	bark_left = maxf(bark_left - delta, 0.0)
	hit_flash = maxf(hit_flash - delta * 4.0, 0.0)
	clang_flash = maxf(clang_flash - delta * 4.0, 0.0)
	_swing_flash = maxf(_swing_flash - delta * 3.5, 0.0)
	_guard_pose_left = maxf(_guard_pose_left - delta, 0.0)
	# A staggered knight reels visibly, so the armour break cannot be missed.
	if _sprite != null:
		_sprite.rotation = sin(_time * 34.0) * 0.22 if stagger_left > 0.0 else 0.0
	if dead:
		# A beaten Champion does not pop out of the world: he kneels there until
		# the victory page takes over (_death_left is effectively infinite).
		if not kneeling:
			# The rest fall over: the armour tips away from the blade and the
			# body is gone before it lands. Better than a sprite that blinks
			# out of a world the player is standing in.
			var fall: float = 1.0 - clampf(_death_left / 0.30, 0.0, 1.0)
			if _sprite != null:
				_sprite.rotation = _fall_side * 1.35 * fall
				_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - 0.9 * fall)
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
	# The Champion drags its hue around the wheel, so its sprite has to be
	# re-tinted as the hue moves. Only the boss does this.
	if not is_zero_approx(hue_speed):
		SpriteBank.set_tint(_sprite.material, colour)
	queue_redraw()


## Pick the animation for what the guard is doing. A moving guard runs, a
## standing one idles, and either way it faces where its vision cone points.
##
## The melee's art is drawn for a camera looking from the south, so every
## facing uses the same frames and "left" is the only one that flips. What
## carries the rest of the read is the ground itself: the cone, the arc and the
## swing streak all point where the knight does.
func _update_animation() -> void:
	if _sprite == null:
		return
	var face: String = SpriteBank.dir_from_angle(_facing)
	_dir = face
	_sprite.flip_h = face == "left"

	# A swing owns the sprite until the knight has recovered. Holding the last
	# frame through RECOVER is what makes the punish window visible: the blade
	# is still out, the guard is wide open.
	if attack_state != Attack.NONE and _sprite.sprite_frames.has_animation(_attack_anim):
		if _sprite.animation != _attack_anim:
			_sprite.play(_attack_anim)
		return

	var want: String = "run" if velocity.length() > 5.0 else "idle"
	# The Champion turns the blade aside behind the defence set whenever a
	# strike clangs off his shield.
	if _guard_pose_left > 0.0 and _sprite.sprite_frames.has_animation("guard"):
		want = "guard"
	# A warden standing still plants behind its shield: the same armour as the
	# knights, read as the heavy it is from across the arena.
	elif want == "idle" and unit == "warden" and _sprite.sprite_frames.has_animation("guard"):
		want = "guard"
	if _sprite.animation != want:
		_sprite.play(want)


## Start the windup's attack sheet, alternating between the two so a knight who
## swings twice does not look like a loop. The sheets are timed to the windup,
## so the last frame lands when the blade is coded to connect.
func _begin_attack() -> void:
	_attack_toggle = not _attack_toggle
	var pair: String = "attack2" if (_attack_toggle and
		_sprite != null and _sprite.sprite_frames.has_animation("attack2")) else "attack1"
	_attack_anim = pair
	if _sprite != null and _sprite.sprite_frames.has_animation(pair):
		_sprite.play(pair)


func _physics_process(delta: float) -> void:
	if dead:
		return

	# --- the Champion drags the wheel around ------------------------------
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

	# Bloody footprints: if walking through blood, leave footprints
	if blood != null and velocity.length() > 15.0 and not dead:
		if blood.is_in_blood(global_position):
			var blood_colour: Color = blood.get_blood_at(global_position)
			if blood_colour.a > 0.0:
				blood.add_footprint(global_position, blood_colour, velocity.normalized(), body_radius / 14.0)


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

	# The room gives everybody a moment to get their bearings: at the start of
	# the room, and again each time a later wave marches in.
	var awake: bool = room == null or (room.time_in_room >= LevelData.SPAWN_GRACE
		and room.time_in_room >= spawn_grace_until)

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
				charge_state = Charge.NONE
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

	# The boss's charge is its own commitment: while it is running, nothing else
	# in the chase (walking, sweeping) may happen.
	if is_boss and charge_state != Charge.NONE:
		_do_charge(delta, player)
		return

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
			_charge_cooldown_left = maxf(_charge_cooldown_left - delta, 0.0)
			# Phase II of the Champion opens with a long, telegraphed charge:
			# the lane is drawn on the ground for charge_windup seconds, and
			# then he commits. It is the one attack you must roll, not walk,
			# away from.
			if is_boss and boss_phase >= 2 and not player.frozen \
					and _charge_cooldown_left <= 0.0 \
					and dist >= charge_min_range and dist <= charge_range:
				charge_state = Charge.WINDUP
				_charge_left = charge_windup
				_charge_hit = false
				velocity = Vector2.ZERO
				_say("charge")
				return
			if dist <= attack_range and _attack_cooldown_left <= 0.0 and not player.frozen:
				attack_state = Attack.WINDUP
				_attack_left = attack_windup
				_begin_attack()
			elif dist > attack_range * 0.85:
				velocity = Vector2.RIGHT.rotated(_facing) * chase_speed
			else:
				velocity = Vector2.ZERO


## The three-beat charge: hold the lane, sprint it, then stand open for a
## moment. The player can roll through the dash (i-frames) or step out of the
## lane during the telegraph, which is the whole read.
func _do_charge(delta: float, player: Player) -> void:
	match charge_state:
		Charge.WINDUP:
			velocity = Vector2.ZERO
			# Still tracking during the telegraph, so the lane is the player's
			# problem to solve - but the committed direction is frozen at the end.
			_turn_towards((player.global_position - global_position).angle(), delta, turn_speed_deg * 1.6)
			_charge_left = maxf(_charge_left - delta, 0.0)
			if _charge_left <= 0.0:
				charge_state = Charge.DASH
				_charge_left = charge_duration
				_charge_dir = Vector2.RIGHT.rotated(_facing)
				_charge_hit = false
				charge_started.emit()
		Charge.DASH:
			# No steering: the Champion has committed his weight.
			velocity = _charge_dir * charge_speed
			_charge_left = maxf(_charge_left - delta, 0.0)
			var gap: float = player.global_position.distance_to(global_position)
			if not _charge_hit and gap <= body_radius + player.body_radius + 8.0:
				_charge_hit = true
				player.take_damage(charge_damage, global_position)
			# Stop at a wall rather than grinding against it, so the punish
			# window opens where the dash actually ended.
			if _charge_left <= 0.0 or is_on_wall():
				charge_state = Charge.RECOVER
				_charge_left = charge_recover
				velocity = Vector2.ZERO
		Charge.RECOVER:
			velocity = Vector2.ZERO
			_charge_left = maxf(_charge_left - delta, 0.0)
			if _charge_left <= 0.0:
				charge_state = Charge.NONE
				_charge_cooldown_left = charge_cooldown
		_:
			charge_state = Charge.NONE


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
	if dead or dormant or state == State.CHASE:
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
## hue-multiplied; `shatter` marks a complement strike and `heavy` the last,
## hardest swing of the player's chain. Returns true when the strike landed.
func take_hit(amount: float, shatter: bool, heavy: bool, from_position: Vector2, strike_serial: int) -> bool:
	if dead:
		return false
	# One swing only hits each guard once, no matter how many physics frames
	# the blade overlaps them.
	if strike_serial == _last_strike_serial:
		return false
	_last_strike_serial = strike_serial

	hp = maxf(hp - amount, 0.0)
	hit_flash = 1.0
	# A shatter breaks the charge too: catching the Champion mid-dash with his
	# complement is the reward for reading the lane.
	if shatter and charge_state != Charge.NONE:
		charge_state = Charge.NONE
		_charge_cooldown_left = charge_cooldown * 0.5
	# Everything flinches briefly; a shatter knocks the knight down properly,
	# and the heavy third swing staggers even through neutral armour.
	var flinch: float = 0.18
	if heavy:
		flinch = 0.30
	if shatter:
		flinch = stagger_time
	stagger_left = maxf(stagger_left, flinch)
	var away: Vector2 = global_position - from_position
	if away.length() > 0.001:
		var push: float = 90.0
		if heavy:
			push = 320.0
		if shatter:
			push = maxf(push, 240.0)
		velocity += away.normalized() * push
		# Remembered for the death topple: the armour falls away from the blade.
		if absf(away.x) > 0.01:
			_fall_side = signf(away.x)
	if shatter:
		_say("stagger")

	# Losing a third of his vigour moves the Champion into the next phase. The
	# check is skipped on the killing blow: a dead man does not summon help.
	if hp > 0.0 and is_boss:
		_update_boss_phase()

	if hp <= 0.0:
		die()
	return true


## Phase thresholds. Phase II adds the charging dash; phase III calls the
## Aspirants and spins the wheel faster. Phases only ever move forwards, so a
## big single hit can skip II entirely - and still lands in the right place.
func _update_boss_phase() -> void:
	if not is_boss or dead:
		return
	var ratio: float = health_ratio()
	var want: int = 1
	if ratio <= phase_three_ratio:
		want = 3
	elif ratio <= phase_two_ratio:
		want = 2
	if want <= boss_phase:
		return
	boss_phase = want
	if boss_phase == 3:
		hue_speed = _base_hue_speed * phase_three_hue_scale
		summons_requested.emit(summons_count)
		_say("summon")
	phase_changed.emit(boss_phase)


## A strike that glanced off without doing anything (the Champion's shield,
## outside the complement window). Purely feedback.
func clang() -> void:
	clang_flash = 1.0
	# Hold the defence pose long enough to read: the blade is turned aside.
	_guard_pose_left = maxf(_guard_pose_left, 0.45)


## Health left as 0..1, for the over-head bar.
func health_ratio() -> float:
	return clampf(hp / maxf(max_hp, 0.01), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Waves
# ---------------------------------------------------------------------------

## Take the knight off the field until its wave is called by the room: hidden,
## inert and deaf. Everything _ready() needs is already set up, so waking is
## just turning it back on.
func sleep_for_wave() -> void:
	dormant = true
	detection = 0.0
	charge_state = Charge.NONE
	attack_state = Attack.NONE
	visible = false
	set_process(false)
	set_physics_process(false)


## Its wave has been called: back on the field, facing its route, with the
## same blind moment every knight gets when a room starts.
func wake_for_wave() -> void:
	dormant = false
	detection = 0.0
	state = State.PATROL
	attack_state = Attack.NONE
	charge_state = Charge.NONE
	velocity = Vector2.ZERO
	spawn_grace_until = (room.time_in_room if room != null else 0.0) + LevelData.SPAWN_GRACE
	visible = true
	set_process(true)
	set_physics_process(true)
	queue_redraw()


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
	charge_state = Charge.NONE
	velocity = Vector2.ZERO
	_death_left = 0.30
	# The Champion's death is a beat, not a pop: he kneels in the sand and
	# stays there (the win page follows a couple of seconds later).
	if is_boss:
		kneeling = true
		_death_left = 1.0e9
		if _sprite != null:
			_sprite.rotation = -1.1
			_sprite.stop()
			_sprite.modulate = Color(0.72, 0.72, 0.78)
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
		if kneeling:
			# The beaten Champion: a low shadow, the broken ring of the wheel
			# bleeding out around him, and one last pulse of his hue.
			var breathe: float = 0.5 + 0.5 * sin(_time * 2.0)
			draw_circle(Vector2(0.0, body_radius * 0.9), body_radius * 1.5, Color(0.0, 0.0, 0.0, 0.45))
			draw_arc(Vector2.ZERO, body_radius + 16.0, 0.0, TAU, 40,
				Color(colour.r, colour.g, colour.b, 0.25 + 0.25 * breathe), 3.0, true)
			var font: Font = ThemeDB.fallback_font
			if font != null:
				draw_string(font, Vector2(-70.0, body_radius + 26.0), "THE CHAMPION KNEELS",
					HORIZONTAL_ALIGNMENT_CENTER, 140.0, 12, Color(1.0, 1.0, 1.0, 0.85))
			return
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
	# It is drawn as four nested wedges, brightest at the knight and thinning
	# towards its reach: on top of a painted floor a flat wash reads like a
	# stain, a falloff reads like light.
	var alert: float = clampf(detection, 0.0, 1.0)
	for k in 4:
		var t: float = 1.0 - float(k) * 0.24
		var band: PackedVector2Array = PackedVector2Array()
		for p in points:
			band.append(p * t)
		var band_alpha: float = (0.045 + 0.05 * alert) * (0.5 + float(k) * 0.5)
		draw_colored_polygon(band, Color(body.r, body.g, body.b, band_alpha))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(Vector2.ZERO)
	draw_polyline(outline, Color(body.r, body.g, body.b, 0.38 + 0.42 * alert), 1.5)

	# --- boss charge telegraph --------------------------------------------
	# A long, hot lane painted on the sand: at full charge the wedge is already
	# committed, so the lane you see is exactly the lane he will run.
	if is_boss and charge_state != Charge.NONE:
		var lane_dir: Vector2 = _charge_dir if charge_state != Charge.WINDUP else Vector2.RIGHT.rotated(_facing)
		var lane_len: float = charge_speed * charge_duration
		var t_end: Vector2 = lane_dir * lane_len
		var side: Vector2 = lane_dir.orthogonal() * (body_radius + 4.0)
		if charge_state == Charge.WINDUP:
			var ct: float = clampf(1.0 - _charge_left / maxf(charge_windup, 0.01), 0.0, 1.0)
			draw_line(Vector2.ZERO, t_end, Color(1.0, 0.35, 0.20, 0.10 + 0.25 * ct), body_radius * 1.7)
			draw_line(side, t_end + side, Color(1.0, 0.85, 0.65, 0.30 + 0.60 * ct), 2.5)
			draw_line(-side, t_end - side, Color(1.0, 0.85, 0.65, 0.30 + 0.60 * ct), 2.5)
		else:
			draw_line(Vector2.ZERO, t_end, Color(1.0, 0.20, 0.10, 0.22), body_radius * 1.9)

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

	# --- Champion of the Wheel extras ------------------------------------
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
		# Phase pips above the ring: three small marks that fill as he loses
		# ground, so the duel's shape is readable between hits.
		for i in 3:
			var pip: Vector2 = Vector2((float(i) - 1.0) * 12.0, -body_radius - 54.0)
			var lit: bool = (i + 1) <= boss_phase
			draw_circle(pip, 3.2, Color(1.0, 0.86, 0.35, 0.95) if lit else Color(0.0, 0.0, 0.0, 0.55))

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
