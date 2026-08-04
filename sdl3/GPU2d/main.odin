

package main

import "core:fmt"

import "vendor:sdl3"

import "./canvas"
main :: proc() {
	run()
}

TEST_IMAGE :: #load("./assets/Mario.png")

clear_copland:: proc(cv: ^canvas.Canvas) {
		base_color := canvas.Color { r= 221, g = 221, b = 221, a = 255 }
	base_color_dark := canvas.Color { r= 216, g = 216, b = 216, a = 255 }
	color3d_dark := canvas.Color { r= 119, g = 119, b = 119, a = 119 }
	color3d_semi_dark := canvas.Color { r= 159, g = 159, b = 159, a = 255 }
	base_gradient := canvas.create_linear_2_points_gradient_color_provider(canvas.UPoint{0,0}, base_color, canvas.UPoint{1,1}, base_color_dark)
	canvas.fill_rect(cv, canvas.Point{0,0}, f32(cv.res.canvas_width), f32(cv.res.canvas_height), base_gradient)
}

draw_copland_button :: proc (cv:^canvas.Canvas, font: canvas.ScalableFont, label: string, position: canvas.AbsolutePosition, rt: ^ canvas.Realized_Text) {
	font_size :: 15
	padding_vertical_percentage :: 1
	padding_horizontal_percentage :: 1.65
	border_width :: 1
	border_radius :: 3
	border_3d_width :: 2
	base_color := canvas.Color { r= 221, g = 221, b = 221, a = 255 }
	base_color_dark := canvas.Color { r= 216, g = 216, b = 216, a = 255 }
	color3d_dark := canvas.Color { r= 119, g = 119, b = 119, a = 255 }
	color3d_semi_dark := canvas.Color { r= 170, g = 170, b = 170, a = 255 }
	base_gradient := canvas.create_linear_2_points_gradient_color_provider(canvas.UPoint{0,0}, base_color, canvas.UPoint{1,1}, base_color_dark)
	//canvas.create_corner_gradient_color_provider(base_color, base_color, base_color_dark, base_color_dark)
 
	gradient_3d := canvas.create_linear_2_points_gradient_color_provider(canvas.UPoint{0,0}, base_color, canvas.UPoint{1,1}, color3d_dark)

	hello_world_rt := canvas.create_realized_text_line(cv, font, canvas.POSITION_CENTER, font_size, label)
	//defer canvas.destroy_realized_text(&hello_world_rt)
	hello_world_size := canvas.measure_realized_text(cv, hello_world_rt)
	//gh:=canvas.compute_max_glyph_height(font, font_size)
	//nh := max(hello_world_size.h, gh)
	//hello_world_size.h = nh

	padding_horizontal := 0.5 * padding_horizontal_percentage * hello_world_size.w 
	padding_vertical  := 0.5 * padding_vertical_percentage * hello_world_size.h 
	button_size := canvas.Size { hello_world_size.w + padding_horizontal, hello_world_size.h + padding_vertical }

	
	//button border

	
	//canvas.fill_rounded_corners(cv, position, button_size.w, button_size.h, border_radius, canvas.Corners { top_left = .rounded_pixel, top_right = .rounded_pixel, bottom_left = .rounded_pixel, bottom_right = .rounded_pixel},  canvas.COLOR_BLACK)
	
	//canvas.line(cv, canvas.POSITION_TOP_LEFT, canvas.POSITION_BOTTOM_RIGHT, 0.6, canvas.COLOR_BLACK)

	centered_button_position := canvas.RelativePosition { anchored_position = canvas.POSITION_CENTER, parent_position = position, parent_size =  button_size}
	
	// button 3d border
	highlight_position := canvas.RelativePosition { anchored_position = canvas.AnchoredPosition { anchor = canvas.Point{0,0} , position = canvas.Point {2, 2} }, parent_position = position, parent_size =  button_size}
	//canvas.fill_rounded_rect(cv, centered_button_position, button_size.w-2*border_width, button_size.h-2*border_width, border_radius, gradient_3d)
	gradient_3d_top :=  canvas.create_corner_gradient_color_provider(canvas.COLOR_WHITE, canvas.COLOR_WHITE, canvas.COLOR_WHITE, color3d_dark)
	gradient_3d_bottom := canvas.create_linear_2_points_gradient_color_provider({0.4,0.1}, canvas.COLOR_WHITE,  {1,1} , color3d_dark)
	
	//canvas.fill_rounded_corners(cv, centered_button_position, button_size.w-2, button_size.h-2, border_radius, canvas.Corners { top_left = .none, top_right = .straight, bottom_left = .straight, bottom_right = .straight}, gradient_3d_bottom)

	shadow_position := canvas.RelativePosition { anchored_position = canvas.AnchoredPosition { anchor = canvas.Point{0,0} , position = canvas.Point {0, 0} }, parent_position = position, parent_size =  button_size}
	canvas.stroke_corners(cv, shadow_position, button_size.w-1, button_size.h-1, 3, 1.4,  canvas.Corners { top_left = .none, top_right = .rounded, bottom_left = .rounded, bottom_right = .rounded}, color3d_dark)
	canvas.stroke_corners(cv, shadow_position, button_size.w-2, button_size.h-2, 3, 1.4,  canvas.Corners { top_left = .none, top_right = .rounded, bottom_left = .rounded, bottom_right = .rounded}, color3d_semi_dark)
	
	//canvas.stroke_corners(cv, position, button_size.w-2, button_size.h-2, 3, border_radius,  canvas.Corners { top_left = .none, top_right = .rounded_pixel, bottom_left = .rounded_pixel, bottom_right = .rounded}, color3d_semi_dark )
	
	canvas.stroke_corners(cv, highlight_position, button_size.w-5, button_size.h-5, 3, 1, canvas.Corners { top_left = .rounded, top_right = .straight, bottom_left = .straight, bottom_right = .none},  canvas.COLOR_WHITE)

	//button surface
	surface_size := canvas.Size { button_size.w-2*border_3d_width-2*border_width, button_size.h-2*border_3d_width-2*border_width }
	canvas.fill_rounded_corners(cv, centered_button_position, surface_size.w, surface_size.h, 2,  canvas.Corners { top_left = .rounded_pixel, top_right = .rounded_pixel, bottom_left = .rounded_pixel, bottom_right = .rounded_pixel}, base_gradient)
	
	// black border
	canvas.stroke_corners(cv, position, button_size.w, button_size.h, border_radius, border_width,  canvas.Corners { top_left = .rounded_pixel, top_right = .rounded_pixel, bottom_left = .rounded_pixel, bottom_right = .rounded_pixel}, canvas.COLOR_BLACK )
	
	//button text
	canvas.draw_realized_text(cv, centered_button_position, hello_world_rt, canvas.COLOR_BLACK)

	rt^ =  hello_world_rt

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

	window_width_s, window_height_s: i32
    sdl3.GetWindowSizeInPixels(window, &window_width_s, &window_height_s)
	window_width, window_height := u32(window_width_s), u32(window_height_s)

    device := sdl3.CreateGPUDevice({.MSL, .METALLIB, .SPIRV, .DXIL}, true, nil)

	if device == nil {
		fmt.eprintf("Failed to initialize low-level GPU drivers!\n")
		return 
	}
    defer sdl3.DestroyGPUDevice(device)

    texture_info := canvas.create_gpu_window_texture_info(device, window, 0.125)
    

	cv : canvas.Canvas
    canvas_error := canvas.create(texture_info, &cv)
   
    if canvas_error != .None {
        fmt.eprintf("Could not create canvas\n")
		return 
    }

    defer canvas.destroy(&cv)

	font := canvas.load_scalable_font(&cv, "/Users/alexandrerochette/Projects/rd_odin/sdl3/GPU2d/assets/NotoSans-Regular.ttf", 15, false)

    canvas.clear(&cv)
	linear_gradient := canvas.create_linear_2_points_gradient_color_provider(canvas.UPoint{0,0}, canvas.COLOR_BLUE, canvas.UPoint{1,1}, canvas.COLOR_YELLOW)
	/*gradient := canvas.create_corner_gradient_color_provider(canvas.COLOR_RED, canvas.COLOR_GREEN, canvas.COLOR_BLUE, canvas.COLOR_YELLOW)
 
	linear_gradient := canvas.create_linear_2_points_gradient_color_provider(canvas.UPoint{0,0}, canvas.COLOR_BLUE, canvas.UPoint{1,1}, canvas.COLOR_YELLOW)


	hello_world_rt := canvas.create_realized_text_line(&cv, font, canvas.POSITION_CENTER, 128, "Hello, world!")
	defer canvas.destroy_realized_text(&hello_world_rt)
	hello_world_size := canvas.measure_realized_text(&cv, hello_world_rt)
	canvas.fill_rounded_rect(&cv, canvas.POSITION_CENTER, hello_world_size.w + 50, hello_world_size.h + 50, 60,  linear_gradient)
	canvas.draw_realized_text(&cv, canvas.POSITION_CENTER, hello_world_rt, gradient)
	//canvas.draw_text_line(&cv, font, canvas.POSITION_CENTER, 128, "Hello world!", color_provider)
	
	w :: 550
	h :: 200
	canvas.fill_rect(&cv, canvas.POSITION_TOP_LEFT, w, h, canvas.Color { 20, 100, 20, 255 })
	text_block := canvas.create_realized_text_block(&cv, font, canvas.Size {w,  h}, 60, "The quick brown fox jumped over the lazy dog.")
	defer canvas.destroy_realized_text(&text_block)
	canvas.draw_realized_text(&cv, canvas.POSITION_TOP_LEFT, text_block, canvas.COLOR_WHITE)

	rt: canvas.Realized_Text
	//draw_copland_button(&cv, font, "A Button", canvas.POSITION_TOP_RIGHT, &rt)
	//canvas.destroy_realized_text(&rt)
    
	//canvas.fill_rect_triangle(&cv, canvas.UPoint{0, 0.5}, 300, 450, linear_gradient)
	//canvas.fill_rounded_corners(&cv, canvas.Point{0, 300}, 300, 450, 50, canvas.Corners {top_left = .rounded, top_right = .rounded, bottom_right = .none}, linear_gradient)
	//canvas.fill_rounded_corners(&cv, canvas.Point{0, 300}, 300, 450, 50, canvas.Corners {bottom_right = .rounded, top_right = .rounded, top_left = .none}, canvas.COLOR_BLUE)
	//canvas.fill_rounded_rect_triangle(&cv,canvas.Point{0, 0.5}, 300, 450, 50, linear_gradient)

	//canvas.fill_triangle(&cv, canvas.POSITION_TOP_LEFT, canvas.POSITION_TOP_RIGHT, canvas.POSITION_CENTER, linear_gradient)
	canvas.line(&cv, canvas.POSITION_TOP_LEFT, canvas.POSITION_CENTER, 10, linear_gradient)
*/
	clear_copland(&cv)
	rt: canvas.Realized_Text
	//draw_copland_button(&cv, font, "Button", canvas.POSITION_CENTER, &rt)
	//defer canvas.destroy_realized_text(&rt)

	//canvas.absolute_quad(&cv, {  {0,0}, {0,150},   {150,150} ,{150,0}  } , canvas.COLOR_BLUE)


	canvas.fill_triangle(&cv, canvas.POSITION_TOP_LEFT, canvas.POSITION_TOP_RIGHT, canvas.POSITION_CENTER, linear_gradient)
	//canvas.fill_triangle(&cv, canvas.POSITION_BOTTOM_LEFT, canvas.POSITION_BOTTOM_RIGHT, canvas.POSITION_CENTER, linear_gradient)

	image_texture := canvas.load_texture_from_bytes(&cv, TEST_IMAGE)
	defer canvas.destroy_texture(image_texture)
	canvas.draw_scaled_texture(&cv, canvas.POSITION_TOP_LEFT, 0.5, image_texture)

	controls_atlas := canvas.load_texture_from_path(&cv, "/Users/alexandrerochette/Projects/rd_odin/sdl3/GPU2d/assets/atlas_simple.png")
	control_slices := canvas.NineSliceSprite {
		  atlas_position = {0,0},
    	size = {20,20},
		border_left = 7,
		border_right = 7,
		border_top = 7,
		border_bottom = 7
	}
	canvas.draw_nine_slice_sprite(&cv, canvas.POSITION_BOTTOM_RIGHT, {60, 45}, controls_atlas, control_slices )

	canvas.render(&cv)


	running := true
	event: sdl3.Event


	for running && sdl3.WaitEvent(&event ) {
		/*for sdl3.PollEvent(&event) {
			if event.type == .QUIT do running = false
            continue
		}
		}*/
	
		if event.type == .QUIT do running = false
		if event.type == .WINDOW_CLOSE_REQUESTED do running = false		

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
				w       = window_width,
				h       = window_height,
			},
			load_op = .LOAD, // Maintains charcoal clear color layer beneath transparent font borders
			filter = .NEAREST,
		}

		sdl3.BlitGPUTexture(command_buffer, blit_info)


		submit_ok := sdl3.SubmitGPUCommandBuffer(command_buffer)
		assert(submit_ok)
		   
	}
}
