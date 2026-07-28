
package main


import "runner"
import "game"

main :: proc() {
	

	game := game.create_color_game()

    runner.run(&game, "Test Game", 800, 600)

	
	
}

