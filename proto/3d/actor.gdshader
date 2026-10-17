shader_type spatial;
//
// ACTOR BILLBOARD - prototype-only (proto/3d/).
//
// Renders a character sprite as a Y-axis billboard: the quad always turns to
// face the camera around the world Y axis, but stays upright in world space -
// the "League of Legends" way of putting 2D art into a pitched 3D view.
//
// It also tints the artwork to a hue exactly like scripts/hue_tint.gdshader
// does for the 2D game: luminance is kept, colour is thrown away and painted
// back in `tint`, so a white knight, a red knight and a yellow knight are the
// same figure in different hues.

render_mode unshaded, cull_disabled, depth_draw_opaque;

// The full sprite sheet (an AtlasTexture does NOT slice when sampled as a 3D
// shader uniform, so the sheet + a frame region are passed instead).
uniform sampler2D frame_tex : source_color, filter_nearest;
// x,y = UV offset of the frame inside the sheet; z,w = UV size of the frame.
uniform vec4 frame_region = vec4(0.0, 0.0, 1.0, 1.0);
// The hue to paint the figure with.
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
// Same meaning as in hue_tint.gdshader (see that file for the reasoning).
uniform float strength : hint_range(0.0, 1.0) = 0.82;
uniform float floor_lift : hint_range(0.0, 0.5) = 0.16;
// Pixels below this alpha are cut away, so the quad writes depth only where
// the figure actually is.
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// Direction from this actor to the camera, flattened onto the ground.
	vec3 to_cam = normalize(vec3(
		INV_VIEW_MATRIX[3].x - MODEL_MATRIX[3].x, 0.0,
		INV_VIEW_MATRIX[3].z - MODEL_MATRIX[3].z));
	// Build an upright basis: right = up x forward, up = world up, forward = to camera.
	vec3 right_axis = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	mat4 m;
	m[0] = vec4(right_axis, 0.0);
	m[1] = vec4(0.0, 1.0, 0.0, 0.0);
	m[2] = vec4(to_cam, 0.0);
	m[3] = vec4(MODEL_MATRIX[3].xyz, 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}

void fragment() {
	vec2 uv = frame_region.xy + UV * frame_region.zw;
	vec4 tex = texture(frame_tex, uv);
	if (tex.a < alpha_cut) {
		discard;
	}
	// Luminance, then re-tint - identical maths to the 2D hue tint shader.
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = tint * (floor_lift + (1.0 - floor_lift) * lum * 1.25);
	ALBEDO = clamp(mix(tex.rgb, clamp(tinted, vec3(0.0), vec3(1.0)), strength),
		vec3(0.0), vec3(1.0));
}
