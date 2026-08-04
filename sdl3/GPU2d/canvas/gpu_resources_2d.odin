package canvas


import "core:fmt"
import "vendor:sdl3"

//VERTEX_BYTECODE :: #load("./.generated/basic.vertex.metallib")
//FRAGMENT_BYTECODE :: #load("./.generated/basic.fragment.metallib")
//FRAGMENT_SDF_BYTECODE :: #load("./.generated/sdf.fragment.metallib")


VERTEX_BYTECODE :: #load("./.generated/coloring.vertex.metallib")
FRAGMENT_BYTECODE :: #load("./.generated/coloring.fragment.metallib")
FRAGMENT_SDF_BYTECODE :: #load("./.generated/sdf.coloring.fragment.metallib")

Drawing_GPU_Resources_2D :: struct {
	pipeline:     ^sdl3.GPUGraphicsPipeline,
	sdf_pipeline: ^sdl3.GPUGraphicsPipeline,
	sampler:      ^sdl3.GPUSampler,
	nil_texture:  ^sdl3.GPUTexture,
}

create_nil_texture :: proc(
	device: ^sdl3.GPUDevice,
	target_format: sdl3.GPUTextureFormat,
) -> ^sdl3.GPUTexture {

	create_info := sdl3.GPUTextureCreateInfo {
		type                 = .D2,
		format               = target_format,
		usage                = {.SAMPLER, .COLOR_TARGET},
		width                = 2,
		height               = 2,
		layer_count_or_depth = 1,
		num_levels           = 1,
	}
	white := Color{255, 255, 255, 255}
	texture_content := []Color{white, white, white, white}

	texture := sdl3.CreateGPUTexture(device, create_info)
    size := len(texture_content) * size_of(Color)
    texture_content_bytes :=([^]u8)(raw_data(texture_content))[:size]

	upload_single_texture_content(device, texture_content_bytes,2, 2, texture)
	return texture

}
upload_single_texture_content :: proc(
	device: ^sdl3.GPUDevice,
	content: []u8,
    w, h : u32,
	target_texture: ^sdl3.GPUTexture,
) {
    transfer_size := u32(len(content))
	upload_command_buffer := sdl3.AcquireGPUCommandBuffer(device)

	//transfer_size := u32(len(content) * size_of(sdl3.FColor))
	transfer_buffer := sdl3.CreateGPUTransferBuffer(
		device,
		sdl3.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = transfer_size},
	)
	defer sdl3.ReleaseGPUTransferBuffer(device, transfer_buffer)

	mapped_ptr := sdl3.MapGPUTransferBuffer(device, transfer_buffer, false)


	copy(
		([^]u8)(rawptr(uintptr(mapped_ptr)))[:transfer_size],
		content,
	)


	sdl3.UnmapGPUTransferBuffer(device, transfer_buffer)


	copy_pass := sdl3.BeginGPUCopyPass(upload_command_buffer)
	sdl3.UploadToGPUTexture(
		copy_pass,
		sdl3.GPUTextureTransferInfo{transfer_buffer = transfer_buffer},
		sdl3.GPUTextureRegion{texture = target_texture, w = w, h = h},
		false,
	)

	sdl3.EndGPUCopyPass(copy_pass)
	result := sdl3.SubmitGPUCommandBuffer(upload_command_buffer)
}


destroy_drawing_gpu_resources :: proc(device: ^sdl3.GPUDevice, res: ^Drawing_GPU_Resources_2D) {
	if res == nil {
		return
	}

	if res.sampler != nil {
		sdl3.ReleaseGPUSampler(device, res.sampler)
		res.sampler = nil
	}

	if res.sdf_pipeline != nil {
		sdl3.ReleaseGPUGraphicsPipeline(device, res.sdf_pipeline)
		res.sdf_pipeline = nil
	}
	if res.pipeline != nil {
		sdl3.ReleaseGPUGraphicsPipeline(device, res.pipeline)
		res.pipeline = nil
	}

	if res.nil_texture != nil {
		sdl3.ReleaseGPUTexture(device, res.nil_texture)
		res.nil_texture = nil
	}
}

