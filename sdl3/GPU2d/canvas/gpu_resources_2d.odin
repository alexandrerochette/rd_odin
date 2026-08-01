package canvas


import "vendor:sdl3"
import "core:fmt"

VERTEX_BYTECODE :: #load("./.generated/basic.vertex.metallib")
FRAGMENT_BYTECODE :: #load("./.generated/basic.fragment.metallib")
FRAGMENT_SDF_BYTECODE :: #load("./.generated/sdf.fragment.metallib")

Drawing_GPU_Resources_2D :: struct {
    pipeline:^sdl3.GPUGraphicsPipeline,
    sdf_pipeline:^sdl3.GPUGraphicsPipeline,
    sampler: ^sdl3.GPUSampler,
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
}

create_graphics_pipeline :: proc(device: ^sdl3.GPUDevice, window_format: sdl3.GPUTextureFormat, use_sdf: bool) -> ^sdl3.GPUGraphicsPipeline {
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
			code_size    = len(FRAGMENT_SDF_BYTECODE),
			code         = raw_data(FRAGMENT_SDF_BYTECODE),
			entrypoint   = "FSMain", 
			stage        = .FRAGMENT,
			format       = {.METALLIB},
			num_samplers = 1, 
            num_uniform_buffers = 1,
		}
	} else {
		fs_info = sdl3.GPUShaderCreateInfo {
			code_size    = len(FRAGMENT_BYTECODE),
			code         = raw_data(FRAGMENT_BYTECODE),
			entrypoint   = "FSMain", 
			stage        = .FRAGMENT,
			format       = {.METALLIB},
			num_samplers = 1, 
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
		{slot = 1, pitch = size_of(sdl3.FPoint), input_rate = .VERTEX, instance_step_rate = 0},
	}

	vertex_attrs := []sdl3.GPUVertexAttribute {
		{location = 0, buffer_slot = 0, format = .FLOAT2, offset = 0},
		{location = 1, buffer_slot = 1, format = .FLOAT2, offset = 0},
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
			num_vertex_buffers = 2,
			vertex_buffer_descriptions = raw_data(vertex_buffers),
			num_vertex_attributes = 2,
			vertex_attributes = raw_data(vertex_attrs),
		},
		primitive_type = .TRIANGLELIST,
		target_info = {num_color_targets = 1, color_target_descriptions = raw_data(color_targets)},
	}

	return sdl3.CreateGPUGraphicsPipeline(device, graphics_pipeline_create_info)
}

create_drawing_gpu_resources :: proc (device: ^sdl3.GPUDevice, window_format: sdl3.GPUTextureFormat , use_sdf:bool) -> Drawing_GPU_Resources_2D {




    sampler_desc := sdl3.GPUSamplerCreateInfo {
		min_filter = .LINEAR,
		mag_filter = .LINEAR,
        min_lod        = 0.0,  
        max_lod        = 0.0,
        mipmap_mode = .NEAREST, 
        address_mode_u = .CLAMP_TO_EDGE,
        address_mode_v = .CLAMP_TO_EDGE,
	}
	sampler := sdl3.CreateGPUSampler(device, sampler_desc)
	

    return Drawing_GPU_Resources_2D {
        pipeline = create_graphics_pipeline(device, window_format, false),
        sdf_pipeline = create_graphics_pipeline(device, window_format, true),
        sampler = sampler
    }
}



render_draw_command :: proc(device: ^sdl3.GPUDevice, command_buffer: ^sdl3.GPUCommandBuffer, output_target: ^sdl3.GPUColorTargetInfo, drawing_resources:Drawing_GPU_Resources_2D, command: GPU_Canvas_Command) {
    sequences := command.atlas_draw_sequence
    graphics_pipeline : ^sdl3.GPUGraphicsPipeline 
    sampler := drawing_resources.sampler
    fmt.printfln("Using SDF %v", command.is_sdf)
    if command.is_sdf {
        graphics_pipeline = drawing_resources.sdf_pipeline
    } else {
        graphics_pipeline = drawing_resources.pipeline
    }

    mvp := command.transform_matrix
    seq_count := 0
	for sequence := sequences; sequence != nil; sequence = sequence.next {
   

        {
            /*sequence.num_vertices, and the first few sequence.xy values for "eeee" */
            fmt.printfln("sequence index : %d", seq_count)
            fmt.printfln("sequence.num_vertices : %d", sequence.num_vertices)
            fmt.printfln("sequence.xy[0]:%v, [1]:%v, [2]:%v",   sequence.xy[0], sequence.xy[1], sequence.xy[2], )
            fmt.printfln("sequence.next ...")
            
        }

		seq_count += 1
		//fmt.printf("sequence %d: verts=%d indices=%d atlas=%v\n", seq_count, s.num_vertices, s.num_indices, s.atlas_texture)

		fmt.printf("total sequences: %d\n", seq_count)

		xy_size := u32(sequence.num_vertices * size_of(sdl3.FPoint))
		uv_size := u32(sequence.num_vertices * size_of(sdl3.FPoint))
		idx_size := u32(sequence.num_indices * size_of(i32))



		xy_buffer := sdl3.CreateGPUBuffer(
			device,
			sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = xy_size},
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
		defer sdl3.ReleaseGPUBuffer(device, uv_buffer)
		defer sdl3.ReleaseGPUBuffer(device, idx_buffer)

		// 10. MAP AND UPLOAD CPU MESH GEOMETRY INTO THE STAGING TRANSFER BUFFER
		total_transfer_size := xy_size + uv_size + idx_size
		transfer_buffer := sdl3.CreateGPUTransferBuffer(
			device,
			sdl3.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = total_transfer_size},
		)
		defer sdl3.ReleaseGPUTransferBuffer(device, transfer_buffer)

		mapped_ptr := sdl3.MapGPUTransferBuffer(device, transfer_buffer, false)

		offset_xy := uintptr(0)
		offset_uv := uintptr(xy_size)
		offset_idx := uintptr(xy_size + uv_size)


		copy(
			([^]u8)(rawptr(uintptr(mapped_ptr) + offset_xy))[:xy_size],
			([^]u8)(sequence.xy)[:xy_size],
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
		uv_binding := sdl3.GPUBufferBinding {
			buffer = uv_buffer,
			offset = 0,
		}
		sdl3.BindGPUVertexBuffers(bake_pass, 0, &xy_binding, 1)
		sdl3.BindGPUVertexBuffers(bake_pass, 1, &uv_binding, 1)

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
        sdl3.PushGPUFragmentUniformData(command_buffer, 0, &fragment_global, size_of(fragment_global))
		// Execute geometric layout drawing pass to freeze text to pixels
		sdl3.DrawGPUIndexedPrimitives(bake_pass, u32(sequence.num_indices), 1, 0, 0, 0)
		sdl3.EndGPURenderPass(bake_pass)
	}

}
