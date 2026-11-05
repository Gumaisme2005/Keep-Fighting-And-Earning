shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, vec3(0.0, 0.392157, 0.0)) < 0.035) c.a = 0.0;
	COLOR *= c;
}