create_graphics_pipeline :: proc(
	device: ^sdl3.GPUDevice,
	window_format: sdl3.GPUTextureFormat,
	use_sdf: bool,
) -> ^sdl3.GPUGraphicsPipeline {
	vs_info := sdl3.GPUShaderCreateInfo {
		code_size           = len(VERTEX_BYTECODE),
		code                = raw_data(VERTEX_BYTECODE),
		entrypoint          = "VSMain", // Must match your Slang function text!
		stage               = .VERTEX,
		format              = {.METALLIB}, // Or .MSL / .DXIL matching the format
		num_samplers        = 0,
		num_uniform_buffers = 1,
	}
	compiled_vertex_shader := sdl3.CreateGPUShader(device, vs_info)
	defer sdl3.ReleaseGPUShader(device, compiled_vertex_shader)


	if compiled_vertex_shader == nil {
		fmt.eprintf("Failed to load a vertex shader.\n")
	}

	fs_info: sdl3.GPUShaderCreateInfo
	if use_sdf {
		fmt.println("Using SDF fragment shader")
		fs_info = sdl3.GPUShaderCreateInfo {
			code_size           = len(FRAGMENT_SDF_BYTECODE),
			code                = raw_data(FRAGMENT_SDF_BYTECODE),
			entrypoint          = "FSMain",
			stage               = .FRAGMENT,
			format              = {.METALLIB},
			num_samplers        = 1,
			num_uniform_buffers = 1,
		}
	} else {
		fs_info = sdl3.GPUShaderCreateInfo {
			code_size           = len(FRAGMENT_BYTECODE),
			code                = raw_data(FRAGMENT_BYTECODE),
			entrypoint          = "FSMain",
			stage               = .FRAGMENT,
			format              = {.METALLIB},
			num_samplers        = 1,
			num_uniform_buffers = 1,
		}
	}


	compiled_fragment_shader := sdl3.CreateGPUShader(device, fs_info)
	defer sdl3.ReleaseGPUShader(device, compiled_fragment_shader)


	color_target_desc := [1]sdl3.GPUColorTargetDescription {
		{
			format = .R8G8B8A8_UNORM,
			blend_state = {
				enable_blend = true,
				src_color_blendfactor = .SRC_ALPHA,
				dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
				color_blend_op = .ADD,
				src_alpha_blendfactor = .ONE,
				dst_alpha_blendfactor = .ZERO,
				alpha_blend_op = .ADD,
			},
		},
	}

	vertex_buffers := []sdl3.GPUVertexBufferDescription {
		{slot = 0, pitch = size_of(sdl3.FPoint), input_rate = .VERTEX, instance_step_rate = 0},
		{slot = 1, pitch = size_of(sdl3.FColor), input_rate = .VERTEX, instance_step_rate = 0},
		{slot = 2, pitch = size_of(sdl3.FPoint), input_rate = .VERTEX, instance_step_rate = 0},
	}

	vertex_attrs := []sdl3.GPUVertexAttribute {
		{location = 0, buffer_slot = 0, format = .FLOAT2, offset = 0},
		{location = 1, buffer_slot = 1, format = .FLOAT4, offset = 0},
		{location = 2, buffer_slot = 2, format = .FLOAT2, offset = 0},
	}


	color_targets := []sdl3.GPUColorTargetDescription {
		{
			format = window_format,
			blend_state = {
				enable_blend = true,
				src_color_blendfactor = .SRC_ALPHA,
				dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
				color_blend_op = .ADD,
				src_alpha_blendfactor = .ONE,
				dst_alpha_blendfactor = .ZERO,
				alpha_blend_op = .ADD,
			},
		},
	}

	graphics_pipeline_create_info := sdl3.GPUGraphicsPipelineCreateInfo {
		vertex_shader = compiled_vertex_shader,
		fragment_shader = compiled_fragment_shader,
		vertex_input_state = {
			num_vertex_buffers = 3,
			vertex_buffer_descriptions = raw_data(vertex_buffers),
			num_vertex_attributes = 3,
			vertex_attributes = raw_data(vertex_attrs),
		},
		primitive_type = .TRIANGLELIST,
		target_info = {num_color_targets = 1, color_target_descriptions = raw_data(color_targets)},
	}

	p := sdl3.CreateGPUGraphicsPipeline(device, graphics_pipeline_create_info)

	fmt.assertf(p != nil, "Failed to Create Graphics Pipeline %s", sdl3.GetError())
	return p
}

