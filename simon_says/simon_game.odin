package simon

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:math/rand"

BoardTile :: struct {
    using rect: rl.Rectangle, 
    is_highlighted : bool
}
BoardPosition :: struct {
    row, col : int
}

GameState :: enum {
    SHOWING_SEQUENCE,
    ENTERING_ANSWER,
    WRONG_ANSWER,
    CORRECT_ANSWER
}

SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720

should_game_run := true

current_game_state : GameState = .SHOWING_SEQUENCE

game_clock :f32 = 0
sequence_started_showing_time : f32 = 0
TIME_TO_SHOW_TILE : f32 : 0.8
TIME_GAP_BETWEEN_TILES :f32 : .25

sequence_to_show: [dynamic]BoardPosition

BOARD_DIM :: 3
board : [BOARD_DIM][BOARD_DIM]BoardTile 

add_to_tile_sequence :: proc() {
    append(&sequence_to_show, BoardPosition {rand.int_max(BOARD_DIM), rand.int_max(BOARD_DIM)} )
}



setup_board :: proc() {
    spacing := 10
    tile_width := SCREEN_WIDTH / BOARD_DIM - spacing
    tile_height := SCREEN_HEIGHT / BOARD_DIM - spacing
    for &row, row_index in board {
        for &tile, col_index in row {
            tile.x = f32(col_index*tile_width + spacing)
            tile.y = f32(row_index*tile_height + spacing)
            tile.width = f32(tile_width - spacing)
            tile.height = f32(tile_height - spacing)
        }
    }
}

clear_tile_highlighting :: proc() {
 for &row, row_index in board {
        for &tile, col_index in row {
            tile.is_highlighted = false
        }
    }
}

main :: proc () {
    
    fmt.println("Running Simon Game...")
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Simon Game")
    rl.SetTargetFPS(60)
    setup_board()
    sequence_started_showing_time = game_clock
    add_to_tile_sequence()
    add_to_tile_sequence()
    fmt.println(sequence_to_show[:])
    for should_game_run {
        if rl.WindowShouldClose() {
            should_game_run = false
        }

        //update
        switch current_game_state {
            case .SHOWING_SEQUENCE:
                position_to_show : = int((game_clock - sequence_started_showing_time) / TIME_TO_SHOW_TILE)
                time_into_current_tile := math.mod_f32((game_clock - sequence_started_showing_time), TIME_TO_SHOW_TILE)
                clear_tile_highlighting()
                if position_to_show < len(sequence_to_show) {
                    if time_into_current_tile > TIME_GAP_BETWEEN_TILES {
                        tile_to_show := sequence_to_show[position_to_show]
                        board[tile_to_show.row][tile_to_show.col].is_highlighted = true
                    } 
                } else {
                    current_game_state = .ENTERING_ANSWER
                }
            case .ENTERING_ANSWER:

            case .WRONG_ANSWER, .CORRECT_ANSWER:

           
        }

        // drawing
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        for &row, row_index in board {
            for &tile, col_index in row {
                color_to_use := rl.RAYWHITE
                if tile.is_highlighted {
                    if current_game_state == .SHOWING_SEQUENCE {
                        color_to_use = rl.BLUE
                    }
                }
                rl.DrawRectangleRounded(tile, 0.3, 4, color_to_use)
                rl.DrawRectangleRoundedLinesEx(tile, 0.3, 4, 6, rl.BLACK)
            }
        }
        rl.EndDrawing()

        game_clock += rl.GetFrameTime()
    }
}