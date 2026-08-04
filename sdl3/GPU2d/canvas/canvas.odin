package canvas

import "core:fmt"
import "core:math"
import "core:math/linalg"
import vmem "core:mem/virtual"


import "vendor:sdl3"
import "vendor:sdl3/ttf"

IPoint :: struct {
	x, y: i32,
}


Texture_Info :: struct {
	texture: ^sdl3.GPUTexture,
	width:   u32,
	height:  u32,
	format:  sdl3.GPUTextureFormat,
	device:  ^sdl3.GPUDevice,
	window:  ^sdl3.Window,
}

GPU_Canvas_Command :: struct {
	text:                ^ttf.Text,
	atlas_draw_sequence: ^ttf.GPUAtlasDrawSequence,
    vertices:            [dynamic]sdl3.FPoint,
    uv:                  [dynamic]sdl3.FPoint,
    indices:             [dynamic]i32,
    texture:             ^sdl3.GPUTexture,
	colors:              [dynamic]sdl3.FColor,
	transform_matrix:    [16]f32,
	fragments_global:    FragmentsGlobalData,
	is_sdf:              bool,
	is_text_owned:       bool,
}

FragmentsGlobalData :: struct {
	color:    [4]f32,
	u_weight: f32,
	padding:  [3]f32,
}


Canvas :: struct {
	res:          GPU_Resources2D,
	canvas_arena: vmem.Arena,
	commands:     ([dynamic]GPU_Canvas_Command),
	text_engine:  ^ttf.TextEngine,
    target_format: sdl3.GPUTextureFormat
}

CanvasCreationError :: enum {
	None,
	Fatal,
}

CreateCanvasResult :: union {
	Canvas,
	CanvasCreationError,
}


CornerStyle :: enum {
	straight,
	rounded,
	rounded_pixel,
	none,
}

Corners :: bit_field u16 {
	top_left:     CornerStyle | 3,
	top_right:    CornerStyle | 3,
	bottom_left:  CornerStyle | 3,
	bottom_right: CornerStyle | 3,
}

@(private)
Pixel_Point :: struct {
	x, y: i32,
}

// Low-radius lookup tables to ensure clean diagonals without ugly L-shapes.
@(private)
get_pixel_art_corner :: proc(radius: i32) -> []Pixel_Point {
	@(static) c1 := [2]Pixel_Point{{0, 1}, {1, 0}}
	@(static) c2 := [3]Pixel_Point{{0, 2}, {1, 1}, {2, 0}}
	@(static) c3 := [5]Pixel_Point{{0, 3}, {0, 2}, {1, 1}, {2, 0}, {3, 0}}
	@(static) c4 := [6]Pixel_Point{{0, 4}, {0, 3}, {1, 2}, {2, 1}, {3, 0}, {4, 0}}
	@(static) c5 := [7]Pixel_Point{{0, 5}, {0, 4}, {1, 3}, {2, 2}, {3, 1}, {4, 0}, {5, 0}}
	@(static) c6 := [8]Pixel_Point{{0, 6}, {0, 5}, {1, 4}, {2, 3}, {3, 2}, {4, 1}, {5, 0}, {6, 0}}

	switch radius {
	case 1:
		return c1[:]
	case 2:
		return c2[:]
	case 3:
		return c3[:]
	case 4:
		return c4[:]
	case 5:
		return c5[:]
	case 6:
		return c6[:]
	}
	return nil
}

push_gpu_command :: proc(canvas: ^Canvas, vertices: []sdl3.Vertex, indices: []i32, texture: ^sdl3.GPUTexture) {
    l := len(canvas.commands)
    canvas_width := f32(canvas.res.canvas_width)
    canvas_height:= f32(canvas.res.canvas_height)

    sx := f32(2.0 / canvas_width)
    sy := f32(-2.0 / canvas_height)

    // Anchor the text's natural top-left (min_x, max_y)
    // directly to the top-left of the canvas (-1.0, 1.0 in NDC)
    tx :f32= -1.0 
    ty :f32= 1.0
    if l == 0 || canvas.commands[l-1].texture != texture {
        
        arena_alloc := vmem.arena_allocator(&canvas.canvas_arena)
	    vertex_arr := make([dynamic]sdl3.FPoint, 0, len(vertices), arena_alloc )
        uv_arr := make([dynamic]sdl3.FPoint, 0, len(vertices), arena_alloc )
        color_arr  := make([dynamic]sdl3.FColor, 0, len(vertices), arena_alloc )
        for vertex,i in vertices {
            append(&vertex_arr, vertex.position)
            append(&uv_arr, vertex.tex_coord)
            append(&color_arr, vertex.color)
        }

        indices_arr  := make([dynamic]i32, 0, len(indices), arena_alloc )
        append(&indices_arr, ..indices)

      
        command := GPU_Canvas_Command {
            vertices = vertex_arr,
            uv = uv_arr,
            colors = color_arr,
            indices = indices_arr,
            texture = texture,
            transform_matrix =  [16]f32{sx, 0.0, 0.0, tx, 0.0, sy, 0.0, ty, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0}
        }
        append(&canvas.commands, command)
    } else {
        cmd :^GPU_Canvas_Command = &canvas.commands[l-1]
        existing_elements_count := i32(len(cmd.vertices))
        new_elements_count := len(vertices)
        reserve(&(cmd.vertices) , len(cmd.vertices) + new_elements_count)
        reserve(&(cmd.uv) , len(cmd.uv) + new_elements_count)
        reserve(&(cmd.colors) , len(cmd.colors) + new_elements_count)
        for vertex,i in vertices {
            append(&(cmd.vertices) , vertex.position)
            append(&(cmd.uv) , vertex.tex_coord)
            append(&(cmd.colors) , vertex.color)            
        }
        reserve(&(cmd.colors) , len(cmd.indices) + len(indices))
        for index in indices {
            append(&cmd.indices, existing_elements_count + index)
        }


    }
}