create_drawing_gpu_resources :: proc(
	device: ^sdl3.GPUDevice,
	window_format: sdl3.GPUTextureFormat,
	use_sdf: bool,
) -> Drawing_GPU_Resources_2D {


	sampler_desc := sdl3.GPUSamplerCreateInfo {
		min_filter     = .NEAREST,
		mag_filter     = .LINEAR,
		min_lod        = 0.0,
		max_lod        = 0.0,
		mipmap_mode    = .NEAREST,
		address_mode_u = .CLAMP_TO_EDGE,
		address_mode_v = .CLAMP_TO_EDGE,
	}
	sampler := sdl3.CreateGPUSampler(device, sampler_desc)


	return Drawing_GPU_Resources_2D {
		pipeline = create_graphics_pipeline(device, window_format, false),
		sdf_pipeline = create_graphics_pipeline(device, window_format, true),
		sampler = sampler,
	}
}

render_draw_command :: proc(
	device: ^sdl3.GPUDevice,
	command_buffer: ^sdl3.GPUCommandBuffer,
	output_target: ^sdl3.GPUColorTargetInfo,
	drawing_resources: Drawing_GPU_Resources_2D,
	command: GPU_Canvas_Command,
) {
	if command.text != nil {
		render_draw_text_command(device, command_buffer, output_target, drawing_resources, command)
	}

	if command.vertices != nil && len(command.vertices) != 0 {
		render_draw_vertices_command(
			device,
			command_buffer,
			output_target,
			drawing_resources,
			command,
		)
	}

}

