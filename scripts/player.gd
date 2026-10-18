class_name Player
extends CharacterBody2D
##
## PLAYER - the Unsworn.
##
## Three things make this node interesting:
##   1. Two verbs, split cleanly. STRIKE (J / left mouse) is a three-swing
##      chain that cuts wherever you are steering; DODGE (space) is a roll
##      with i-frames. Attacking is how you win the room, dodging is how you
##      survive the reply - and the roll also cancels a swing, so committing
##      to it is always possible.
##   2. `colour` is the player's current hue. It starts white/grey and is
##      re-mixed with every guard that dies (ColorTheory.absorb).
##   3. `visibility_now` is written by the room each frame. 0 means the floor
##      under the Unsworn matches their hue, so guards cannot build detection.
##
## Two combat rules live in the room instead, because they need to see the
## whole battlefield: the hue multiplier on a landed swing, and the gentle
## auto-aim that turns a swing onto a knight already standing in front of you.
##
## All the numbers worth tuning are the @export variables right below.

signal died
## Emitted at the start of every swing. `direction` is where the blade points
## before the room's auto-aim; the room answers by aiming the swing and by
## letting nearby guards know they heard a blade.
signal struck(direction: Vector2)
## Emitted at the start of a dodge roll. game.gd hangs its feedback on this.
signal rolled(direction: Vector2)
## Emitted every time a hit actually lands on the player. game.gd uses it for
## feedback; the room does not need it.
signal hurt(amount: float, from_position: Vector2)
## Emitted when a blow is turned on a freshly raised guard. The room answers by
## leaving the attacker wide open - the parry's whole reward.
signal parried(from_position: Vector2)
## Emitted on every footfall, so game.gd can give the boots a sound. Distance
## based, not time based, so walking and sprinting do not step at the same rate.
signal stepped()

@export_group("Movement")
## Walking speed in pixels/second. Guards patrol slower than this but chase
## faster than this, so you cannot simply outrun a fight - you dodge it.
@export var move_speed: float = 240.0
## How quickly the Unsworn reaches walking speed (pixels/second/second).
## High values = the Unsworn answers the keys on the same frame you press them,
## which is what keeps the movement tight instead of floaty.
@export var acceleration: float = 4200.0
## How quickly the Unsworn stops when you let go of the keys.
@export var friction: float = 3800.0
## Below this speed with no keys held, the Unsworn snaps to a dead stop so it
## never drifts a few pixels past where you meant to stand.
@export var stop_snap_speed: float = 14.0
## Physics radius. Must match the collision shape built in _ready().
@export var body_radius: float = 12.0
## Ground covered between footfalls. Distance based, so the boots keep pace with
## the legs however fast the walk speed is tuned.
@export var step_length: float = 54.0

@export_group("Strike")
## The three-swing chain, in order: each swing deals its own damage. The last
## one lands with the whole body behind it and knocks the target back.
@export var combo_damage: Array[float] = [12.0, 12.0, 20.0]
## How long the blade is out and able to connect. Also the swing's whole
## visible life - the arc in _draw() is drawn across exactly this window.
@export var strike_active: float = 0.14
## Seconds after a swing starts before the next one can. Long enough that a
## swing is a commitment, short enough that the chain flows.
@export var strike_cooldown: float = 0.28
## How long the chain survives between swings. Press again inside it and the
## next swing is hit 2 (then the heavy 3); wait past it and the chain resets.
@export var combo_window: float = 0.60
## How far past the body the blade reaches. The room adds the two body
## radii to this when it tests whether a swing connects.
@export var strike_reach: float = 22.0
## Half-angle of the swing, in degrees. The blade cuts a WEDGE, not a circle:
## a knight at your back survives a swing aimed forward.
@export var strike_half_deg: float = 55.0
## Auto-aim arc: the room may turn a swing onto any knight within this many
## degrees of where the player was already pointing. Gentle, not snap-aim -
## it never fires behind the player, so it assists without aiming for you.
@export var auto_aim_deg: float = 60.0
## A small forward step on every swing, so attacking walks you into the fight
## instead of leaving you planted while everyone else moves.
@export var strike_step: float = 300.0
## The heavy third swing's extra reach and arc, as multipliers on the two
## values above. The room resolves hits with the same numbers, so the wedge
## the player DRAWS is always the wedge that cuts.
const HEAVY_REACH_SCALE: float = 1.12
const HEAVY_ARC_SCALE: float = 1.35

