package canvas

import "core:fmt"

import "vendor:sdl3"
import "vendor:sdl3/ttf"


create_renderer_texture_from_gpu_texture :: proc(gpu_texture:^sdl3.GPUTexture, width, height: u32, renderer:^sdl3.Renderer) -> ^sdl3.Texture {

    properties := sdl3.CreateProperties()
    defer sdl3.DestroyProperties(properties)
    sdl3.SetPointerProperty(properties, sdl3.PROP_TEXTURE_CREATE_GPU_TEXTURE_POINTER, gpu_texture)

    sdl3.SetNumberProperty(properties, sdl3.PROP_TEXTURE_CREATE_WIDTH_NUMBER, i64(width));
    sdl3.SetNumberProperty(properties, sdl3.PROP_TEXTURE_CREATE_HEIGHT_NUMBER, i64(height));
    sdl3.SetNumberProperty(properties, sdl3.PROP_TEXTURE_CREATE_ACCESS_NUMBER, i64(sdl3.TextureAccess.TARGET)) 

    renderer_texture := sdl3.CreateTextureWithProperties(renderer, properties)
    if renderer_texture == nil {
        fmt.eprintf("Failed to create renderer texture: %s\n", sdl3.GetError())
    }

    return renderer_texture
}


create_renderer_from_gpu_texture :: proc(gpu_texture:^sdl3.GPUTexture, w,h: u32, device: ^sdl3.GPUDevice, window: ^sdl3.Window) -> ^sdl3.Renderer {

    renderer := sdl3.CreateGPURenderer(device, nil)
    if renderer == nil {
        fmt.eprintf("Failed to create renderer: %s\n", sdl3.GetError())
    }
    renderer_texture := create_renderer_texture_from_gpu_texture(gpu_texture, w, h, renderer)

    if !sdl3.SetRenderTarget(renderer, renderer_texture) {
        fmt.eprintf("SetRenderTarget failed: %s\n", sdl3.GetError())
    }


    if !sdl3.RenderClear(renderer) {
        fmt.eprintf("RenderClear failed: %s\n", sdl3.GetError())
    }

    return renderer
}


GPU_Resources2D :: struct {
    window: ^sdl3.Window,
    device: ^sdl3.GPUDevice,
    gpu_texture:^sdl3.GPUTexture,
    drawing_resources: Drawing_GPU_Resources_2D,
    //renderer_texture:^sdl3.Texture,
    renderer: ^sdl3.Renderer,
    canvas_width: u32,
    canvas_height: u32
}

GPU_Resources2D_Error_Status :: enum {
    success,
    fatal_error
}

create_2d_gpu_resources_for_texture:: proc(window:^sdl3.Window, gpu_device: ^sdl3.GPUDevice, texture: ^sdl3.GPUTexture, width, height: u32, format: sdl3.GPUTextureFormat)  -> (GPU_Resources2D, GPU_Resources2D_Error_Status)  {
   
    
	
    result := GPU_Resources2D {}
    renderer2 := create_renderer_from_gpu_texture(texture, width, height, gpu_device, window)

    renderer, gpu_texture :=  renderer2, texture //create_gpu_renderer_and_texture(format, width, height, gpu_device)

    //window_format := sdl3.GetGPUSwapchainTextureFormat(gpu_device, window)
    drawing_resources := create_drawing_gpu_resources(gpu_device, format, true)
    
    result.device = gpu_device
    result.gpu_texture = gpu_texture
    result.window = window
    result.renderer = renderer
    result.canvas_height = height
    result.canvas_width = width
    result.drawing_resources = drawing_resources

    return result, .success
}


