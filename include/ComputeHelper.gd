# Definitions of key terminologies:
# 
# - **Uniforms**: Inputs to a GPU shader, such as textures, buffers, or constant values, 
#   that are shared between the CPU and GPU. Uniforms are read-only in the shader.
# 
# - **Shader Resource**: A compiled GPU program that performs computations. In this case, 
#   it is a SPIR-V shader used for compute operations.
# 
# - **Pipeline**: A set of configurations and states that define how a shader executes on the GPU. 
#   In this script, the compute pipeline specifies how the shader will be used for computation.
# 
# - **Workgroup**: A group of threads (or work items) that execute a portion of the shader. 
#   Workgroup size determines how many threads are launched in parallel for a compute task.
# 
# - **Thread Size**: The dimensions of the thread group (workgroup) in x, y, and z axes. 
#   It defines how the workload is divided into smaller, manageable chunks.
# 
# - **Buffers**: Memory blocks that are shared between the CPU and GPU. They store data such as arrays 
#   or textures, which are used by the GPU during computation.
# 
# - **RenderingDevice**: The abstraction in Godot's RenderingDevice API for interacting with the GPU. 
#   It allows you to create and manage resources like shaders, pipelines, textures, and buffers.
# 
# - **SPIR-V**: A binary format for representing shaders. It is used by modern graphics and compute APIs like Vulkan.
# 
# - **Texture**: A 2D or 3D array of data (e.g., image pixels) that can be used as input for computations 
#   or rendered to the screen.

# Create a class to assist with GPU compute tasks in a simulation
class_name ComputeHelper

# Member variables
var thread_size : Vector3  # Defines the number of threads per workgroup in (x, y, z)
var pipeline                 # Stores the compute pipeline (shader execution path)
var uniform_set = []         # Stores uniforms (shader inputs like buffers or textures)
var shader                   # Reference to the shader resource
var buffers := {}            # Dictionary to store buffers shared between CPU and GPU

var start_frame := -1        # Tracks the starting frame of computation (unused here)
var is_busy := false         # Flag to indicate if the helper is busy

# Initialize the shader, pipeline, and thread size
# `device`: RenderingDevice for GPU operations
# `shader_file`: Reference to the SPIR-V shader file
# `thread_size_x/y/z`: Defines the thread group dimensions (defaults to x=1, y=1, z=1)
func _init(device : RenderingDevice, shader_file : RDShaderFile, thread_size_x : int, thread_size_y : int = 1, thread_size_z : int = 1):
    self.shader = device.shader_create_from_spirv(shader_file.get_spirv())  # Load shader from SPIR-V
    self.pipeline = device.compute_pipeline_create(self.shader)            # Create a compute pipeline
    self.thread_size = Vector3(thread_size_x, thread_size_y, thread_size_z)  # Set the thread group size

# Free all allocated resources to prevent memory leaks
# `rd`: RenderingDevice instance
func release(rd : RenderingDevice):
    # Free the compute pipeline
    rd.free_rid(self.pipeline)
    self.pipeline = null
    
    # Free the uniform set if it exists
    if typeof(self.uniform_set) == TYPE_RID:
        rd.free_rid(self.uniform_set)
    self.uniform_set = []
    
    # Free the shader resource
    rd.free_rid(shader)
    self.shader = null
    
    # Free all GPU buffers and clear the dictionary
    for key in self.buffers.keys():
        rd.free_rid(self.buffers[key])
    self.buffers.clear()
    
    # Reset the thread size
    self.thread_size = Vector3()

# Share a uniform with another ComputeHelper instance
# `with`: Another ComputeHelper instance
# `binding`: The uniform's binding point to be shared
func share_uniform(with : ComputeHelper, binding : int):
    # Find the uniform with the specified binding and share it
    var uniform = self.uniform_set.filter(func(elem): return elem.binding == binding)[0]
    with.uniform_set.append(uniform)