@export_group("Dodge roll")
## Space: a fast burst with i-frames at the start. The escape button.
@export var roll_duration: float = 0.35
## How long from the roll's start the player cannot be hit. Front-loaded on
## purpose: the roll is a timed answer, not a second health bar.
@export var roll_iframes: float = 0.25
## Peak speed of the roll (about 2.3x walking speed).
@export var roll_speed: float = 560.0
## Seconds between rolls.
@export var roll_cooldown: float = 0.90
## Fading copies left behind during the roll (pure visual juice).
@export var afterimage_count: int = 5
## Seconds between afterimage samples.
@export var afterimage_interval: float = 0.022

@export_group("Guard and parry")
## The first slice of a raised guard DEFLECTS: no blood, and whoever threw the
## blow is left open. Miss the window and the guard still blocks, but a third
## of the hit gets through it. Timing the raise is the whole skill.
@export var parry_window: float = 0.22
## Fraction of a blocked hit that stops at the blade; the rest still gets
## through. A held guard is a good wall, not a free pass.
@export var block_absorb: float = 0.65
## A guard is a wall in FRONT of the Unsworn, not a shell around them: a blow
## landing further than this from the facing is not blocked at all.
@export var guard_half_deg: float = 80.0
## The stance can walk, but slowly.
@export var guard_move_scale: float = 0.42
## A hit at least this heavy breaks the guard open and lands whole - the sound
## a big knight makes when he comes through a small defence.
@export var guard_break_damage: float = 46.0
## How long the parry's white ring stays lit. Purely for reading the moment.
@export var parry_flash_time: float = 0.35

@export_group("Colour")
## Current hue of the Unsworn. White going in; a mix of everything you kill.
@export var colour: Color = Color(1.0, 1.0, 1.0)
## How far each kill pulls the Unsworn's hue towards the guard's hue (0..1).
@export var absorb_amount: float = 0.5
## Hue distance (degrees) under which the floor counts as "a match" and the
## Unsworn is invisible. Also used by the HUD to explain hiding.
@export var hide_tolerance_deg: float = 26.0

@export_group("Combat")
## Player health. The arena is a fight now: hits cost vigour, not the run.
@export var max_hp: float = 100.0
## Seconds of invulnerability after a hit, so a pack cannot chain-stun you.
@export var invuln_time: float = 0.8
## How hard a hit shoves the player away from whoever dealt it.
@export var hit_knockback: float = 260.0
## Seconds the player cannot steer after a hit, so the shove reads.
@export var hitstun_time: float = 0.16

## Seconds of blade-out time left. The room asks is_striking() every frame.
var strike_left: float = 0.0
## Counts down to 0; the next swing is allowed when it hits 0.
var strike_cooldown_left: float = 0.0
## Seconds the current chain survives. 0 means the next swing starts hit 1.
var combo_left: float = 0.0
## Which swing of the chain is out right now (0-based into combo_damage).
var strike_index: int = 0
## Increments once per swing. Guards remember the last serial they took a hit
## from, so one swing hits each of them once no matter how long the blade
## overlaps them.
var strike_serial: int = 0
## Seconds of dodge roll left; 0 means not rolling.
var roll_left: float = 0.0
## Counts down to 0; the next roll is allowed when it hits 0.
var roll_cooldown_left: float = 0.0
## 0..1 how camouflaged the Unsworn is (written by the room every frame).
var visibility_now: float = 1.0
## True when standing in paint that matches the Unsworn's hue.
var is_hidden: bool = false
## Frozen while the death animation plays.
var frozen: bool = false

