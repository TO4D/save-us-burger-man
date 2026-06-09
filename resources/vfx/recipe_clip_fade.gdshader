shader_type canvas_item;

uniform vec4 fade_color : source_color = vec4(1.0, 0.9, 0.72, 1.0);

void fragment() {
	float alpha = 1.0 - UV.y;
	COLOR = vec4(fade_color.rgb, fade_color.a * alpha);
}
