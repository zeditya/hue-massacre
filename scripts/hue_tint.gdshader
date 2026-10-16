shader_type canvas_item;
//
// HUE TINT - re-colour a character sprite to ANY hue, keeping its shading.
//
// WHY THIS EXISTS
//   Colour theory is the core of this game: every guard carries a stolen hue,
//   and the player BECOMES the hue of whatever they kill. The character art
//   ships with its own fixed colours (a red jacket, green hair...), so drawing
//   it directly would fight the whole game.
//
//   This shader throws away the artwork's colour but KEEPS its brightness, and
//   paints the brightness back in `tint`. The result is still a readable human
//   figure - you can see its arms, its walk, its shading - but it is unmistakably
//   the hue it is supposed to be.
//
// HOW IT WORKS
//   1. Read the sprite's pixel.
//   2. Turn it greyscale with a luminance dot product (the standard 0.299 /
//     0.587 / 0.114 weighting, which matches how eyes weight R, G and B).
//   3. Re-apply the `tint` colour, scaled by that brightness so shading survives.
//   4. Mix with the ORIGINAL pixel by `strength`, so a little of the original
//      artwork can show through if you want it to (0 = untouched art, 1 = pure
//      tinted silhouette).

// The hue the character should be. Set per-instance from GDScript.
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

// How hard to push towards the tint. 0.82 keeps hue dominant but preserves the
// sprite's internal detail so the figure still reads as a person.
uniform float strength : hint_range(0.0, 1.0) = 0.82;

// Keeps the darkest pixels from going fully black, so the outline stays visible.
uniform float floor_lift : hint_range(0.0, 0.5) = 0.16;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// 1-2. Luminance (greyscale) of the source pixel.
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// 3. Re-tint: brightness scaled up a little so mid-tones stay bright, with
	//    a floor so outlines do not crush to pure black.
	vec3 tinted = tint * (floor_lift + (1.0 - floor_lift) * lum * 1.25);

	vec4 out_colour = vec4(clamp(tinted, 0.0, 1.0), tex.a);

	// 4. Blend against the untouched artwork.
	COLOR = vec4(mix(tex.rgb, out_colour.rgb, strength), tex.a) * COLOR;
}