## Current health. Hits take it down; reaching 0 runs the normal death path.
var hp: float = 100.0
## Counts down; while positive the player cannot be hit again.
var invuln_left: float = 0.0
## Counts down; while positive input is ignored so the knockback reads.
var hitstun_left: float = 0.0
## 0..1 fade of the red hurt flash. Purely visual.
var hurt_flash: float = 0.0
## True while the blade is held across the body.
var guarding: bool = false
## Seconds left in which a freshly raised guard will deflect instead of block.
var parry_left: float = 0.0
## 0..1 fade of the parry's white ring. Purely visual.
var parry_flash: float = 0.0
## Ground covered since the last footfall, for the boots' sound.
var _step_len: float = 0.0
## Reference to blood field for bloody footprints
var blood: BloodField = null

## Where the blade points while it is out. The room may turn it (auto-aim).
var _strike_dir: Vector2 = Vector2.RIGHT
## Where the roll is going. Locked in when the roll starts.
var _roll_dir: Vector2 = Vector2.RIGHT
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
	# player and guards pass through each other. Strikes are detected by
	# distance in room.gd, which is far more predictable than physics contacts.
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	shape.shape = circle
	add_child(shape)
	# Sorted with the walls and props by the ground line: walk behind a block
	# and its stones cover you, the way they should.
	z_index = 0

	# The character itself: a real animated figure instead of the old dot, with
	# a hue-tint shader so the artwork can show the player's current colour.
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = SpriteBank.adventurer()
	_sprite.centered = true
	_sprite.material = SpriteBank.tint_material(colour)
	add_child(_sprite)
	hp = max_hp
	_update_animation()


func _physics_process(delta: float) -> void:
	strike_left = maxf(strike_left - delta, 0.0)
	strike_cooldown_left = maxf(strike_cooldown_left - delta, 0.0)
	combo_left = maxf(combo_left - delta, 0.0)
	roll_left = maxf(roll_left - delta, 0.0)
	roll_cooldown_left = maxf(roll_cooldown_left - delta, 0.0)
	invuln_left = maxf(invuln_left - delta, 0.0)
	hitstun_left = maxf(hitstun_left - delta, 0.0)
	parry_left = maxf(parry_left - delta, 0.0)
	parry_flash = maxf(parry_flash - delta / maxf(parry_flash_time, 0.01), 0.0)

	if frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# --- reading input -----------------------------------------------------
	# While hit-stunned or mid-roll the keys are ignored, so a hit actually
	# interrupts you and a roll actually commits you.
	var busy: bool = hitstun_left > 0.0 or roll_left > 0.0
	var input: Vector2 = Vector2.ZERO
	if not busy:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# --- the two verbs ------------------------------------------------------
	# STRIKE: one swing at a time, then a short cooldown. Press again inside
	# the combo window and the chain continues to hit 2, then the heavy 3.
	if not busy and strike_cooldown_left <= 0.0 and Input.is_action_just_pressed("strike"):
		begin_strike(input)
	# DODGE: a roll the way you steer. Deliberately checked after the strike,
	# so if both land on the same frame the roll wins and cancels the swing -
	# the defensive option must never be the one that gets eaten.
	if not busy and roll_cooldown_left <= 0.0 and Input.is_action_just_pressed("dodge"):
		begin_roll(input)
	# GUARD: hold to stand behind the blade. The PARRY window opens only on the
	# way UP, so a permanently held guard is safe but slow, and the one who
	# times the raise is the one who gets the free hit. A roll drops the guard,
	# and so does a swing: the blade cannot hold a wall and cut through it.
	var can_guard: bool = not busy and strike_left <= 0.0
	if not can_guard:
		end_guard()
	elif Input.is_action_just_pressed("guard"):
		begin_guard()
	elif Input.is_action_pressed("guard"):
		guarding = true
	else:
		end_guard()

	# --- moving ------------------------------------------------------------
	if roll_left > 0.0:
		# The roll: a fast burst that eases out over its life. No steering -
		# a roll is a commitment, and the i-frames are what you paid for.
		var t: float = roll_left / maxf(roll_duration, 0.01)
		velocity = _roll_dir * roll_speed * (0.35 + 0.65 * t)
		# Leave a fading copy of ourselves behind roughly every 22ms.
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = afterimage_interval
			_trail.append({"pos": global_position, "age": 0.0})
			if _trail.size() > afterimage_count:
				_trail.pop_front()
	else:
		var speed: float = move_speed * (guard_move_scale if guarding else 1.0)
		var target: Vector2 = input * speed
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
	# (The roll skips it: the tumble rotation below is its animation.)
	var spd: float = velocity.length()
	if spd > 50.0 and roll_left <= 0.0:
		_walk_cycle = fposmod(_walk_cycle + delta * spd / 80.0, 1.0)
		_squash = 0.5 - 0.5 * cos(_walk_cycle * TAU)
	else:
		_squash = 0.0

	move_and_slide()

	# --- boots -------------------------------------------------------------
	# A footfall per `step_length` of ground covered. Distance based, so a slow
	# walk and a fast walk both keep the sound locked to the legs.
	if roll_left <= 0.0:
		_step_len += velocity.length() * delta
		if _step_len >= step_length:
			_step_len = 0.0
			stepped.emit()

	# Safety net: if a wall is ever missed, never let the Unsworn leave the room.
	global_position.x = clampf(global_position.x, LevelData.PLAYER_RADIUS, LevelData.PLAYFIELD.x - LevelData.PLAYER_RADIUS)
	global_position.y = clampf(global_position.y, LevelData.PLAYER_RADIUS, LevelData.PLAYFIELD.y - LevelData.PLAYER_RADIUS)

	# Bloody footprints: if walking through blood, leave footprints
	if blood != null and velocity.length() > 30.0 and roll_left <= 0.0:
		if blood.is_in_blood(global_position):
			var blood_colour: Color = blood.get_blood_at(global_position)
			if blood_colour.a > 0.0:
				blood.add_footprint(global_position, blood_colour, velocity.normalized())

	# Age the afterimages.
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i]["age"] = float(_trail[i]["age"]) + delta
		if float(_trail[i]["age"]) > 0.25:
			_trail.remove_at(i)

	_update_animation()


