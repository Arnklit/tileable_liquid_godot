shader_type spatial;

// Uniforms set by script
uniform vec3 i_bb_start;
uniform vec3 i_bb_size;
uniform sampler2D i_curve_texture : hint_normal;
uniform int i_mesh_repeat = 1;

// Vertex uniforms
uniform float speed : hint_range(0.0, 20.0) = 1.0;
uniform float thickness : hint_range(0.0, 10.0) = 1.0;
uniform sampler2D thickness_curve : hint_white;
uniform float max_rotation = 6.0;
uniform sampler2D rotation_over_curve;

// Shading uniforms
uniform sampler2D gradient;
uniform sampler2D emission_intensity_rim;
uniform vec4 transmission_color : hint_color;
uniform bool use_fake_ss = true;
uniform float fake_ss_sharpness = 2.0;

// Varyings
varying float scaled_uv_y;

mat4 rot_y(float angle){
	float cos_a = cos(angle);
	float sin_a = sin(angle);
	return mat4(
		vec4(cos_a, 0.0, sin_a, 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(-sin_a, 0.0, cos_a, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void vertex() {
	scaled_uv_y = UV.y / float(i_mesh_repeat + 1) + COLOR.r + (fract(TIME * speed) / float(i_mesh_repeat + 1));
	vec3 curve_pos = texture(i_curve_texture, vec2(scaled_uv_y, 0.16666)).rgb;
	vec3 curve_nor = (texture(i_curve_texture, vec2(scaled_uv_y, 0.5)).rgb * 2.0 - 1.0);
	vec3 curve_up = texture(i_curve_texture, vec2(scaled_uv_y, 0.83333)).rgb * 2.0 - 1.0;
	float thick_curve = texture(thickness_curve, vec2(scaled_uv_y, 0.5)).r;
	vec3 curve_side = cross(curve_nor, curve_up);
	mat4 curve_matrix = mat4(vec4(curve_side, 0.0), vec4(curve_nor, 0.0), vec4(curve_up, 0.0), vec4(curve_pos * i_bb_size, 0.0));
	mat4 rot = rot_y(max_rotation
			* texture(rotation_over_curve, vec2(scaled_uv_y)).r
		);
	VERTEX = (rot * vec4(VERTEX, 1.0)).rgb;
	NORMAL = (rot * vec4(NORMAL, 0.0)).rgb;
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
	
	ROUGHNESS = 0.0;
	float fresnel = abs(dot(normalize(NORMAL), normalize(VERTEX)));
	vec4 color = texture(gradient, vec2(fresnel));
	ALBEDO = color.rgb;
	if (use_fake_ss){
		EMISSION = ALBEDO * pow(1.0 - fresnel, fake_ss_sharpness);
	}
	TRANSMISSION = transmission_color.rgb;
	SSS_STRENGTH = 1.0;
	
}