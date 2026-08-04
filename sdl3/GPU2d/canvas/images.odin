package canvas


import "core:math"
import "core:slice"
import "core:strings"
import vmem "core:mem/virtual"
import "vendor:sdl3"
import "vendor:sdl3/image"



TextureHandle :: struct {
    device: ^sdl3.GPUDevice,
    
    uploaded_texture: ^sdl3.GPUTexture,
    w,h: u32
}
destroy_texture :: proc(h: TextureHandle) {
    sdl3.ReleaseGPUTexture(h.device, h.uploaded_texture)
}
@private 
surface_from_memory :: proc(image_bytes: []u8) -> ^sdl3.Surface {
    if len(image_bytes) == 0 do return nil

    // 1. Create a read-only IOStream wrapping the slice memory
    io := sdl3.IOFromConstMem(raw_data(image_bytes), uint(len(image_bytes)))
    if io == nil {
        return nil
    }

    // 2. Load the surface from the stream.
    // Setting the last argument to 'true' tells SDL to automatically close/free 
    // the IOStream when loading finishes.
    surface := image.Load_IO(io, true)
    
    return surface
}
@private
surface_from_path :: proc(path: string) -> ^sdl3.Surface {
    arena: vmem.Arena

	err := vmem.arena_init_growing(&arena)
	assert(err == nil)
	defer vmem.arena_destroy(&arena)

	arena_alloc := vmem.arena_allocator(&arena)


	cpath := strings.clone_to_cstring(path, arena_alloc)


    surface := image.Load(cpath)
    
    return surface
}

@private
surface_to_texture :: proc(canvas: ^Canvas, surface: ^sdl3.Surface) -> TextureHandle {
    surface := surface
    target_format := canvas.target_format 
    target_pixel_format := sdl3.GetPixelFormatFromGPUTextureFormat(target_format)
    if surface.format != target_pixel_format {
        converted := sdl3.ConvertSurface(surface, target_pixel_format)
        if converted != nil {
            sdl3.DestroySurface(surface) // Free original
            surface = converted           // Use converted surface
        }
    }
    w := u32(surface.w)
    h := u32(surface.h)

    texture_desc := sdl3.GPUTextureCreateInfo{
        type        = .D2,
        format      = target_format,
        width       = w,
        height      = h,
        layer_count_or_depth = 1,
        num_levels  = 1,
        usage       = {.SAMPLER},
    }
 
    device := canvas.res.device
    gpu_texture := sdl3.CreateGPUTexture(device, texture_desc)
    image_size_in_bytes := u32(surface.h * surface.pitch)
    pixel_slice: []u8 = slice.from_ptr(transmute(^u8)surface.pixels, int(image_size_in_bytes))
    upload_single_texture_content(device, pixel_slice, w, h, gpu_texture )
    return TextureHandle{device=device, uploaded_texture = gpu_texture, w=w, h=h}
}


load_texture_from_bytes:: proc( canvas: ^Canvas , bytes: []u8) -> TextureHandle {

    surface := surface_from_memory(bytes)
    defer sdl3.DestroySurface(surface)
    return surface_to_texture(canvas, surface)
}

load_texture_from_path:: proc( canvas: ^Canvas , path: string) -> TextureHandle {

    surface := surface_from_path(path)
    defer sdl3.DestroySurface(surface)
    return surface_to_texture(canvas, surface)
}

draw_texture :: proc(canvas: ^Canvas, position: ElementPosition, texture: TextureHandle) {
    w :=  f32(texture.w)
    h := f32(texture.h)
    draw_resized_texture(canvas, position, Size{w,h}, texture)
}

draw_scaled_texture :: proc(canvas: ^Canvas, position: ElementPosition, scaling:f32, texture: TextureHandle) {
    w :=  f32(texture.w) * scaling
    h := f32(texture.h) * scaling
    draw_resized_texture(canvas, position, Size{w,h}, texture)
}

draw_resized_texture :: proc(canvas: ^Canvas, position: ElementPosition, size: Size, texture: TextureHandle) {
    w :=  size.w
    h := size.h
    abs_pos := compute_element_position(position, w, h, f32(canvas.res.canvas_width), f32(canvas.res.canvas_height))
    uvs :[4]Point =  {{1, 0}, {0,0}, {0,1},  {1,1}, }
    points :[4]Point = {{abs_pos.x, abs_pos.y}, {abs_pos.x+w, abs_pos.y} ,  {abs_pos.x+w, abs_pos.y+h}, {abs_pos.x, abs_pos.y+h},  }
    absolute_quad(canvas, points, uvs, COLOR_WHITE, texture)
}
