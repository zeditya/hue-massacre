class_name BloodField
extends Node2D
##
## BLOOD FIELD - the arena's visceral second layer.
##
## `paint_layer.gd` is the RULE layer: it answers "what colour is the floor
## here?", and the camouflage maths depends on it. This file is the LOOK layer:
## the wet, physical blood of a fight. It never answers a rules question, so it
## is free to be as red and as messy as it likes - and the two layers work
## together: a knight spills their hue as paint (the rule) and their blood as
## blood (the picture, tinted with that same hue so the fiction stays one thing).
##
## Three kinds of thing live here:
##
##   DROPS   - the spray thrown off a hit. Each droplet is a short streak with
##             velocity, gravity and drag; it dies on the sand and becomes...
##   STAINS  - a permanent-ish mark on the ground. Stains fade only very slowly
##             (default 45s), so by the end of an arena the sand is a butcher's
##             board, which is exactly the point.
##   POOLS   - the big, growing puddle under a body. Same as a stain, but it
##             swells from 0 to full radius over a beat, like a spreading pool.
##   SPLATTER - arterial spray on vertical surfaces (walls), drips down over time
##
## Everything is drawn with `draw_*` calls (no textures), capped by
## `max_stains` / `max_drops`, and the node turns its own processing off when
## the field is quiet, so a long fight never costs more than a quiet one.

@export_group("Spray")
## Droplets thrown per hit at power 1.0.
@export var drops_per_hit: int = 24
## Downward pull on a droplet, in pixels/second^2.
@export var gravity: float = 720.0
## How quickly a droplet loses speed (per second, applied as exponential drag).
@export var drag: float = 3.5
## Droplet life, in seconds, before it lands as a stain.
@export var drop_life_min: float = 0.25
@export var drop_life_max: float = 0.65

@export_group("Stains")
## A landed droplet leaves a mark this big (scaled by the droplet's size).
@export var drop_stain_radius: float = 6.0
## A death leaves a pool this big, before `pool_scale_mul` for the boss.
@export var pool_radius: float = 36.0
## How long a stain stays on the sand before it has faded away entirely.
@export var stain_lifetime: float = 60.0
## Fraction of the life a stain spends fully opaque.
@export var stain_hold: float = 0.6
## Upper bound on remembered stains. The oldest is forgotten past this.
@export var max_stains: int = 400
## Upper bound on live droplets.
@export var max_drops: int = 300
## Blood pools spread over time
@export var pool_spread_speed: float = 8.0
## Blood darkens as it dries
@export var drying_enabled: bool = true

@export_group("Splatter")
## Arterial spray on walls
@export var splatter_enabled: bool = true
@export var max_splatters: int = 80
@export var splatter_lifetime: float = 30.0
@export var splatter_drip_speed: float = 12.0

@export_group("Footprints")
## Bloody footprints when walking through blood
@export var footprints_enabled: bool = true
@export var max_footprints: int = 60
@export var footprint_lifetime: float = 20.0

## Live droplets: { pos, vel, colour, size, age, life }
var drops: Array = []
## Marks on the sand: { pos, radius, colour, age, life, gait, grow, dryness }
var stains: Array = []
## Pools: { pos, radius, target_radius, colour, age, life, grow }
var pools: Array = []
## Wall splatter: { pos, vel, colour, size, age, life, wall_normal }
var splatters: Array = []
## Bloody footprints: { pos, colour, age, life, direction, size }
var footprints: Array = []
## Set true while there is anything to animate, so idle frames cost nothing.
var _active: bool = false

## Reference to walls for splatter collision
var walls_ref: Array = []


func _ready() -> void:
	# The gore lies just above the paint (the rule layer), both below actors.
	z_index = -1
	set_process(false)


# ---------------------------------------------------------------------------
# Creating blood
# ---------------------------------------------------------------------------