create_gpu_window_texture_info :: proc(device: ^sdl3.GPUDevice, window: ^sdl3.Window, scaling:f32=1.0) -> Texture_Info {
  
    ttf_lib_init_success := ttf.Init()
	fmt.assertf(ttf_lib_init_success, "Failed to initialize SDL3_ttf subsystem: %s\n", sdl3.GetError())
		
	if !sdl3.ClaimWindowForGPUDevice(device, window) {
        sdl3.DestroyGPUDevice(device)
		fmt.eprintf("Failed to claim window swapchain: %s\n", sdl3.GetError())
		
	}
	

    width_s, height_s: i32
    sdl3.GetWindowSizeInPixels(window, &width_s, &height_s)
    format := sdl3.GetGPUSwapchainTextureFormat(device, window)
    width, height := u32(f32(width_s) * scaling), u32(f32(height_s) * scaling)

    offscreen_texture_desc := sdl3.GPUTextureCreateInfo{
        type   = .D2,
        format =format,
        width  = width,
        height = height,
        layer_count_or_depth = 1,
        num_levels = 1,
    
         usage  = {.COLOR_TARGET, .SAMPLER}, 
    }
    gpu_texture := sdl3.CreateGPUTexture(device, offscreen_texture_desc)

    return Texture_Info { gpu_texture,  width, height, format, device, window }
}

create_gpu_texture_info :: proc(device: ^sdl3.GPUDevice, format: sdl3.GPUTextureFormat, w, h: u32) -> Texture_Info {
  
    offscreen_texture_desc := sdl3.GPUTextureCreateInfo{
        type   = .D2,
        format =format,
        width  = w,
        height = h,
        layer_count_or_depth = 1,
        num_levels = 1,
    
         usage  = {.COLOR_TARGET, .SAMPLER}, 
    }
    gpu_texture := sdl3.CreateGPUTexture(device, offscreen_texture_desc)

    return Texture_Info { gpu_texture,  w, h, format, device, nil }
}
/*
create_2d_gpu_resource :: proc(window:^sdl3.Window) -> (GPU_Resources2D, GPU_Resources2D_Error_Status)  {

    gpu_device := sdl3.CreateGPUDevice({.MSL, .METALLIB, .SPIRV, .DXIL}, true, nil)
    result := GPU_Resources2D {}
	if gpu_device == nil {
		fmt.eprintf("Failed to initialize low-level GPU drivers!\n")
		return result, .fatal_error
	}
	
	if !sdl3.ClaimWindowForGPUDevice(gpu_device, window) {
        sdl3.DestroyGPUDevice(gpu_device)
		fmt.eprintf("Failed to claim window swapchain: %s\n", sdl3.GetError())
		return result, .fatal_error
	}
	

    width_s, height_s: i32
    sdl3.GetWindowSizeInPixels(window, &width_s, &height_s)
    format := sdl3.GetGPUSwapchainTextureFormat(gpu_device, window)
    width, height := u32(width_s), u32(height_s)
      // 1. Create a custom offscreen texture with COLOR_TARGET and SAMPLER usage
    offscreen_texture_desc := sdl3.GPUTextureCreateInfo{
        type   = .D2,
        format =format,
        width  = u32(width),
        height = u32(height),
        layer_count_or_depth = 1,
        num_levels = 1,
    
         usage  = {.COLOR_TARGET, .SAMPLER}, 
    }
    gpu_texture2 := sdl3.CreateGPUTexture(gpu_device, offscreen_texture_desc)
    if gpu_texture2 == nil {
        fmt.eprintf("gpu_texture creation failed: %s\n", sdl3.GetError())
        sdl3.DestroyGPUDevice(gpu_device)
        return result, .fatal_error
    }
    
    return create_2d_gpu_resources_for_texture(window, gpu_device, gpu_texture2, width, height)
  
}*/

destroy_2d_gpu_resources::proc(res: ^GPU_Resources2D) {

    destroy_drawing_gpu_resources(res.device, &res.drawing_resources)

    if res.renderer != nil {
        sdl3.DestroyRenderer(res.renderer)
    }

    if res.gpu_texture != nil {
        sdl3.ReleaseGPUTexture(res.device, res.gpu_texture)
    }

    sdl3.ReleaseWindowFromGPUDevice(res.device, res.window)

   /* if res.device != nil {
        sdl3.DestroyGPUDevice(res.device)
    }*/
     ttf.Quit()

}