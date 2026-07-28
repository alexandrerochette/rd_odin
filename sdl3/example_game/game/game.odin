package game

import "core:math/rand"
import "vendor:sdl3"
import "../interfaces"

ColorGame:: interfaces.Game(GameState)

create_color_game :: proc() -> ColorGame {
    return interfaces.Game(GameState) {
        state = GameState {},
        update = update,
        init = init,
        handle_events = handle_events,
        draw = draw

    }
}

Color :: struct { r,g,b,a: u8 }

GameState :: struct {
    background_color: Color,
    total_clicks: int
}

init :: proc(game: ^ColorGame ) {
    game.state.background_color = Color { 20, 40, 80, 255 }
    game.state.total_clicks = 0
}

draw :: proc (game : ^ColorGame, renderer: ^sdl3.Renderer ) {
    bg := game.state.background_color
	sdl3.SetRenderDrawColor(renderer, bg.r, bg.g, bg.b, bg.a)
	sdl3.RenderClear(renderer)
}

handle_events :: proc(game : ^ColorGame,  events: []sdl3.Event ) {
    for event in events {
        if event.type ==  .MOUSE_BUTTON_DOWN {
            if event.button.button == sdl3.BUTTON_LEFT {
                handle_click(&game.state)
            }
        }
    }
}
handle_click :: proc(state: ^GameState) {
    state.total_clicks += 1
    state.background_color = Color {
        r = u8(rand.int_max(256)),
        g = u8(rand.int_max(256)),
        b = u8(rand.int_max(256)),
        a = 255
    }
}

update :: proc(game : ^ColorGame,  delta_time: f64) {
    
}