## The spray of a landed hit. `dir` is the direction the blade was travelling
## (the blood goes that way, plus a wide cone of spread); `power` scales the
## count and the distance: a shatter throws far more than a graze.
func spray(pos: Vector2, dir: Vector2, colour: Color, power: float = 1.0, is_heavy: bool = false, is_shatter: bool = false) -> void:
	var base: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var count_mult: float = 1.0
	var vel_mult: float = 1.0
	var spread_angle: float = 1.0  # radians (~57 deg)

	if is_shatter:
		count_mult = 2.5
		vel_mult = 1.8
		spread_angle = 1.3  # wider for dramatic shatter
	elif is_heavy:
		count_mult = 1.6
		vel_mult = 1.4
		spread_angle = 0.9
	else:
		count_mult = 1.0
		vel_mult = 1.0
		spread_angle = 1.0

	var count: int = int(round(float(drops_per_hit) * clampf(power, 0.4, 2.6) * count_mult))
	for i in count:
		# Cone of spread around the blade's direction
		var spread: float = (randf() * 2.0 - 1.0) * spread_angle * (0.5 + randf() * 0.5)
		var speed: float = randf_range(100.0, 400.0) * sqrt(clampf(power, 0.4, 2.6)) * vel_mult
		var vel: Vector2 = base.rotated(spread) * speed
		var life: float = randf_range(drop_life_min, drop_life_max)
		_add_drop(pos, vel, colour, randf_range(1.5, 3.5), life, is_shatter)

	# Arterial spray for heavy/shatter hits - higher velocity, narrower cone
	if is_heavy or is_shatter:
		var arterial_count: int = int(6 * count_mult)
		for i in arterial_count:
			var spread: float = (randf() * 2.0 - 1.0) * 0.4  # narrow cone
			var speed: float = randf_range(300.0, 600.0) * vel_mult
			var vel: Vector2 = base.rotated(spread) * speed
			var life: float = randf_range(0.4, 0.8)
			_add_drop(pos, vel, colour, randf_range(2.0, 4.0), life, true, true)  # arterial flag

	_active = true
	set_process(true)


## A quiet dribble of blood from a wound that did not kill (used sparingly, so
## the sand keeps telling you where the fight has been without drowning in red).
func dribble(pos: Vector2, colour: Color, amount: int = 4) -> void:
	for i in amount:
		var vel: Vector2 = Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 60.0))
		_add_drop(pos, vel, colour, randf_range(1.2, 2.5), randf_range(0.2, 0.4))
	_active = true
	set_process(true)


## The pool under a body. `scale_mul` lets the Champion spill a hero-sized one.
func pool(pos: Vector2, colour: Color, scale_mul: float = 1.0) -> void:
	var target_r: float = pool_radius * scale_mul
	var blood_col: Color = blood_tint(colour, 0.5)
	pools.append({
		"pos": pos,
		"radius": 1.0,
		"target_radius": target_r,
		"colour": blood_col,
		"age": 0.0,
		"life": stain_lifetime * 1.5 * scale_mul,
		"grow": 0.8 * scale_mul
	})
	# A ring of thrown droplets around the body, so a death reads as a burst
	# rather than a decal appearing under the feet.
	for i in 18:
		var angle: float = randf() * TAU
		var speed: float = randf_range(80.0, 280.0) * scale_mul
		_add_drop(pos, Vector2.RIGHT.rotated(angle) * speed, colour,
			randf_range(2.0, 4.0), randf_range(0.3, 0.6))
	_active = true
	set_process(true)


## Wall splatter - arterial spray hits a wall
func splatter_on_wall(pos: Vector2, dir: Vector2, colour: Color, wall_normal: Vector2) -> void:
	if not splatter_enabled:
		return
	var blood_col: Color = blood_tint(colour, 0.35)
	# Main splatter
	for i in 8:
		var spread: float = (randf() * 2.0 - 1.0) * 0.6
		var speed: float = randf_range(60.0, 180.0)
		var vel: Vector2 = dir.rotated(spread) * speed
		splatters.append({
			"pos": pos,
			"vel": vel,
			"colour": blood_col,
			"size": randf_range(3.0, 7.0),
			"age": 0.0,
			"life": splatter_lifetime,
			"wall_normal": wall_normal,
			"drip_phase": randf() * TAU
		})
	# Drips running down
	for i in 4:
		splatters.append({
			"pos": pos + wall_normal * 2.0 + Vector2(randf_range(-8.0, 8.0), 0.0),
			"vel": Vector2(0.0, randf_range(5.0, 15.0)),
			"colour": blood_col.darkened(0.2),
			"size": randf_range(1.5, 3.0),
			"age": 0.0,
			"life": splatter_lifetime * 1.5,
			"wall_normal": wall_normal,
			"is_drip": true,
			"drip_phase": randf() * TAU
		})
	while splatters.size() > max_splatters:
		splatters.pop_front()
	_active = true
	set_process(true)


