package layout

import "core:fmt"
import "../canvas"
import "vendor:sdl3"

import "yoga"
Rect :: struct {
    x, y, w, h: i32,
}

Color :: struct {
    r, g, b, a: u8, // Each channel is 0-255, giving you 16.7+ million combinations
}

// 1. Put your rich color data directly into your persistent Odin data structures
Widget_Data :: struct {
    is_button:        bool,
    label:            string,
    background_color: Color, // <-- Your 32-bit color lives here safely
}




draw_widget:: proc(widget: ^Widget_Data, rect: Rect) {
    // Canvas background logic goes here
    fmt.print("drawing widget %v or color %v", rect, widget.background_color)
}

// Our recursive rendering pass
draw_entire_yoga_tree :: proc(node: yoga.YGNodeRef, parent_absolute_x, parent_absolute_y: i32) {
    if node == nil do return

    local_x := i32(yoga.YGNodeLayoutGetLeft(node))
    local_y := i32(yoga.YGNodeLayoutGetTop(node))
    width   := i32(yoga.YGNodeLayoutGetWidth(node))
    height  := i32(yoga.YGNodeLayoutGetHeight(node))

    absolute_x := parent_absolute_x + local_x
    absolute_y := parent_absolute_y + local_y
    absolute_rect := Rect{ absolute_x, absolute_y, width, height }

    context_ptr := yoga.YGNodeGetContext(node)
  
    if context_ptr != nil {
        widget := (^Widget_Data)(context_ptr)
        
        draw_widget(widget, absolute_rect)
    }

    child_count := yoga.YGNodeGetChildCount(node)
    for i in 0..<child_count {
        child := yoga.YGNodeGetChild(node, i)
        draw_entire_yoga_tree(child, absolute_x, absolute_y)
    }
}
main :: proc() {
    // Allocate a root node using our newly bound functions
    root := yoga.YGNodeNew()
    defer yoga.YGNodeFreeRecursive(root)

    yoga.YGNodeStyleSetWidthPercent(root, 100)
    yoga.YGNodeStyleSetHeightPercent(root, 100)
    yoga.YGNodeStyleSetJustifyContent(root, .Center)
    yoga.YGNodeStyleSetAlignItems(root, .Center)
    window_data := Widget_Data { label = "My Window", background_color = Color {30, 30, 55, 255}}
    yoga.YGNodeSetContext(root, rawptr(&window_data))
    // Calculate layout parameters
    yoga.YGNodeCalculateLayout(root, 1920.0, 1080.0, .LTR)

    // Draw the whole tree recursively from scratch
    draw_entire_yoga_tree(root, 0, 0)
}

/*
// A pseudo-DSL using Odin's native scopes
layout_root(width = percent(100), height = percent(100), align = .Center) {
    
    // This container is nested inside the root automatically by the wrapper
    layout_row(width = percent(60), height = percent(60), justify = .SpaceBetween) {
        
        ui_button("label A", grow = 1)
        ui_button("label B", grow = 1, margin_left = 15)
        ui_button("label C", grow = 1, margin_left = 15)
        
    } // The row automatically closes its Yoga context here via 'defer'
} 



main_view := View {
    style = { width = percent(100), height = percent(100), justify = .Center, align = .Center },
    children = {
        View {
            style = { width = percent(60), height = percent(60), direction = .Row, justify = .SpaceBetween },
            children = {
                Button{ label = "label A", style = { grow = 1 } },
                Button{ label = "label B", style = { grow = 1, margin_left = 15 } },
                Button{ label = "label C", style = { grow = 1, margin_left = 15 } },
            },
        },
    },
}
*/