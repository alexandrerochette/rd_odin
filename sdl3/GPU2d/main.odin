

package main

import "core:fmt"

import "vendor:sdl3"

import "./canvas"
main :: proc() {
	run()
}
run :: proc() {
	// 2. INITIALIZE MULTIMEDIA CORE SUBSYSTEMS
	if !sdl3.Init({.VIDEO}) {
		fmt.eprintf("Failed to initialize core SDL3: %s\n", sdl3.GetError())
		return
	}
	defer sdl3.Quit()
	main_scale := sdl3.GetDisplayContentScale(sdl3.GetPrimaryDisplay())


	window := sdl3.CreateWindow(
		"Hello Odin + SDL3 Window",
		800,
		600,
		{.RESIZABLE, .HIGH_PIXEL_DENSITY},
	)

	defer sdl3.DestroyWindow(window)
    device := sdl3.CreateGPUDevice({.MSL, .METALLIB, .SPIRV, .DXIL}, true, nil)

	if device == nil {
		fmt.eprintf("Failed to initialize low-level GPU drivers!\n")
		return 
	}
    defer sdl3.DestroyGPUDevice(device)

    texture_info := canvas.create_gpu_window_texture_info(device, window)
    
    cvr := canvas.create(texture_info)
    cv, is_canvas := cvr.(canvas.Canvas)
    if !is_canvas {
        fmt.eprintf("Could not create canvas\n")
		return 
    }
    defer canvas.destroy(cv)

    canvas.clear(cv)

	color_provider := canvas.create_constant_color_provider(canvas.COLOR_GREEN)
	color_provider = canvas.create_corner_gradient_color_provider(canvas.COLOR_RED, canvas.COLOR_GREEN, canvas.COLOR_BLUE, canvas.COLOR_YELLOW)
    canvas.fill_rounded_rect(cv, 0, 0, 500, 500,  100, color_provider)

	canvas.fill_rect(cv, 0, 550, 500, 500, color_provider)
    canvas.render(cv)
/*
	gpu_resources, err := canvas.create_2d_gpu_resource(window)
	if err != .success {
		fmt.eprintf("Failed to get gpu resources SDL3: %s\n", sdl3.GetError())
		return
	}
	defer canvas.destroy_2d_gpu_resources(gpu_resources)

    if !sdl3.SetRenderDrawColor(gpu_resources.renderer, 30, 30, 30, 255) {
       fmt.eprintf("SetRenderDrawColor failed: %s\n", sdl3.GetError())
    }

    if !sdl3.RenderClear(gpu_resources.renderer)  {
       fmt.eprintf("RenderClear failed: %s\n", sdl3.GetError())
    }

    sdl3.SetRenderDrawColor(gpu_resources.renderer, 0, 120, 255, 255) // blue
    blue_box := sdl3.FRect{0.0, 0.0, 300.0, 200.0}
    if ! sdl3.RenderFillRect(gpu_resources.renderer, &blue_box) {
         fmt.eprintf("RenderFillRect failed: %s\n", sdl3.GetError())
    }
    
 
    if !sdl3.RenderPresent(gpu_resources.renderer) {
        fmt.eprintf("RenderPresent failed: %s\n", sdl3.GetError())
    }
   
    _ = sdl3.WaitForGPUIdle(gpu_resources.device)
*/

	running := true
	event: sdl3.Event


	for running {
		for sdl3.PollEvent(&event) {
			if event.type == .QUIT do running = false
            continue

		}


		// Position and size your window to cover the screen or a specific region
		//imgui.SetNextWindowPos(imgui.Vec2{0, 0}, .Always)
		//imgui.SetNextWindowSize(imgui.Vec2{f32(width), f32(height)}, .Always)


		command_buffer := sdl3.AcquireGPUCommandBuffer(device)
		swapchain_texture: ^sdl3.GPUTexture
		swapchain_texture_ok := sdl3.WaitAndAcquireGPUSwapchainTexture(
			command_buffer,
			window,
			&swapchain_texture,
			nil,
			nil,
		)
		assert(swapchain_texture_ok)
		clear_target := sdl3.GPUColorTargetInfo {
			texture     = swapchain_texture,
			clear_color = sdl3.FColor{0.1, 0.1, 0.12, 1.0},
			load_op     = .CLEAR,
			store_op    = .STORE,
		}
		render_pass := sdl3.BeginGPURenderPass(command_buffer, &clear_target, 1, nil)
		sdl3.EndGPURenderPass(render_pass) // Close pass immediately—no shaders execute here!


		blit_info := sdl3.GPUBlitInfo {
			source = {
				texture = texture_info.texture,
				w = texture_info.width,
				h = texture_info.height,
			},
			destination = {
				texture = swapchain_texture,
				x       = 0, // Screen layout position placement anchor offsets
				y       = 0,
				w       = texture_info.width,
				h        = texture_info.height,
			},
			load_op = .LOAD, // Maintains charcoal clear color layer beneath transparent font borders
			filter = .LINEAR,
		}

		sdl3.BlitGPUTexture(command_buffer, blit_info)


		submit_ok := sdl3.SubmitGPUCommandBuffer(command_buffer)
		assert(submit_ok)
	}
}