render_draw_vertices_command :: proc(
	device: ^sdl3.GPUDevice,
	command_buffer: ^sdl3.GPUCommandBuffer,
	output_target: ^sdl3.GPUColorTargetInfo,
	drawing_resources: Drawing_GPU_Resources_2D,
	command: GPU_Canvas_Command,
) {

	graphics_pipeline: ^sdl3.GPUGraphicsPipeline
	sampler := drawing_resources.sampler
	fmt.printfln("Using SDF %v", command.is_sdf)
	if command.is_sdf {
		graphics_pipeline = drawing_resources.sdf_pipeline
	} else {
		graphics_pipeline = drawing_resources.pipeline
	}
	colors := command.colors

	mvp := command.transform_matrix
	fmt.printfln("MVP = %v", mvp)
	seq_count := 0
	color_begin: i32 = 0
	fmt.printfln("Total Color Count %d", len(colors))

	num_vertices := len(command.vertices)
	num_indices := len(command.indices)
	num_colors := len(command.colors)

	xy_size := u32(num_vertices * size_of(sdl3.FPoint))
	color_size := u32(num_vertices * size_of(sdl3.FColor))
	uv_size := u32(num_vertices * size_of(sdl3.FPoint))
	idx_size := u32(num_indices * size_of(i32))


	xy_buffer := sdl3.CreateGPUBuffer(
		device,
		sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = xy_size},
	)

	color_buffer := sdl3.CreateGPUBuffer(
		device,
		sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = color_size},
	)

	uv_buffer := sdl3.CreateGPUBuffer(
		device,
		sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = uv_size},
	)
	idx_buffer := sdl3.CreateGPUBuffer(
		device,
		sdl3.GPUBufferCreateInfo{usage = {.INDEX}, size = idx_size},
	)

	defer sdl3.ReleaseGPUBuffer(device, xy_buffer)
	defer sdl3.ReleaseGPUBuffer(device, color_buffer)
	defer sdl3.ReleaseGPUBuffer(device, uv_buffer)
	defer sdl3.ReleaseGPUBuffer(device, idx_buffer)

	// 10. MAP AND UPLOAD CPU MESH GEOMETRY INTO THE STAGING TRANSFER BUFFER
	total_transfer_size := xy_size + color_size + uv_size + idx_size
	transfer_buffer := sdl3.CreateGPUTransferBuffer(
		device,
		sdl3.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = total_transfer_size},
	)
	defer sdl3.ReleaseGPUTransferBuffer(device, transfer_buffer)

	mapped_ptr := sdl3.MapGPUTransferBuffer(device, transfer_buffer, false)

	offset_xy := uintptr(0)
	offset_color := uintptr(xy_size)
	offset_uv := uintptr(xy_size + color_size)
	offset_idx := uintptr(xy_size + color_size + uv_size)

	fmt.printfln("uploading vertices: %v", command.vertices[:])
	copy(
		([^]u8)(rawptr(uintptr(mapped_ptr) + offset_xy))[:xy_size],
		([^]u8)(raw_data(command.vertices))[:xy_size],
	)

	fmt.printfln("uploading colors: %v", command.colors[:])
	copy(
		([^]u8)(rawptr(uintptr(mapped_ptr) + offset_color))[:color_size],
		([^]u8)(raw_data(command.colors))[:color_size],
	)

	fmt.printfln("uploading uvs: %v", command.uv[:])
	copy(
		([^]u8)(rawptr(uintptr(mapped_ptr) + offset_uv))[:uv_size],
		([^]u8)(raw_data(command.uv))[:uv_size],
	)

	fmt.printfln("uploading indices: %v", command.indices[:])
	copy(
		([^]u8)(rawptr(uintptr(mapped_ptr) + offset_idx))[:idx_size],
		([^]u8)(raw_data(command.indices))[:idx_size],
	)


	sdl3.UnmapGPUTransferBuffer(device, transfer_buffer)

	// 11. SUBMIT STAGING DATA UPLOADS AND BAKE TEXTURE (RUNS EXACTLY ONCE AT BOOT)

	copy_pass := sdl3.BeginGPUCopyPass(command_buffer)

	sdl3.UploadToGPUBuffer(
		copy_pass,
		sdl3.GPUTransferBufferLocation{transfer_buffer = transfer_buffer, offset = u32(offset_xy)},
		sdl3.GPUBufferRegion{buffer = xy_buffer, offset = 0, size = xy_size},
		false,
	)

	sdl3.UploadToGPUBuffer(
		copy_pass,
		sdl3.GPUTransferBufferLocation {
			transfer_buffer = transfer_buffer,
			offset = u32(offset_color),
		},
		sdl3.GPUBufferRegion{buffer = color_buffer, offset = 0, size = color_size},
		false,
	)

	sdl3.UploadToGPUBuffer(
		copy_pass,
		sdl3.GPUTransferBufferLocation{transfer_buffer = transfer_buffer, offset = u32(offset_uv)},
		sdl3.GPUBufferRegion{buffer = uv_buffer, offset = 0, size = uv_size},
		false,
	)
	sdl3.UploadToGPUBuffer(
		copy_pass,
		sdl3.GPUTransferBufferLocation {
			transfer_buffer = transfer_buffer,
			offset = u32(offset_idx),
		},
		sdl3.GPUBufferRegion{buffer = idx_buffer, offset = 0, size = idx_size},
		false,
	)
	sdl3.EndGPUCopyPass(copy_pass)

	bake_pass := sdl3.BeginGPURenderPass(command_buffer, output_target, 1, nil)

	sdl3.BindGPUGraphicsPipeline(bake_pass, graphics_pipeline)
	sdl3.PushGPUVertexUniformData(command_buffer, 0, &mvp, size_of(mvp))

	xy_binding := sdl3.GPUBufferBinding {
		buffer = xy_buffer,
		offset = 0,
	}
	color_binding := sdl3.GPUBufferBinding {
		buffer = color_buffer,
		offset = 0,
	}

	uv_binding := sdl3.GPUBufferBinding {
		buffer = uv_buffer,
		offset = 0,
	}
	sdl3.BindGPUVertexBuffers(bake_pass, 0, &xy_binding, 1)
	sdl3.BindGPUVertexBuffers(bake_pass, 1, &color_binding, 1)
	sdl3.BindGPUVertexBuffers(bake_pass, 2, &uv_binding, 1)

	idx_binding := sdl3.GPUBufferBinding {
		buffer = idx_buffer,
		offset = 0,
	}
	sdl3.BindGPUIndexBuffer(bake_pass, idx_binding, ._32BIT) // Linked to explicit FFI Enum

	source_texture := command.texture
	if source_texture == nil {
		source_texture = drawing_resources.nil_texture
	}

	sampler_binding := sdl3.GPUTextureSamplerBinding {
		texture = source_texture,
		sampler = sampler,
	}
	sdl3.BindGPUFragmentSamplers(bake_pass, 0, &sampler_binding, 1)
	fragment_global := command.fragments_global
	sdl3.PushGPUFragmentUniformData(command_buffer, 0, &fragment_global, size_of(fragment_global))
	// Execute geometric layout drawing pass to freeze text to pixels
	sdl3.DrawGPUIndexedPrimitives(bake_pass, u32(num_indices), 1, 0, 0, 0)
	sdl3.EndGPURenderPass(bake_pass)
}