# Create a texture and register it in the uniform set
# `rd`: RenderingDevice
# `texture`: Data for the texture as a byte array
# `nameID`: Identifier for the texture in the buffers dictionary
# `binding`: Binding point for the texture in the shader
# `format`: Texture format
func create_texture(rd : RenderingDevice, texture : PackedByteArray, nameID : String, binding : int, format : RDTextureFormat):
    # Create the texture and store it in the buffers dictionary
    self.buffers[nameID] = rd.texture_create(format, RDTextureView.new(), [texture])
    
    # Create a uniform for the texture
    var uniform = RDUniform.new()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    uniform.binding = binding
    uniform.add_id(self.buffers[nameID])
    self.uniform_set.append(uniform)

# Create a GPU buffer and register it in the uniform set
# `rd`: RenderingDevice
# `data_or_bytesize`: Initial data (byte array) or buffer size (integer)
# `nameID`: Identifier for the buffer in the buffers dictionary
# `binding`: Binding point for the buffer in the shader
func create_buffer(rd : RenderingDevice, data_or_bytesize, nameID : String, binding : int):
    # Create the buffer based on whether data or size is provided
    if typeof(data_or_bytesize) == TYPE_INT:
        self.buffers[nameID] = rd.storage_buffer_create(data_or_bytesize)
    else:
        if typeof(data_or_bytesize) != TYPE_PACKED_BYTE_ARRAY:
            data_or_bytesize = data_or_bytesize.to_byte_array()
        self.buffers[nameID] = rd.storage_buffer_create(data_or_bytesize.size(), data_or_bytesize)
    
    # Create a uniform for the buffer
    var uniform = RDUniform.new()
    uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    uniform.binding = binding
    uniform.add_id(self.buffers[nameID])
    self.uniform_set.append(uniform)

# Update the contents of a texture
# `rd`: RenderingDevice
# `nameID`: Identifier for the texture
# `data`: New data to update the texture
# `layer`: The texture layer to update (default is 0)
func set_texture(rd : RenderingDevice, nameID : String, data : PackedByteArray, layer : int = 0):
    rd.texture_update(self.buffers[nameID], layer, data)

# Update the contents of a buffer
# `rd`: RenderingDevice
# `nameID`: Identifier for the buffer
# `data`: New data to update the buffer
func set_buffer(rd : RenderingDevice, nameID : String, data : PackedByteArray):
    rd.buffer_update(self.buffers[nameID], 0, data.size(), data)

# Dispatch a compute operation on the GPU
# `rd`: RenderingDevice
# `workgroup_size_x/y/z`: Workgroup dimensions
# `setID`: Uniform set ID (default is 0)
func dispatch(rd : RenderingDevice, workgroup_size_x : int, workgroup_size_y : int = 1, workgroup_size_z : int = 1, setID : int = 0):
    # Create the uniform set if it doesn't exist
    if typeof(self.uniform_set) != TYPE_RID:
        self.uniform_set = rd.uniform_set_create(self.uniform_set, self.shader, setID)
    
    # Begin a compute command list
    var compute_list := rd.compute_list_begin()
    rd.compute_list_bind_compute_pipeline(compute_list, self.pipeline)      # Bind the compute pipeline
    rd.compute_list_bind_uniform_set(compute_list, self.uniform_set, setID) # Bind the uniform set
    rd.compute_list_dispatch(compute_list, ceil(workgroup_size_x / self.thread_size.x), ceil(workgroup_size_y / self.thread_size.y), ceil(workgroup_size_z / self.thread_size.z))  # Dispatch the compute operation
    rd.compute_list_end()
    rd.submit()  # Submit the compute command list

# Helper function to define texture formats
# `size`: Dimensions of the texture (width, height)
# `_format`: Data format (default is R8G8B8A8_UNORM)
func get_format(size : Vector2i, _format := RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM) -> RDTextureFormat:
    var format = RDTextureFormat.new()
    format.width = size.x
    format.height = size.y
    format.format = _format
    format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
    return format