create :: proc(textureInfo: Texture_Info, canvas: ^Canvas) -> CanvasCreationError {
    window_format := sdl3.GetGPUSwapchainTextureFormat(textureInfo.device, textureInfo.window)

	resources, err_textures := create_2d_gpu_resources_for_texture(
		textureInfo.window,
		textureInfo.device,
		textureInfo.texture,
		textureInfo.width,
		textureInfo.height,
        window_format
	)
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
    canvas.target_format = window_format

	arena_alloc := vmem.arena_allocator(&canvas.canvas_arena)
	commands_arr := make([dynamic]GPU_Canvas_Command, arena_alloc)
	canvas.commands = commands_arr

    canvas.res.drawing_resources.nil_texture = create_nil_texture(textureInfo.device, window_format)
  

	return .None
}

destroy :: proc(canvas: ^Canvas) {
	destroy_2d_gpu_resources(&canvas.res)
	ttf.DestroyGPUTextEngine(canvas.text_engine)
	vmem.arena_destroy(&(canvas.canvas_arena))

}


fill_solid_rect :: proc(canvas: ^Canvas, x, y, w, h: f32, color: Color) {
	gpu_resources := canvas.res

	fmt.println("color", color)
	sdl3.SetRenderDrawColor(gpu_resources.renderer, color.r, color.g, color.b, color.a)
	blue_box := sdl3.FRect{x, y, w, h}
	if !sdl3.RenderFillRect(gpu_resources.renderer, &blue_box) {
		fmt.eprintf("RenderFillRect failed: %s\n", sdl3.GetError())
	}
}

fill_triangle :: proc(
	canvas: ^Canvas,
	position_A: ElementPosition,
	position_B: ElementPosition,
	position_C: ElementPosition,
	color_provider: ColorProvider,
) {

	positions := []ElementPosition{position_A, position_B, position_C}

	anchored_points: [3]AnchoredPoint
	vertices: [3]sdl3.Vertex
	indices: [3]i32
	origin := sdl3.FPoint{}
	for position, index in positions {
		anchored_point := compute_unanchored_position(
			position,
			f32(canvas.res.canvas_width),
			f32(canvas.res.canvas_height),
		)
		anchored_points[index] = anchored_point
	}

	max_x := max(anchored_points[0].x, anchored_points[1].x, anchored_points[2].x)
	min_x := min(anchored_points[0].x, anchored_points[1].x, anchored_points[2].x)
	w := max_x - min_x

	max_y := max(anchored_points[0].y, anchored_points[1].y, anchored_points[2].y)
	min_y := min(anchored_points[0].y, anchored_points[1].y, anchored_points[2].y)
	h := max_y - min_y

	for point, index in anchored_points {
		// abs_pos := compute_anchored_position(point, w, h)

		x := point.x
		y := point.y


		point := sdl3.FPoint{x, y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, min_x, min_y, w, h)

		vertices[index] = sdl3.Vertex{point, color, origin}
		indices[index] = i32(index)
	}

    push_gpu_command(canvas, vertices[:], indices[:], nil)
	/*sdl3.RenderGeometry(
		canvas.res.renderer,
		nil,
		raw_data(&vertices),
		len(vertices),
		raw_data(&indices),
		i32(len(indices)),
	)*/

}

StrokePosition :: enum {
    normal, inside, outside
}

LinePosition :: enum {
    on, over, below
}

