package interfaces

import "vendor:sdl3"

Game :: struct($T: typeid) {
	state:           T,
	init:            proc(game: ^Game(T)), // Pass as a pointer so 'init' can mutate fields
    handle_events: proc(game: ^Game(T), events: []sdl3.Event),
	update: proc(game:  ^Game(T), deltaTime: f64),
	draw:   proc(game: ^Game(T), renderer: ^sdl3.Renderer),
}

game_init :: proc(game: ^Game($T)) {
    if game.init != nil {
        game.init(game)
    }
}

game_handle_events :: proc( game: ^Game($T), events: []sdl3.Event) {
   if game.handle_events != nil {
        game.handle_events(game, events)
    }
}

game_update :: proc(game: ^Game($T), deltaTime: f64) {
	if game.update != nil {
		game.update(game, deltaTime)
	}
}

game_draw :: proc(game: ^Game($T), renderer: ^sdl3.Renderer) {
	if game.draw != nil {
		game.draw(game, renderer)
	}
}
