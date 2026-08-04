package canvas

import "core:fmt"
import "core:math"
import "core:strings"

import vmem "core:mem/virtual"

import "vendor:sdl3"
import "vendor:sdl3/ttf"


// structs

ScalableFont :: struct {
	sdl_font:  ^ttf.Font,
	base_size: f32,
	padding_x: f32,
	padding_y: f32,
	// scaling: f32,
	is_sdf:    bool,
}


bounds_2d :: struct {
	min_x, min_y, max_x, max_y: f32,
}

Realized_Text :: struct {
	text:      ^ttf.Text,
	scaling:   f32,
	padding_x: f32,
	padding_y: f32,
	is_sdf:    bool,
    is_empty: bool
}

// constants

INFINITE_SIZE_DIM: f32 : math.INF_F32

// procs
create_realized_text_line :: proc(
	canvas: ^Canvas,
	font: ScalableFont,
	position: ElementPosition,
	text_size: f32,
	text: string,
) -> Realized_Text {
	text := ttf.CreateText(canvas.text_engine, font.sdl_font, cstring(raw_data(text)), len(text))
	fmt.assertf(text != nil, "Creating SDL TTF Text Object failed: %s\n", sdl3.GetError())

	scaling := f32(text_size) / f32(font.base_size)
	return Realized_Text {
		text = text,
		scaling = scaling,
		padding_x = font.padding_x,
		padding_y = font.padding_y,
		is_sdf = font.is_sdf,
	}
}

create_realized_text_block :: proc(
	canvas: ^Canvas,
	font: ScalableFont,
	size: Size,
	text_size: f32,
	text: string,
) -> Realized_Text {
	text_obj := ttf.CreateText(
		canvas.text_engine,
		font.sdl_font,
		cstring(raw_data(text)),
		len(text),
	)
	fmt.assertf(text_obj != nil, "Creating SDL TTF Text Object failed: %s\n", sdl3.GetError())
	scaling := f32(text_size) / f32(font.base_size)

	max_width, max_height: f32 = INFINITE_SIZE_DIM, INFINITE_SIZE_DIM
	if size.w != INFINITE_SIZE_DIM {
		max_width = size.w / scaling
		wrap_width: i32 = i32(max_width)
		ttf.SetTextWrapWidth(text_obj, wrap_width)
	}
	if size.h != INFINITE_SIZE_DIM {
		max_height = size.h / scaling
	}
    new_length: uint = len(text)
    is_empty := new_length == 0

	w, h: i32
	ttf.GetTextSize(text_obj, &w, &h)
	if !is_empty && (f32(h) > max_height || f32(w) > max_width) {

			buf := make([]u8, len(text))
			defer delete(buf)

			// Copy the text into our buffer and manually null-terminate it
			copy(buf[:len(text)], text)
			cbuf := cstring(&buf[0])


			character_remove: uint = 0
			for (f32(h) > max_height || f32(w) > max_width) && new_length > 0 {
				new_length -= 1
				if new_length > 3 {
					buf[new_length - 1] = '.'
					buf[new_length - 2] = '.'
					buf[new_length - 3] = '.'
				} else {
					new_length = 0
					buf[0] = 0
                    is_empty = true
                    ttf.DestroyText(text_obj)
                    text_obj = nil
				}


				ttf.SetTextString(text_obj, cbuf, new_length)
				ttf.GetTextSize(text_obj, &w, &h)
			}
		
	}

	return Realized_Text {
		text = text_obj,
		scaling = scaling,
		padding_x = font.padding_x,
		padding_y = font.padding_y,
		is_sdf = font.is_sdf,
        is_empty = is_empty
	}
}

destroy_realized_text :: proc(realized_text: ^Realized_Text) {
	ttf.DestroyText(realized_text.text)
}

measure_realized_text :: proc(canvas: ^Canvas, realized_text: Realized_Text) -> Size {
	w, h: i32
	ttf.GetTextSize(realized_text.text, &w, &h)
	scaling := realized_text.scaling
	return Size{w = f32(w) * scaling, h = f32(h) * scaling}
}

