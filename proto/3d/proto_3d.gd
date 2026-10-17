extends Node3D
##
## PROTOTYPE (camera track A) - a true-3D billboard world. Throwaway.
##
## Renders ROOM 01 from `scripts/level_data.gd` as a real Godot 3D scene so the
## League-of-Legends-style camera can be judged against the 2D-tilt prototype:
##
##   * a pitched Camera3D that follows the player (mouse wheel zooms, Q/E orbits),
##   * characters as upright billboard cut-outs (the LoL approach: 2D art in a
##     3D world) via `proto/3d/actor.gdshader`,
##   * real lighting: a warm key with long shadows, a cool fill, four corner
##     torches, and one coloured OmniLight per guard so every guard pools their
##     hue on the sand,
##   * blob shadows under every actor (billboard sprites cannot cast real ones),
##   * two spilled paint discs so paint-on-the-floor can be judged in 3D.
##
## It is NOT the real game and nothing outside `proto/3d/` is touched.
## Run it:   godot --path . res://proto/3d/proto_3d.tscn
## Capture:  godot --path . --script res://proto/3d/capture.gd

## World units per playfield pixel. 1280x720 px becomes 64x36 units, which puts
## a person at a believable ~1.7 units tall.
const S: float = 0.05
## The adventurer sheet cell (see scripts/sprite_bank.gd) and the whole sheet
## size, for the frame-region maths in the billboard shader.
const ACTOR_CELL := Vector2(96.0, 80.0)
const SHEET_SIZE := Vector2(768.0, 80.0)
## Pixels of transparent margin under the figure inside its cell (measured from
## the PNG), so the feet can be placed exactly on the node origin.
const FEET_FROM_CELL_BOTTOM: float = 23.0

const WALK_SPEED: float = 6.0
const ZOOM_MIN: float = 7.0
const ZOOM_MAX: float = 40.0
const PITCH_DEFAULT: float = -55.0

var player: CharacterBody3D = null
var camera_rig: Node3D = null
var camera: Camera3D = null

var _zoom: float = 19.0
var _pitch_deg: float = PITCH_DEFAULT
var _yaw_deg: float = 0.0
var _torch_time: float = 0.0
var _torches: Array = []


func _ready() -> void:
	randomize()
	_build_environment()
	_build_floor()
	_build_walls()
	_build_paint()
	_build_player()
	_build_guard(Vector2(760.0, 250.0), Color(1.0, 0.16, 0.16))   # "RED"
	_build_guard(Vector2(540.0, 500.0), Color(1.0, 0.88, 0.10))   # "YELLOW"
	_build_lights()
	_build_camera()


# ---------------------------------------------------------------------------
# World
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.045, 0.105)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.85)
	env.ambient_light_energy = 0.30
	# Glow: supported by the Compatibility renderer since 4.3. The threshold is
	# pushed below 1.0 so even LDR highlights get some Hades-style bloom.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# A little depth fog so the far edges of the arena fall away.
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.08, 0.16)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_floor() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = LevelData.PLAYFIELD * S
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _sand_texture()
	mat.albedo_color = Color(0.74, 0.60, 0.43)
	mat.uv1_scale = Vector3(8.0, 8.0, 1.0)
	mat.texture_repeat = true
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


## A small procedurally drawn sand-and-flagstones texture: warm grain with a
## darker grout line, so the ground reads as an arena floor rather than a plane.
func _sand_texture() -> ImageTexture:
	var size: int = 128
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in size:
		for x in size:
			var grain: float = 0.94 + rng.randf() * 0.06
			# Per-slab brightness wobble (two slabs per texture repeat).
			var slab: float = 1.0 + 0.035 * sin(float((x / 64) * 31 + (y / 64) * 17))
			var v: float = grain * slab
			if x % 64 < 2 or y % 64 < 2:
				v *= 0.72   # grout
			img.set_pixel(x, y, Color(v, v * 0.985, v * 0.95))
	return ImageTexture.create_from_image(img)