## Bloody footprints when a character walks through blood
func add_footprint(pos: Vector2, colour: Color, direction: Vector2, size_mult: float = 1.0) -> void:
	if not footprints_enabled:
		return
	var blood_col: Color = blood_tint(colour, 0.4)
	footprints.append({
		"pos": pos,
		"colour": blood_col,
		"age": 0.0,
		"life": footprint_lifetime,
		"direction": direction.normalized(),
		"size": randf_range(8.0, 12.0) * size_mult
	})
	while footprints.size() > max_footprints:
		footprints.pop_front()
	_active = true
	set_process(true)


func _add_drop(pos: Vector2, vel: Vector2, colour: Color, size: float, life: float, is_shatter: bool = false, is_arterial: bool = false) -> void:
	var tint_amount: float = 0.30
	if is_arterial:
		tint_amount = 0.15  # fresher, brighter blood
	drops.append({
		"pos": pos,
		"vel": vel,
		"colour": blood_tint(colour, tint_amount),
		"size": size,
		"age": 0.0,
		"life": maxf(life, 0.08),
		"is_shatter": is_shatter,
		"is_arterial": is_arterial,
		"trail": []  # for streak effect
	})
	while drops.size() > max_drops:
		drops.pop_front()


func _add_stain(pos: Vector2, radius: float, colour: Color, life: float, grow: bool) -> void:
	stains.append({
		"pos": pos,
		"radius": maxf(radius, 1.5),
		"colour": colour,
		"age": 0.0,
		"life": maxf(life, 1.0),
		"gait": stains.size() * 1.618,
		"grow": 0.7 if grow else 0.0,
		"dryness": 0.0  # 0 = wet, 1 = fully dry
	})
	while stains.size() > max_stains:
		stains.pop_front()


## Every mark in this field, for a room reset.
func clear_all() -> void:
	drops.clear()
	stains.clear()
	pools.clear()
	splatters.clear()
	footprints.clear()
	_active = false
	set_process(false)


# ---------------------------------------------------------------------------
# The look of blood
# ---------------------------------------------------------------------------

## Darken and slightly drain a hue until it reads as blood rather than paint.
## `amount` is how far towards "dried": 0.15 for fresh arterial, 0.30 for a wet droplet, 0.5 for a dried stain.
## The hue survives, so a blue knight still bleeds blue-black, and the
## colour theory stays legible on the floor.
static func blood_tint(colour: Color, amount: float) -> Color:
	var dark: Color = colour.darkened(amount)
	# A touch of desaturation, because real blood is browner than pure hue.
	dark.s = dark.s * 0.72
	dark.v = dark.v * 0.88
	# Shift slightly towards red-brown as it darkens
	var r_shift: float = amount * 0.15
	dark.r = min(dark.r + r_shift, 1.0)
	dark.g = max(dark.g - r_shift * 0.5, 0.0)
	return dark


