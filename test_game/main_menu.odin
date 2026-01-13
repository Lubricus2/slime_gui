package game
import rl "vendor:raylib"
import sg "../slime_gui"
//import "core:fmt"

/*
main meny/start menu for a game written in Odin + Raylib
*/
main_menu_draw :: proc(game: ^Game) {
	box_style := game.style
	box_style.padding = 20

	rl.ClearBackground(rl.BLUE)
	sg.begin_gui(&game.style)
    sg.begin_box(spacing = 16, style = &box_style, place = sg.Place_xy{.Center, .Center})
		if sg.button(text = "Play") {
			game.scene = .World
		}
		if sg.button(text = "Settings")  {
			game.scene = .Settings
		}
		if sg.button(text = "Exit") {
			game.exit = true
		}
	sg.end_box()

	sg.end_gui()
}