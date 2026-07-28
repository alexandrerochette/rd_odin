package main

import "core:fmt"
import "vendor:sdl3"

main :: proc() {
	// 1. Initialize SDL3 Subsystems
	if !sdl3.Init({.VIDEO}) {
		fmt.eprintf("Failed to initialize SDL3: %s\n", sdl3.GetError())
		return
	}
	defer sdl3.Quit() // Guarantees cleanup when main exits

	// 2. Create the Window
	// SDL3 replaces SDL_CreateWindow with clean configuration flags
	window := sdl3.CreateWindow(
		"Hello Odin + SDL3 Window",
		800,
		600,
		{.RESIZABLE},
	)
	if window == nil {
		fmt.eprintf("Failed to create window: %s\n", sdl3.GetError())
		return
	}
	defer sdl3.DestroyWindow(window)

	// 3. Create a Renderer
	renderer := sdl3.CreateRenderer(window, nil)
	if renderer == nil {
		fmt.eprintf("Failed to create renderer: %s\n", sdl3.GetError())
		return
	}
	defer sdl3.DestroyRenderer(renderer)

	fmt.println("Application initialized successfully!")

	// 4. The Main Loop Variables
	running := true
	event: sdl3.Event

	// 5. The Core Application Loop
	for running {
		// Handle input and system events
		for sdl3.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				running = false
			case .KEY_DOWN:
				if event.key.key == sdl3.K_ESCAPE {
					running = false
				}
			}
		}

		// Clear screen to a dark blue color (R, G, B, A)
		sdl3.SetRenderDrawColor(renderer, 20, 40, 80, 255)
		sdl3.RenderClear(renderer)

		// Render drawings go here (if any)

		// Swap buffers to draw everything to the screen
		sdl3.RenderPresent(renderer)
	}

	fmt.println("Application shut down cleanly.")
}
