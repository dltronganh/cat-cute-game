// Cartoon "iris out" for the fail scene: the screen goes black
// except inside two circles, one on the cat and one on Lộc.
// Positions and radii are in the overlay's own pixel space (canvas units).
shader_type canvas_item;

uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 center_a = vec2(640.0, 360.0);
uniform float radius_a = 2000.0;
uniform vec2 center_b = vec2(0.0, 0.0);
uniform float radius_b = 0.0;

void fragment() {
	vec2 p = UV * rect_size;
	float inside_a = 1.0 - step(radius_a, distance(p, center_a));
	float inside_b = 1.0 - step(radius_b, distance(p, center_b));
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - max(inside_a, inside_b));
}