line :: proc(
	canvas: ^Canvas,
	start: ElementPosition,
	end: ElementPosition,
	thickness: f32,
	color_provider: ColorProvider,
    strokePosition: LinePosition = .on
) {
	abs_start := compute_unanchored_position(
		start,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
	)
	abs_end := compute_unanchored_position(
		end,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
	)


	p1 := linalg.Vector2f32{abs_start.x, abs_start.y}
	p2 := linalg.Vector2f32{abs_end.x, abs_end.y}

	direction := p2 - p1
	length := linalg.vector_length(direction)
	if length == 0.0 do return

	direction = direction / length
	normal := linalg.Vector2f32{-direction.y, direction.x}
	offset := normal * (thickness * 0.5)
    quad_vertices : [4]linalg.Vector2f32
    switch strokePosition {
        case .on:
            quad_vertices = [?]linalg.Vector2f32{p1 - offset, p1 + offset, p2 + offset, p2 - offset}
        case .below:
            quad_vertices = [?]linalg.Vector2f32{p1 , p1 + 2*offset, p2 + 2*offset, p2 }
        case .over:
            quad_vertices = [?]linalg.Vector2f32{p1 - 2*offset, p1 , p2, p2 - 2*offset}
    }
	
	quad_point_vertices := transmute([4]Point)quad_vertices
	absolute_quad(canvas, quad_point_vertices, nil, color_provider)
}



pixel_line :: proc(
    canvas: ^Canvas,
    p1, p2: IPoint,
    thickness: i32,
    color_provider: ColorProvider,
) {
    dx := p2.x - p1.x
    dy := p2.y - p1.y
    if dx == 0 && dy == 0 do return

    t := max(1, thickness)
    o1, o2: IPoint

    if dy == 0 {
        // --- HORIZONTAL LINE ---
        oy := (dx > 0) ? t : -t
        o1 = {0, oy}
        o2 = {0, oy}
    } else if dx == 0 {
        // --- VERTICAL LINE ---
        ox := (dy > 0) ? -t : t
        o1 = {ox, 0}
        o2 = {ox, 0}
    } else if math.abs(dx) == math.abs(dy) {
        // --- 45-DEGREE DIAGONAL (Clockwise Miter Offsets) ---
        if dx > 0 && dy < 0 {      // Top-Left Direction
            o1 = {t, 0};  o2 = {0, t}
        } else if dx > 0 && dy > 0 { // Top-Right Direction
            o1 = {0, t};  o2 = {-t, 0}
        } else if dx < 0 && dy > 0 { // Bottom-Right Direction
            o1 = {-t, 0}; o2 = {0, -t}
        } else if dx < 0 && dy < 0 { // Bottom-Left Direction
            o1 = {0, -t}; o2 = {t, 0}
        }
    }

    // Build watertight quad
    quad := [4]Point{
        {f32(p1.x), f32(p1.y)},
        {f32(p1.x + o1.x), f32(p1.y + o1.y)},
        {f32(p2.x + o2.x), f32(p2.y + o2.y)},
        {f32(p2.x), f32(p2.y)},
    }

    absolute_quad(canvas, quad, nil, color_provider)
}

pixel_line_aligned :: proc(
    canvas: ^Canvas,
    p1, p2: IPoint,
    thickness: i32,
    color_provider: ColorProvider,
) {
    dx := p2.x - p1.x
    dy := p2.y - p1.y
    if dx == 0 && dy == 0 do return

    t := max(1, thickness)

    if dy == 0 {
        // --- HORIZONTAL LINE ---
        oy := (dx > 0) ? t : -t
        quad := [4]Point{to_point(p1), to_point({p1.x, p1.y + oy}), to_point({p2.x, p2.y + oy}), to_point(p2)}
        absolute_quad(canvas, quad, nil, color_provider)

    } else if dx == 0 {
        // --- VERTICAL LINE ---
        ox := (dy > 0) ? -t : t
        quad := [4]Point{ to_point(p1), to_point({p1.x + ox, p1.y}), to_point({p2.x + ox, p2.y}), to_point(p2)}
        absolute_quad(canvas, quad, nil, color_provider)

    } else if math.abs(dx) == math.abs(dy) {
        // --- 45-DEGREE PIXEL-ART DIAGONALS ---
        // Emit discrete 1x1 pixel quads to bypass GPU subpixel rasterization bias
        steps := math.abs(dx)
        sx :i32= (dx > 0) ? 1 : -1
        sy :i32= (dy > 0) ? 1 : -1

        cur_x := p1.x
        cur_y := p1.y

        // Offset start coordinates to connect flush with adjacent straight edges
        if dx > 0 && dy < 0 {        // Top-Left: (0,3) -> (3,0)
            cur_y -= 1
        } else if dx < 0 && dy > 0 { // Bottom-Right: (161,49) -> (158,52)
            cur_x -= 1
        } else if dx < 0 && dy < 0 { // Bottom-Left: (3,52) -> (0,49)
            cur_x -= 1
            cur_y -= 1
        }

        for i in 0..<steps {
            // Emit exact 1x1 pixel quad
            quad := [4]Point{
                to_point({cur_x,     cur_y}),
                to_point({cur_x + 1, cur_y}),
                to_point({cur_x + 1, cur_y + 1}),
                to_point({cur_x,     cur_y + 1}),
            }
            absolute_quad(canvas, quad, nil, color_provider)

            cur_x += sx
            cur_y += sy
        }
    }

}


