package main

import "core:fmt"
import "core:math"
import "vendor:sdl3"
import "vendor:sdl3/ttf"


// 1. Bake your TrueType font directly into the executable data segment.
// This path must be relative to this main.odin file location on your disk.
FONT_BYTES :: #load("assets/Doto_Rounded-Medium.ttf")

VERTEX_BYTECODE :: #load("./.generated/basic.vertex.metallib")
FRAGMENT_BYTECODE :: #load("./.generated/basic.fragment.metallib")
FRAGMENT_SDF_BYTECODE :: #load("./.generated/sdf.fragment.metallib")

USE_SDF :: true

scale: f32 = 1

main :: proc() {
	// 2. INITIALIZE MULTIMEDIA CORE SUBSYSTEMS
	if !sdl3.Init({.VIDEO}) {
		fmt.eprintf("Failed to initialize core SDL3: %s\n", sdl3.GetError())
		return
	}
	defer sdl3.Quit()

	if !ttf.Init() {
		fmt.eprintf("Failed to initialize SDL3_ttf subsystem: %s\n", sdl3.GetError())
		return
	}
	defer ttf.Quit()

	// 3. CREATE OS WINDOW DESKTOP WRAPPER
	window := sdl3.CreateWindow("GPU Blit Text", 800, 600, {})
	if window == nil {
		fmt.eprintf("Failed to create window: %s\n", sdl3.GetError())
		return
	}
	defer sdl3.DestroyWindow(window)

	// 4. INITIALIZE MODERM GPU HARDWARE GRAPHICS LAYERS
	// We declare the supported cross-platform shader formats (Metal, Vulkan, DX12)
	gpu_device := sdl3.CreateGPUDevice({.MSL, .METALLIB, .SPIRV, .DXIL}, true, nil)
	if gpu_device == nil {
		fmt.eprintf("Failed to initialize low-level GPU drivers!\n")
		return
	}
	defer sdl3.DestroyGPUDevice(gpu_device)

	if !sdl3.ClaimWindowForGPUDevice(gpu_device, window) {
		fmt.eprintf("Failed to claim window swapchain: %s\n", sdl3.GetError())
		return
	}
	defer sdl3.ReleaseWindowFromGPUDevice(gpu_device, window)

	// 5. ATTACH THE TEXT LAYOUT GLYPH PACKING ENGINE
	engine := ttf.CreateGPUTextEngine(gpu_device)
	if engine == nil {
		fmt.eprintf("Failed to create GPU Text Engine: %s\n", sdl3.GetError())
		return
	}
	defer ttf.DestroyGPUTextEngine(engine)

	// 6. STREAM AND PARSE STATIC FONT BYTES OUT OF EXECUTABLE READ-ONLY MEMORY
	stream := sdl3.IOFromConstMem(raw_data(FONT_BYTES), len(FONT_BYTES))
	if stream == nil {
		fmt.eprintf("Failed to create IO stream from memory: %s\n", sdl3.GetError())
		return
	}

	font := ttf.OpenFontIO(stream, true, 64)
	if font == nil {
		fmt.eprintf("Failed to parse embedded font bytes: %s\n", sdl3.GetError())
		return
	}
	defer ttf.CloseFont(font)

	if USE_SDF {
		fmt.println("Using SDF font")
		if !ttf.SetFontSDF(font, true) {
			fmt.eprintf("Failed to enable SDF rendering: %s\n", sdl3.GetError())
			return
		}
	}

	// 7. ARRANGE STRING GEOMETRY (Automatically processes HarfBuzz/FreeType)
	text := ttf.CreateText(engine, font, "Hello GPU Font Atlas!", 0)
	if text == nil {
		fmt.eprintf("Failed to process layout string data: %s\n", sdl3.GetError())
		return
	}
	defer ttf.DestroyText(text)

	sequences := ttf.GetGPUTextDrawData(text)
	if sequences == nil {
		fmt.eprintf("Font sequence failed to generate vertices.\n")
		return
	}


	window_width_signed, window_height_signed: i32
	sdl3.GetWindowSizeInPixels(window, &window_width_signed, &window_height_signed)
	window_width, window_height := u32(window_width_signed), u32(window_height_signed)

	first := true
	min_x, max_x, min_y, max_y: f32
	for seq := sequences; seq != nil; seq = seq.next {
		for i in 0 ..< int(seq.num_vertices) {
			p := seq.xy[i]
			if first {
				min_x, max_x, min_y, max_y = p.x, p.x, p.y, p.y
				first = false
			} else {
				min_x = min(min_x, p.x); max_x = max(max_x, p.x)
				min_y = min(min_y, p.y); max_y = max(max_y, p.y)
			}
		}
	}

	padding: f32 = 4.0
	text_w := (max_x - min_x) + padding * 2
	text_h := (max_y - min_y) + padding * 2

	text_canvas_w := u32(math.ceil(text_w))
	text_canvas_h := u32(math.ceil(text_h))

	// 8. ALLOCATE THE COMPACT STATIC OFFSCREEN INTERMEDIATE TEXTURE BOX
	window_format := sdl3.GetGPUSwapchainTextureFormat(gpu_device, window)

	text_texture_desc := sdl3.GPUTextureCreateInfo {
		type                 = .D2,
		format               = window_format,
		width                = window_width,
		height               = window_height,
		layer_count_or_depth = 1,
		num_levels           = 1,
		usage                = {.COLOR_TARGET, .SAMPLER},
	}
	static_text_texture := sdl3.CreateGPUTexture(gpu_device, text_texture_desc)
	if static_text_texture == nil {
		fmt.eprintf("Failed to allocate static VRAM canvas texture.\n")
		return
	}
	defer sdl3.ReleaseGPUTexture(gpu_device, static_text_texture)

	// 9. PROVISION COMPACT STRUCTURAL VRAM BUFFERS


	sampler_desc := sdl3.GPUSamplerCreateInfo {
		min_filter = .LINEAR,
		mag_filter = .LINEAR,
	}
	font_sampler := sdl3.CreateGPUSampler(gpu_device, sampler_desc)
	defer sdl3.ReleaseGPUSampler(gpu_device, font_sampler)


	// Render shapes into static_text_texture
	bake_target := sdl3.GPUColorTargetInfo {
		texture     = static_text_texture,
		clear_color = sdl3.FColor{1, 0.5, 0.12, 0.0},
		load_op     = .LOAD,
		store_op    = .STORE,
	}



	vs_info := sdl3.GPUShaderCreateInfo {
		code_size           = len(VERTEX_BYTECODE),
		code                = raw_data(VERTEX_BYTECODE),
		entrypoint          = "VSMain", // Must match your Slang function text!
		stage               = .VERTEX,
		format              = {.METALLIB}, // Or .MSL / .DXIL matching the format
		num_samplers        = 0,
		num_uniform_buffers = 1,
	}
	compiled_vertex_shader := sdl3.CreateGPUShader(gpu_device, vs_info)
	defer sdl3.ReleaseGPUShader(gpu_device, compiled_vertex_shader)
	if compiled_vertex_shader == nil {
		fmt.eprintf("Failed to load a vertex shader.\n")
	}

	fs_info: sdl3.GPUShaderCreateInfo
	if USE_SDF {
		fmt.println("Using SDF fragment shader")
		fs_info = sdl3.GPUShaderCreateInfo {
			code_size    = len(FRAGMENT_SDF_BYTECODE),
			code         = raw_data(FRAGMENT_SDF_BYTECODE),
			entrypoint   = "FSMain", // Must match your Slang function text!
			stage        = .FRAGMENT,
			format       = {.METALLIB},
			num_samplers = 1, // 🌟 Matches our single font atlas binding!
		}
	} else {
		fs_info = sdl3.GPUShaderCreateInfo {
			code_size    = len(FRAGMENT_BYTECODE),
			code         = raw_data(FRAGMENT_BYTECODE),
			entrypoint   = "FSMain", // Must match your Slang function text!
			stage        = .FRAGMENT,
			format       = {.METALLIB},
			num_samplers = 1, // 🌟 Matches our single font atlas binding!
		}
	}
	compiled_fragment_shader := sdl3.CreateGPUShader(gpu_device, fs_info)
	defer sdl3.ReleaseGPUShader(gpu_device, compiled_fragment_shader)
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

	graphics_pipeline := sdl3.CreateGPUGraphicsPipeline(gpu_device, graphics_pipeline_create_info)

	if graphics_pipeline == nil {
		fmt.eprintf("Failed to create a graphics pipeline.\n")
	}

	init_cmd_buf := sdl3.AcquireGPUCommandBuffer(gpu_device)

	clear_target := sdl3.GPUColorTargetInfo {
		texture     = static_text_texture,
		clear_color = sdl3.FColor{1, 0.5, 0.12, 0.0},
		load_op     = .CLEAR,
		store_op    = .STORE,
	}

    clear_pass := sdl3.BeginGPURenderPass(init_cmd_buf, &clear_target, 1, nil)
    sdl3.EndGPURenderPass(clear_pass)

	seq_count := 0
	for sequence := sequences; sequence != nil; sequence = sequence.next {
		seq_count += 1
		//fmt.printf("sequence %d: verts=%d indices=%d atlas=%v\n", seq_count, s.num_vertices, s.num_indices, s.atlas_texture)

		fmt.printf("total sequences: %d\n", seq_count)

		xy_size := u32(sequence.num_vertices * size_of(sdl3.FPoint))
		uv_size := u32(sequence.num_vertices * size_of(sdl3.FPoint))
		idx_size := u32(sequence.num_indices * size_of(i32))

		xy_buffer := sdl3.CreateGPUBuffer(
			gpu_device,
			sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = xy_size},
		)
		uv_buffer := sdl3.CreateGPUBuffer(
			gpu_device,
			sdl3.GPUBufferCreateInfo{usage = {.VERTEX}, size = uv_size},
		)
		idx_buffer := sdl3.CreateGPUBuffer(
			gpu_device,
			sdl3.GPUBufferCreateInfo{usage = {.INDEX}, size = idx_size},
		)

		defer sdl3.ReleaseGPUBuffer(gpu_device, xy_buffer)
		defer sdl3.ReleaseGPUBuffer(gpu_device, uv_buffer)
		defer sdl3.ReleaseGPUBuffer(gpu_device, idx_buffer)

		// 10. MAP AND UPLOAD CPU MESH GEOMETRY INTO THE STAGING TRANSFER BUFFER
		total_transfer_size := xy_size + uv_size + idx_size
		transfer_buffer := sdl3.CreateGPUTransferBuffer(
			gpu_device,
			sdl3.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = total_transfer_size},
		)
		defer sdl3.ReleaseGPUTransferBuffer(gpu_device, transfer_buffer)

		mapped_ptr := sdl3.MapGPUTransferBuffer(gpu_device, transfer_buffer, false)

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


		sdl3.UnmapGPUTransferBuffer(gpu_device, transfer_buffer)

		// 11. SUBMIT STAGING DATA UPLOADS AND BAKE TEXTURE (RUNS EXACTLY ONCE AT BOOT)

		copy_pass := sdl3.BeginGPUCopyPass(init_cmd_buf)

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


		mvp := build_text_transform(
			min_x,
			min_y,
			max_x,
			max_y,
			f32(window_width),
			f32(window_height),
			scale,
		)

		if compiled_fragment_shader == nil {
			fmt.eprintf("Failed to load a fragment shader.\n")
		}


		bake_pass := sdl3.BeginGPURenderPass(init_cmd_buf, &bake_target, 1, nil)

		sdl3.BindGPUGraphicsPipeline(bake_pass, graphics_pipeline)
		sdl3.PushGPUVertexUniformData(init_cmd_buf, 0, &mvp, size_of(mvp))

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
			sampler = font_sampler,
		}
		sdl3.BindGPUFragmentSamplers(bake_pass, 0, &sampler_binding, 1)

		// Execute geometric layout drawing pass to freeze text to pixels
		sdl3.DrawGPUIndexedPrimitives(bake_pass, u32(sequence.num_indices), 1, 0, 0, 0)
		sdl3.EndGPURenderPass(bake_pass)
	}
	// Hand off initialization steps to the GPU device loop queue
	_ = sdl3.SubmitGPUCommandBuffer(init_cmd_buf)

	//fmt.eprintf("Failed to create renderer: %s\n", sdl3.GetError())
	fmt.printf(
		"🎉 System bootstrapped and static text baked into VRAM successfully? %s\n",
		sdl3.GetError(),
	)

	running := true
	event: sdl3.Event

	// --- 12. RUNTIME GRAPHICS RENDERING LOOP (ZERO RUNTIME ALLOCATIONS) ---
	for running {
		for sdl3.PollEvent(&event) {
			if event.type == .QUIT do running = false

			if (event.type == .MOUSE_WHEEL) {

				// Vertical scrolling (Up / Down)
				if (event.wheel.y > 0) {
					fmt.print(event.wheel.y)
				} else if (event.wheel.y < 0) {
					// Scrolled Down (toward user)
				}
			}
		}

		cmd_buf := sdl3.AcquireGPUCommandBuffer(gpu_device)
		if cmd_buf == nil do continue

		swapchain_texture: ^sdl3.GPUTexture
		if !sdl3.AcquireGPUSwapchainTexture(cmd_buf, window, &swapchain_texture, nil, nil) {
			_ = sdl3.SubmitGPUCommandBuffer(cmd_buf)
			continue
		}

		if swapchain_texture != nil {
			// Clear monitor frame background to charcoal gray
			clear_target := sdl3.GPUColorTargetInfo {
				texture     = swapchain_texture,
				clear_color = sdl3.FColor{0.1, 0.1, 0.12, 1.0},
				load_op     = .CLEAR,
				store_op    = .STORE,
			}
			render_pass := sdl3.BeginGPURenderPass(cmd_buf, &clear_target, 1, nil)
			sdl3.EndGPURenderPass(render_pass) // Close pass immediately—no shaders execute here!


			blit_info := sdl3.GPUBlitInfo {
				source = {texture = static_text_texture, w = window_width, h = window_height},
				destination = {
					texture = swapchain_texture,
					x       = 0, // Screen layout position placement anchor offsets
					y       = 0,
					w       = window_width,
					h       = window_height,
				},
				load_op = .LOAD, // Maintains charcoal clear color layer beneath transparent font borders
				filter = .LINEAR,
			}

			sdl3.BlitGPUTexture(cmd_buf, blit_info)
		}

		_ = sdl3.SubmitGPUCommandBuffer(cmd_buf)
	}
}


build_text_transform :: proc(
	min_x, min_y, max_x, max_y, canvas_w, canvas_h, scale: f32,
) -> [16]f32 {
	sx := (2.0 / canvas_w) * scale
	sy := (2.0 / canvas_h) * scale

	mid_x := (min_x + max_x) * 0.5
	mid_y := (min_y + max_y) * 0.5
	tx := -sx * mid_x
	ty := -sy * mid_y

	return [16]f32{sx, 0.0, 0.0, tx, 0.0, sy, 0.0, ty, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0}
}
