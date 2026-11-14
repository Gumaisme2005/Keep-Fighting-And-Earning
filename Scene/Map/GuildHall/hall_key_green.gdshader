shader_type canvas_item;
// Yugi đứng trong Guild Hall: bỏ nền xanh (0, 100, 0) của sprite sheet, giữ nguyên màu các điểm ảnh khác.
// (COLOR đã là màu texture x modulate nên không nhân thêm lần nữa.)
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, vec3(0.0, 0.392157, 0.0)) < 0.035) {
		COLOR.a = 0.0;
	}
}
