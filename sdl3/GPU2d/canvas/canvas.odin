package canvas

import "core:fmt"
import "core:math"
import vmem "core:mem/virtual"


import "vendor:sdl3"
import "vendor:sdl3/ttf"

IPoint :: struct {
    x, y : i32
}


Texture_Info :: struct {
    texture: ^sdl3.GPUTexture,
    width: u32,
    height: u32,
    format: sdl3.GPUTextureFormat,
    device: ^sdl3.GPUDevice,
    window: ^sdl3.Window

}

GPU_Canvas_Command :: struct {
    text: ^ttf.Text,
    atlas_draw_sequence: ^ttf.GPUAtlasDrawSequence,
    colors: [dynamic]sdl3.FColor,
    transform_matrix: [16]f32,  
    fragments_global: FragmentsGlobalData,
    is_sdf: bool
}

FragmentsGlobalData:: struct {
    color: [4]f32,
    u_weight: f32,
    padding: [3] f32
}


Canvas :: struct {
    res: GPU_Resources2D,
    canvas_arena: vmem.Arena,
    commands: ([dynamic] GPU_Canvas_Command),
    text_engine: ^ttf.TextEngine,
}

CanvasCreationError:: enum {
    None,
    Fatal
}

CreateCanvasResult :: union {
    Canvas, CanvasCreationError
}

create::  proc(textureInfo: Texture_Info, canvas: ^Canvas) -> CanvasCreationError {


    resources, err_textures := create_2d_gpu_resources_for_texture(textureInfo.window, textureInfo.device, textureInfo.texture, textureInfo.width, textureInfo.height)
    if err_textures != nil {
        return .Fatal
    }

    arena: vmem.Arena
    
    err := vmem.arena_init_growing(&arena)
    assert(err == nil)


    gpu_text_engine := ttf.CreateGPUTextEngine(resources.device)

    //arena_alloc := vmem.arena_allocator(&arena)

    //return Canvas{res = resources, canvas_arena = arena, text_engine = gpu_text_engine , commands = commands_arr}

    canvas.res = resources
    canvas.canvas_arena = arena

    canvas.text_engine = gpu_text_engine

    arena_alloc := vmem.arena_allocator(&canvas.canvas_arena)
    commands_arr := make([dynamic]GPU_Canvas_Command, arena_alloc)
    canvas.commands = commands_arr
    return .None
}

destroy :: proc(canvas: ^Canvas) {
    destroy_2d_gpu_resources(&canvas.res)
    ttf.DestroyGPUTextEngine(canvas.text_engine)
    vmem.arena_destroy(& (canvas.canvas_arena) )
  
}


fill_solid_rect :: proc(canvas:^ Canvas, x, y, w, h: f32, color: Color) {
    gpu_resources := canvas.res
    
    fmt.println("color", color)
    sdl3.SetRenderDrawColor(gpu_resources.renderer, color.r, color.g, color.b, color.a) 
    blue_box := sdl3.FRect{x, y, w, h}
    if ! sdl3.RenderFillRect(gpu_resources.renderer, &blue_box) {
         fmt.eprintf("RenderFillRect failed: %s\n", sdl3.GetError())
    }
}

