package canvas



UPoint:: struct {
    x: f32,
    y: f32
}

Point:: struct {
    x: f32,
    y: f32
}

Position:: union {
    UPoint, Point
}

AnchoredPosition :: struct {
    position: Position,
    anchor: Position
}

ElementPosition :: union {
    AnchoredPosition, Position
}

UPOIMT_ORIGIN:: UPoint { 0, 0 }
UPOIMT_CENTER:: UPoint { 0.5, 0.5 }
UPOIMT_MAX:: UPoint { 1, 1 }
// x and y are in 0..1
POSITION_CENTER:: AnchoredPosition { anchor= UPoint{ 0.5, 0.5}, position= UPoint {0.5, 0.5}}

compute_element_position:: proc(element_position: ElementPosition,  element_width, element_height, container_width, container_height: f32) -> Point {

    switch v in element_position {
        case Position:
            return compute_absolute_position(v, container_width, container_height)
  
        case AnchoredPosition:
            anchor_position := compute_absolute_position(v.anchor, element_width, element_height)
            top_left_element_position := compute_absolute_position(v.position, container_width, container_height)
            return Point { x = top_left_element_position.x - anchor_position.x, y = top_left_element_position.y - anchor_position.y}

    }

    return Point {x = 0, y = 0}
}

compute_absolute_position:: proc(position: Position, container_width, container_height: f32) -> Point {

    switch v in position {
        case Point:
            return v
        case UPoint:
            return Point {x = container_width * v.x, y = container_height * v.y}

    }
    return Point {x = 0, y = 0}
}