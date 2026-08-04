
package canvas
import "core:math"
import "vendor:sdl3"
import "vendor:vulkan"
DEFAULT_COLOR :: Color{}

COLOR_BLUE :: Color{30, 30, 220, 255}
COLOR_GREEN :: Color{30, 220, 30, 255}
COLOR_RED :: Color{220, 30, 30, 255}
COLOR_YELLOW :: Color{220, 220, 30, 255}
COLOR_BLACK :: Color{0, 0, 0, 255}
COLOR_WHITE :: Color{255, 255, 255, 255}


Color :: struct {
	r, g, b, a: u8,
}


CornerGradient :: struct {
	top_left:     Color,
	top_right:    Color,
	bottom_left:  Color,
	bottom_right: Color,
}

ColorUPointTuple:: struct {
    color: Color, 
    upoint: UPoint
}

Linear2Gradient :: struct {
	begin: ColorUPointTuple,
    end: ColorUPointTuple
}

ColorProvider :: union {
	Color,
	CornerGradient,
	Linear2Gradient,
}

create_constant_color_provider :: proc(color: Color) -> ColorProvider {
	return color
}

create_corner_gradient_color_provider :: proc(
	top_left: Color,
	top_right: Color,
	bottom_left: Color,
	bottom_right: Color,
) -> ColorProvider {
	return CornerGradient {
		top_left = top_left,
		top_right = top_right,
		bottom_left = bottom_left,
		bottom_right = bottom_right,
	}
}

create_linear_2_points_gradient_color_provider :: proc(
	pointA: UPoint,
	colorA: Color,
	pointB: UPoint,
	colorB: Color,
) -> ColorProvider { 

    begin := ColorUPointTuple { colorA, pointA } 
    end := ColorUPointTuple { colorB, pointB} 

	return Linear2Gradient { begin = begin, end = end }
}

compute_color :: proc(color_data: ColorProvider, pt: UPoint) -> Color {
	result_color := DEFAULT_COLOR
	switch v in color_data {
	case Color:
		result_color = v
	case CornerGradient:
		result_color = compute_corner_gradient_color(v, pt)
	case Linear2Gradient:
		result_color = compute_linear_2_gradient_color(v, pt)
	}

	return result_color
}
compute_linear_2_gradient_color :: proc(gradient: Linear2Gradient, pt: UPoint) -> Color {
	
    v_x := gradient.end.upoint.x  - gradient.begin.upoint.x 
    v_y := gradient.end.upoint.y  - gradient.begin.upoint.y 

    projected_x := pt.x - gradient.begin.upoint.x 
    projected_y := pt.y - gradient.begin.upoint.y

    v_squared_length := v_x*v_x + v_y*v_y
    interpolation := (v_x * projected_x + v_y * projected_y) / v_squared_length
    interpolation = clamp(interpolation, 0, 1)
    r := (1-interpolation) * f32(gradient.begin.color.r) + interpolation * f32(gradient.end.color.r)
    g := (1-interpolation) * f32(gradient.begin.color.g) + interpolation * f32(gradient.end.color.g)
    b := (1-interpolation) * f32(gradient.begin.color.b) + interpolation * f32(gradient.end.color.b)
    a := (1-interpolation) * f32(gradient.begin.color.a) + interpolation * f32(gradient.end.color.a)

	return Color{r = u8(r), g = u8(g), b = u8(b), a = u8(a)}
}

distance::proc(pA: UPoint, pB: UPoint) -> f32 {
    dx := pA.x - pB.x
    dy := pA.y - pB.y 
    return math.sqrt( dx*dx + dy*dy )
}

mix_channel :: proc(v, h: f32, channel_V_A, channel_V_B, channel_H_A, channel_H_B: u8) -> f32 {
	vp := 1 - v
	hp := 1 - h

	return(
		v * f32(channel_V_A) +
		vp * f32(channel_V_B) +
		h * f32(channel_H_A) +
		hp * f32(channel_H_B) \
	)

}

compute_corner_gradient_color :: proc(gradient: CornerGradient, pt: UPoint) -> Color {

	u_left := 1 - pt.x
	u_right := pt.x
	v_top := 1 - pt.y
	v_bottom := pt.y

	r :=
		u_left * v_top * f32(gradient.top_left.r) +
		u_right * v_top * f32(gradient.top_right.r) +
		u_left * v_bottom * f32(gradient.bottom_left.r) +
		u_right * v_bottom * f32(gradient.bottom_right.r)
	g :=
		u_left * v_top * f32(gradient.top_left.g) +
		u_right * v_top * f32(gradient.top_right.g) +
		u_left * v_bottom * f32(gradient.bottom_left.g) +
		u_right * v_bottom * f32(gradient.bottom_right.g)
	b :=
		u_left * v_top * f32(gradient.top_left.b) +
		u_right * v_top * f32(gradient.top_right.b) +
		u_left * v_bottom * f32(gradient.bottom_left.b) +
		u_right * v_bottom * f32(gradient.bottom_right.b)
	a :=
		u_left * v_top * f32(gradient.top_left.a) +
		u_right * v_top * f32(gradient.top_right.a) +
		u_left * v_bottom * f32(gradient.bottom_left.a) +
		u_right * v_bottom * f32(gradient.bottom_right.a)


	return Color{r = u8(r), g = u8(g), b = u8(b), a = u8(a)}
}


compute_fcolor :: proc(color_data: ColorProvider, pt: UPoint) -> sdl3.FColor {
	r := compute_color(color_data, pt)
	c := sdl3.FColor{f32(r.r) / 255.0, f32(r.g) / 255.0, f32(r.b) / 255.0, f32(r.a) / 255.0}
	return c
}

compute_fcolor_from_screen_fpoint :: proc(
	color_data: ColorProvider,
	fpt: sdl3.FPoint,
	x, y, w, h: f32,
) -> sdl3.FColor {
	pt := UPoint{(fpt[0] - x) / w, (fpt[1] - y) / h}
	r := compute_color(color_data, pt)
	c := sdl3.FColor{f32(r.r) / 255.0, f32(r.g) / 255.0, f32(r.b) / 255.0, f32(r.a) / 255.0}
	return c
}