func _process(delta: float) -> void:
	hurt_flash = maxf(hurt_flash - delta * 3.0, 0.0)
	if _sprite != null:
		# Invulnerability reads as a blink: the universal "you cannot be hit".
		# A roll shows the tumble instead - blinking on top of it would just
		# look like a broken sprite.
		var blinking: bool = invuln_left > 0.0 and roll_left <= 0.0
		_sprite.visible = not blinking or fmod(invuln_left, 0.18) > 0.09
		if roll_left > 0.0:
			var progress: float = 1.0 - roll_left / maxf(roll_duration, 0.01)
			_sprite.rotation = TAU * progress * (1.0 if _roll_dir.x >= 0.0 else -1.0)
		else:
			_sprite.rotation = 0.0
	queue_redraw()


## Pick the animation that matches what the character is doing right now:
##   rolling -> attack_<dir> (tumbled)   swinging -> attack_<dir>
##   moving  -> run_<dir>                still    -> idle_<dir>
func _update_animation() -> void:
	if _sprite == null:
		return
	# Apply the walk bob: a subtle vertical squash plus a small lift, so the
	# Unsworn reads as walking even now that it is a real sprite and not a dot.
	var squash: float = _squash * 0.16
	_sprite.scale = Vector2(1.0 + squash, 1.0 - squash)
	_sprite.position = Vector2(0.0, -2.0 * _squash)
	var want: String
	if is_rolling():
		_dir = SpriteBank.dir_from_vector(_roll_dir)
		want = "attack_%s" % _dir
	elif is_striking():
		_dir = SpriteBank.dir_from_angle(_strike_dir.angle())
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
# The two verbs. begin_strike / begin_roll are called by the input handling
# above - and directly by the test suite, which is how a swing or a roll can
# be simulated without synthesising key events.
# ---------------------------------------------------------------------------

## Swing the blade. `input` is the steering direction this frame, if any: the
## swing goes the way you are moving, or the way you last faced. Emits
## `struck` so the room can add its auto-aim and the noise.
func begin_strike(input: Vector2 = Vector2.ZERO) -> void:
	# The swing takes both hands: the guard drops, and it does not come back
	# with a fresh parry window until the key is released and pressed again.
	end_guard()
	if input.length() > 0.01:
		_facing = input.angle()
	_strike_dir = Vector2.RIGHT.rotated(_facing)
	# The chain: a swing inside the window continues it, otherwise it starts
	# over. Hit 3 (the last entry) is the heavy one.
	if combo_left > 0.0 and not combo_damage.is_empty():
		strike_index = (strike_index + 1) % combo_damage.size()
	else:
		strike_index = 0
	combo_left = combo_window
	strike_left = strike_active
	strike_cooldown_left = strike_cooldown
	strike_serial += 1
	# A small step into the swing, so attacking moves you forward.
	velocity = _strike_dir * strike_step
	struck.emit(_strike_dir)