stroke_corners :: proc(
	canvas: ^Canvas,
	position: ElementPosition,
	w, h, radius: f32,
    thickness: f32,
	corners: Corners,
	color_provider: ColorProvider,
) {
    points := make([dynamic]Point)

    defer delete(points)


    abs_position := compute_rounded_corners_points(canvas, position, w, h, radius, corners, &points)

    for pt, index in points {
        if index > 0 {
          
            start := to_ipoint(points[index-1])
            end := to_ipoint(pt)
            fmt.printfln("line from %v to %v", start, end)
            pixel_line_aligned(canvas, start, end, i32(math.round(thickness)), color_provider)
        }
    }
    points_count := len(points)
    if points_count > 1 {
        start := to_ipoint(points[points_count - 1])
        end := to_ipoint(points[0])
          fmt.printfln("line from %v to %v", start, end)
        pixel_line_aligned(canvas, start , end, i32(math.round(thickness)), color_provider)
    }
}



absolute_quad :: proc(canvas: ^Canvas, quad_vertices: [4]Point, uvs: Maybe([4]Point), color_provider: ColorProvider, texture: TextureHandle = TextureHandle {}) {
	min_x := min(quad_vertices[0].x, quad_vertices[1].x, quad_vertices[2].x, quad_vertices[3].x)
	min_y := min(quad_vertices[0].y, quad_vertices[1].y, quad_vertices[2].y, quad_vertices[3].y)

	max_x := max(quad_vertices[0].x, quad_vertices[1].x, quad_vertices[2].x, quad_vertices[3].x)
	max_y := max(quad_vertices[0].y, quad_vertices[1].y, quad_vertices[2].y, quad_vertices[3].y)
	w := max_x - min_x
	h := max_y - min_y

	vertices: [4]sdl3.Vertex

	origin := sdl3.FPoint{}

    quad_uvs : [4]Point
    switch v in uvs {
        case [4]Point:
            quad_uvs = v
        case: 
            quad_uvs = { {0,0}, {0,0}, {0,0}, {0,0}}
    }

	for vertex, index in quad_vertices {
        uv := quad_uvs[index]
		point := sdl3.FPoint{vertex.x, vertex.y}

		color := compute_fcolor_from_screen_fpoint(color_provider, point, min_x, min_y, w, h)
		vertex := sdl3.Vertex{point, color, sdl3.FPoint{uv.x, uv.y}}
		vertices[index] = vertex

	}
    fmt.printfln("quad vertices: %v", quad_vertices)
	indices := [6]i32{0, 1, 2, 2, 0, 3}

    push_gpu_command(canvas, vertices[:], indices[:], texture.uploaded_texture)
}

