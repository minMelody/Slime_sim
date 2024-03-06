class_name ComputeHelper

var thread_size : Vector3
var pipeline
var uniform_set = []
var shader
var buffers := {}

var start_frame := -1
var is_busy := false

func _init(device : RenderingDevice, shader_file : RDShaderFile, thread_size_x : int, thread_size_y : int = 1, thread_size_z : int = 1):
	self.shader = device.shader_create_from_spirv(shader_file.get_spirv())
	self.pipeline = device.compute_pipeline_create(self.shader)
	self.thread_size = Vector3(thread_size_x, thread_size_y, thread_size_z)

func release(rd : RenderingDevice):
	rd.free_rid(self.pipeline)
	self.pipeline = null
	
	if typeof(self.uniform_set) == TYPE_RID:
		rd.free_rid(self.uniform_set)
	self.uniform_set = []
	
	rd.free_rid(shader)
	self.shader = null
	
	for key in self.buffers.keys():
		rd.free_rid(self.buffers[key])
	self.buffers.clear()
	
	self.thread_size = Vector3()

func share_uniform(with : ComputeHelper, binding : int):
	var uniform = self.uniform_set.filter(func(elem): return elem.binding == binding)[0]
	with.uniform_set.append(uniform)

func create_texture(rd : RenderingDevice, texture : PackedByteArray, nameID : String, binding : int, format : RDTextureFormat):
	self.buffers[nameID] = rd.texture_create(format, RDTextureView.new(), [texture])
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(self.buffers[nameID])
	self.uniform_set.append(uniform)

func create_buffer(rd : RenderingDevice, data_or_bytesize, nameID : String, binding : int):
	if typeof(data_or_bytesize) == TYPE_INT:
		self.buffers[nameID] = rd.storage_buffer_create(data_or_bytesize)
	else:
		if typeof(data_or_bytesize) != TYPE_PACKED_BYTE_ARRAY:
			data_or_bytesize = data_or_bytesize.to_byte_array()
		self.buffers[nameID] = rd.storage_buffer_create(data_or_bytesize.size(), data_or_bytesize)
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(self.buffers[nameID])
	self.uniform_set.append(uniform)

func set_texture(rd : RenderingDevice, nameID : String, data : PackedByteArray, layer : int = 0):
	rd.texture_update(self.buffers[nameID], layer, data)

func set_buffer(rd : RenderingDevice, nameID : String, data : PackedByteArray):
	rd.buffer_update(self.buffers[nameID], 0, data.size(), data)

func dispatch(rd : RenderingDevice, workgroup_size_x : int, workgroup_size_y : int = 1, workgroup_size_z : int = 1, setID : int = 0):
	if typeof(self.uniform_set) != TYPE_RID:
		self.uniform_set = rd.uniform_set_create(self.uniform_set, self.shader, setID)
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, self.pipeline)
	rd.compute_list_bind_uniform_set(compute_list, self.uniform_set, setID)
	rd.compute_list_dispatch(compute_list, ceil(workgroup_size_x / self.thread_size.x), ceil(workgroup_size_y / self.thread_size.y), ceil(workgroup_size_z / self.thread_size.z))
	rd.compute_list_end()
	rd.submit()

func get_format(size : Vector2i, _format := RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM) -> RDTextureFormat:
	var format = RDTextureFormat.new()
	format.width = size.x
	format.height = size.y
	format.format = _format
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	return format