static func dried_blood_colour(colour: Color) -> Color:
	# Fully dried blood - dark brownish
	var dry: Color = colour.darkened(0.65)
	dry.s = dry.s * 0.4
	dry.v = dry.v * 0.55
	dry.r = min(dry.r + 0.12, 0.45)
	dry.g = min(dry.g, 0.25)
	dry.b = min(dry.b, 0.15)
	return dry


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# --- Drops (airborne) ---
	if not drops.is_empty():
		var i: int = drops.size() - 1
		while i >= 0:
			var d: Dictionary = drops[i]
			d["age"] += delta
			if float(d["age"]) >= float(d["life"]):
				# It hit the sand: leave a mark and forget the droplet.
				var stain_r: float = drop_stain_radius * float(d["size"]) * 0.9
				if d["is_shatter"]:
					stain_r *= 1.4
				if d["is_arterial"]:
					stain_r *= 1.2
				_add_stain(d["pos"], stain_r, d["colour"], stain_lifetime, false)
				drops.remove_at(i)
			else:
				var vel: Vector2 = d["vel"]
				vel.y += gravity * delta
				vel = vel.lerp(Vector2.ZERO, clampf(drag * delta, 0.0, 1.0))
				d["vel"] = vel
				d["pos"] += vel * delta
				# Store trail positions for streak drawing
				if not d.has("trail") or d["trail"].size() == 0:
					d["trail"] = [d["pos"]]
				else:
					d["trail"].append(d["pos"])
					if d["trail"].size() > 5:
						d["trail"].pop_front()
			i -= 1

	# --- Pools (growing puddles under bodies) ---
	if not pools.is_empty():
		var j: int = pools.size() - 1
		while j >= 0:
			var p: Dictionary = pools[j]
			p["age"] += delta
			# Grow towards target radius
			if p["radius"] < p["target_radius"]:
				p["radius"] = min(p["radius"] + pool_spread_speed * delta * p["grow"], p["target_radius"])
			if float(p["age"]) >= float(p["life"]):
				pools.remove_at(j)
			j -= 1

	# --- Stains (on ground, fading) ---
	if not stains.is_empty():
		var k: int = stains.size() - 1
		while k >= 0:
			var s: Dictionary = stains[k]
			s["age"] += delta
			if float(s["age"]) >= float(s["life"]):
				stains.remove_at(k)
			else:
				# Drying progression
				if drying_enabled:
					s["dryness"] = clampf(float(s["age"]) / float(s["life"]), 0.0, 1.0)
			k -= 1

	# --- Splatters (on walls, dripping) ---
	if not splatters.is_empty():
		var m: int = splatters.size() - 1
		while m >= 0:
			var sp: Dictionary = splatters[m]
			sp["age"] += delta
			if float(sp["age"]) >= float(sp["life"]):
				splatters.remove_at(m)
			else:
				if not sp.get("is_drip", false):
					# Airborne splatter - gravity and drag
					var vel: Vector2 = sp["vel"]
					vel.y += gravity * delta * 0.5
					vel = vel.lerp(Vector2.ZERO, clampf(drag * delta * 0.5, 0.0, 1.0))
					sp["vel"] = vel
					sp["pos"] += vel * delta
					# Check wall collision (simplified - just stop when hitting wall)
					# In practice, splatters are spawned already on the wall
				else:
					# Drip running down wall (only for splatters with is_drip = true)
					if sp.get("is_drip", false):
						var drip_phase: float = sp.get("drip_phase", 0.0) + delta * 3.0
						sp["drip_phase"] = drip_phase
						sp["pos"].y += splatter_drip_speed * delta
						# Wiggle
						sp["pos"].x += sin(drip_phase) * 2.0 * delta
			m -= 1

	# --- Footprints (fading) ---
	if not footprints.is_empty():
		var n: int = footprints.size() - 1
		while n >= 0:
			var fp: Dictionary = footprints[n]
			fp["age"] += delta
			if float(fp["age"]) >= float(fp["life"]):
				footprints.remove_at(n)
			n -= 1

	_active = not drops.is_empty() or not stains.is_empty() or not pools.is_empty() or not splatters.is_empty() or not footprints.is_empty()
	if not _active:
		set_process(false)
	queue_redraw()


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Draw order: pools (bottom) -> stains -> footprints -> splatters (on walls) -> drops (airborne, top)

	# Pools first - they're the base layer
	for p in pools:
		_draw_pool(p)

	# Stains on ground
	for s in stains:
		_draw_stain(s)

	# Footprints
	for fp in footprints:
		_draw_footprint(fp)

	# Wall splatters
	for sp in splatters:
		_draw_splatter(sp)

	# Airborne droplets (streaks)
	for d in drops:
		_draw_drop(d)


func _draw_pool(p: Dictionary) -> void:
	var life_t: float = float(p["age"]) / maxf(float(p["life"]), 0.001)
	var alpha: float = 1.0
	if life_t > stain_hold:
		alpha = clampf(1.0 - (life_t - stain_hold) / maxf(1.0 - stain_hold, 0.001), 0.0, 1.0)
	if alpha <= 0.02:
		return

	var r: float = float(p["radius"])
	var c: Color = p["colour"]
	var gait: float = p.get("gait", 0.0)  # pools might not have gait

	# Base pool - dark center
	draw_circle(p["pos"], r, Color(c.r, c.g, c.b, 0.65 * alpha))
	# Mid ring
	draw_circle(p["pos"], r * 0.68, Color(c.r * 1.2, c.g * 1.1, c.b * 1.1, 0.75 * alpha))
	# Glossy center highlight (wet look)
	draw_circle(p["pos"], r * 0.35, Color(c.r * 1.5 + 0.1, c.g * 1.3, c.b * 1.2, 0.5 * alpha))
	# Irregular edges - satellite blobs
	for k in 4:
		var a: float = gait + float(k) * 2.1 + p["age"] * 0.5
		var offset: Vector2 = Vector2.RIGHT.rotated(a) * r * (0.7 + 0.25 * float(k))
		draw_circle(p["pos"] + offset, r * (0.25 + 0.12 * float(k)),
			Color(c.r, c.g, c.b, 0.4 * alpha))


