shader_type canvas_item;

// DARKNESS - the halls at dusk, lit by the Unsworn's torch and by the lanterns
// the sworn carry.
//
// This is a full-screen overlay drawn on its own CanvasLayer ABOVE the world but
// BELOW the HUD, so the interface stays fully legible while the world goes dim.
// It is additive night, not a hard blackout: three lights lift it.
//
//   1. The player's torch - a POOL of light around the Unsworn, not a beam.
//      (It was a directional cone in the stealth build; the sworn now see you
//      the moment they notice you and never give up, so a sight cone was only
//      ever punishing the player. 180 degrees = a full circle.)
//   2. A soft AMBIENT pool around the player, so the ground near you is always
//      readable.
//   3. A lantern pool around every sworn soldier, tinted with the colour that
//      soldier carries. The sworn glow in the dark, so the threat is legible
//      before it is on top of you - and the whole screen reads as "colour is
//      light".
//
// The light does not cast wall shadows (that needs LightOccluders), but it falls
// off with both distance and angle, which is enough.

// Size of the canvas in pixels (the base viewport, e.g. 1280x720).
uniform vec2 screen_size = vec2(1280.0, 720.0);
// Where the player is, in the same pixel space as screen_size.
uniform vec2 player_pos = vec2(640.0, 360.0);
// Direction the torch is held, in radians. Only matters while the arc is
// narrower than 180.
uniform float facing = 0.0;
// Full width of the torch arc, in degrees. 180 = the full circle (a pool).
uniform float light_arc_deg : hint_range(0.0, 180.0) = 180.0;
// How far the torch reaches, in pixels.
uniform float light_range : hint_range(0.0, 2048.0) = 720.0;
// A small always-lit circle around the player so they never lose themselves.
uniform float near_radius : hint_range(0.0, 512.0) = 95.0;
// A dim pool around the player that is visible in EVERY direction. Keeps the
// immediate area readable so the dark is atmospheric, not disorienting.
uniform float ambient_range : hint_range(0.0, 1024.0) = 150.0;
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.30;
// How far a guard's own lantern reaches.
uniform float lantern_range : hint_range(0.0, 512.0) = 150.0;
// 0 = daylight, 1 = pitch black outside the light.
uniform float darkness_amount : hint_range(0.0, 1.0) = 0.74;
// A very dark cool blue, matching the drained world rather than pure black.
uniform vec4 dark_colour : source_color = vec4(0.02, 0.02, 0.04, 1.0);

// Guard lanterns. Up to 8 nearest guards, padded by the caller so the array
// length is always exactly 8 (the GPU needs a fixed size).
uniform int light_count = 0;
uniform vec2 light_pos[8];
uniform vec4 light_col[8];

void fragment() {
	vec2 px = SCREEN_UV * screen_size;
	vec2 d = px - player_pos;
	float dist = length(d);

	// --- 1. the player's cone -------------------------------------------
	float lit = 0.0;
	if (dist < near_radius) {
		lit = 1.0 - dist / near_radius;
	}

	float half_cone = radians(light_arc_deg);
	// Shortest angular distance between the pixel direction and the cone.
	float diff = abs(mod(atan(d.y, d.x) - facing + PI, TAU) - PI);
	if (diff < half_cone && dist < light_range) {
		float ang_fall = 1.0 - diff / half_cone;
		float dist_fall = 1.0 - dist / light_range;
		// Square the angular term for a softer, more torch-like falloff.
		lit = max(lit, ang_fall * ang_fall * dist_fall);
	}

	// --- 2. ambient pool so the near ground is always readable ----------
	float ambient = (1.0 - clamp(dist / max(ambient_range, 1.0), 0.0, 1.0)) * ambient_strength;
	float openness = max(lit, ambient);

	// --- 3. guard lanterns ----------------------------------------------
	// Each lantern lifts the dark AND bleeds a little of the guard's hue in, so
	// a blue guard reads as a blue pool of light at the edge of your vision.
	vec3 tint = dark_colour.rgb;
	for (int i = 0; i < 8; i++) {
		if (i >= light_count) {
			break;
		}
		vec2 gd = px - light_pos[i];
		float gdist = length(gd);
		if (gdist < lantern_range) {
			float fall = 1.0 - gdist / lantern_range;
			fall *= fall;
			openness = max(openness, fall * 0.85);
			tint = mix(tint, light_col[i].rgb, fall * 0.35);
		}
	}

	openness = clamp(openness, 0.0, 1.0);
	COLOR = vec4(tint, darkness_amount * (1.0 - openness));
}
