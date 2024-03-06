#[compute]
#version 460

#define BOUNDARY_WRAP 0
#define BOUNDARY_CLAMP 1
#define BOUNDARY_CIRCLE 2

float rand(vec2 co){
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

layout(set = 0, binding = 0) restrict buffer Time {
	float delta;
	int frames;
}
time;
layout(binding = 1, std430) restrict buffer Agents {
	vec4 data[];
}
agents;

layout(binding = 2, std430) restrict buffer SimulationSetup
{
	int num_agents;
	int spawn_direction;
	int num_species;
	int spawn_radius;
	int boundary_type;
} setup;

layout(binding = 3, rgba8) uniform image2D agentMap;
layout(binding = 4, std430) restrict buffer ProcessParams {
	float move_speed;
	float turn_speed;
	float sensor_distance;
	float sensor_angle;
	float trail_weight;
	int sensor_size;
}
params;

void simulationSetup(uint id, vec2 size) {
	vec2 vp_center = size * 0.5;
	// spawn agents randomly in a circle at the center of the screen
	float rand_angle = rand(vec2(id - 583.87, id + 1.48441)) * 6.2831 + 0.041854 * id;
	// calculate position
	vec2 rand_pos = vec2(cos(rand_angle), sin(rand_angle));
	float dist = (sqrt(rand(rand_pos * rand_angle)) - rand(rand_pos * id) * 0.02333) * setup.spawn_radius;
	agents.data[id].xy = vp_center + dist * rand_pos;
	// calculate facing
	float dir = setup.spawn_direction == 0 ? 0 : 3.1415 * sign(dot(agents.data[id].xy - vp_center, vec2(1, 0)));
	agents.data[id].z = rand_angle + dir;
	// populate species
	agents.data[id].w = id % setup.num_species;
}

void readPixel(int x, int y, vec3 species_mask, inout float sum)
{
	vec3 trail = imageLoad(agentMap, ivec2(x, y)).xyz;
	// avoid other species, go towards agents of same species
	vec3 bias = trail * (species_mask * 2.0 - 1.0);
	sum += bias.x + bias.y + bias.z;
}

float sense(vec4 agent, vec3 species_mask, float angle_offset, ivec2 canvas_size) {
	float theta = agent.z + angle_offset;
	vec2 dir = vec2(cos(theta), sin(theta));
	ivec2 sensor_pos = ivec2(agent.xy + dir * params.sensor_distance);
	
	float sum = 0;
	for (int i = -params.sensor_size; i <= params.sensor_size; i++) {
		for (int j = -params.sensor_size; j <= params.sensor_size; j++) {
			int x = sensor_pos.x + i;
			int y = sensor_pos.y + j;
			
			if (x >= 0 && x < canvas_size.x && y >= 0 && y < canvas_size.y)
			{
				readPixel(x, y, species_mask, sum);
			}
			else if (setup.boundary_type == BOUNDARY_WRAP)
			{
				if (x < 0 || x >= canvas_size.x) x = abs(canvas_size.x - abs(x));
				if (y < 0 || y >= canvas_size.y) y = abs(canvas_size.y - abs(y));
				readPixel(x, y, species_mask, sum);
			}
		}
	}
	return sum;
}

void steerTowardsTrail(vec4 agent, vec3 species_mask, uint id, ivec2 canvas_size, inout float newangle) {
	float weight_forward = sense(agent, species_mask, 0.0, canvas_size);
	float weight_left = sense(agent, species_mask, params.sensor_angle, canvas_size);
	float weight_right = sense(agent, species_mask, -params.sensor_angle, canvas_size);
	float random_steer = rand(agent.xy + id + time.frames * time.delta);
	if (weight_forward > weight_left && weight_forward > weight_right) {
		newangle = agent.z;
	}
	else if (weight_forward < weight_left && weight_forward < weight_right) {
		newangle += (random_steer - 0.5) * 2 * params.turn_speed * time.delta;
	}
	else if (weight_right > weight_left) {
		newangle -= random_steer * params.turn_speed * time.delta;
	}
	else if (weight_left > weight_right) {
		newangle += random_steer * params.turn_speed * time.delta;
	}
}

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;
void main() {
	vec2 size = imageSize(agentMap);
	uint id = gl_GlobalInvocationID.x;
	
	if (time.frames < 1) {
		simulationSetup(id, size);
		return;
	}
	
	vec3 species_mask = vec3(agents.data[id].w == 0, agents.data[id].w == 1, agents.data[id].w == 2);

	// steer towards nearby trail
	steerTowardsTrail(agents.data[id], species_mask, id, ivec2(size), agents.data[id].z);

	// calculate new position
	vec2 dir = vec2(cos(agents.data[id].z), sin(agents.data[id].z));
	vec2 newpos = agents.data[id].xy + dir * params.move_speed * time.delta;
	
	if (setup.boundary_type == BOUNDARY_WRAP)
	{
		if (newpos.x < 0 || newpos.x >= size.x) newpos.x = abs(size.x - abs(newpos.x));
		if (newpos.y < 0 || newpos.y >= size.y) newpos.y = abs(size.y - abs(newpos.y));
	}
	else if (setup.boundary_type == BOUNDARY_CIRCLE)
	{
		float r = min(size.x, size.y) * 0.45;
		vec2 center = size * 0.5;
		if (length(newpos - center) >= r)
		{
			newpos = normalize(newpos - center) * (r - 0.01) + center;
			agents.data[id].z = rand(newpos + id + time.frames * time.delta) * 6.2831;
		}
	}
	else if (newpos.x < 0 || newpos.x >= size.x || newpos.y < 0 || newpos.y >= size.y)
	{
		newpos.x = clamp(newpos.x, 0, size.x - 0.01);
		newpos.y = clamp(newpos.y, 0, size.y - 0.01);
		agents.data[id].z = rand(newpos + id + time.frames * time.delta) * 6.2831;
	}

	vec3 trail = imageLoad(agentMap, ivec2(newpos)).xyz;
	vec3 newtrail = (species_mask * 2.0 - 1.0) * params.trail_weight * time.delta;
	trail = clamp(trail + newtrail, vec3(0.0), vec3(1.0));

	imageStore(agentMap, ivec2(newpos), vec4(trail, 1.0));
	agents.data[id].xy = newpos;
}