func _draw_stain(s: Dictionary) -> void:
	var life_t: float = float(s["age"]) / maxf(float(s["life"]), 0.001)
	var alpha: float = 1.0
	if life_t > stain_hold:
		alpha = clampf(1.0 - (life_t - stain_hold) / maxf(1.0 - stain_hold, 0.001), 0.0, 1.0)
	if alpha <= 0.02:
		return

	var r: float = float(s["radius"])
	if float(s.get("grow", 0.0)) > 0.0:
		r *= clampf(float(s["age"]) / float(s["grow"]), 0.12, 1.0)
	var c: Color = s["colour"]
	var gait: float = float(s["gait"])
	var dryness: float = s.get("dryness", 0.0)

	# Interpolate between wet and dry colour
	var dry_c: Color = dried_blood_colour(c)
	var display_colour: Color = c.lerp(dry_c, dryness * 0.7)

	# Main body
	draw_circle(s["pos"], r, Color(display_colour.r, display_colour.g, display_colour.b, 0.55 * alpha))
	# Darker center (thicker blood)
	draw_circle(s["pos"], r * 0.62, Color(display_colour.r * 1.2, display_colour.g * 1.1, display_colour.b * 1.1, 0.66 * alpha))
	# Wet highlight (only if not fully dry)
	if dryness < 0.8:
		draw_circle(s["pos"], r * 0.3, Color(display_colour.r * 1.8 + 0.15, display_colour.g * 1.4, display_colour.b * 1.3, 0.4 * alpha * (1.0 - dryness)))
	# Satellite blobs for irregular shape
	for k in 3:
		var a: float = gait + float(k) * 2.1
		var offset: Vector2 = Vector2.RIGHT.rotated(a) * r * (0.75 + 0.35 * float(k))
		draw_circle(s["pos"] + offset, r * (0.30 + 0.10 * float(k)),
			Color(display_colour.r, display_colour.g, display_colour.b, 0.42 * alpha))
	# Very dry stains get a cracked texture hint
	if dryness > 0.7:
		for k in 2:
			var a2: float = gait * 1.7 + float(k) * 3.1
			var r2: float = r * (0.4 + 0.2 * float(k))
			draw_arc(s["pos"], r2, a2, a2 + 0.8, 6, Color(0.08, 0.06, 0.04, alpha * 0.3 * (dryness - 0.7) / 0.3), 1.0, false)


func _draw_footprint(fp: Dictionary) -> void:
	var life_t: float = float(fp["age"]) / maxf(float(fp["life"]), 0.001)
	var alpha: float = 1.0
	if life_t > 0.7:
		alpha = clampf(1.0 - (life_t - 0.7) / 0.3, 0.0, 1.0)
	if alpha <= 0.05:
		return

	var size: float = float(fp["size"])
	var dir: Vector2 = fp["direction"]
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var c: Color = fp["colour"]
	var dryness: float = clampf(life_t * 1.2, 0.0, 1.0)
	var dry_c: Color = dried_blood_colour(c)
	var display_colour: Color = c.lerp(dry_c, dryness * 0.6)

	# Footprint shape: heel + ball + toes
	var heel: Vector2 = fp["pos"] - dir * size * 0.35
	var ball: Vector2 = fp["pos"] + dir * size * 0.25
	var toe_spread: float = size * 0.4

	# Heel
	draw_circle(heel, size * 0.55, Color(display_colour.r, display_colour.g, display_colour.b, 0.65 * alpha))
	# Ball
	draw_circle(ball, size * 0.45, Color(display_colour.r, display_colour.g, display_colour.b, 0.6 * alpha))
	# Toes (3 small circles)
	for t in 3:
		var toe_x: float = ball.x + perp.x * (toe_spread * (float(t) - 1.0) * 0.5)
		var toe_y: float = ball.y + perp.y * (toe_spread * (float(t) - 1.0) * 0.5)
		draw_circle(Vector2(toe_x, toe_y), size * 0.22, Color(display_colour.r, display_colour.g, display_colour.b, 0.55 * alpha))

	# Fade trail behind (previous footprints blend)


