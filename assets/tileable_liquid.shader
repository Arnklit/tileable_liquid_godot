shader_type spatial;

// Uniforms set by script
uniform vec3 i_bb_start;
uniform vec3 i_bb_size;
uniform sampler2D i_curve_texture : hint_normal;
uniform int i_mesh_repeat = 1;

// Uniforms
uniform float speed : hint_range(0.0, 20.0) = 1.0;
uniform float thickness : hint_range(0.0, 10.0) = 1.0;
uniform sampler2D thickness_curve : hint_white;

// Varyings
varying float scaled_uv_y;

void vertex() {
	scaled_uv_y = UV.y / float(i_mesh_repeat + 1) + COLOR.r + (fract(TIME * speed) / float(i_mesh_repeat + 1));
	vec3 curve_pos = texture(i_curve_texture, vec2(scaled_uv_y, 0.16666)).rgb;
	vec3 curve_nor = (texture(i_curve_texture, vec2(scaled_uv_y, 0.5)).rgb * 2.0 - 1.0);
	vec3 curve_up = texture(i_curve_texture, vec2(scaled_uv_y, 0.83333)).rgb * 2.0 - 1.0;
	float thick_curve = texture(thickness_curve, vec2(scaled_uv_y, 0.5)).r;
	vec3 curve_side = cross(curve_nor, curve_up);
	mat4 curve_matrix = mat4(vec4(curve_side, 0.0), vec4(curve_nor, 0.0), vec4(curve_up, 0.0), vec4(curve_pos * i_bb_size, 0.0));
	VERTEX *= thickness * thick_curve;
	VERTEX.y = 0.0;
	VERTEX = (curve_matrix * vec4(VERTEX, 1.0)).xyz;
	VERTEX += i_bb_start;
	NORMAL = (curve_matrix * vec4(NORMAL, 0.0)).xyz;
	TANGENT = (curve_matrix * vec4(TANGENT, 0.0)).xyz;
}

void fragment() {
	float cutoff = 1.0 / float(i_mesh_repeat + 1);
	if (scaled_uv_y < cutoff || scaled_uv_y > 1.0 - cutoff) {
		discard;
	}
}