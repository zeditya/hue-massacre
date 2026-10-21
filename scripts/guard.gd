class_name Guard
extends CharacterBody2D
##
## GUARD - one of the SWORN: a soldier of a hall, carrying that hall's hue.
##
## THE OATH RULE (this is the story AND the AI):
## a sworn soldier notices the player the ordinary way - in front of it, in
## clear line of sight, not camouflaged - and then it NEVER gives up. The
## oath is total: no searching, no walking home. Once a knight has locked on,
## it knows where the Unsworn is until one of them is on the sand, and the
## only choice left is whose colour spills.
##
## THE FAINT CONE: a knight does not carry a detection METER, but it does have
## a direction, and the player deserves to read it. `_draw()` lays a very
## faint wedge of the knight's own hue along exactly the arc `_in_sight()`
## tests (same `sight_arc_deg`, same `sight_range`), so the picture and the
## rule are one thing without the cone ever becoming the fight. It is a
## readability cue, not a stealth system: the alpha stays under a tenth.
##
## The one mercy is the first strike: `ColorTheory.visibility()` returns 0
## when the paint the player stands in matches their own hue, so a knight
## that has never seen them can look straight through them. That is
## simultaneous contrast used as an opener, and it only works once - after
## the alarm is up, every sworn in the hall is awake.
##
## States: PATROL -> CHASE (permanent), plus INVESTIGATE when a shout from a
## comrade sends it to the alarm point before it has eyes of its own.
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
## Emitted as a knight commits to the MARKED overhead - the blow a held guard
## does not stop. The room teaches the read on it, once per room.
signal perilous_started()
## Emitted when a warden's ground strike erupts: the hall's own colour comes up
## out of the floor. The room paints the shockwave and game.gd sounds it, so the
## ring carries the warden's hue without the room having to guess it.
signal slam_landed(at: Vector2, radius: float, ring_colour: Color)
## THORN-SWORN only: the root answered, and `at` was mended. The room paints the
## pack's heal effect there in the healer's own hue, so the player can see WHICH
## sworn is being kept alive - which is the whole read of the back line.
signal heal_pulsed(at: Vector2, colour: Color)

enum State { PATROL, INVESTIGATE, CHASE }
## Swing state machine: NONE -> WINDUP -> RECOVER -> NONE. A WARDEN also has
## SLAM: the ground strike that comes up through the floor of its own hall.
enum Attack { NONE, WINDUP, RECOVER, SLAM }
## Boss charge state machine: NONE -> WINDUP -> DASH -> RECOVER -> NONE.
enum Charge { NONE, WINDUP, DASH, RECOVER }

## What each set of armour DOES, when the room does not name a role outright.
## The garrison's three trades are read off the art, so a room spec only has to
## name the unit and gets the behaviour that belongs to it.
const ROLE_BY_UNIT := {
	"archer": "archer",
	"monk": "healer",
	"lancer": "lancer",
}

## What armour a unit wears -> what the hall calls it.
const UNIT_NAMES := {
	"knight": "SWORN KNIGHT",
	"harrier": "SWORN THRALL",
	"warden": "SWORN WARDEN",
	"aspirant": "ASPIRANT",
	"champion": "CHAMPION OF THE WHEEL",
	"archer": "SWORN ARCHER",
	"monk": "THORN-SWORN",
	"lancer": "SWORN LANCE",
}