fill_rect :: proc(
	canvas: ^Canvas,
	position: ElementPosition,
	w, h: f32,
	color_provider: ColorProvider,
) {

	vertices := make([dynamic]sdl3.Vertex)
	indices := make([dynamic]i32)
	defer delete(vertices)
	defer delete(indices)

	origin := sdl3.FPoint{}
	//color := sdl3.FColor { f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) /255.0, f32(color.a) / 255.0}
	pi: f32 = math.PI
	half_pi := 0.5 * pi

	abs_pos := compute_element_position(
		position,
		w,
		h,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
	)
	x := math.round(abs_pos.x)
	y := math.round(abs_pos.y)
	center_point := sdl3.FPoint{x + w / 2.0, y + h / 2.0}

	center_color := compute_fcolor(color_provider, UPOIMT_CENTER)
	center_vertex := sdl3.Vertex{center_point, center_color, origin}
	append(&vertices, center_vertex)

	// a
	{
		point_x := math.round(x)
		point_y := math.round(y)


		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	// b
	{

		point_x := math.round(x + w)
		point_y := math.round(y)


		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	// c
	{

		point_x := math.round(x + w)
		point_y := math.round(y + h)


		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	// d
	{

		point_x := math.round(x)
		point_y := math.round(y + h)


		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	vertex_count := (len(vertices))
	last_vertex_index := vertex_count - 1
	for vertex, index in vertices {
        
		append(&indices, 0)
		append(&indices, i32(index))
		if index == last_vertex_index {
			append(&indices, 1)
		} else {
			append(&indices, i32(index + 1))
		}
	}
    push_gpu_command(canvas, vertices[:], indices[:], nil)
	/*sdl3.RenderGeometry(
		canvas.res.renderer,
		nil,
		raw_data(vertices),
		i32(vertex_count),
		raw_data(indices),
		i32(len(indices)),
	)*/
}


colored_clear :: proc(canvas: ^Canvas, r, g, b, a: u8) {
	gpu_resources := canvas.res
	if !sdl3.SetRenderDrawColor(gpu_resources.renderer, r, g, b, a) {
		fmt.eprintf("SetRenderDrawColor failed: %s\n", sdl3.GetError())
	}

	if !sdl3.RenderClear(gpu_resources.renderer) {
		fmt.eprintf("RenderClear failed: %s\n", sdl3.GetError())
	}
}

clear :: proc(canvas: ^Canvas) {
	gpu_resources := canvas.res
	if !sdl3.SetRenderDrawColor(gpu_resources.renderer, 0, 0, 0, 255) {
		fmt.eprintf("SetRenderDrawColor failed: %s\n", sdl3.GetError())
	}

	if !sdl3.RenderClear(gpu_resources.renderer) {
		fmt.eprintf("RenderClear failed: %s\n", sdl3.GetError())
	}
}


fill_rounded_rect :: proc(
	canvas: ^Canvas,
	position: ElementPosition,
	w, h, radius: f32,
	color_provider: ColorProvider,
) {
	fill_rounded_corners(
		canvas,
		position,
		w,
		h,
		radius,
		Corners {
			top_left = .rounded,
			top_right = .rounded,
			bottom_left = .rounded,
			bottom_right = .rounded,
		},
		color_provider,
	)
}




compute_rounded_corners_points:: proc(canvas: ^Canvas,
	position: ElementPosition,
	w, h, radius: f32,
	corners: Corners,
    points: ^[dynamic]Point) -> Point {
    push_rounded_corner :: proc(
		vertices: ^[dynamic]Point,
		start_angle, x, y: f32,
		r: f32,
		corner_segment_counts: f32 = 8,

	) {
		fcorner_segment_counts := f32(corner_segment_counts)
		pi: f32 = math.PI
		half_pi := 0.5 * pi
		origin := sdl3.FPoint{}
		for i in 0 ..< corner_segment_counts {
			theta := start_angle + (f32(i) * half_pi / fcorner_segment_counts)
			point_x := math.round(x + r * math.cos_f32(theta))
			point_y := math.round(y + r * math.sin_f32(theta))


			point := Point{point_x, point_y}
			append(vertices, point)
		}
	}

	push_pixel_corner2 :: proc(
		vertices: ^[dynamic]Point,
		forward: bool,
		ir: i32,
		x, y: f32,
		dx, dy: f32
	) {
		origin := sdl3.FPoint{}
		layout := get_pixel_art_corner(ir)
		if forward {
			for pt in layout {
				point_x := x + dx * f32(pt.x)
				point_y := y + dy * f32(pt.y)
				point := Point{point_x, point_y}
				append(vertices, point)
			}
		} else {
			#reverse for pt in layout {
				point_x := x + dx * f32(pt.x)
				point_y := y + dy * f32(pt.y)
				point := Point{point_x, point_y}

				append(vertices, point)
			}
		}
	}

	push_pixel_corner :: proc(
		vertices: ^[dynamic]Point,
		forward: bool,
		ir: i32,
		x, y: f32,
		dx, dy: f32,
	) {

		pointA := Point{ x,  y + dy * f32(ir)}
		pointB := Point{x + dx * f32(ir), y}
		

		if forward {
			append(vertices, pointA)
			append(vertices, pointB)
		} else {
        
			append(vertices, pointB)
			append(vertices, pointA)
		}

	}

	push_straight_corner :: proc(
		vertices: ^[dynamic]Point,
		x, y: f32,

	) {
		origin := sdl3.FPoint{}
		point_x := math.round(x)
		point_y := math.round(y)
		point := Point{point_x, point_y}
		append(vertices, point)
	}


	abs_pos := compute_element_position(
		position,
		w,
		h,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
	)
	x := math.round(abs_pos.x)
	y := math.round(abs_pos.y)

	r := radius


	origin := sdl3.FPoint{}
	//color := sdl3.FColor { f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) /255.0, f32(color.a) / 255.0}
	pi: f32 = math.PI
	half_pi := 0.5 * pi
	forward :: true
	corner_segment_counts := 8 // establish this based on the size of radius
	fcorner_segment_counts := f32(corner_segment_counts)

	if corners.top_left == .rounded_pixel && radius <= 6 {
		push_pixel_corner(points, forward, i32(radius), x, y, 1, 1)

	} else if corners.top_left == .rounded || corners.top_left == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			points,
			pi,
			x + r,
			y + r,
			r,
			fcorner_segment_counts,
		)

	} else if corners.top_left == .straight {
		push_straight_corner(points, x, y)
	}

	if corners.top_right == .rounded_pixel && radius <= 6 {
		push_pixel_corner(points, !forward, i32(radius), x + w, y, -1, 1)

	} else if corners.top_right == .rounded || corners.top_right == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			points,
			-half_pi,
			x + w - r,
			y + r,
			r,
			fcorner_segment_counts
		)

	} else if corners.top_right == .straight {
		push_straight_corner(points, x+w, y)
	}

	if corners.bottom_right == .rounded_pixel && radius <= 6 {
		push_pixel_corner(
			points,
			forward,
			i32(radius),
			x + w,
			y + h,
	
			-1,
			-1,
	
		)

	} else if corners.bottom_right == .rounded ||
	   corners.bottom_right == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			points,
			0,
			x + w - r,
			y + h - r,
			r,
			fcorner_segment_counts
		)

	} else if corners.bottom_right == .straight {
		push_straight_corner(points, x+w, y+h)
	}

	if corners.bottom_left == .rounded_pixel && radius <= 6 {
		push_pixel_corner(points, !forward, i32(radius), x, y + h, 1, -1)

	} else if corners.bottom_left == .rounded ||
	   corners.bottom_left == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			points,
			half_pi,
			x + r,
			y + h - r,
			r,
			fcorner_segment_counts,
		)

	} else if corners.bottom_left == .straight {
		push_straight_corner(points, x, y+h)
	}

    return Point { x, y }
}

