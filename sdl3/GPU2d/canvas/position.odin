package canvas

import "core:math"

UPoint:: struct {
    x: f32,
    y: f32
}


Point:: struct {
    x: f32,
    y: f32
}

//Point :: linalg.Vector2f32

Position:: union {
    UPoint, Point
}

AnchoredPosition :: struct {
    position: Position,
    anchor: Position
}

RelativePosition :: struct {
    anchored_position: AnchoredPosition,
    parent_position: AbsolutePosition,
    parent_size: Size,
}

AbsolutePosition :: union {
    AnchoredPosition, Position
}

ElementPosition :: union {
   AbsolutePosition, RelativePosition
}

Size :: struct {
    w: f32,
    h: f32
}



UPOIMT_ORIGIN:: UPoint { 0, 0 }
UPOIMT_CENTER:: UPoint { 0.5, 0.5 }
UPOIMT_MAX:: UPoint { 1, 1 }
// x and y are in 0..1
POSITION_TOP_LEFT:: Point { 0,0 }
POSITION_TOP_RIGHT:: AnchoredPosition { anchor= UPoint{ 1, 0}, position= UPoint {1, 0}}

POSITION_BOTTOM_LEFT::  AnchoredPosition { anchor= UPoint{ 0, 1}, position= UPoint {0, 1}}
POSITION_BOTTOM_RIGHT:: AnchoredPosition { anchor= UPoint{ 1, 1}, position= UPoint {1, 1}}

POSITION_MIDDLE_LEFT::  AnchoredPosition { anchor= UPoint{ 0, 0.5}, position= UPoint {0, 0.5}}
POSITION_MIDDLE_RIGHT:: AnchoredPosition { anchor= UPoint{ 1, 0.5}, position= UPoint {1, 0.5}}

POSITION_CENTER:: AnchoredPosition { anchor= UPoint{ 0.5, 0.5}, position= UPoint {0.5, 0.5}}

AnchoredPoint :: struct {
    anchor : Position,
    x, y: f32
}

round_point :: proc(pt: Point) -> Point {
    return Point { math.round(pt.x), math.round(pt.y)}
}
to_point :: proc(pt: IPoint) -> Point {
    return Point { f32((pt.x)), f32((pt.y))}
}

to_ipoint :: proc(pt: Point) -> IPoint {
    return IPoint { i32( math.round(pt.x)), i32(math.round(pt.y))}
}


compute_unanchored_position :: proc (element_position: ElementPosition,  container_width, container_height: f32) -> AnchoredPoint {
    switch v in element_position {
        case AbsolutePosition:
            return compute_unanchored_absolute_element_position(v,   container_width, container_height)
        case RelativePosition:
            parent_top_left := compute_absolute_element_position(v.parent_position, v.parent_size.w, v.parent_size.w, container_width, container_height)

            child_relative_top_left := compute_unanchored_absolute_element_position(v.anchored_position,  v.parent_size.w, v.parent_size.h)
            ps := v.parent_size
            return AnchoredPoint { x = child_relative_top_left.x + parent_top_left.x, y = child_relative_top_left.y + parent_top_left.y, anchor = child_relative_top_left.anchor }

    }
    return AnchoredPoint { anchor = UPOIMT_ORIGIN, x = 0, y = 0}


}

compute_unanchored_absolute_element_position:: proc(element_position: AbsolutePosition,  container_width, container_height: f32) -> AnchoredPoint {

    switch v in element_position {
        case Position:
            pt := compute_absolute_position(v, container_width, container_height)
            return AnchoredPoint { anchor = UPOIMT_ORIGIN, x = pt.x, y = pt.y}
  
        case AnchoredPosition:
         
            top_left_element_position := compute_absolute_position(v.position, container_width, container_height)
            return AnchoredPoint { x = top_left_element_position.x, y = top_left_element_position.y, anchor = v.anchor}

    }

    return AnchoredPoint { anchor = UPOIMT_ORIGIN, x = 0, y = 0}
}

compute_anchored_position:: proc( pt: AnchoredPoint, element_width, element_height: f32 ) -> Point {
    anchor_position := compute_absolute_position(pt.anchor, element_width, element_height)
    return Point { x = pt.x - anchor_position.x, y = pt.y - anchor_position.y}
}



compute_element_position:: proc(element_position: ElementPosition,  element_width, element_height, container_width, container_height: f32) -> Point {
    switch v in element_position {
        case AbsolutePosition:
            return compute_absolute_element_position(v, element_width, element_height, container_width, container_height)
        case RelativePosition:
            parent_top_left := compute_absolute_element_position(v.parent_position, v.parent_size.w, v.parent_size.h, container_width, container_height)

            child_relative_top_left := compute_absolute_element_position(v.anchored_position, element_width, element_height, v.parent_size.w, v.parent_size.h)
            ps := v.parent_size
            return Point {  child_relative_top_left.x + parent_top_left.x,  child_relative_top_left.y + parent_top_left.y }

    }
    return Point { 0,  0}
}

compute_absolute_element_position:: proc(element_position: AbsolutePosition,  element_width, element_height, container_width, container_height: f32) -> Point {

    switch v in element_position {
        case Position:
            return compute_absolute_position(v, container_width, container_height)
  
        case AnchoredPosition:
            anchor_position := compute_absolute_position(v.anchor, element_width, element_height)
            top_left_element_position := compute_absolute_position(v.position, container_width, container_height)
            return Point { top_left_element_position.x - anchor_position.x,  top_left_element_position.y - anchor_position.y}

    }

    return Point { 0,  0}
}

compute_absolute_position:: proc(position: Position, container_width, container_height: f32) -> Point {

    switch v in position {
        case Point:
            return v
        case UPoint:
            return Point { container_width * v.x,  container_height * v.y}

    }
    return Point { 0,  0}
}


