// TEMPLATE FILE #############################
// Antialiasing is practically required in VR. This shader will fill in the floor
// with a texture where lines are ALWAYS one pixel, no matter where they are.
// This type of thing fights the jittery mess a traditional texture becomes at distance.
//############################################

shader_type spatial;

uniform vec3 floor_color : source_color = vec3(0.10, 0.11, 0.13);
uniform vec3 line_color : source_color = vec3(0.30, 0.48, 0.68);
uniform float cell_size = 0.5;

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 cell = world.xz / cell_size;

	vec2 edge = abs(fract(cell - 0.5) - 0.5) / fwidth(cell);
	float line = 1.0 - min(min(edge.x, edge.y), 1.0);

	ALBEDO = mix(floor_color, line_color, line);
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
