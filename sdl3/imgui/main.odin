

package main

import "core:fmt"

import "vendor:sdl3"

import imgui "./.dependencies/shared/odin-imgui"
import "./.dependencies/shared/odin-imgui/imgui_impl_sdl3"
import "./.dependencies/shared/odin-imgui/imgui_impl_sdlgpu3"
main::proc() {
    run()
}
run:: proc () {
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
		{.RESIZABLE,  .HIGH_PIXEL_DENSITY},
	)

    defer sdl3.DestroyWindow(window)
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

    width, height: i32
    sdl3.GetWindowSizeInPixels(window, &width, &height)

    // 1. Create a custom offscreen texture with COLOR_TARGET and SAMPLER usage
    offscreen_texture_desc := sdl3.GPUTextureCreateInfo{
        type   = .D2,
        format = sdl3.GetGPUSwapchainTextureFormat(gpu_device, window),
        width  = u32(width),
        height = u32(height),
        layer_count_or_depth = 1,
        num_levels = 1,
        usage  = {.COLOR_TARGET, .SAMPLER}, 
    }
    my_text_texture := sdl3.CreateGPUTexture(gpu_device, offscreen_texture_desc)
    defer sdl3.ReleaseGPUTexture(gpu_device, my_text_texture)

  
    imgui.CHECKVERSION()
    imgui.CreateContext()
    defer imgui.DestroyContext()
    io := imgui.GetIO()
    io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad, .DockingEnable, .ViewportsEnable}

    style := imgui.GetStyle()
	imgui.Style_ScaleAllSizes(style, main_scale)
	style.FontScaleDpi = main_scale
	io.ConfigDpiScaleFonts = true
	io.ConfigDpiScaleViewports = true

    // 2. Initialize SDL3 platform backend
    imgui_impl_sdl3.InitForSDLGPU(window)
    defer imgui_impl_sdl3.Shutdown()

    // 3. Initialize SDL3 GPU renderer backend (passing your GPU device and swapchain format)
    init_info := imgui_impl_sdlgpu3.InitInfo {
		Device               = gpu_device,
		ColorTargetFormat    = sdl3.GetGPUSwapchainTextureFormat(gpu_device, window),
		MSAASamples          = ._1,
		SwapchainComposition = .SDR,
		PresentMode          = .VSYNC,
	}
    imgui_impl_sdlgpu3.Init(&init_info)

    defer imgui_impl_sdlgpu3.Shutdown()

    /*cmd_buf := sdl3.AcquireGPUCommandBuffer(gpu_device)
    // 2. Build your ImGui frame and draw your text label
    imgui_impl_sdlgpu3.NewFrame()
    imgui_impl_sdl3.NewFrame()
    imgui.NewFrame()

    imgui.Begin("Offscreen Canvas")
    imgui.Text("Hello text rendered inside an SDL GPU texture via ImGui!")
    imgui.End()

    imgui.Render()

    // 3. Prepare ImGui draw data for the command buffer
    imgui_impl_sdlgpu3.PrepareDrawData(imgui.GetDrawData(), cmd_buf)

    // 4. Target your OFFSCREEN texture instead of the swapchain
    offscreen_target := sdl3.GPUColorTargetInfo{
        texture     = my_text_texture,
        clear_color = sdl3.FColor{0.0, 0.0, 0.0, 0.0}, // Transparent background
        load_op     = .CLEAR,
        store_op    = .STORE, // .STORE keeps it in VRAM so you can use it later!
    }

    render_pass := sdl3.BeginGPURenderPass(cmd_buf, &offscreen_target, 1, nil)

    // 5. Render ImGui's geometry straight into your texture
    imgui_impl_sdlgpu3.RenderDrawData(imgui.GetDrawData(), cmd_buf, render_pass)

    sdl3.EndGPURenderPass(render_pass)
    _ = sdl3.SubmitGPUCommandBuffer(cmd_buf)
*/
    running := true
	event: sdl3.Event

	// --- 12. RUNTIME GRAPHICS RENDERING LOOP (ZERO RUNTIME ALLOCATIONS) ---
	for running {
		for sdl3.PollEvent(&event) {
            if event.type == .QUIT do running = false
            imgui_impl_sdl3.ProcessEvent(&event)
		
		}

        imgui_impl_sdlgpu3.NewFrame()
		imgui_impl_sdl3.NewFrame()
		imgui.NewFrame()

		imgui.ShowDemoWindow()

		/*if imgui.Begin("Window containing a quit button") {
			if imgui.Button("The quit button in question") {
				running = false
			}
		}*/

        flags := imgui.WindowFlags{
            .NoTitleBar,
            .NoResize,
            .NoMove,
            .NoBackground,
            .NoSavedSettings,
            .NoMouseInputs
        }

        // Position and size your window to cover the screen or a specific region
        //imgui.SetNextWindowPos(imgui.Vec2{0, 0}, .Always)
        //imgui.SetNextWindowSize(imgui.Vec2{f32(width), f32(height)}, .Always)

        imgui.Begin("CenteredTextOverlay", nil, flags)
        imgui.Text("Hello text rendered inside an SDL GPU texture via ImGui!")
   

		imgui.End()

        imgui.Render()
		draw_data := imgui.GetDrawData()
		is_minimized := draw_data.DisplaySize.x == 0 || draw_data.DisplaySize.y == 0

		command_buffer := sdl3.AcquireGPUCommandBuffer(gpu_device)
		swapchain_texture: ^sdl3.GPUTexture
		swapchain_texture_ok := sdl3.WaitAndAcquireGPUSwapchainTexture(command_buffer, window, &swapchain_texture, nil, nil)
		assert(swapchain_texture_ok)

		if swapchain_texture != nil && !is_minimized {
			imgui_impl_sdlgpu3.PrepareDrawData(draw_data, command_buffer)

			target_info := sdl3.GPUColorTargetInfo {
				texture = swapchain_texture,
				clear_color = { 0, 0, 0, 1 },
				load_op = .CLEAR,
				store_op = .STORE,
			}
			render_pass := sdl3.BeginGPURenderPass(command_buffer, &target_info, 1, nil)

			imgui_impl_sdlgpu3.RenderDrawData(draw_data, command_buffer, render_pass, nil)

			sdl3.EndGPURenderPass(render_pass)
		}

		if .ViewportsEnable in io.ConfigFlags {
			imgui.UpdatePlatformWindows()
			imgui.RenderPlatformWindowsDefault()
		}

		submit_ok := sdl3.SubmitGPUCommandBuffer(command_buffer)
		assert(submit_ok)
    }
}