fill_rounded_corners :: proc(
	canvas: ^Canvas,
	position: ElementPosition,
	w, h, radius: f32,
	corners: Corners,
	color_provider: ColorProvider,
) {

	if radius <= 0 {

		fill_rect(canvas, position, w, h, color_provider)
	}

	push_rounded_corner :: proc(
		vertices: ^[dynamic]sdl3.Vertex,
		start_angle, x, y, ox, oy: f32,
		r: f32,
		corner_segment_counts: f32 = 8,
		w, h: f32,
		color_provider: ColorProvider,
	) {
		fcorner_segment_counts := f32(corner_segment_counts)
		pi: f32 = math.PI
		half_pi := 0.5 * pi
		origin := sdl3.FPoint{}
		for i in 0 ..< corner_segment_counts {
			theta := start_angle + (f32(i) * half_pi / fcorner_segment_counts)
			point_x := math.round(x + r * math.cos_f32(theta))
			point_y := math.round(y + r * math.sin_f32(theta))


			point := sdl3.FPoint{point_x, point_y}
			color := compute_fcolor_from_screen_fpoint(color_provider, point, ox, oy, w, h)
			vertex := sdl3.Vertex{point, color, origin}
			append(vertices, vertex)
		}
	}

	push_pixel_corner2 :: proc(
		vertices: ^[dynamic]sdl3.Vertex,
		forward: bool,
		ir: i32,
		x, y, w, h: f32,
		dx, dy: f32,
		color_provider: ColorProvider,
	) {
		origin := sdl3.FPoint{}
		layout := get_pixel_art_corner(ir)
		if forward {
			for pt in layout {
				point_x := x + dx * f32(pt.x)
				point_y := y + dy * f32(pt.y)
				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(vertices, vertex)
			}
		} else {
			#reverse for pt in layout {
				point_x := x + dx * f32(pt.x)
				point_y := y + dy * f32(pt.y)
				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(vertices, vertex)
			}
		}
	}

	push_pixel_corner :: proc(
		vertices: ^[dynamic]sdl3.Vertex,
		forward: bool,
		ir: i32,
		x, y, ox, oy, w, h: f32,
		dx, dy: f32,
		color_provider: ColorProvider,
	) {
		origin := sdl3.FPoint{}
		vertexA, vertexB: sdl3.Vertex
		{
			point_x := x
			point_y := y + dy * f32(ir)
			point := sdl3.FPoint{point_x, point_y}
			color := compute_fcolor_from_screen_fpoint(color_provider, point, ox, oy, w, h)
			vertexA = sdl3.Vertex{point, color, origin}
		}


		{
			point_x := x + dx * f32(ir)
			point_y := y
			point := sdl3.FPoint{point_x, point_y}
			color := compute_fcolor_from_screen_fpoint(color_provider, point, ox, oy, w, h)
			vertexB = sdl3.Vertex{point, color, origin}


		}
		if forward {
            fmt.printfln("vertexA:%v", vertexA.position)
            fmt.printfln("vertexB:%v", vertexB.position)
			append(vertices, vertexA)
			append(vertices, vertexB)
		} else {
             fmt.printfln("vertexA:%v", vertexB.position)
            fmt.printfln("vertexB:%v", vertexA.position)
			append(vertices, vertexB)
			append(vertices, vertexA)
		}

	}

	push_straight_corner :: proc(
		vertices: ^[dynamic]sdl3.Vertex,
		x, y, ox, oy,  w, h: f32,
		color_provider: ColorProvider,
	) {
		origin := sdl3.FPoint{}
		point_x := math.round(x)
		point_y := math.round(y)
		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, ox, oy, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(vertices, vertex)
	}


	abs_pos := compute_element_position(
		position,
		w,
		h,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
	)
	x := math.round(abs_pos.x)
	y := math.round(abs_pos.y)

	r := radius
	vertices := make([dynamic]sdl3.Vertex)
	indices := make([dynamic]i32)
	defer delete(vertices)
	defer delete(indices)

	origin := sdl3.FPoint{}
	//color := sdl3.FColor { f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) /255.0, f32(color.a) / 255.0}
	pi: f32 = math.PI
	half_pi := 0.5 * pi
	forward :: true
	corner_segment_counts := 8 // establish this based on the size of radius
	fcorner_segment_counts := f32(corner_segment_counts)

	center_point := sdl3.FPoint{x + w / 2.0, y + h / 2.0}

	center_color := compute_fcolor(color_provider, UPOIMT_CENTER)
	center_vertex := sdl3.Vertex{center_point, center_color, origin}
	append(&vertices, center_vertex)

	if corners.top_left == .rounded_pixel && radius <= 6 {
		push_pixel_corner(&vertices, forward, i32(radius), x, y, x, y, w, h, 1, 1, color_provider)

	} else if corners.top_left == .rounded || corners.top_left == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			&vertices,
			pi,
			x + r,
			y + r,
            x, y,
			r,
			fcorner_segment_counts,
			w,
			h,
			color_provider,
		)

	} else if corners.top_left == .straight {
		push_straight_corner(&vertices, x, y,  x, y, w, h, color_provider)
	}

	if corners.top_right == .rounded_pixel && radius <= 6 {
		push_pixel_corner(&vertices, !forward, i32(radius), x + w, y, x, y, w, h, -1, 1, color_provider)

	} else if corners.top_right == .rounded || corners.top_right == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			&vertices,
			-half_pi,
			x + w - r,
			y + r,
             x, y,
			r,
			fcorner_segment_counts,
			w,
			h,
			color_provider,
		)

	} else if corners.top_right == .straight {
		push_straight_corner(&vertices, x + w, y, x, y, w, h, color_provider)
	}

	if corners.bottom_right == .rounded_pixel && radius <= 6 {
		push_pixel_corner(
			&vertices,
			forward,
			i32(radius),
			x + w,
			y + h,
             x, y,
			w,
			h,
			-1,
			-1,
			color_provider,
		)

	} else if corners.bottom_right == .rounded ||
	   corners.bottom_right == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			&vertices,
			0,
			x + w - r,
			y + h - r,
             x, y,
			r,
			fcorner_segment_counts,
			w,
			h,
			color_provider,
		)

	} else if corners.bottom_right == .straight {
		push_straight_corner(&vertices, x+w, y+h,  x, y, w, h, color_provider)
	}

	if corners.bottom_left == .rounded_pixel && radius <= 6 {
		push_pixel_corner(&vertices, !forward, i32(radius), x, y + h, x, y, w, h, 1, -1, color_provider)

	} else if corners.bottom_left == .rounded ||
	   corners.bottom_left == .rounded_pixel && radius <= 6 {

		push_rounded_corner(
			&vertices,
			half_pi,
			x + r,
			y + h - r,
             x, y,
			r,
			fcorner_segment_counts,
			w,
			h,
			color_provider,
		)

	} else if corners.bottom_left == .straight {
		push_straight_corner(&vertices, x, y+h, x, y, w, h, color_provider)
	}
    fmt.printfln("vertices:%v", vertices)

	vertex_count := (len(vertices))
	last_vertex_index := vertex_count - 1
	for vertex, index in vertices {
		append(&indices, 0)
		append(&indices, i32(index))
		if index == last_vertex_index {
			append(&indices, 1)
		} else {
			append(&indices, i32(index + 1))
		}
	}
    push_gpu_command(canvas, vertices[:], indices[:], nil)
	/*sdl3.RenderGeometry(
		canvas.res.renderer,
		nil,
		raw_data(vertices),
		i32(vertex_count),
		raw_data(indices),
		i32(len(indices)),
	)*/
}


