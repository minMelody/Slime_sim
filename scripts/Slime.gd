extends TextureRect

# [b]Flag to signal updating simulation parameters[/b][br]
# Set this to [color=cyan]true[/color] when the behavior of agents or environment parameters needs to be updated.
@export var update_flag := false

# Reference to the settings for the slime simulation
@export var settings : SlimeSettings

# Variables for managing GPU rendering and compute tasks
var rd : RenderingDevice                  # Rendering device used for GPU operations
var comp_sim : ComputeHelper              # Compute helper for the simulation (agents)
var comp_env : ComputeHelper              # Compute helper for the environment

# Variables for simulation data
var vp_size : Vector2i                    # Size of the viewport (used for simulation textures)
var agent_map := PackedByteArray()        # Byte array representing the agent map texture

# Function to generate time parameters for the simulation
# `delta_time`: Time elapsed since the last frame
# Returns a byte array with the delta time and frame count
func get_time_params(delta_time):
    var time = PackedFloat32Array([delta_time]).to_byte_array()  # Convert delta time to bytes
    time.append_array(PackedInt32Array([Engine.get_frames_drawn()]).to_byte_array())  # Add frame count
    return time

# Called when the node is added to the scene
func _ready():
    # Get the size of the viewport for simulation textures
    vp_size = get_viewport_rect().size
    
    # Create a local rendering device for GPU operations
    rd = RenderingServer.create_local_rendering_device()
    
    # Initialize compute helpers for the simulation and environment
    comp_sim = ComputeHelper.new(rd, load("res://Compute/Simulation.glsl"), 1024)  # Simulation shader with thread size 1024
    comp_env = ComputeHelper.new(rd, load("res://Compute/Environment.glsl"), 32, 32)  # Environment shader with 32x32 thread size
    
    # Shared resources between simulation and environment
    comp_sim.create_buffer(rd, get_time_params(0), "time", 0)  # Create a buffer for time parameters
    comp_sim.share_uniform(comp_env, 0)  # Share the time uniform with the environment shader
    agent_map.resize(vp_size.x * vp_size.y * 4)  # Resize the agent map texture (RGBA8 format)
    comp_sim.create_texture(rd, agent_map, "agent_map", 3, comp_sim.get_format(vp_size))  # Create texture for the agent map
    comp_sim.share_uniform(comp_env, 3)  # Share the agent map uniform with the environment shader
    
    # Buffers for simulation-specific data
    comp_sim.create_buffer(rd, 16 * settings.num_agents, "agents", 1)  # Create buffer for agent data
    comp_sim.create_buffer(rd, settings.get_sim_settings(), "settings", 2)  # Create buffer for simulation settings
    comp_sim.create_buffer(rd, settings.get_sim_params(), "params", 4)  # Create buffer for simulation parameters
    
    # Buffers for environment-specific data
    comp_env.create_buffer(rd, settings.get_env_params(), "params", 1)  # Create buffer for environment parameters

# Called every frame
# `delta`: Time elapsed since the last frame
func _process(delta):
    # Update the time buffer with the current delta time and frame count
    comp_sim.set_buffer(rd, "time", get_time_params(delta))
    
    # Update buffers if the update flag is set
    if update_flag:
        comp_sim.set_buffer(rd, "params", settings.get_sim_params())  # Update simulation parameters
        comp_env.set_buffer(rd, "params", settings.get_env_params())  # Update environment parameters
        update_flag = false  # Reset the update flag
    
    # Dispatch the simulation compute shader
    comp_sim.dispatch(rd, settings.num_agents)
    rd.sync()  # Synchronize GPU tasks to ensure computation is completed
    
    # Dispatch the environment compute shader
    comp_env.dispatch(rd, vp_size.x, vp_size.y)
    rd.sync()  # Synchronize GPU tasks
    
    # Retrieve the updated agent map texture from the GPU
    agent_map = rd.texture_get_data(comp_sim.buffers.agent_map, 0)
    texture = ImageTexture.create_from_image(Image.create_from_data(vp_size.x, vp_size.y, false, Image.FORMAT_RGBA8, agent_map))  # Update the texture displayed in the UI
