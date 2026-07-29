
package canvas
import "vendor:sdl3"
DEFAULT_COLOR :: Color{}

COLOR_BLUE :: Color { 30, 30, 220, 255 }
COLOR_GREEN :: Color { 30, 220, 30, 255 }
COLOR_RED :: Color { 220, 30, 30, 255 }
COLOR_YELLOW :: Color { 220, 220, 30, 255 }
COLOR_BLACK ::  Color { 0, 0, 0, 255 }
COLOR_WHITE ::  Color { 255, 255, 255, 255 }

UPOIMT_ORIGIN:: UPoint { 0, 0 }
UPOIMT_CENTER:: UPoint { 0.5, 0.5 }
UPOIMT_MAX:: UPoint { 1, 1 }
// x and y are in 0..1
UPoint:: struct {
    x: f32,
    y: f32
}


Color :: struct {
    r,g,b,a: u8
}

CornerGradient :: struct {
    top_left: Color,
    top_right: Color,
    bottom_left: Color,
    bottom_right: Color
}

ColorProvider:: union {
    Color, CornerGradient
}

create_constant_color_provider :: proc(color: Color) -> ColorProvider {
    return  color
}

create_corner_gradient_color_provider :: proc(top_left: Color, top_right: Color, bottom_left: Color, bottom_right: Color ) -> ColorProvider {
    return CornerGradient { top_left = top_left, top_right = top_right, bottom_left = bottom_left, bottom_right = bottom_right}
}


compute_color:: proc(color_data: ColorProvider, pt: UPoint)  -> Color {
    result_color := DEFAULT_COLOR
    switch v in color_data {
        case Color:
            result_color = v 
        case CornerGradient:
            result_color = compute_corner_gradient_color(v, pt)
    }

    return result_color
}

compute_corner_gradient_color :: proc(gradient: CornerGradient, pt: UPoint) -> Color {

    u_left := 1 - pt.x 
    u_right := pt.x
    v_top := 1 - pt.y
    v_bottom := pt.y

    r := u_left * v_top * f32(gradient.top_left.r) + u_right * v_top * f32(gradient.top_right.r)  + u_left * v_bottom * f32(gradient.bottom_left.r)  + u_right * v_bottom * f32(gradient.bottom_right.r) 
    g := u_left * v_top * f32(gradient.top_left.g) + u_right * v_top * f32(gradient.top_right.g)  + u_left * v_bottom * f32(gradient.bottom_left.g)  + u_right * v_bottom * f32(gradient.bottom_right.g) 
    b := u_left * v_top * f32(gradient.top_left.b) + u_right * v_top * f32(gradient.top_right.b)  + u_left * v_bottom * f32(gradient.bottom_left.b)  + u_right * v_bottom * f32(gradient.bottom_right.b) 
    a := u_left * v_top * f32(gradient.top_left.a) + u_right * v_top * f32(gradient.top_right.a)  + u_left * v_bottom * f32(gradient.bottom_left.a)  + u_right * v_bottom * f32(gradient.bottom_right.a) 


    return Color { r = u8(r), g = u8(g), b = u8(b), a = u8(a)}
}


compute_fcolor :: proc(color_data: ColorProvider, pt: UPoint) -> sdl3.FColor {
    r := compute_color(color_data, pt)
    c := sdl3.FColor { f32(r.r) / 255.0, f32(r.g) / 255.0, f32(r.b) / 255.0, f32(r.a) / 255.0}
    return c
}

compute_fcolor_from_screen_fpoint :: proc(color_data: ColorProvider, fpt: sdl3.FPoint, x,y, w, h: f32) -> sdl3.FColor {
    pt := UPoint { ( fpt[0] - x )/ w, (fpt[1] - y )/ h }
    r := compute_color(color_data, pt)
    c := sdl3.FColor { f32(r.r) / 255.0, f32(r.g) / 255.0, f32(r.b) / 255.0, f32(r.a) / 255.0}
    return c
}
