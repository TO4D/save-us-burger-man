shader_type canvas_item;
render_mode blend_mix;

uniform vec4 halo_color : source_color = vec4(1.0, 0.88, 0.25, 0.9);
uniform float outline_size = 3.0;
uniform float glow_size = 7.0;
uniform float glow_strength = 0.38;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 right = vec2(1.0, 0.0);
	vec2 left = vec2(-1.0, 0.0);
	vec2 down = vec2(0.0, 1.0);
	vec2 up = vec2(0.0, -1.0);
	vec2 down_right = normalize(vec2(1.0, 1.0));
	vec2 down_left = normalize(vec2(-1.0, 1.0));
	vec2 up_right = normalize(vec2(1.0, -1.0));
	vec2 up_left = normalize(vec2(-1.0, -1.0));
	vec2 outline_pixel = TEXTURE_PIXEL_SIZE * outline_size;
	vec2 inner_outline_pixel = TEXTURE_PIXEL_SIZE * outline_size * 0.5;
	vec2 glow_pixel = TEXTURE_PIXEL_SIZE * glow_size;

	float outline_alpha = 0.0;
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + right * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + left * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + down * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + up * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + down_right * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + down_left * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + up_right * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + up_left * outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + right * inner_outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + left * inner_outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + down * inner_outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + up * inner_outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + down_right * inner_outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + down_left * inner_outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + up_right * inner_outline_pixel).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + up_left * inner_outline_pixel).a);

	float glow_alpha = 0.0;
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + right * glow_pixel).a);
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + left * glow_pixel).a);
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + down * glow_pixel).a);
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + up * glow_pixel).a);
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + down_right * glow_pixel).a);
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + down_left * glow_pixel).a);
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + up_right * glow_pixel).a);
	glow_alpha = max(glow_alpha, texture(TEXTURE, UV + up_left * glow_pixel).a);

	float outside = 1.0 - step(0.02, base.a);
	glow_alpha *= glow_strength;
	float halo_alpha = max(outline_alpha * halo_color.a, glow_alpha * halo_color.a) * outside;
	COLOR = vec4(halo_color.rgb, halo_alpha);
}