func _draw_splatter(sp: Dictionary) -> void:
	var life_t: float = float(sp["age"]) / maxf(float(sp["life"]), 0.001)
	var alpha: float = 1.0
	if life_t > 0.6:
		alpha = clampf(1.0 - (life_t - 0.6) / 0.4, 0.0, 1.0)
	if alpha <= 0.05:
		return

	var c: Color = sp["colour"]
	var size: float = float(sp["size"])
	var pos: Vector2 = sp["pos"]

	if sp.get("is_drip", false):
		# Drip - elongated circle
		draw_circle(pos, size, Color(c.r, c.g, c.b, 0.7 * alpha))
		# Drip tail
		var tail_len: float = size * 3.0 * (1.0 + sin(sp["drip_phase"]) * 0.3)
		draw_line(pos, pos + sp["wall_normal"] * tail_len, Color(c.r, c.g, c.b, 0.5 * alpha), size * 0.6)
	else:
		# Impact splatter - starburst
		for i in 5:
			var angle: float = float(i) * TAU / 5.0 + sp.get("rotation", 0.0)
			var len: float = size * 1.5
			draw_line(pos, pos + Vector2(cos(angle), sin(angle)) * len, Color(c.r, c.g, c.b, 0.8 * alpha), size * 0.5)
		# Central blob
		draw_circle(pos, size * 0.6, Color(c.r, c.g, c.b, 0.9 * alpha))


func _draw_drop(d: Dictionary) -> void:
	var vel: Vector2 = d["vel"]
	var age_t: float = float(d["age"]) / maxf(float(d["life"]), 0.001)
	var c: Color = d["colour"]
	var size: float = float(d["size"])

	# Draw streak using trail
	if d.has("trail") and d["trail"].size() >= 2:
		var trail: Array = d["trail"]
		for t in range(trail.size() - 1):
			var p1: Vector2 = trail[t]
			var p2: Vector2 = trail[t + 1]
			var t_alpha: float = (float(t) / float(trail.size())) * (1.0 - age_t) * 0.7
			var t_size: float = size * (0.5 + 0.5 * float(t) / float(trail.size()))
			draw_line(p1, p2, Color(c.r, c.g, c.b, t_alpha), t_size)
	else:
		# Fallback: single streak
		if vel.length() > 30.0:
			var tail: Vector2 = vel.normalized() * size * 4.0
			draw_line(d["pos"] - tail, d["pos"], Color(c.r, c.g, c.b, 0.85 * (1.0 - age_t)), size)
		else:
			draw_circle(d["pos"], size * 0.7, Color(c.r, c.g, c.b, 0.85 * (1.0 - age_t)))

	# Bright highlight on leading edge (wet catch)
	if vel.length() > 20.0 and age_t < 0.7:
		var highlight_pos: Vector2 = d["pos"] + vel.normalized() * size * 0.5
		draw_circle(highlight_pos, size * 0.35, Color(c.r * 2.0 + 0.2, c.g * 1.5, c.b * 1.3, 0.6 * (1.0 - age_t)))


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Get the blood colour at a world position (for footprints, etc.)
func get_blood_at(pos: Vector2, radius: float = 20.0) -> Color:
	var best_colour: Color = Color(0, 0, 0, 0)
	var best_alpha: float = 0.0
	for s in stains:
		if s["pos"].distance_to(pos) <= radius + s["radius"]:
			var life_t: float = float(s["age"]) / maxf(float(s["life"]), 0.001)
			var alpha: float = 1.0
			if life_t > stain_hold:
				alpha = clampf(1.0 - (life_t - stain_hold) / maxf(1.0 - stain_hold, 0.001), 0.0, 1.0)
			if alpha > best_alpha:
				best_alpha = alpha
				best_colour = s["colour"]
	for p in pools:
		if p["pos"].distance_to(pos) <= p["radius"]:
			var life_t: float = float(p["age"]) / maxf(float(p["life"]), 0.001)
			var alpha: float = 1.0
			if life_t > stain_hold:
				alpha = clampf(1.0 - (life_t - stain_hold) / maxf(1.0 - stain_hold, 0.001), 0.0, 1.0)
			if alpha > best_alpha:
				best_alpha = alpha
				best_colour = p["colour"]
	return best_colour


## Check if position is in a blood pool (for footprint triggering)
func is_in_blood(pos: Vector2) -> bool:
	for p in pools:
		if p["pos"].distance_to(pos) <= p["radius"] * 0.8:
			return true
	for s in stains:
		if s["pos"].distance_to(pos) <= s["radius"] * 0.6:
			return true
	return false


## Set walls reference for splatter collision
func set_walls(walls: Array) -> void:
	walls_ref = walls