## Roll. `input` is the steering direction this frame, if any; standing still
## rolls the way you last faced. The first `roll_iframes` seconds cannot be
## hit, and a swing in progress is cancelled - the roll is the universal
## "get me out of this".
func begin_roll(input: Vector2 = Vector2.ZERO) -> void:
	end_guard()
	_roll_dir = input.normalized() if input.length() > 0.01 else Vector2.RIGHT.rotated(_facing)
	_facing = _roll_dir.angle()
	roll_left = roll_duration
	roll_cooldown_left = roll_cooldown
	invuln_left = maxf(invuln_left, roll_iframes)
	strike_left = 0.0
	_trail.clear()
	_trail_timer = 0.0
	rolled.emit(_roll_dir)


## Raise the blade. Only the RAISE opens the parry window: holding the guard
## afterwards is a block, which is why the courage to lower it and raise it
## again on the beat is what the fight asks of you.
func begin_guard() -> void:
	if frozen:
		return
	guarding = true
	parry_left = parry_window


## Lower the blade.
func end_guard() -> void:
	guarding = false
	parry_left = 0.0


## True while the blade is held across the body (blocking, or parrying).
func is_guarding() -> bool:
	return guarding


## True while a hit would be DEFLECTED rather than merely blocked.
func parry_open() -> bool:
	return guarding and parry_left > 0.0


# ---------------------------------------------------------------------------
# Public API used by the room
# ---------------------------------------------------------------------------

## True while the blade is out and able to cut.
func is_striking() -> bool:
	return strike_left > 0.0


## True while the roll is carrying the Unsworn.
func is_rolling() -> bool:
	return roll_left > 0.0


## Damage of the swing that is out right now, before the hue multiplier.
func strike_damage_now() -> float:
	if combo_damage.is_empty():
		return 0.0
	return combo_damage[clampi(strike_index, 0, combo_damage.size() - 1)]


## True when the swinging hit is the heavy last one of the chain.
func strike_is_heavy() -> bool:
	return not combo_damage.is_empty() and strike_index >= combo_damage.size() - 1


## The heavy third swing cleaves wider and further than the two quick ones.
## The room resolves hits with these same numbers, so the wedge you see drawn
## is exactly the wedge that cuts.
func strike_reach_now() -> float:
	return strike_reach * (HEAVY_REACH_SCALE if strike_is_heavy() else 1.0)


func strike_half_rad() -> float:
	return deg_to_rad(strike_half_deg) * (HEAVY_ARC_SCALE if strike_is_heavy() else 1.0)


## Direction the blade is pointing (already auto-aimed by the room).
func strike_angle() -> float:
	return _strike_dir.angle()


## The room's gentle - and only - auto-aim: turn the swing onto a knight the
## player could already see. Called from room._on_player_struck.
func aim_strike_at(target_position: Vector2) -> void:
	_strike_dir = (target_position - global_position).normalized()
	_facing = _strike_dir.angle()


## Take on `guard_colour` using HSV hue blending.
func absorb_colour(guard_colour: Color) -> void:
	colour = ColorTheory.absorb(colour, guard_colour, absorb_amount)
	# The sprite is tinted by `colour`, so it has to be told the hue changed.
	_apply_tint()


