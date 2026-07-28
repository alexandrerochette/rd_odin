// Engine-specific wrappers grouped into a clean structural payload

package runner

import "core:mem"
import "core:time"

import "vendor:sdl3"

import interfaces "../interfaces"


Engine_Ctx :: struct {
	window:   ^sdl3.Window,
	renderer: ^sdl3.Renderer,
	running:  bool,
}

run :: proc(game: ^interfaces.Game($T),  title: cstring, width, height: i32) {
	
	main_loop(game, title, width, height)
}

// Infrastructure Setup: Returns a boolean indicating successful boot
engine_init :: proc(ctx: ^Engine_Ctx, title: cstring, width, height: i32) -> bool {
	if !sdl3.Init({.VIDEO}) {
		//fmt.eprintf("SDL3 Init Error: %s\n", sdl3.GetError())
		return false
	}

	ctx.window = sdl3.CreateWindow(title, width, height, {.RESIZABLE})
	if ctx.window == nil {
		//fmt.eprintf("Window Error: %s\n", sdl3.GetError())
		return false
	}

	ctx.renderer = sdl3.CreateRenderer(ctx.window, nil)
	if ctx.renderer == nil {
		//fmt.eprintf("Renderer Error: %s\n", sdl3.GetError())
		return false
	}

	ctx.running = true
	return true
}

// Infrastructure Shutdown: Sweeps memory cleanly via deferred pipelines
engine_shutdown :: proc(ctx: ^Engine_Ctx) {
	if ctx.renderer != nil do sdl3.DestroyRenderer(ctx.renderer)
	if ctx.window != nil   do sdl3.DestroyWindow(ctx.window)
	sdl3.Quit()
}

main_loop :: proc(game: ^interfaces.Game($T), title:cstring, width, height : i32) {
	arena_buffer: [64 * 1024]byte 
	
	arena: mem.Arena
	mem.arena_init(&arena, arena_buffer[:])
	
	// Create an allocator interface that hooks into your arena
	arena_allocator := mem.arena_allocator(&arena)


	engine: Engine_Ctx
	if !engine_init(&engine, title, width, height) do return
	defer engine_shutdown(&engine)
	
	interfaces.game_init(game)

	event: sdl3.Event

	last_tick :=  time.tick_now()

	// The Main Unified Loop
	for engine.running {
		current_tick := time.tick_now()
    
   
    	duration := time.tick_diff(last_tick, current_tick)
    

    	dt := time.duration_seconds(duration)

		frame_events := make([dynamic]sdl3.Event, arena_allocator)

		// 1. INPUT DOMAIN: Route input actions straight to game behavior
		for sdl3.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				engine.running = false
			case .KEY_DOWN:
				if event.key.key == sdl3.K_ESCAPE do engine.running = false
			}
			append(&frame_events, event)

		}
		interfaces.game_handle_events(game, frame_events[:])
		interfaces.game_update(game, dt)
		interfaces.game_draw(game, engine.renderer)

		sdl3.RenderPresent(engine.renderer)
		mem.arena_free_all(&arena) 
	}
}