compute_max_glyph_height :: proc (font: ScalableFont, size: f32) -> f32 {
    //int TTF_GetFontHeight(const TTF_Font *font);
    scaling := f32(size) / f32(font.base_size)
    return f32(ttf.GetFontHeight(font.sdl_font)) * scaling
}

load_scalable_font :: proc(canvas: ^Canvas, path: string, size_hint :f32= 28, use_sdf:bool=true) -> ScalableFont {
	constant_size : = size_hint
    use_sdf := use_sdf // true
	calibration_text_string: cstring : "e"
	arena: vmem.Arena

	err := vmem.arena_init_growing(&arena)
	assert(err == nil)
	defer vmem.arena_destroy(&arena)

	arena_alloc := vmem.arena_allocator(&arena)


	cpath := strings.clone_to_cstring(path, arena_alloc)

	font := ttf.OpenFont(cpath, constant_size)

	fmt.assertf(font != nil, "load ttf font: %s\n", sdl3.GetError())

	calibration_text := ttf.CreateText(canvas.text_engine, font, calibration_text_string, 0)
	defer ttf.DestroyText(calibration_text)

	plain_sequences := ttf.GetGPUTextDrawData(calibration_text)
	plain_bounds := compute_text_sequence_bounds(plain_sequences)

	

	success := ttf.SetFontSDF(font, use_sdf)
	assert(success)

	sdf_sequences := ttf.GetGPUTextDrawData(calibration_text)
	sdf_bounds := compute_text_sequence_bounds(sdf_sequences)

	padding_x :=
		0.5 * ((plain_bounds.max_x - plain_bounds.min_x) - (sdf_bounds.max_x - sdf_bounds.min_x))
	padding_y :=
		0.5 * ((plain_bounds.max_y - plain_bounds.min_y) - (sdf_bounds.max_y - sdf_bounds.min_y))

	return ScalableFont {
		sdl_font = font,
		base_size = constant_size,
		padding_x = padding_x,
		padding_y = padding_y,
		is_sdf = use_sdf,
	}
}

draw_realized_text :: proc(
	canvas: ^Canvas,
	position: ElementPosition,
	realizedText: Realized_Text,
	color_provider: ColorProvider,
) {
    if realizedText.is_empty {
        return
    }
	text := realizedText.text
	scaling := realizedText.scaling
	is_sdf := realizedText.is_sdf
	padding_x := realizedText.padding_x
	padding_y := realizedText.padding_y

	//ttf.SetTextPosition(text, i32(x), i32(y))
	sequences := ttf.GetGPUTextDrawData(text)
	fmt.assertf(sequences != nil, "Font sequence failed to generate vertices.\n")


	bounds := compute_text_sequence_bounds(sequences)

	position := compute_element_position(
		position,
		scaling * ((bounds.max_x - bounds.min_x) + 2 * padding_x),
		scaling * ((bounds.max_y - bounds.min_y) + 2 * padding_y),
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
	)
    position.x /= scaling
    position.y /= scaling

	colors := compute_colors_for_sequences(sequences, bounds, color_provider, &canvas.canvas_arena)

	transform := build_text_transform(
		bounds,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
		scaling,
		f32(padding_x) + position.x,
		f32(padding_y) + position.y,
	)


	append(
		&canvas.commands,
		GPU_Canvas_Command {
			text = text,
			atlas_draw_sequence = sequences,
			fragments_global = FragmentsGlobalData{color = {1, 1, 1, 1}, u_weight = -0.02},
			is_sdf = is_sdf,
			is_text_owned = false,
			transform_matrix = transform,
            colors = colors
		},
	)
}

