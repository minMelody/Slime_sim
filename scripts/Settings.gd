class_name SlimeSettings extends Resource

@export_group("Simulation setup")
@export var num_agents := 100000
@export_range(1, 3) var num_species := 2
@export var spawn_radius := 100
@export_enum("Outwards", "Inwards") var spawn_direction := 1
@export_enum("Wrap", "Clamp", "Circle") var boundary_type := 2
@export_group("Agents behavior")
@export var move_speed := 10.0
@export var turn_speed := 15.0
@export var sensor_radius := 1
@export var sensor_distance := 10.0
@export var sensor_angle_radians := 1.0472
@export var trail_weight := 1.0
@export_group("Environment")
@export_range(1, 10) var diffusion_radius := 1
@export var diffusion_force := 3.0
@export var evaporation := 0.8

func get_sim_settings() -> PackedByteArray:
	return PackedInt32Array([num_agents, spawn_direction, num_species, spawn_radius, boundary_type]).to_byte_array()

func get_sim_params() -> PackedByteArray:
	var params := PackedFloat32Array([move_speed, turn_speed, sensor_distance, sensor_angle_radians, trail_weight]).to_byte_array()
	params.append_array(PackedInt32Array([sensor_radius]).to_byte_array())
	return params

func get_env_params() -> PackedByteArray:
	var params := PackedFloat32Array([diffusion_force, evaporation]).to_byte_array()
	params.append_array(PackedInt32Array([diffusion_radius]).to_byte_array())
	return params