## Things the sworn say. "%s" is replaced with the guard's own colour name, so
## a blue knight shouts about the blue one, and the banter teaches the wheel.
##
## The voice is the story's small print: they are not villains, they are
## guards, and they know exactly what happens to the hall if its colour
## leaves. Short lines only - a bark has to be readable mid-fight.
const BARKS := {
	"alert": [
		"...a colour that is not ours.",
		"The sand moved.",
		"Who walks there?",
	],
	"spotted": [
		"A hueless knight - here?!",
		"Stop! The quarter is not yours!",
		"Thief! For the hall!",
		"The Unsworn - I see it!",
	],
	# The alarm. A knight that has just locked on shouts, and every sworn in
	# earshot wakes up. This is the shout that replaces the vision cone.
	"shout": [
		"THE OATH - WAKE! AN UNSWORN WALKS!",
		"To me! Hueless in the hall!",
		"Ring the hall - it is here!",
	],
	"lost": [
		"Where - where?",
		"It was here.",
		"Find it. FIND IT.",
	],
	"investigate": [
		"I heard a shout.",
		"Something is wrong.",
		"Show yourself.",
	],
	"stagger": [
		"My oath - it cracks!",
		"Not the colour - not the last of it!",
		"How does it cut me?!",
	],
	# The player just turned a blow on the beat. For a sworn knight this is
	# worse than being cut: it means the hueless thing is LEARNING them.
	"parried": [
		"It TURNED my blow!",
		"Who taught it that?",
		"Impossible - again! Come again!",
		"That is OUR school, hueless!",
	],
	# An ally has just spilled their colour nearby. The hall notices.
	"comrade": [
		"%s is down - its colour is out!",
		"You will not have ours!",
		"That was the last of %s.",
	],
	# The player is nearly finished, and the sworn can taste it.
	"last": [
		"It is nearly ours!",
		"Keep it cornered!",
		"One more and the hall keeps its colour.",
	],
	# Warning the player - and the hall - that the marked overhead is coming.
	# They are not gloating: they are promising, which is worse.
	"perilous": [
		"Everything - for the hall!",
		"Guard THAT, hueless.",
		"Hold, and die holding!",
	],
	# A shield boss turning a blow on the wall. He is not gloating: the wall is
	# the whole point of him, and it has held longer than the player has lived.
	"shield": [
		"The wall holds.",
		"The sun does not move.",
		"Beat on it. Beat on it all day.",
	],
	# A warden reaching for the floor of its own hall. Short, because a warden
	# does not explain itself to a thief.
	"slam": [
		"KNEEL.",
		"This ground is ours.",
		"Stand there. STAND THERE.",
	],
	# --- the garrison's three trades (docs/STORY.md §7) ------------------
	# One event each, and only their own: the line's barks belong to the line.
	# An archer speaks when the lane is laid, a THORN-SWORN when the root
	# answers, a lance when it is dragged off its post and turns back for it.
	"shot": [
		"Line up, hueless.",
		"Hold still. The hall aims.",
		"One line. That is all it takes.",
	],
	"heal": [
		"The root will hold.",
		"Grow again, brothers.",
		"You cannot cut us all down.",
	],
	"hold": [
		"This line does not move.",
		"Come into the reach, hueless.",
		"HOLD. To the last.",
	],
	# Boss only: the wait before the charging dash, and the summons.
	"charge": [
		"The wheel will not be denied!",
		"Take up your colour, aspirant.",
		"I was you. You will be me.",
	],
	"summon": [
		"Aspirants! To me!",
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

@export_group("Role")
## WHAT THIS SWORN IS FOR. The line's knights all do the same job; the garrison
## has three trades, and each one changes the fight's shape rather than its
## numbers:
##   "" / "melee" - the ordinary shield-and-sword line.
##   "archer"      - keeps its distance, paints a lane, fires a real arrow.
##   "healer"      - never swings; mends the sworn around it, so the back line
##                   is the thing worth diving.
##   "lancer"      - the longest reach in the hall on the shortest leash.
## Left empty it is inferred from `unit` in _ready(), so a room spec only has
## to name the armour (see ROLE_BY_UNIT).
@export var role: String = ""
## Archer: the band it tries to hold, in pixels. Closer than `keep_min` and it
## gives ground; further than `keep_max` and it walks in; between them it stands
## and draws. The band IS the spacing claim, so the test can assert on it.
@export var keep_min: float = 230.0
@export var keep_max: float = 320.0
## Archer: how far a shot can travel, and how fast. The drawn lane is this
## length, so the picture never promises a reach the arrow does not have.
@export var shoot_range: float = 330.0
@export var arrow_speed: float = 640.0
## Healer: HP mended per pulse, the radius it reaches, and how often.
@export var heal_amount: float = 9.0
@export var heal_radius: float = 150.0
@export var heal_cooldown: float = 3.2
## Healer: inside this distance of the player it stops mending and walks away.
## A support that stands and takes the blade is not a support, it is a target.
@export var heal_flee_range: float = 210.0
## Lancer: how far from the post it was given it will go. Past this it walks
## home while still stabbing anything that comes into reach.
@export var leash_range: float = 260.0

@export_group("Perilous attack")## Every so many swings a knight bets everything on one overhead blow: a longer
## windup (so it stays fair), more reach and damage, and a warning mark over the
## head - because a HELD GUARD DOES NOT STOP IT. This is the genre's rule and
## the anti-turtle rule both: the player has to move on the mark. Rolling it, or
## parrying it on the beat, is the answer.
@export var perilous_every: int = 4
## The perilous windup, as a multiple of the ordinary one.
@export var perilous_windup_scale: float = 1.7
## Its damage, as a multiple of the ordinary swing.
@export var perilous_damage_scale: float = 2.2
## Its reach, as a multiple of the ordinary swing.
@export var perilous_reach_scale: float = 1.15

@export_group("Warden slam")
## The hall's wardens fight their own floor: when the player hugs them, they
## strike the ground and the colour comes up through it in a ring. It is the
## answer to standing under a boss and trading - the one place a big enemy is
## otherwise safe to be farmed from.
@export var slam_windup: float = 1.05
## Radius of the ring, in pixels. The drawn disc IS the radius that hurts.
@export var slam_radius: float = 168.0
## Damage when the ring erupts.
@export var slam_damage: float = 30.0
## Open window after the strike, for the player who rolled out of it.
@export var slam_recover: float = 0.9
## Seconds between slams.
@export var slam_cooldown: float = 7.0
## How close the player has to be for the warden to reach for the floor.
@export var slam_trigger_range: float = 100.0

@export_group("Boss phases")
## HP ratio at or below which the Champion enters phase II (adds the charge).
@export var phase_two_ratio: float = 0.66
## HP ratio at or below which he enters phase III (summons + spins faster).
@export var phase_three_ratio: float = 0.33
## How much faster the wheel spins once he is losing.
@export var phase_three_hue_scale: float = 1.8
## Aspirants called in when phase III begins.
@export var summons_count: int = 2
## How much faster a shield boss's ground strike comes once his wall is down
## (phase II). 0.6 = roughly every four seconds instead of every seven.
@export var phase_two_slam_scale: float = 0.6

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

@export_group("Boss identity")
## The name the HUD puts over the boss bar and the herald shouts when the
## warden steps out. Empty for ordinary knights.
@export var boss_display_name: String = ""
## The line under the name in the arrival banner.
@export var boss_subtitle: String = ""
## The quarter of the Wheel this warden keeps. The room hands the name to the
## game on death (§12.4); empty for everyone but a boss.
@export var quarter: String = ""
## How many phases the duel has, for the HUD's phase pips.
@export var boss_phases: int = 3
## True for the Champion: his defence is the TURNING WHEEL, so the complement
## kill window applies and the ring of hues is drawn around him. A boss with
## a shield stance leaves this false - he is not vulnerable to a wheel window.
@export var wheel_style: bool = false

@export_group("Shield stance")
## A boss whose defence is a raised shield rather than the turning wheel: a
## plain blow from the front is turned aside. The counterplay is named in the
## fiction - break the wall with the heavy third swing, parry him on the beat,
## or get behind the direction he is facing.
@export var has_shield_stance: bool = false
## Half-width of the shield's facing arc, in degrees. The arc that is DRAWN is
## the arc that blocks, so a blow outside it is a blow from behind.
@export var shield_half_deg: float = 70.0
## How long the shield stays open after it is broken by a heavy blow or a
## parry. Long enough to punish, short enough that the wall comes back.
@export var shield_break_time: float = 2.5
## How much slower he moves with the shield up: a wall is not a sprinter.
@export var shield_move_scale: float = 0.55

@export_group("Sight")
## How far a knight notices movement, in pixels. This is both the range of the
## sight test AND the reach of the drawn cone, so the wedge can never claim
## more or less than the knight can actually see.
@export var sight_range: float = 310.0
## Full width of the sight arc in degrees. Half of this is the half-angle.
##
## The room authors this per hall (64 wide by default, 92 for the Champion,
## 150 for Hall I's warden), so this export value is what a Guard built
## outside the room uses. The drawn cone and the sight test both read it.
@export var sight_arc_deg: float = 64.0
## Opacity of the faint sight cone's fill. Deliberately tiny: the cone is a
## readability cue for "which way is this one looking", never a stealth meter
## and never the brightest thing on the sand.
@export_range(0.0, 0.3) var cone_alpha: float = 0.06
## Opacity of the cone's outline, a touch stronger than the fill so the arc
## still has an edge to read at a glance.
@export_range(0.0, 0.4) var cone_edge_alpha: float = 0.13
## Seconds of full contrast needed to go from unaware to chasing.
@export var detect_time: float = 0.45
## How fast the meter drains when the guard cannot see you. Only matters
## before the first lock-on: after that the oath never lets go.
@export var detect_decay: float = 1.15
## Must match Player.hide_tolerance_deg, or the rules would lie about what the
## paint veil does.
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
## The full length of the windup that is running right now: perilous overheads
## wind up for longer, and the telegraph's growth is measured against this, not
## against the ordinary `attack_windup`, or a marked blow would start at 0.8.
var _windup_len: float = 0.0
## How far the swing that is winding up (or just landed) actually reaches. Set
## when the attack is chosen so the drawn wedge is exactly the wedge that cuts.
var _reach_now: float = 60.0
## True while the windup is the UNBLOCKABLE, marked overhead.
var _perilous: bool = false
## Swings since the last overhead, so they arrive on a rhythm.
var _swings_since_perilous: int = 0
## Counts down inside Attack.SLAM and its recovery.
var _slam_left: float = 0.0
## Counts down between slams.
var _slam_cooldown_left: float = 0.0
## 1 -> 0 fade of the shockwave drawn right after the ring erupts.
var _slam_ring: float = 0.0
## The pack's warning sign, held over a knight winding up the marked blow.
var _warn_mark: Texture2D = null
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
## The authored slam cooldown, so phase II can quicken it without compounding.
var _base_slam_cooldown: float = 0.0
## The authored slam radius/damage, restored if a spec never overrides them.
var _base_slam_radius: float = 168.0
var _base_slam_damage: float = 30.0

## Where this sworn was posted, in world px. The lancer's leash is measured
## from here, which is what makes "it will not follow you home" true.
var home: Vector2 = Vector2.ZERO

## --- archer ------------------------------------------------------------
## The lane the current shot is committed to. Locked when the windup opens (not
## when the arrow leaves) so the line on the sand is exactly the line the arrow
## takes, and stepping out of it is a real answer.
var _lane_dir: Vector2 = Vector2.RIGHT
var _shot_left: float = 0.0
## The arrow in flight, if any. A real travelling body: it stops on walls, it
## can be blocked, and it is not a hitscan pretending to be a shot.
var arrow_flying: bool = false
var arrow_pos: Vector2 = Vector2.ZERO
var arrow_dir: Vector2 = Vector2.RIGHT
var _arrow_travel: float = 0.0
var _arrow_tex: Texture2D = null

## --- healer ------------------------------------------------------------
var _heal_cooldown_left: float = 0.0

## True while the shield is actually in front of him. Written only by
## _update_shield(), so the picture and the rule can never disagree.
var shield_up: bool = false
## Seconds during which a broken shield cannot be raised again.
var _shield_broken_left: float = 0.0

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
	# The post it was given, and the trade it follows. Both are read here because
	# this is the first moment the room has finished dressing the body: `unit`
	# is already set, and so is its position.
	home = global_position
	if role.is_empty():
		role = str(ROLE_BY_UNIT.get(unit, "melee"))
	if role == "archer":
		_arrow_tex = load("res://assets/fx/arrow.png")
	_base_hue_speed = hue_speed
	_base_slam_cooldown = slam_cooldown
	_base_slam_radius = slam_radius
	_base_slam_damage = slam_damage
	# A shield boss starts the duel behind the wall; every other knight has no
	# shield at all (and shield_up stays false for the whole fight).
	shield_up = has_shield_stance
	# The pack's own hazard sign: the mark that says "do not block this one".
	_warn_mark = load("res://assets/fx/mark_warning.png")
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
	_slam_ring = maxf(_slam_ring - delta * 1.6, 0.0)
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
	# A warden plants behind its shield, and the hall's shield boss does it
	# even while advancing: the stance is the read, so the pose has to hold it.
	elif (want == "idle" and unit == "warden" or shield_up) \
			and _sprite.sprite_frames.has_animation("guard"):
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


## Choose the next swing and open its windup. Most swings are the ordinary
## sweep; every `perilous_every` of them is the OVERHEAD - longer windup, longer
## reach, and unblockable, announced by the warning mark over the head. It is
## the answer to a player who only ever holds the guard, and it is the only
## attack in the game that asks for a roll or a parry by name.
func _start_windup() -> void:
	_perilous = _swings_since_perilous >= perilous_every
	if _perilous:
		_say("perilous")
		perilous_started.emit()
	_windup_len = attack_windup * (perilous_windup_scale if _perilous else 1.0)
	_reach_now = attack_reach * (perilous_reach_scale if _perilous else 1.0)
	_attack_left = _windup_len
	attack_state = Attack.WINDUP
	_begin_attack()


func _physics_process(delta: float) -> void:
	if dead:
		return

	# An arrow already in the air is its own body, so it keeps flying while the
	# archer is staggered, winding up, or walking away from the line it painted.
	_update_arrow(delta)

	# --- the Champion drags the wheel around ------------------------------
	if not is_zero_approx(hue_speed):
		colour = Color.from_hsv(fposmod(colour.h + (hue_speed / 360.0) * delta, 1.0), colour.s, colour.v, 1.0)

	_update_shield(delta)

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
		var in_sight: bool = _in_sight(player.global_position)
		if in_sight:
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
				# The shout. Every sworn in earshot hears it and wakes up -
				# this line is the whole alarm system, spoken out loud.
				_say("shout" if randf() < 0.6 else "spotted")
			state = State.CHASE
			_lost_timer = 0.0
	elif state == State.CHASE:
		# THE OATH IS TOTAL. There is no give-up branch any more: a knight
		# that has seen the Unsworn follows until one of them is on the sand.
		# Losing sight does not matter - `_do_chase` walks at the player's
		# real position, and the hall is small enough that the only way out
		# is through. The meter only ever matters for the FIRST lock-on, and
		# that is the one moment the paint veil buys.
		_lost_timer = 0.0
	else:
		detection = clampf(detection - delta * detect_decay, 0.0, 1.0)


func _player() -> Player:
	if room == null:
		return null
	return room.player


## Half-angle of the sight test, in radians. `_in_sight()` and the drawn cone
## both call this, so the wedge the player sees is exactly the wedge that can
## see them.
func sight_half_rad() -> float:
	return deg_to_rad(sight_arc_deg * 0.5)


func _in_sight(point: Vector2) -> bool:
	var to_point: Vector2 = point - global_position
	var dist: float = to_point.length()
	if dist > sight_range:
		return false
	if dist < 1.0:
		return true
	return absf(_angle_delta(to_point.angle(), _facing)) <= sight_half_rad()


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


## How fast this body moves right now. A shield boss advances behind the wall,
## so closing the distance must cost him something.
func _move_scale() -> float:
	return shield_move_scale if shield_up else 1.0


## Keep the shield honest. It is up only while the stance is intact, he is not
## reeling from a parry or a broken guard, and he has not reached phase II - at
## which point the wall comes down for the rest of the duel.
##
## This is the ONLY writer of `shield_up`, which is why the drawn arc and the
## blocking rule can never drift apart.
func _update_shield(delta: float) -> void:
	if not has_shield_stance:
		shield_up = false
		return
	if boss_phase >= 2:
		has_shield_stance = false
		shield_up = false
		return
	_shield_broken_left = maxf(_shield_broken_left - delta, 0.0)
	shield_up = stagger_left <= 0.0 and _shield_broken_left <= 0.0


## Knock the wall open for `seconds`. Called by the room when a parry lands and
## by take_hit() when a heavy blow or a complement shatter connects with it.
func break_shield(seconds: float) -> void:
	if not has_shield_stance:
		return
	_shield_broken_left = maxf(_shield_broken_left, seconds)
	shield_up = false


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
	velocity = Vector2.RIGHT.rotated(_facing) * patrol_speed * _move_scale()


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

	# The garrison's three trades do not fight like the line does, so they do not
	# walk like it either. Each has its own chase; everything below this is the
	# line's shield-and-sword.
	match role:
		"archer":
			_do_archer(delta, player)
			return
		"healer":
			_do_healer(delta, player)
			return
		"lancer":
			_do_lancer(delta, player)
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
		Attack.SLAM:
			# The warden plants and reaches for the floor. Planted throughout:
			# the ring is coming up out of the ground under the player's boots,
			# so walking out of it is the whole answer until the last moment.
			velocity = Vector2.ZERO
			_slam_left = maxf(_slam_left - delta, 0.0)
			if _slam_left <= 0.0:
				_slam_land(player)
		_:
			_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
			_charge_cooldown_left = maxf(_charge_cooldown_left - delta, 0.0)
			_slam_cooldown_left = maxf(_slam_cooldown_left - delta, 0.0)
			# A warden that is being hugged drops the sword and hits the floor:
			# everything inside the ring takes it, through any guard, and the
			# player's roll is the answer. Checked before the swing so that
			# closing in on a boss is not a way to make it harmless.
			if is_boss and not player.frozen and _slam_cooldown_left <= 0.0 \
					and dist <= slam_trigger_range:
				_start_slam()
				return
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
				_start_windup()
			elif dist > attack_range * 0.85:
				velocity = Vector2.RIGHT.rotated(_facing) * chase_speed * _move_scale()
			else:
				velocity = Vector2.ZERO


# ---------------------------------------------------------------------------
# The garrison's three trades
# ---------------------------------------------------------------------------

## THE ARCHER - a sworn who keeps the line at arm's length and shoots you down
## it. Two reads, and both are on the sand before anything happens:
##   1. the SPACING: inside `keep_min` it gives ground, and it will never stand
##      and trade, so cornering it is the fight;
##   2. the LANE: the shot's direction is locked when the windup opens and drawn
##      for its whole windup, so the arrow goes exactly where the line said it
##      would. Stepping out of the lane during the draw is the answer.
func _do_archer(delta: float, player: Player) -> void:
	match attack_state:
		Attack.WINDUP:
			# Drawing. The feet are still free, so it backs off if you close in -
			# but slowly, because a drawn bow is not a sprint.
			var drawn_to: float = player.global_position.distance_to(global_position)
			velocity = Vector2.RIGHT.rotated(_facing + PI) * chase_speed * 0.55 \
				if drawn_to < keep_min else Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				_loose_arrow()
			return
		Attack.RECOVER:
			velocity = Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				attack_state = Attack.NONE
			return

	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	if player.frozen:
		velocity = Vector2.ZERO
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	# The band: hold it. Too close and it retreats, too far and it advances.
	if dist < keep_min:
		velocity = -to_player.normalized() * chase_speed * 0.9 if dist > 0.001 else Vector2.ZERO
	elif dist > keep_max:
		velocity = to_player.normalized() * chase_speed * 0.9
	else:
		velocity = Vector2.ZERO

	# One arrow in the air at a time: the read is the lane, not the volume.
	if dist <= shoot_range and _attack_cooldown_left <= 0.0 and not arrow_flying:
		_start_shot(to_player)


## Open the draw and LOCK the lane. It points at the player as they are when the
## windup begins and does not follow them afterwards, which is what makes
## walking out of it work.
func _start_shot(to_player: Vector2) -> void:
	_lane_dir = to_player.normalized() if to_player.length() > 0.001 else Vector2.RIGHT.rotated(_facing)
	_facing = _lane_dir.angle()
	_windup_len = attack_windup * 1.3
	_attack_left = _windup_len
	_reach_now = shoot_range
	_perilous = false
	attack_state = Attack.WINDUP
	_begin_attack()
	_say("shot")


## The string releases. The arrow is a body in the hall from here on: it is
## stopped by walls, it can be guarded, and it can be outrun.
func _loose_arrow() -> void:
	attack_state = Attack.RECOVER
	_attack_left = attack_recover
	_attack_cooldown_left = attack_cooldown
	_swing_flash = 1.0
	arrow_dir = _lane_dir
	arrow_pos = global_position + arrow_dir * (body_radius + 10.0)
	_arrow_travel = 0.0
	arrow_flying = true


## Fly the arrow. Stepped in short hops so a fast arrow cannot tunnel through a
## wall, and every hop is checked against the walls (layer 1) and the Unsworn.
func _update_arrow(delta: float) -> void:
	if not arrow_flying:
		return
	var player: Player = _player()
	var remaining: float = arrow_speed * delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	while remaining > 0.0:
		var step: float = minf(remaining, 12.0)
		var next: Vector2 = arrow_pos + arrow_dir * step
		if space != null:
			var query := PhysicsRayQueryParameters2D.create(arrow_pos, next, 1)
			query.collide_with_areas = false
			if not space.intersect_ray(query).is_empty():
				# Into the stonework. The hall keeps its colour.
				arrow_flying = false
				return
		arrow_pos = next
		_arrow_travel += step
		remaining -= step
		if player != null and not player.frozen \
				and arrow_pos.distance_to(player.global_position) <= player.body_radius + 7.0:
			# A front blow through the ordinary path: a held guard stops it, a
			# parry turns it, the roll's i-frames ignore it. No special case -
			# an arrow is a blade with a longer arm.
			player.take_damage(damage, global_position, false)
			arrow_flying = false
			return
		if _arrow_travel >= shoot_range:
			arrow_flying = false
			return


## THE THORN-SWORN - it does not fight. It mends the sworn around it on a slow
## pulse, which turns the back line into the thing worth diving, and it walks
## away from the blade instead of trading with it. Never heals itself: killing
## the monk has to stay the answer.
func _do_healer(delta: float, player: Player) -> void:
	match attack_state:
		Attack.WINDUP:
			velocity = Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				_heal_pulse()
			return
		Attack.RECOVER:
			velocity = Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				attack_state = Attack.NONE
			return

	_heal_cooldown_left = maxf(_heal_cooldown_left - delta, 0.0)
	if player.frozen:
		velocity = Vector2.ZERO
		return

	var dist: float = player.global_position.distance_to(global_position)
	# Face the blade and give ground from it: the root is patient, not brave.
	velocity = Vector2.RIGHT.rotated(_facing + PI) * chase_speed * 0.9 \
		if dist < heal_flee_range else Vector2.ZERO
	if _heal_cooldown_left <= 0.0 and _wounded_ally() != null:
		_start_heal()


func _start_heal() -> void:
	_windup_len = attack_windup * 0.8
	_attack_left = _windup_len
	_perilous = false
	attack_state = Attack.WINDUP
	_begin_attack()


## The root answers: every wounded sworn inside `heal_radius` with a clear path
## is mended, and the room paints the pack's heal effect on each one. Out of the
## radius, behind a wall, or already whole - nothing. The drawn ring during the
## cast IS this radius.
func _heal_pulse() -> void:
	attack_state = Attack.RECOVER
	_attack_left = attack_recover * 0.7
	_heal_cooldown_left = heal_cooldown
	var mended: int = 0
	if room != null:
		for other in room.guards:
			if other == self or not is_instance_valid(other) or other.dead or other.dormant:
				continue
			if other.hp >= other.max_hp - 0.01:
				continue
			if other.global_position.distance_to(global_position) > heal_radius:
				continue
			if not room.has_line_of_sight(global_position, other.global_position):
				continue
			other.hp = minf(other.hp + heal_amount, other.max_hp)
			heal_pulsed.emit(other.global_position, colour)
			mended += 1
	if mended > 0:
		_say("heal")


## The nearest sworn this one could actually reach: wounded, inside the radius,
## and not behind a wall. Null when the root has nothing to do.
func _wounded_ally() -> Guard:
	if room == null:
		return null
	var best: Guard = null
	var best_ratio: float = 0.999
	for other in room.guards:
		if other == self or not is_instance_valid(other) or other.dead or other.dormant:
			continue
		var ratio: float = other.health_ratio()
		if ratio >= best_ratio:
			continue
		if other.global_position.distance_to(global_position) > heal_radius:
			continue
		if not room.has_line_of_sight(global_position, other.global_position):
			continue
		best = other
		best_ratio = ratio
	return best


## THE SWORN LANCE - the longest reach in the hall on the shortest leash. It
## plants, turns slowly and stabs a long way, so the fight is about the angle,
## not about a queue of knights. `leash_range` is measured from the post it was
## given: past it, the lance walks home while still stabbing anything that comes
## into the reach, so the player can lead it, but cannot take it home.
func _do_lancer(delta: float, player: Player) -> void:
	match attack_state:
		Attack.WINDUP:
			velocity = Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				_swing(player)
			return
		Attack.RECOVER:
			velocity = Vector2.ZERO
			_attack_left = maxf(_attack_left - delta, 0.0)
			if _attack_left <= 0.0:
				attack_state = Attack.NONE
			return

	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	var to_home: Vector2 = home - global_position
	var leashed: bool = to_home.length() > leash_range
	if leashed:
		# Dragged off its line. It says so, once per bark, and turns back for
		# the post - facing the player the whole way, because the reach is what
		# it is retreating behind.
		if bark_left <= 0.0:
			_say("hold")
		velocity = to_home.normalized() * chase_speed * 0.85
		if not player.frozen \
				and player.global_position.distance_to(global_position) <= attack_range \
				and _attack_cooldown_left <= 0.0:
			_start_windup()
		return

	var dist: float = player.global_position.distance_to(global_position)
	if not player.frozen and dist <= attack_range and _attack_cooldown_left <= 0.0:
		_start_windup()
	elif dist > attack_range * 0.85:
		velocity = Vector2.RIGHT.rotated(_facing) * chase_speed * _move_scale()
	else:
		velocity = Vector2.ZERO


## The warden commits to the ground strike. One and a quarter seconds of
## telegraph, and the disc drawn during it is exactly `slam_radius`: what the
## player sees is what will hurt, which is the only reason a one-shot ring this
## big is allowed to be unblockable.
func _start_slam() -> void:
	attack_state = Attack.SLAM
	_slam_left = slam_windup
	_swing_flash = 0.0
	_say("slam")
	_begin_attack()


## The ring erupts. Everyone inside it takes it through their guard - it comes up
## out of the floor, so there is nothing in front of the player to hold a blade
## against - and the roll's i-frames are the whole counterplay. The shockwave is
## the room's to paint and game.gd's to sound.
func _slam_land(player: Player) -> void:
	attack_state = Attack.RECOVER
	_attack_left = slam_recover
	_slam_cooldown_left = slam_cooldown
	_slam_ring = 1.0
	slam_landed.emit(global_position, slam_radius, colour)
	if player == null:
		return
	var gap: float = player.global_position.distance_to(global_position)
	if gap <= slam_radius + player.body_radius:
		player.take_damage(slam_damage, global_position, true)


## True while the marked overhead is winding up (the room's teaching hook and
## the tests both read it).
func is_perilous_windup() -> bool:
	return attack_state == Attack.WINDUP and _perilous


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
				# Unblockable: a charging Champion is a thing to be out of the
				# way of, not a thing to stand in front of behind a blade.
				player.take_damage(charge_damage, global_position, true)
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


## The blade falls: anything still inside the arc takes the hit. A PERILOUS
## overhead is announced as unblockable, so the player's guard is not consulted
## for it at all - only the roll's i-frames and the parry's window can answer it.
func _swing(player: Player) -> void:
	attack_state = Attack.RECOVER
	_attack_left = attack_recover
	_attack_cooldown_left = attack_cooldown
	_swing_flash = 1.0
	var was_perilous: bool = _perilous
	var damage_now: float = damage * (perilous_damage_scale if was_perilous else 1.0)
	if was_perilous:
		_swings_since_perilous = 0
	else:
		_swings_since_perilous += 1
	_perilous = false
	var to_player: Vector2 = player.global_position - global_position
	var inside: bool = to_player.length() <= _reach_now + player.body_radius \
		and absf(_angle_delta(to_player.angle(), _facing)) <= deg_to_rad(attack_half_deg)
	if inside:
		player.take_damage(damage_now, global_position, was_perilous)


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


## An ally has just spilled their colour nearby. The hall notices, and says so.
func grieve(dead_colour: Color) -> void:
	if dead:
		return
	_say("comrade", ColorTheory.color_name(dead_colour))


## The player is nearly finished and the sworn can taste it. Only ever fired
## once per room by the game, so it reads as a moment and not a nag.
func taste_blood() -> void:
	if dead or state != State.CHASE:
		return
	_say("last")


## What the hall calls this one. Used by the HUD, the barks and the obituaries.
func unit_name() -> String:
	return str(UNIT_NAMES.get(unit, "SWORN KNIGHT"))


## Say a random line for `event`. A "%s" in the line is filled with `fill`
## when given (an ally's colour, say) and with this guard's own colour name
## otherwise.
func _say(event: String, fill: String = "") -> void:
	var lines: Array = BARKS.get(event, [])
	if lines.is_empty():
		return
	var line: String = str(lines[randi() % lines.size()])
	if line.find("%s") >= 0:
		line = line % (fill if not fill.is_empty() else ColorTheory.color_name(colour))
	bark_text = line
	bark_left = 2.0
	bark_total = 2.0
	bark_colour = colour


## Bark from the hall's own mouth, called by the room - the line has to come
## out of THEM, because a parry is their oath cracking, not the player's deed.
func bark(event: String) -> void:
	_say(event)


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

	# THE SHIELD STANCE. A blow from the side the shield faces is turned aside:
	# no damage, a bright clang, and the knight's own word for it. The wall
	# opens only to the things the fiction names - the heavy third swing, a
	# complement shatter, or a parry (handled by the room, which knows who
	# swung) - or to a blow from behind it.
	if shield_up:
		var to_attacker: Vector2 = from_position - global_position
		var in_front: bool = to_attacker.length() < 0.001 \
			or absf(_angle_delta(to_attacker.angle(), _facing)) <= deg_to_rad(shield_half_deg)
		if in_front:
			if shatter or heavy:
				# The heavy swing is the guard-break: the wall comes open for a
				# real window, and the blow lands whole behind it.
				break_shield(shield_break_time)
			else:
				clang()
				_say("shield")
				return false

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
	# A shield boss's phase II is the wall coming down: he stops defending, the
	# ground strike quickens, and the charge unlocks (guard.gd's chase branch
	# only runs it from boss_phase >= 2). The wheel boss has no shield to drop.
	if boss_phase == 2 and has_shield_stance:
		has_shield_stance = false
		shield_up = false
		_shield_broken_left = 0.0
		slam_cooldown = maxf(_base_slam_cooldown * phase_two_slam_scale, 1.0)
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
				# The warden's own name, so the first boss and the last boss do
				# not both announce the Champion.
				var label: String = "%s KNEELS" % (boss_display_name if boss_display_name != "" else "THE CHAMPION")
				draw_string(font, Vector2(-130.0, body_radius + 26.0), label,
					HORIZONTAL_ALIGNMENT_CENTER, 260.0, 12, Color(1.0, 1.0, 1.0, 0.85))
			return
		# A quick white pop instead of an enemy that simply vanishes.
		var t: float = 1.0 - clampf(_death_left / 0.26, 0.0, 1.0)
		draw_circle(Vector2.ZERO, body_radius * (1.0 + t * 1.6), Color(1.0, 1.0, 1.0, (1.0 - t) * 0.8))
		return

	var body: Color = colour

	# --- the faint sight cone ---------------------------------------------
	# Where this sworn is looking, drawn in its own hue at an alpha low enough
	# to sit UNDER everything without ever competing with the fight. It is not
	# a stealth meter and it is not a promise: the same arc that is drawn here
	# is the arc `_in_sight()` tests, so a player who is inside the wedge can
	# be seen (if the paint under their feet lets them be seen at all). A patch
	# of detection opens the cone a hair, which is the only thing about it that
	# moves; the rest of the time it is a quiet direction marker.
	var cone_fill: float = cone_alpha + 0.04 * detection
	_draw_wedge(sight_half_rad(), sight_range,
		Color(body.r, body.g, body.b, cone_fill),
		Color(body.r, body.g, body.b, cone_edge_alpha))

	# --- the notice ring --------------------------------------------------
	# The oath does not need a wedge of light to do its work - the faint cone
	# above is only a direction cue. THIS ring is the warning: while a
	# knight is working out whether it has seen you, a thin ring tightens
	# around its feet in its own hue. The moment it locks on, the ring shuts
	# and the alarm shout goes up - which is the only "vision" the player
	# needs to read, and it reads at a glance.
	if detection > 0.001:
		var locked: bool = detection >= 1.0 or state == State.CHASE
		var rr: float = body_radius * (2.2 + 2.4 * detection)
		var ring_a: float = 0.20 if locked else (0.26 + 0.55 * detection)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 26, Color(body.r, body.g, body.b, ring_a),
			1.2 + 1.6 * detection if not locked else 1.2)

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
			# The Champion's dash is a PERILOUS attack too: the mark over his
			# head tells the player that the guard will not save them here.
			_draw_perilous_mark(ct)
		else:
			draw_line(Vector2.ZERO, t_end, Color(1.0, 0.20, 0.10, 0.22), body_radius * 1.9)

	# --- swing telegraph and blade arc ------------------------------------
	# The windup wedge grows towards the swing's reach; the flashing wedge
	# right after the blade falls shows exactly where it went. Both are drawn
	# on the ground, so "where will the hit land" is never a guess. The warm
	# gold is deliberately NOT the guard's own hue: the telegraph has to read
	# on top of the vision cone the guard is standing in.
	if attack_state == Attack.WINDUP:
		var wt: float = clampf(1.0 - _attack_left / maxf(_windup_len, 0.01), 0.0, 1.0)
		if _perilous:
			# The marked overhead reads in RED, the genre's universal "this one
			# is not blocked", and carries the pack's own hazard sign overhead.
			# The wedge is drawn at the swing's REAL (longer) reach, so where it
			# points is where it will land.
			_draw_wedge(deg_to_rad(attack_half_deg), _reach_now * (0.55 + 0.45 * wt),
				Color(1.0, 0.18, 0.14, 0.12 + 0.28 * wt),
				Color(1.0, 0.32, 0.24, 0.45 + 0.55 * wt))
			_draw_perilous_mark(wt)
		else:
			_draw_wedge(deg_to_rad(attack_half_deg), _reach_now * (0.55 + 0.45 * wt),
				Color(1.0, 0.82, 0.42, 0.10 + 0.24 * wt),
				Color(1.0, 0.70, 0.30, 0.35 + 0.65 * wt))
	if _swing_flash > 0.0:
		_draw_wedge(deg_to_rad(attack_half_deg), _reach_now,
			Color(1.0, 0.95, 0.82, 0.38 * _swing_flash),
			Color(1.0, 1.0, 1.0, 0.55 * _swing_flash))
	# --- the archer's lane and arrow --------------------------------------
	# The lane is laid down as the bow is drawn and the arrow flies exactly down
	# it: two rails, a wash of the archer's own hue, and a bright edge that runs
	# out to the end of the shot as the draw finishes. Stepping out of the lane
	# before the string releases is the second half of the read (the first is
	# the archer backing away).
	if role == "archer" and attack_state == Attack.WINDUP:
		var lt: float = clampf(1.0 - _attack_left / maxf(_windup_len, 0.01), 0.0, 1.0)
		var lane_end: Vector2 = _lane_dir * shoot_range
		var rail: Vector2 = _lane_dir.orthogonal() * 6.0
		draw_line(rail, lane_end + rail, Color(colour.r, colour.g, colour.b, 0.16 + 0.34 * lt), 2.0)
		draw_line(-rail, lane_end - rail, Color(colour.r, colour.g, colour.b, 0.16 + 0.34 * lt), 2.0)
		# The wash fills out from the bow along the lane the arrow will take.
		var reach: float = shoot_range * lt
		var pts: PackedVector2Array = PackedVector2Array([
			-_lane_dir.orthogonal() * 5.0,
			_lane_dir.orthogonal() * 5.0,
			_lane_dir * reach + _lane_dir.orthogonal() * 5.0,
			_lane_dir * reach - _lane_dir.orthogonal() * 5.0,
		])
		draw_colored_polygon(pts, Color(colour.r, colour.g, colour.b, 0.05 + 0.09 * lt))
	if role == "archer" and arrow_flying and _arrow_tex != null:
		# The pack's own arrow, turned along its flight and painted in the
		# archer's hue. Drawn in local space because _draw() is local to the body.
		draw_set_transform(arrow_pos - global_position, arrow_dir.angle(), Vector2.ONE)
		draw_texture_rect(_arrow_tex, Rect2(-32.0, -32.0, 64.0, 64.0), false,
			Color(colour.r, colour.g, colour.b, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- the healer's ring -------------------------------------------------
	# The circle drawn during the cast is exactly `heal_radius`, so "who is going
	# to be mended" is never a guess. It closes in as the root answers.
	if role == "healer" and attack_state == Attack.WINDUP:
		var ht: float = clampf(1.0 - _attack_left / maxf(_windup_len, 0.01), 0.0, 1.0)
		draw_arc(Vector2.ZERO, heal_radius * (1.0 - 0.12 * ht), 0.0, TAU, 48,
			Color(colour.r, colour.g, colour.b, 0.10 + 0.22 * ht), 1.0 + 1.5 * ht, true)

	# --- the warden's ground strike ---------------------------------------
	# A disc of the hall's own colour, drawn at exactly the radius that hurts,
	# filling up as the warden reaches for the floor. The read is spatial, not
	# directional: the answer is to be OUT of it, and the answer is visible from
	# the first frame.
	if attack_state == Attack.SLAM:
		var st: float = clampf(1.0 - _slam_left / maxf(slam_windup, 0.01), 0.0, 1.0)
		var disc_r: float = slam_radius * (0.62 + 0.38 * st)
		draw_circle(Vector2.ZERO, disc_r, Color(colour.r, colour.g, colour.b, 0.06 + 0.16 * st))
		draw_arc(Vector2.ZERO, slam_radius, 0.0, TAU, 64,
			Color(colour.r, colour.g, colour.b, 0.35 + 0.55 * st), 2.0 + 2.0 * st, true)
		# The last fraction of a second, the disc burns white: leave now.
		if st > 0.82:
			var warn: float = (st - 0.82) / 0.18
			draw_arc(Vector2.ZERO, slam_radius, 0.0, TAU, 64,
				Color(1.0, 0.96, 0.90, 0.55 * warn), 3.0 + 2.0 * warn, true)
	if _slam_ring > 0.0:
		# The shockwave itself: the ring running outward past the radius that
		# hurt, so the player can see how close they were.
		var ring_r: float = slam_radius * (1.0 + 0.28 * (1.0 - _slam_ring))
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64,
			Color(colour.r, colour.g, colour.b, 0.85 * _slam_ring), 5.0 * _slam_ring + 1.0, true)

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

	# --- the shield stance ------------------------------------------------
	# The arc that is drawn IS the arc that blocks (shield_half_deg): a blow
	# outside it is a blow from behind, and the picture says so before the rule
	# is ever tested. A broken wall is drawn dim and cracked, so the opening is
	# as readable as the wall was.
	if has_shield_stance:
		var half: float = deg_to_rad(shield_half_deg)
		if shield_up:
			draw_arc(Vector2.ZERO, body_radius + 11.0, _facing - half, _facing + half, 28,
				Color(colour.r, colour.g, colour.b, 0.85), 6.0, true)
			draw_arc(Vector2.ZERO, body_radius + 14.0, _facing - half, _facing + half, 28,
				Color(1.0, 0.95, 0.82, 0.60), 2.0, true)
		else:
			# Broken: no wall, but the habit is still visible.
			draw_arc(Vector2.ZERO, body_radius + 11.0, _facing - half, _facing + half, 24,
				Color(colour.r, colour.g, colour.b, 0.18), 2.0, true)

	# --- Champion of the Wheel extras ------------------------------------
	if is_boss and wheel_style:
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
	# Phase pips above the shoulders: one mark per phase, filling as the duel
	# escalates, so its shape is readable between hits.
	if is_boss:
		var span: float = float(maxi(boss_phases, 1) - 1) * 12.0
		for i in boss_phases:
			var pip: Vector2 = Vector2(float(i) * 12.0 - span * 0.5, -body_radius - 54.0)
			var lit: bool = (i + 1) <= boss_phase
			draw_circle(pip, 3.2, Color(1.0, 0.86, 0.35, 0.95) if lit else Color(0.0, 0.0, 0.0, 0.55))

	# --- unit name --------------------------------------------------------
	# One short name, only while the room is awake: the hall's word for what
	# this is (SWORN KNIGHT, SWORN WARDEN...). No hues, no degrees - the
	# colour is the knight's armour and does not need to be read out.
	var font: Font = ThemeDB.fallback_font
	if font != null and (hp < max_hp - 0.001 or state == State.CHASE):
		var label: String = unit_name()
		draw_string(font, Vector2(-70.0, body_radius + 18.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 140.0, 10, Color(0.0, 0.0, 0.0, 0.6))
		draw_string(font, Vector2(-70.0, body_radius + 17.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 140.0, 10, Color(1.0, 1.0, 1.0, 0.62))


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


## The pack's own triangular hazard sign, held over the head of a knight who is
## winding up the blow that cannot be blocked. Deliberately large, red and
## bobbing: this is the one moment in a fight where looking at the enemy and
## not at your own health bar is the correct play.
func _draw_perilous_mark(t: float) -> void:
	if _warn_mark == null:
		return
	var cell: float = float(_warn_mark.get_height())
	var frames: int = maxi(int(_warn_mark.get_width() / cell), 1)
	# The strip is a 60-frame animation that ends by COLLAPSING the sign, which
	# would read as "the danger has passed" exactly when it has not. So the
	# sign pops in over the first fifth of the windup and then holds on a frame
	# that is safely inside the visible stretch.
	var pop: float = clampf(t / 0.22, 0.0, 1.0)
	var frame: int = clampi(4 + int(pop * 40.0), 0, frames - 1)
	var size: float = body_radius * 3.6 * (0.68 + 0.32 * pop)
	var bob: float = sin(_time * 11.0) * 2.5
	var pos := Vector2(-size * 0.5, -body_radius * 2.4 - size + bob)
	draw_texture_rect_region(_warn_mark, Rect2(pos, Vector2(size, size)),
		Rect2(float(frame) * cell, 0.0, cell, cell), Color(1.0, 0.38, 0.32, 0.95))