fill_rounded_corners_pixel_art :: proc(
	canvas: ^Canvas,
	position: ElementPosition,
	w, h, radius: f32,
	corners: Corners,
	color_provider: ColorProvider,
) {

	if radius <= 0 ||
	   (corners.top_left != .rounded &&
			   corners.top_right != .rounded &&
			   corners.bottom_left != .rounded &&
			   corners.bottom_right != .rounded) {
		fill_rect(canvas, position, w, h, color_provider)
	}
	if radius > 6 {
		fill_rounded_corners(canvas, position, w, h, radius, corners, color_provider)
	}

	abs_pos := compute_element_position(
		position,
		w,
		h,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
	)
	x := math.round(abs_pos.x)
	y := math.round(abs_pos.y)

	r := radius
	ir := i32(math.round(r)) // Convert to integer for the lookup table checks

	vertices := make([dynamic]sdl3.Vertex)
	indices := make([dynamic]i32)
	defer delete(vertices)
	defer delete(indices)

	origin := sdl3.FPoint{}
	pi: f32 = math.PI
	half_pi := 0.5 * pi
	corner_segment_counts := 8
	fcorner_segment_counts := f32(corner_segment_counts)

	center_point := sdl3.FPoint{x + w / 2.0, y + h / 2.0}

	center_color := compute_fcolor(color_provider, UPOIMT_CENTER)
	center_vertex := sdl3.Vertex{center_point, center_color, origin}
	append(&vertices, center_vertex)

	// --- TOP LEFT CORNER ---
	if corners.top_left == .rounded {
		if ir > 0 && ir <= 6 {
			layout := get_pixel_art_corner(ir)
			for pt in layout {
				point_x := x + f32(pt.x)
				point_y := y + f32(pt.y)
				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(&vertices, vertex)
			}
		}
	} else if corners.top_left == .straight {
		point_x := math.round(x)
		point_y := math.round(y)
		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	// --- TOP RIGHT CORNER ---
	if corners.top_right == .rounded {
		if ir > 0 && ir <= 6 {
			layout := get_pixel_art_corner(ir)
			#reverse for pt in layout {
				point_x := x + w - f32(pt.x)
				point_y := y + f32(pt.y)
				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(&vertices, vertex)
			}
		} else {
			for i in 0 ..< corner_segment_counts {
				theta := -half_pi + (f32(i) * half_pi / fcorner_segment_counts)
				point_x := math.round(x + w - r + r * math.cos_f32(theta))
				point_y := math.round(y + r + r * math.sin_f32(theta))

				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(&vertices, vertex)
			}
		}
	} else if corners.top_right == .straight {
		point_x := math.round(x + w)
		point_y := math.round(y)
		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	// --- BOTTOM RIGHT CORNER ---
	if corners.bottom_right == .rounded {
		if ir > 0 && ir <= 6 {
			layout := get_pixel_art_corner(ir)
			for pt in layout {
				point_x := x + w - f32(pt.x)
				point_y := y + h - f32(pt.y)
				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(&vertices, vertex)
			}
		} else {
			for i in 0 ..< corner_segment_counts {
				theta := 0 + (f32(i) * half_pi / fcorner_segment_counts)
				point_x := math.round(x + w - r + r * math.cos_f32(theta))
				point_y := math.round(y + h - r + r * math.sin_f32(theta))

				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(&vertices, vertex)
			}
		}
	} else if corners.bottom_right == .straight {
		point_x := math.round(x + w)
		point_y := math.round(y + h)
		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	// --- BOTTOM LEFT CORNER ---
	if corners.bottom_left == .rounded {
		if ir > 0 && ir <= 6 {
			layout := get_pixel_art_corner(ir)
			#reverse for pt in layout {
				point_x := x + f32(pt.x)
				point_y := y + h - f32(pt.y)
				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(&vertices, vertex)
			}
		} else {
			for i in 0 ..< corner_segment_counts {
				theta := half_pi + (f32(i) * half_pi / fcorner_segment_counts)
				point_x := math.round(x + r + r * math.cos_f32(theta))
				point_y := math.round(y + h - r + r * math.sin_f32(theta))

				point := sdl3.FPoint{point_x, point_y}
				color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
				vertex := sdl3.Vertex{point, color, origin}
				append(&vertices, vertex)
			}
		}
	} else if corners.bottom_left == .straight {
		point_x := math.round(x)
		point_y := math.round(y + h)
		point := sdl3.FPoint{point_x, point_y}
		color := compute_fcolor_from_screen_fpoint(color_provider, point, x, y, w, h)
		vertex := sdl3.Vertex{point, color, origin}
		append(&vertices, vertex)
	}

	vertex_count := (len(vertices))
	last_vertex_index := vertex_count - 1
	for vertex, index in vertices {
		append(&indices, 0)
		append(&indices, i32(index))
		if index == last_vertex_index {
			append(&indices, 1)
		} else {
			append(&indices, i32(index + 1))
		}
	}
      push_gpu_command(canvas, vertices[:], indices[:], nil)
	/*sdl3.RenderGeometry(
		canvas.res.renderer,
		nil,
		raw_data(vertices),
		i32(vertex_count),
		raw_data(indices),
		i32(len(indices)),
	)*/
}


destroy_command :: proc(cmd: GPU_Canvas_Command) {
	if cmd.text != nil && cmd.is_text_owned {
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