func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	var walls: Array = LevelData.walls_for(LevelData.ROOMS[0])
	for r in walls:
		var is_border: bool = r.position.x <= 0.1 or r.position.y <= 0.1 \
			or r.end.x >= LevelData.PLAYFIELD.x - 0.1 or r.end.y >= LevelData.PLAYFIELD.y - 0.1
		var is_pillar: bool = r.size.x <= 48.0 and r.size.y <= 48.0
		var height: float = 2.4
		var colour := Color(0.36, 0.25, 0.28)
		if is_pillar:
			# The colonnade reads best as tall columns.
			height = 3.4
			colour = Color(0.44, 0.31, 0.34)
		elif not is_border:
			height = 1.5
		_add_wall(body, r, height, colour)


func _add_wall(body: StaticBody3D, r: Rect2, height: float, colour: Color) -> void:
	var size := Vector3(r.size.x * S, height, r.size.y * S)
	var pos := Vector3(
		(r.position.x + r.size.x * 0.5) * S, height * 0.5,
		(r.position.y + r.size.y * 0.5) * S)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = _stone_mat(colour)
	add_child(mi)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


func _stone_mat(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.92
	return mat


## Two spilled hues on the sand, so "paint" can be judged in the 3D light.
func _build_paint() -> void:
	_add_paint(Vector2(430.0, 300.0), Color(0.85, 0.08, 0.10), 1.9)
	_add_paint(Vector2(880.0, 520.0), Color(0.10, 0.75, 0.85), 1.5)


func _add_paint(pos_px: Vector2, colour: Color, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 40
	mi.mesh = disc
	mi.position = Vector3(pos_px.x * S, 0.012, pos_px.y * S)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	mi.material_override = mat
	add_child(mi)


# ---------------------------------------------------------------------------
# Actors
# ---------------------------------------------------------------------------

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	player.position = _px_to_world(Vector2(640.0, 420.0))

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.2
	cs.shape = cap
	cs.position.y = 0.6
	player.add_child(cs)

	_add_actor_visual(player, Color(1.0, 1.0, 1.0))
	_add_blob(player)
	_add_ring(player, Color(1.0, 0.97, 0.88))

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.94, 0.82)
	lamp.light_energy = 1.5
	lamp.omni_range = 4.5
	lamp.position.y = 1.0
	player.add_child(lamp)
	add_child(player)


func _build_guard(pos_px: Vector2, hue: Color) -> void:
	var root := Node3D.new()
	root.name = "Guard"
	root.position = _px_to_world(pos_px)
	add_child(root)
	_add_actor_visual(root, hue)
	_add_blob(root)
	_add_ring(root, hue)
	# The guard lantern: this guard's hue pooled on the sand around them.
	var lamp := OmniLight3D.new()
	lamp.light_color = hue
	lamp.light_energy = 3.2
	lamp.omni_range = 6.5
	lamp.position.y = 0.9
	root.add_child(lamp)


func _add_actor_visual(parent: Node3D, hue: Color) -> void:
	var quad := QuadMesh.new()
	quad.size = ACTOR_CELL * S
	var sprite := MeshInstance3D.new()
	sprite.mesh = quad
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad is centred on its origin; lift it so the figure's feet
	# (23 px up from the cell's bottom edge) land exactly on the node origin.
	sprite.position.y = ACTOR_CELL.y * 0.5 * S - FEET_FROM_CELL_BOTTOM * S
	var mat := ShaderMaterial.new()
	mat.shader = load("res://proto/3d/actor.gdshader")
	mat.set_shader_parameter("frame_tex", load("res://assets/characters/adventurer/idle_down.png"))
	mat.set_shader_parameter("frame_region",
		Vector4(0.0, 0.0, ACTOR_CELL.x / SHEET_SIZE.x, ACTOR_CELL.y / SHEET_SIZE.y))
	mat.set_shader_parameter("tint", Vector3(hue.r, hue.g, hue.b))
	sprite.material_override = mat
	parent.add_child(sprite)


func _add_blob(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.02
	disc.radial_segments = 24
	mi.mesh = disc
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	mi.material_override = mat
	parent.add_child(mi)


## The Hades-style selection/presence ring, drawn in the actor's own hue.
func _add_ring(parent: Node3D, hue: Color) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.52
	torus.outer_radius = 0.72
	torus.rings = 40
	torus.ring_segments = 8
	mi.mesh = torus
	mi.position.y = 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(hue.r, hue.g, hue.b, 0.75)
	mi.material_override = mat
	parent.add_child(mi)


# ---------------------------------------------------------------------------
# Lights and camera
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	# Warm key: long shadows and gold on stone - the Hades look.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_color = Color(1.0, 0.82, 0.62)
	key.light_energy = 1.15
	key.shadow_enabled = false   # DIAGNOSTIC: shadows temporarily off
	key.directional_shadow_max_distance = 90.0
	key.shadow_bias = 0.05
	add_child(key)

	# Cool fill so shadowed sides read blue instead of black.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38.0, 140.0, 0.0)
	fill.light_color = Color(0.55, 0.68, 1.0)
	fill.light_energy = 0.45
	add_child(fill)

	# Four corner torches with a gentle flicker.
	var corners := [
		Vector2(60.0, 60.0), Vector2(1220.0, 60.0),
		Vector2(60.0, 660.0), Vector2(1220.0, 660.0),
	]
	for c in corners:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.62, 0.28)
		torch.light_energy = 5.0
		torch.omni_range = 13.0
		torch.position = Vector3(c.x * S, 3.0, c.y * S)
		add_child(torch)
		_torches.append(torch)


func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.position = player.position if player != null else Vector3.ZERO
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 45.0
	camera_rig.add_child(camera)
	_apply_camera()


func _px_to_world(p: Vector2) -> Vector3:
	return Vector3(p.x * S, 0.0, p.y * S)


# ---------------------------------------------------------------------------
# Per-frame
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.velocity = Vector3(input.x, 0.0, input.y) * WALK_SPEED
	player.move_and_slide()
	if camera_rig != null:
		var t: float = clampf(delta * 7.0, 0.0, 1.0)
		camera_rig.position = camera_rig.position.lerp(player.position, t)


func _process(delta: float) -> void:
	_torch_time += delta
	var flicker: float = 0.92 + 0.06 * sin(_torch_time * 9.0) + 0.03 * sin(_torch_time * 23.0 + 1.3)
	for torch in _torches:
		torch.light_energy = 5.0 * flicker


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom - 1.2)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom + 1.2)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_Q:
			_yaw_deg -= 5.0
			camera_rig.rotation_degrees.y = _yaw_deg
		elif key.keycode == KEY_E:
			_yaw_deg += 5.0
			camera_rig.rotation_degrees.y = _yaw_deg


# ---------------------------------------------------------------------------
# API used by the capture tool (proto/3d/capture.gd)
# ---------------------------------------------------------------------------

func place_player_px(p: Vector2) -> void:
	if player == null:
		return
	player.position = _px_to_world(p)
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	if camera_rig != null:
		camera_rig.position = player.position


func set_camera(yaw_deg: float, pitch_deg: float, zoom: float) -> void:
	_yaw_deg = yaw_deg
	_pitch_deg = pitch_deg
	_zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	if camera_rig != null:
		camera_rig.rotation_degrees.y = _yaw_deg
	_apply_camera()


func _set_zoom(v: float) -> void:
	_zoom = clampf(v, ZOOM_MIN, ZOOM_MAX)
	_apply_camera()


func _apply_camera() -> void:
	if camera == null:
		return
	var a: float = deg_to_rad(absf(_pitch_deg))
	camera.position = Vector3(0.0, _zoom * sin(a), _zoom * cos(a))
	camera.rotation_degrees = Vector3(_pitch_deg, 0.0, 0.0)
