#[compute]
#version 460

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

layout(binding = 0) restrict buffer Time {
	float delta;
	int frames;
}
time;
layout(binding = 1, std430) restrict buffer Params {
	float diffuse_rate;
	float evaporate_rate;
	int diffuse_size;
}
params;
layout(binding = 3, rgba8) uniform image2D agentMap;

vec4 blur(ivec2 id, ivec2 size) {
	vec4 sum = vec4(0.0);
	for (int i = -params.diffuse_size; i <= params.diffuse_size; i++) {
		for (int j = -params.diffuse_size; j <= params.diffuse_size; j++) {
			int x = clamp(id.x + i, 0, size.x - 1);
			int y = clamp(id.y + j, 0, size.y - 1);
			sum += imageLoad(agentMap, ivec2(x, y));
		}
	}
	return sum / pow(params.diffuse_size * 2 + 1, 2);
}

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;
void main() {
	ivec2 size = ivec2(imageSize(agentMap));
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	vec2 uv = id / size;
	if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1) return;
	
	vec4 trail = imageLoad(agentMap, id);

	// diffuse trail
	vec3 diffused_trail = mix(trail, blur(id, size), params.diffuse_rate * time.delta).xyz;

	// evaporate trail
	vec3 evaporated_trail = max(vec3(0.0), diffused_trail - params.evaporate_rate * time.delta);

	imageStore(agentMap, id, vec4(evaporated_trail, 1.0));
}