draw_text_line :: proc(
	canvas: ^Canvas,
	font: ScalableFont,
	position: ElementPosition,
	text_size: f32,
	text: string,
	color_provider: ColorProvider,
) {
	text := ttf.CreateText(canvas.text_engine, font.sdl_font, cstring(raw_data(text)), len(text))
	fmt.assertf(text != nil, "Creating SDL TTF Text Object failed: %s\n", sdl3.GetError())

	scaling := f32(text_size) / f32(font.base_size)

	//ttf.SetTextPosition(text, i32(x), i32(y))
	sequences := ttf.GetGPUTextDrawData(text)
	fmt.assertf(sequences != nil, "Font sequence failed to generate vertices.\n")


	bounds := compute_text_sequence_bounds(sequences)

	position := compute_element_position(
		position,
		(bounds.max_x - bounds.min_x) + 2 * font.padding_x,
		(bounds.max_y - bounds.min_y) + 2 * font.padding_y,
		f32(canvas.res.canvas_width) / scaling,
		f32(canvas.res.canvas_height) / scaling,
	)

	colors := compute_colors_for_sequences(sequences, bounds, color_provider, &canvas.canvas_arena)

	transform := build_text_transform(
		bounds,
		f32(canvas.res.canvas_width),
		f32(canvas.res.canvas_height),
		scaling,
		f32(font.padding_x) + position.x,
		f32(font.padding_y) + position.y,
	)


	append(
		&canvas.commands,
		GPU_Canvas_Command {
			text = text,
			atlas_draw_sequence = sequences,
			fragments_global = FragmentsGlobalData{color = {1, 1, 1, 1}, u_weight = -0.02},
			is_sdf = font.is_sdf,
			is_text_owned = true,
			transform_matrix = transform,
            colors = colors
		},
	)
}

compute_colors_for_sequences :: proc(
	sequences: ^ttf.GPUAtlasDrawSequence,
	bounds: bounds_2d,
	color_provider: ColorProvider,
	arena: ^vmem.Arena,
) -> [dynamic]sdl3.FColor {
	allocator := vmem.arena_allocator(arena)
	r := make([dynamic]sdl3.FColor, allocator)
	for seq := sequences; seq != nil; seq = seq.next {
		for i in 0 ..< seq.num_vertices {
			pt := seq.xy[i]
            
            x,y := bounds.min_x, bounds.min_y
            w := bounds.max_x - bounds.min_x
            h := bounds.max_y - bounds.min_y
            upt := UPoint { ( pt.x - x )/ w, 1 - (pt.y - y )/ h }
            upt.x = clamp(upt.x, 0, 1)
            upt.y = clamp(upt.y, 0, 1)
            color := compute_fcolor(color_provider, upt)
			append(&r, color)
		}
	}
	return r
}

compute_text_sequence_bounds :: proc(sequences: ^ttf.GPUAtlasDrawSequence) -> bounds_2d {
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

	//	padding: f32 = 4.0
	//	text_w := (max_x - min_x) + padding * 2
	//	text_h := (max_y - min_y) + padding * 2
	return bounds_2d{min_x = min_x, min_y = min_y, max_x = max_x, max_y = max_y}
}

build_text_transform :: proc(
	bounds: bounds_2d,
	canvas_w, canvas_h: f32,
	scale: f32,
	translate_x, translate_y: f32,
) -> [16]f32 {
	sx := (2.0 / canvas_w) * scale
	sy := (2.0 / canvas_h) * scale

	// Anchor the text's natural top-left (min_x, max_y)
	// directly to the top-left of the canvas (-1.0, 1.0 in NDC)
	tx := -1.0 - ((bounds.min_x - translate_x) * sx)
	ty := 1.0 - ((bounds.max_y + translate_y) * sy)

	return [16]f32{sx, 0.0, 0.0, tx, 0.0, sy, 0.0, ty, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0}
}


render_text :: proc(canvas: ^Canvas) {
	fmt.printfln("Rendering text for %d commands  ", len(canvas.commands))
	device := canvas.res.device
	cmd_buf := sdl3.AcquireGPUCommandBuffer(device)

	bake_target := sdl3.GPUColorTargetInfo {
		texture     = canvas.res.gpu_texture,
		clear_color = sdl3.FColor{1, 0.5, 0.12, 0.0},
		load_op     = .LOAD,
		store_op    = .STORE,
	}

	for command in canvas.commands {
		render_draw_command(device, cmd_buf, &bake_target, canvas.res.drawing_resources, command)

	}

	result := sdl3.SubmitGPUCommandBuffer(cmd_buf)
	fmt.assertf(result, "Could not submit command buffer to GPU: %s\n", sdl3.GetError())


}