render_draw_text_command :: proc(
	device: ^sdl3.GPUDevice,
	command_buffer: ^sdl3.GPUCommandBuffer,
	output_target: ^sdl3.GPUColorTargetInfo,
	drawing_resources: Drawing_GPU_Resources_2D,
	command: GPU_Canvas_Command,
) {
	sequences := command.atlas_draw_sequence

	graphics_pipeline: ^sdl3.GPUGraphicsPipeline
	sampler := drawing_resources.sampler
	fmt.printfln("Using SDF %v", command.is_sdf)
	if command.is_sdf {
		graphics_pipeline = drawing_resources.sdf_pipeline
	} else {
		graphics_pipeline = drawing_resources.pipeline
	}
	colors := command.colors

	mvp := command.transform_matrix
	seq_count := 0
	color_begin: i32 = 0
	fmt.printfln("Total Color Count %d", len(colors))
	for sequence := sequences; sequence != nil; sequence = sequence.next {


		{
			/*sequence.num_vertices, and the first few sequence.xy values for "eeee" */
			fmt.printfln("sequence index : %d", seq_count)
			fmt.printfln("sequence.num_vertices : %d", sequence.num_vertices)
			fmt.printfln(
				"sequence.xy[0]:%v, [1]:%v, [2]:%v",
				sequence.xy[0],
				sequence.xy[1],
				sequence.xy[2],
			)
			fmt.printfln("sequence.next ...")

		}

		seq_count += 1
		//fmt.printf("sequence %d: verts=%d indices=%d atlas=%v\n", seq_count, s.num_vertices, s.num_indices, s.atlas_texture)

		fmt.printf("total sequences: %d\n", seq_count)

		color_count := sequence.num_vertices
		fmt.printfln("Sequence [%d] Color Count %d", seq_count - 1, color_count)
		xy_size := u32(sequence.num_vertices * size_of(sdl3.FPoint))
		color_size := u32(sequence.num_vertices * size_of(sdl3.FColor))
		uv_size := u32(sequence.num_vertices * size_of(sdl3.FPoint))
		idx_size := u32(sequence.num_indices * size_of(i32))


		xy_buffer := sdl3.CreateGPUBuffer(
			device,
			sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = xy_size},
		)

		color_buffer := sdl3.CreateGPUBuffer(
			device,
			sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = color_size},
		)

		uv_buffer := sdl3.CreateGPUBuffer(
			device,
			sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = uv_size},
		)
		idx_buffer := sdl3.CreateGPUBuffer(
			device,
			sdl3.GPUBufferCreateInfo{usage = {.INDEX}, size = idx_size},
		)

		defer sdl3.ReleaseGPUBuffer(device, xy_buffer)
		defer sdl3.ReleaseGPUBuffer(device, color_buffer)
		defer sdl3.ReleaseGPUBuffer(device, uv_buffer)
		defer sdl3.ReleaseGPUBuffer(device, idx_buffer)

		// 10. MAP AND UPLOAD CPU MESH GEOMETRY INTO THE STAGING TRANSFER BUFFER
		total_transfer_size := xy_size + color_size + uv_size + idx_size
		transfer_buffer := sdl3.CreateGPUTransferBuffer(
			device,
			sdl3.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = total_transfer_size},
		)
		defer sdl3.ReleaseGPUTransferBuffer(device, transfer_buffer)

		mapped_ptr := sdl3.MapGPUTransferBuffer(device, transfer_buffer, false)

		offset_xy := uintptr(0)
		offset_color := uintptr(xy_size)
		offset_uv := uintptr(xy_size + color_size)
		offset_idx := uintptr(xy_size + color_size + uv_size)

		debug_buf := make([]u8, total_transfer_size)
		defer delete(debug_buf)

		copy(
			([^]u8)(rawptr(uintptr(mapped_ptr) + offset_xy))[:xy_size],
			([^]u8)(sequence.xy)[:xy_size],
		)

		copy(
			([^]u8)(rawptr(uintptr(mapped_ptr) + offset_color))[:color_size],
			([^]u8)(rawptr(raw_data(colors[color_begin:color_begin + color_count])))[:color_size],
		)


		copy(
			([^]u8)(rawptr(uintptr(mapped_ptr) + offset_uv))[:uv_size],
			([^]u8)(sequence.uv)[:uv_size],
		)
		copy(
			([^]u8)(rawptr(uintptr(mapped_ptr) + offset_idx))[:idx_size],
			([^]u8)(sequence.indices)[:idx_size],
		)


		sdl3.UnmapGPUTransferBuffer(device, transfer_buffer)

		// 11. SUBMIT STAGING DATA UPLOADS AND BAKE TEXTURE (RUNS EXACTLY ONCE AT BOOT)

		copy_pass := sdl3.BeginGPUCopyPass(command_buffer)

		sdl3.UploadToGPUBuffer(
			copy_pass,
			sdl3.GPUTransferBufferLocation {
				transfer_buffer = transfer_buffer,
				offset = u32(offset_xy),
			},
			sdl3.GPUBufferRegion{buffer = xy_buffer, offset = 0, size = xy_size},
			false,
		)

		sdl3.UploadToGPUBuffer(
			copy_pass,
			sdl3.GPUTransferBufferLocation {
				transfer_buffer = transfer_buffer,
				offset = u32(offset_color),
			},
			sdl3.GPUBufferRegion{buffer = color_buffer, offset = 0, size = color_size},
			false,
		)

		sdl3.UploadToGPUBuffer(
			copy_pass,
			sdl3.GPUTransferBufferLocation {
				transfer_buffer = transfer_buffer,
				offset = u32(offset_uv),
			},
			sdl3.GPUBufferRegion{buffer = uv_buffer, offset = 0, size = uv_size},
			false,
		)
		sdl3.UploadToGPUBuffer(
			copy_pass,
			sdl3.GPUTransferBufferLocation {
				transfer_buffer = transfer_buffer,
				offset = u32(offset_idx),
			},
			sdl3.GPUBufferRegion{buffer = idx_buffer, offset = 0, size = idx_size},
			false,
		)
		sdl3.EndGPUCopyPass(copy_pass)

		bake_pass := sdl3.BeginGPURenderPass(command_buffer, output_target, 1, nil)

		sdl3.BindGPUGraphicsPipeline(bake_pass, graphics_pipeline)
		sdl3.PushGPUVertexUniformData(command_buffer, 0, &mvp, size_of(mvp))

		xy_binding := sdl3.GPUBufferBinding {
			buffer = xy_buffer,
			offset = 0,
		}
		color_binding := sdl3.GPUBufferBinding {
			buffer = color_buffer,
			offset = 0,
		}

		uv_binding := sdl3.GPUBufferBinding {
			buffer = uv_buffer,
			offset = 0,
		}
		sdl3.BindGPUVertexBuffers(bake_pass, 0, &xy_binding, 1)
		sdl3.BindGPUVertexBuffers(bake_pass, 1, &color_binding, 1)
		sdl3.BindGPUVertexBuffers(bake_pass, 2, &uv_binding, 1)

		idx_binding := sdl3.GPUBufferBinding {
			buffer = idx_buffer,
			offset = 0,
		}
		sdl3.BindGPUIndexBuffer(bake_pass, idx_binding, ._32BIT) // Linked to explicit FFI Enum

		sampler_binding := sdl3.GPUTextureSamplerBinding {
			texture = sequence.atlas_texture,
			sampler = sampler,
		}
		sdl3.BindGPUFragmentSamplers(bake_pass, 0, &sampler_binding, 1)
		fragment_global := command.fragments_global
		sdl3.PushGPUFragmentUniformData(
			command_buffer,
			0,
			&fragment_global,
			size_of(fragment_global),
		)
		// Execute geometric layout drawing pass to freeze text to pixels
		sdl3.DrawGPUIndexedPrimitives(bake_pass, u32(sequence.num_indices), 1, 0, 0, 0)
		sdl3.EndGPURenderPass(bake_pass)
		color_begin += sequence.num_vertices
	}

}
