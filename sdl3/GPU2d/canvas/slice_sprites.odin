
package canvas

import "vendor:sdl3"


NineSliceSprite:: struct {
    atlas_position: Point,
    size: Size,
    border_left: f32,
    border_right: f32,
    border_top: f32,
    border_bottom: f32
}


draw_nine_slice_sprite:: proc(canvas: ^Canvas, position: ElementPosition, size: Size, atlas_texture: TextureHandle, slices: NineSliceSprite ) {
    abs_position := compute_element_position(position, size.w, size.h, f32(canvas.res.canvas_width), f32(canvas.res.canvas_height))
    x := abs_position.x
    y := abs_position.y 
    rx := x + size.w 
    ry := y+ size.h

    full_atlas_size := Size { f32(atlas_texture.w), f32(atlas_texture.h) }
    left_width := slices.border_left
    top_height := slices.border_top
    

    uv_tile_begin_x := slices.atlas_position.x 
    uv_tile_size_w := (slices.border_left)

    uv_tile_begin_y := slices.atlas_position.x
    uv_tile_size_h := (slices. border_top) 

    // middle_center stretches in both directions
    mid_w := size.w - slices.border_left - slices.border_right
    mid_h := size.h - slices.border_bottom - slices.border_top
    uv_mid_x := slices.border_left + slices.atlas_position.x 
    uv_mid_y := slices.border_right + slices.atlas_position.y
    uv_mid_w := slices.size.w - slices.border_right - slices.border_left
    uv_mid_h := slices.size.h - slices.border_top - slices.border_bottom

    mid_uv_offset :: -1
    draw_slice(canvas, {x + slices.border_left, y + slices.border_top}, {mid_w, mid_h}, {uv_mid_x+mid_uv_offset, uv_mid_y+mid_uv_offset}, {uv_mid_w-2*mid_uv_offset, uv_mid_h-2*mid_uv_offset}, full_atlas_size, atlas_texture)


    // top-left (quad same size as slice)
    draw_slice(canvas, {x, y}, {left_width, top_height}, {uv_tile_begin_x, uv_tile_begin_y}, {uv_tile_size_w, uv_tile_size_h}, full_atlas_size, atlas_texture)

    // top-right (quad same size as slice)
    right_x := rx - slices.border_right
    uv_tile_begin_right := uv_tile_begin_x + slices.size.w - slices.border_right + 1
    draw_slice(canvas, {right_x, y}, {slices.border_right, slices.border_top}, {uv_tile_begin_right, uv_tile_begin_y}, {slices.border_right, slices.border_top}, full_atlas_size, atlas_texture)

    // bottom-right (quad same size as slice)
    bottom_y := ry - slices.border_bottom
    uv_tile_begin_bottom :=  uv_tile_begin_y + slices.size.h - slices.border_bottom + 1
 
    draw_slice(canvas, {right_x, bottom_y}, {slices.border_right, slices.border_bottom}, {uv_tile_begin_right, uv_tile_begin_bottom}, {slices.border_right, slices.border_bottom}, full_atlas_size, atlas_texture)

    // bottom-left (quad same size as slice)
    draw_slice(canvas, {x, bottom_y}, {slices.border_left, slices.border_bottom}, {uv_tile_begin_x, uv_tile_begin_bottom}, {slices.border_left, slices.border_bottom}, full_atlas_size, atlas_texture)


    // middle-left quad stretches vertically

    draw_slice(canvas, {x, y + top_height}, {slices.border_left, mid_h}, {uv_tile_begin_x, uv_mid_y}, {slices.border_left, uv_mid_h}, full_atlas_size, atlas_texture)


    // middle-right quad stretches vertically
    draw_slice(canvas, {right_x, y + top_height}, {slices.border_right, mid_h}, {uv_tile_begin_right, uv_mid_y}, {slices.border_right, uv_mid_h}, full_atlas_size, atlas_texture)

    // top-center quad stretches horizontally
  
    draw_slice(canvas, {x + slices.border_left, y}, {mid_w, slices.border_top}, {uv_mid_x, uv_tile_begin_y}, {uv_mid_w,  slices.border_top}, full_atlas_size, atlas_texture)
    
    // bottom-center quad stretches horizontally
    draw_slice(canvas, {x+left_width, bottom_y}, {mid_w, slices.border_bottom}, {uv_mid_x, uv_tile_begin_bottom}, {uv_mid_w, slices.border_bottom}, full_atlas_size, atlas_texture)
    
}

@private 
draw_slice::proc(canvas: ^Canvas, quad_position:Point, quad_size:Size, atlas_position: Point, atlas_tile_size: Size, atlas_size: Size, atlas_texture: TextureHandle) {
    x := quad_position.x
    y := quad_position.y
    w := quad_size.w
    h := quad_size.h
    quad_points :[4]Point = { {x, y}, {x + w, y}, {x + w, y + h}, {x, y + h} }

    uv_ax := (atlas_position.x + 0.5) / atlas_size.w
    uv_ay := (atlas_position.y + 0.5) / atlas_size.h
    uv_aw := (atlas_tile_size.w - 0.5) / atlas_size.w
    uv_ah := (atlas_tile_size.h - 0.5) / atlas_size.h
    uv_points :[4]Point = { {uv_ax, uv_ay}, {uv_ax + uv_aw, uv_ay}, { uv_ax + uv_aw, uv_ay + uv_ah}, {uv_ax, uv_ay + uv_ah}} 
    absolute_quad(canvas, quad_points, uv_points, COLOR_WHITE, atlas_texture)
}