## Take a hit. Returns true when it actually landed (false while invulnerable,
## while a parry turns it aside, or already dying), so the attacker can key its
## feedback on the result.
##
## A raised guard changes this in three ways: a blow inside the parry window is
## DEFLECTED (no damage, no shove, and the room leaves the attacker open), a
## blow inside the guard arc is BLOCKED (most of it stops at the blade, no
## stun, so the wall holds), and a blow heavy enough breaks the guard open
## entirely.
func take_damage(amount: float, from_position: Vector2) -> bool:
	if frozen or invuln_left > 0.0:
		return false
	var away: Vector2 = global_position - from_position
	if away.length() < 0.001:
		away = Vector2.RIGHT.rotated(_facing + PI)
	var stun: float = hitstun_time
	var shove: float = hit_knockback
	if guarding and _guard_covers(from_position):
		if parry_open():
			# DEFLECTED. A short invulnerability keeps two attackers swinging
			# on the same frame from both landing: one parry, one moment.
			parry_left = 0.0
			parry_flash = 1.0
			invuln_left = maxf(invuln_left, 0.14)
			parried.emit(from_position)
			return false
		if amount >= guard_break_damage:
			# Too heavy for the blade. The guard opens and the blow lands
			# whole, which is the sound a big knight makes through a small
			# defence.
			end_guard()
			stun = hitstun_time * 1.6
		else:
			# BLOCKED. Never any invulnerability: the cost of a late guard is
			# blood, and the wall has to be held deliberately.
			amount *= 1.0 - clampf(block_absorb, 0.0, 0.95)
			shove = hit_knockback * 0.25
			stun = 0.0
	hp = maxf(hp - amount, 0.0)
	invuln_left = invuln_time
	hitstun_left = stun
	hurt_flash = 1.0
	# Shoved away from whoever hit us, so hits physically move the fight.
	velocity = away.normalized() * shove
	hurt.emit(amount, from_position)
	if hp <= 0.0:
		kill()
	return true


## A guard is a wall in front of the Unsworn, not a shell around them.
func _guard_covers(from_position: Vector2) -> bool:
	var to_attacker: Vector2 = from_position - global_position
	if to_attacker.length() < 0.001:
		return true
	var diff: float = absf(wrapf(to_attacker.angle() - _facing, -PI, PI))
	return diff <= deg_to_rad(guard_half_deg)


## True while the last hit is still ringing (or a roll's i-frames are up).
func is_invulnerable() -> bool:
	return invuln_left > 0.0


## Called when health runs out (and once by the room for scripted deaths).
func kill() -> void:
	if frozen:
		return
	frozen = true
	died.emit()


func get_facing() -> float:
	return _facing


## Direction the light cone points. This is simply the way the Unsworn faces,
## which is driven entirely by WASD: the torch IS your movement direction, so
## there is no separate aiming to learn and nothing to fight the keyboard.
func aim_angle() -> float:
	return _facing


## Take on the whole hue of a colour mote. Unlike a kill, a mote is a full
## drink of colour rather than a 50% blend, because the mote is already made
## of pure hue and there is nothing to mix it with.
func drink(mote_colour: Color) -> void:
	colour = Color.from_hsv(mote_colour.h, clampf(maxf(mote_colour.s, 0.85), 0.0, 1.0),
		clampf(maxf(mote_colour.v, 0.92), 0.0, 1.0), 1.0)
	_apply_tint()


# ---------------------------------------------------------------------------
# Drawing - everything is vector shapes so there are no art assets
# ---------------------------------------------------------------------------