fill_rect :: proc(canvas: ^Canvas, position: ElementPosition, w, h: f32,  color_provider: ColorProvider)  {

    vertices :=  make([dynamic]sdl3.Vertex)
    indices :=  make([dynamic]i32)
    defer delete(vertices)
    defer delete(indices)
    
    origin :=  sdl3.FPoint {}
    //color := sdl3.FColor { f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) /255.0, f32(color.a) / 255.0}
    pi :f32 = math.PI
    half_pi := 0.5 * pi

    abs_pos := compute_element_position(position, w, h, f32(canvas.res.canvas_width), f32(canvas.res.canvas_height))
    x := abs_pos.x
    y := abs_pos.y
    center_point := sdl3.FPoint{x + w/2.0, y + w/2.0}

    center_color := compute_fcolor(color_provider, UPOIMT_CENTER )
    center_vertex := sdl3.Vertex {center_point, center_color, origin }
    append(&vertices, center_vertex)

    // a
    {
        point_x := x 
        point_y := y 
       
        
        point := sdl3.FPoint{point_x, point_y}
        color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    // b
    {
      
        point_x := x + w 
        point_y := y 
       
        
        point := sdl3.FPoint{point_x, point_y}
        color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    // c
    {

        point_x := x + w 
        point_y := y + h 
       
        
        point := sdl3.FPoint{point_x, point_y}
        color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    // d
    {
       
        point_x := x 
        point_y := y + h 
       
        
        point := sdl3.FPoint{point_x, point_y}
        color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    vertex_count := (len(vertices))
    last_vertex_index := vertex_count - 1
    for vertex, index in vertices {
            append(&indices, 0)
            append(&indices, i32(index))
            if index == last_vertex_index {
                append(&indices,  1)
            }
            else {
                append(&indices, i32( index +1))
            }
    }
    sdl3.RenderGeometry(canvas.res.renderer, nil, raw_data(vertices), i32(vertex_count) , raw_data(indices), i32(len(indices)))
}



colored_clear :: proc(canvas: ^Canvas, r, g, b, a: u8) {
    gpu_resources := canvas.res
    if !sdl3.SetRenderDrawColor(gpu_resources.renderer, r, g, b, a) {
       fmt.eprintf("SetRenderDrawColor failed: %s\n", sdl3.GetError())
    }

    if !sdl3.RenderClear(gpu_resources.renderer)  {
       fmt.eprintf("RenderClear failed: %s\n", sdl3.GetError())
    }
}

clear :: proc(canvas: ^Canvas) {
    gpu_resources := canvas.res
    if !sdl3.SetRenderDrawColor(gpu_resources.renderer, 0, 0, 0, 255) {
       fmt.eprintf("SetRenderDrawColor failed: %s\n", sdl3.GetError())
    }

    if !sdl3.RenderClear(gpu_resources.renderer)  {
       fmt.eprintf("RenderClear failed: %s\n", sdl3.GetError())
    }
}


fill_rounded_rect :: proc(canvas: ^Canvas, position: ElementPosition, w, h, radius: f32, color_provider: ColorProvider)  {
  
    if radius <= 0 {

        fill_rect(canvas, position, w, h, color_provider)
    }
    abs_pos := compute_element_position(position, w, h, f32(canvas.res.canvas_width), f32(canvas.res.canvas_height))
    x := abs_pos.x
    y := abs_pos.y

    r := radius
    vertices :=  make([dynamic]sdl3.Vertex)
    indices :=  make([dynamic]i32)
    defer delete(vertices)
    defer delete(indices)
    
    origin :=  sdl3.FPoint {}
    //color := sdl3.FColor { f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) /255.0, f32(color.a) / 255.0}
    pi :f32 = math.PI
    half_pi := 0.5 * pi
    corner_segment_counts := 7 // establish this based on the size of radius
    fcorner_segment_counts := f32(corner_segment_counts) 

    center_point := sdl3.FPoint{x + w/2.0, y + w/2.0}

    center_color := compute_fcolor(color_provider, UPOIMT_CENTER )
    center_vertex := sdl3.Vertex {center_point, center_color, origin }
    append(&vertices, center_vertex)

    // a
    for i in 0..<corner_segment_counts {
        theta := pi + (f32(i) * half_pi / fcorner_segment_counts)
        point_x := x + r + r * math.cos_f32(theta) 
        point_y := y + r + r * math.sin_f32(theta)
       
        
        point := sdl3.FPoint{point_x, point_y}
        color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    // b
    for i in 0..<corner_segment_counts {
        theta := -half_pi + (f32(i) * half_pi / fcorner_segment_counts)
        point_x := x + w - r + r * math.cos_f32(theta) 
        point_y := y + r + r * math.sin_f32(theta)
       
        
        point := sdl3.FPoint{point_x, point_y}
        color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    // c
    for i in 0..<corner_segment_counts {
        theta := 0 + (f32(i) * half_pi / fcorner_segment_counts)
        point_x := x + w - r + r * math.cos_f32(theta) 
        point_y := y + h - r + r * math.sin_f32(theta)
       
        
        point := sdl3.FPoint{point_x, point_y}
        color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    // d
    for i in 0..<corner_segment_counts {
        theta := half_pi + (f32(i) * half_pi / fcorner_segment_counts)
        point_x := x + r + r * math.cos_f32(theta) 
        point_y := y + h - r +  r * math.sin_f32(theta)
       
        
        point := sdl3.FPoint{point_x, point_y}
         color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
        vertex := sdl3.Vertex {point, color, origin }
        append(&vertices, vertex)
    }

    vertex_count := (len(vertices))
    last_vertex_index := vertex_count - 1
    for vertex, index in vertices {
            append(&indices, 0)
            append(&indices, i32(index))
            if index == last_vertex_index {
                append(&indices,  1)
            }
            else {
                append(&indices, i32( index +1))
            }
    }
    sdl3.RenderGeometry(canvas.res.renderer, nil, raw_data(vertices), i32(vertex_count) , raw_data(indices), i32(len(indices)))
}

destroy_command :: proc(cmd: GPU_Canvas_Command) {
    if cmd.text != nil {
        ttf.DestroyText(cmd.text)
    }
}

render :: proc(canvas: ^Canvas) {
    if !sdl3.RenderPresent(canvas.res.renderer) {
        fmt.eprintf("RenderPresent failed: %s\n", sdl3.GetError())
    }
    render_text(canvas)
    _ = sdl3.WaitForGPUIdle(canvas.res.device)

    for command in canvas.commands {
        destroy_command(command)
    }

    vmem.arena_free_all(&(canvas.canvas_arena))

    arena_alloc := vmem.arena_allocator(&(canvas.canvas_arena))
    commands_arr := make([dynamic]GPU_Canvas_Command, arena_alloc)
    canvas.commands = commands_arr
}
