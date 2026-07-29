package yoga 

when ODIN_OS == .Windows {
    foreign import yoga {
        "../../.dependencies/lib/yogacore.lib", // Change this path to where your compiled file sits!
        "system:msvcrt.lib",         // C Standard Runtime Library
        "system:msvcprt.lib",        // C++ Standard Library (resolves std::exception, etc.)
    }
}
when ODIN_OS == .Linux {
    foreign import yoga {
        "../../.dependencies/lib/libyogacore.a",
        "system:stdc++", // Pulls in std::exception and standard C++ symbols
    }
} else when ODIN_OS == .Darwin { // macOS
    foreign import yoga {
        "../../.dependencies/lib/libyogacore.a",
        "system:c++",    // Apple's Clang C++ runtime library
    }
}

// 2. Map Yoga's internal C object pointers to type-safe Odin handles
YGNodeRef :: distinct rawptr

// 3. Recreate the core enumerations required by the layout math
YGEdge :: enum i32 {
    Left, Top, Right, Bottom, Start, End, Horizontal, Vertical, All,
}

YGFlexDirection :: enum i32 {
    Column, ColumnReverse, Row, RowReverse,
}

YGJustify :: enum i32 {
    FlexStart, Center, FlexEnd, SpaceBetween, SpaceAround, SpaceEvenly,
}

YGAlign :: enum i32 {
    Auto, FlexStart, Center, FlexEnd, Stretch, Baseline, SpaceBetween, SpaceAround,
}

YGDirection :: enum i32 {
    Inherit, LTR, RTL,
}

// 4. Declare the foreign C API function signatures matching Yoga's engine
@(default_calling_convention="c")
foreign yoga {
    // Allocation & Tree Lifetime Lifecycles
    YGNodeNew             :: proc() -> YGNodeRef ---
    YGNodeFree            :: proc(node: YGNodeRef) ---
    YGNodeFreeRecursive   :: proc(node: YGNodeRef) ---
    
    // Parent/Child Structural Links
    YGNodeInsertChild     :: proc(node: YGNodeRef, child: YGNodeRef, index: u32) ---
    YGNodeGetChildCount   :: proc(node: YGNodeRef) -> u32 ---
    YGNodeGetChild        :: proc(node: YGNodeRef, index: u32) -> YGNodeRef ---
    
    // Layout Metric Computations
    YGNodeCalculateLayout :: proc(node: YGNodeRef, availableWidth, availableHeight: f32, ownerDirection: YGDirection) ---
    
    // Style Constraints Setters
    YGNodeStyleSetWidthPercent   :: proc(node: YGNodeRef, width: f32) ---
    YGNodeStyleSetHeightPercent  :: proc(node: YGNodeRef, height: f32) ---
    YGNodeStyleSetFlexDirection  :: proc(node: YGNodeRef, flexDirection: YGFlexDirection) ---
    YGNodeStyleSetJustifyContent :: proc(node: YGNodeRef, justifyContent: YGJustify) ---
    YGNodeStyleSetAlignItems     :: proc(node: YGNodeRef, alignItems: YGAlign) ---
    YGNodeStyleSetFlexGrow       :: proc(node: YGNodeRef, flexGrow: f32) ---
    YGNodeStyleSetMargin         :: proc(node: YGNodeRef, edge: YGEdge, margin: f32) ---
    
    // Pixel Coordinate Extraction Getters
    YGNodeLayoutGetLeft   :: proc(node: YGNodeRef) -> f32 ---
    YGNodeLayoutGetTop    :: proc(node: YGNodeRef) -> f32 ---
    YGNodeLayoutGetWidth  :: proc(node: YGNodeRef) -> f32 ---
    YGNodeLayoutGetHeight :: proc(node: YGNodeRef) -> f32 ---

    // 
    YGNodeSetContext      :: proc(node: YGNodeRef, ctx: rawptr) ---
    YGNodeGetContext      :: proc(node: YGNodeRef) -> rawptr ---


    // Forces Yoga to treat a node as modified before running a fresh math loop pass
    YGNodeMarkDirty :: proc(node: YGNodeRef) ---

    // Returns true if a specific element or its children have pending mutations
    YGNodeIsDirty   :: proc(node: YGNodeRef) -> bool ---

    // Removes an isolated child element from its container row or column layout tree
    YGNodeRemoveChild      :: proc(node: YGNodeRef, child: YGNodeRef) ---

    // Flushes out an entire element row cleanly in a single execution sweep
    YGNodeRemoveAllChildren:: proc(node: YGNodeRef) ---


    // Forces an element to constrain its structural dimensions to exact absolute floats
    YGNodeStyleSetWidth  :: proc(node: YGNodeRef, width: f32) ---
    YGNodeStyleSetHeight :: proc(node: YGNodeRef, height: f32) ---
}
