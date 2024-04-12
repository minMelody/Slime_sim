extends TextureRect
## [b]Flag the simulation to update params buffers.[/b][br]
## Set this [color=cyan]true[/color] to update [i]Agents behavior[/i] or [i]Environment[/i] parameters.
@export var update_flag := false
@export var settings : SlimeSettings

var rd : RenderingDevice
var comp_sim : ComputeHelper
var comp_env : ComputeHelper

var vp_size : Vector2i
var agent_map := PackedByteArray()

func get_time_params(delta_time):
	var time = PackedFloat32Array([delta_time]).to_byte_array()
	time.append_array(PackedInt32Array([Engine.get_frames_drawn()]).to_byte_array())
	return time;

func _ready():
	vp_size = get_viewport_rect().size
	
	rd = RenderingServer.create_local_rendering_device()
	comp_sim = ComputeHelper.new(rd, load("res://Compute/Simulation.glsl"), 1024)
	comp_env = ComputeHelper.new(rd, load("res://Compute/Environment.glsl"), 32, 32)
	
	# Shared resources
	comp_sim.create_buffer(rd, get_time_params(0), "time", 0)
	comp_sim.share_uniform(comp_env, 0)
	agent_map.resize(vp_size.x * vp_size.y * 4)
	comp_sim.create_texture(rd, agent_map, "agent_map", 3, comp_sim.get_format(vp_size))
	comp_sim.share_uniform(comp_env, 3)
	# comp_sim buffers
	comp_sim.create_buffer(rd, 16 * settings.num_agents, "agents", 1)
	comp_sim.create_buffer(rd, settings.get_sim_settings(), "settings", 2)
	comp_sim.create_buffer(rd, settings.get_sim_params(), "params", 4)
	# comp_env buffers
	comp_env.create_buffer(rd, settings.get_env_params(), "params", 1)

func _process(delta):
	comp_sim.set_buffer(rd, "time", get_time_params(delta))
	if update_flag:
		comp_sim.set_buffer(rd, "params", settings.get_sim_params())
		comp_env.set_buffer(rd, "params", settings.get_env_params())
		update_flag = false
	
	comp_sim.dispatch(rd, settings.num_agents)
	rd.sync()
	
	comp_env.dispatch(rd, vp_size.x, vp_size.y)
	rd.sync()
	
	agent_map = rd.texture_get_data(comp_sim.buffers.agent_map, 0)
	texture = ImageTexture.create_from_image(Image.create_from_data(vp_size.x, vp_size.y, false, Image.FORMAT_RGBA8, agent_map))