func _draw() -> void:
	# --- roll afterimages ---------------------------------------------------
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

	# --- the swinging blade -------------------------------------------------
	# A white arc sweeping through the strike wedge, along the direction the
	# room last aimed it. It stays bright for the whole swing (the room is
	# dark: a slash that fades to nothing cannot be read). The heavy third
	# swing is longer, thicker and tipped with the player's own hue - the
	# chain has to READ at a glance, because hit 3 is worth more than hit 1
	# and hit 2 together.
	if is_striking():
		var half: float = strike_half_rad()
		var dir: float = _strike_dir.angle()
		var progress: float = clampf(1.0 - strike_left / maxf(strike_active, 0.01), 0.0, 1.0)
		var from_a: float = dir - half
		var to_a: float = dir - half + 2.0 * half * progress
		var fade: float = 1.0 - 0.45 * progress
		var reach: float = body_radius + strike_reach_now()
		var heavy: bool = strike_is_heavy()
		if heavy:
			draw_arc(Vector2.ZERO, reach, from_a, to_a, 28,
				Color(1.0, 1.0, 1.0, 0.95 * fade), 7.0, true)
			draw_arc(Vector2.ZERO, reach * 0.75, from_a, to_a, 22,
				Color(colour.r, colour.g, colour.b, 0.60 * fade), 3.5, true)
		else:
			draw_arc(Vector2.ZERO, reach, from_a, to_a, 20,
				Color(1.0, 1.0, 1.0, 0.85 * fade), 4.0, true)
		# The point of the blade: a bright dot riding the leading edge of the
		# sweep, so the eye can tell WHICH WAY the cut is going.
		var tip_dir: Vector2 = Vector2.RIGHT.rotated(to_a)
		draw_circle(tip_dir * reach, 4.0 if heavy else 3.0,
			Color(1.0, 1.0, 1.0, minf(1.0, 1.1 * fade)))

	# --- hurt flash --------------------------------------------------------
	# A red ring snapping outward for a beat, so a hit on the player is never
	# mistaken for a hit on somebody else.
	if hurt_flash > 0.0:
		draw_arc(Vector2.ZERO, body_radius * 2.4, 0.0, TAU, 28,
			Color(1.0, 0.25, 0.20, 0.75 * hurt_flash), 3.0, true)

	# --- the guard ---------------------------------------------------------
	# The blade held across the body, drawn as a ward in the facing direction.
	# The arc you see IS the arc that blocks (guard_half_deg), so a blow that
	# lands outside it visibly should not have been blocked - and a blow from
	# behind reads as the back-stab it is.
	if guarding:
		var half: float = deg_to_rad(guard_half_deg)
		var steps: int = 16
		for i in range(steps):
			var t: float = float(i) / float(steps - 1)
			var a: float = _facing - half + 2.0 * half * t
			var near: float = 1.0 - absf(t * 2.0 - 1.0)
			var r0: float = body_radius + 4.0 + 5.0 * near
			var ward := Color(0.80, 0.88, 1.0, 0.26 + 0.46 * near)
			draw_line(Vector2.RIGHT.rotated(a) * r0,
				Vector2.RIGHT.rotated(a) * (r0 + 7.0 + 7.0 * near), ward, 2.0 + 1.6 * near)
		if parry_open():
			# The window itself shines: a bright edge for the fifth of a second
			# in which a blow would be turned. Seeing it is how you learn it.
			draw_arc(Vector2.ZERO, body_radius + 15.0, _facing - half * 0.7, _facing + half * 0.7,
				24, Color(1.0, 1.0, 1.0, 0.55), 2.0, true)
	if parry_flash > 0.0:
		draw_arc(Vector2.ZERO, body_radius + 10.0 + 34.0 * (1.0 - parry_flash),
			_facing - 1.7, _facing + 1.7, 24,
			Color(1.0, 1.0, 1.0, 0.75 * parry_flash), 3.5, true)

	# --- glow --------------------------------------------------------------
	# The glow fades out when camouflaged, which is the player's clearest
	# "I am safe right now" signal. This is colour theory as game feedback.
	# It sits behind the sprite, so it reads as an aura around the figure.
	if not is_hidden:
		draw_circle(Vector2.ZERO, body_radius * 3.1, Color(colour.r, colour.g, colour.b, 0.13))
	else:
		draw_circle(Vector2.ZERO, body_radius * 1.7, Color(colour.r, colour.g, colour.b, 0.09))

	# --- roll readiness ring ----------------------------------------------
	# A thin ring that fills as the roll recharges and closes into a full
	# circle when it is ready again. Without it the only feedback is
	# "nothing happened".
	var ready: float = 1.0 - clampf(roll_cooldown_left / maxf(roll_cooldown, 0.01), 0.0, 1.0)
	if ready < 1.0:
		draw_arc(Vector2.ZERO, body_radius * 2.0, -PI * 0.5, -PI * 0.5 + TAU * ready, 24,
			Color(1.0, 1.0, 1.0, 0.40), 2.0, true)
	else:
		draw_arc(Vector2.ZERO, body_radius * 2.0, 0.0, TAU, 24,
			Color(colour.r, colour.g, colour.b, 0.22), 1.5, true)
