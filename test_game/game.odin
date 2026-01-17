package game
import rl "vendor:raylib"
import sg "../slime_gui"
//import "core:fmt"

/* 
file with the main start procedure for a game written in Odin + raylib 
it handles switching between screens, initialize stuff, the main loop and exit the program
*/

Scene :: enum {Main_menu, World, Settings}  // different main screens

Game :: struct {
	settings: Settings,
	world: World,
	scene: Scene,			// different main screens
	exit: bool,
	ui_font: rl.Font,
	style: sg.Style,
}

main :: proc() {
	rl.InitWindow(1280, 720, "My First Game")
	rl.SetExitKey(.KEY_NULL)
	rl.SetTargetFPS(60) //frame_cap
	game : Game
	game.scene = .Main_menu
	game.exit = false

	// codepointCount = 255 to get characters as åäö if more exotic characters are needed codepoints and codepointCount may be needed to adjusted
	game.ui_font = rl.LoadFontEx(fileName = "assets/roboto/Roboto-VariableFont_wdth,wght.ttf", fontSize = 32, codepoints = nil, codepointCount = 255)
	game.style = sg.Style {
		font_size = 32,     // elements that isn't strictly text as checkbox and sliders could also be set by font size
		font = game.ui_font,  // how handle the font?
		text_alignment = .Center,
		text_spacing = 3,
		padding = 6,
		width = 256,
		height = 54,
		focus_color = rl.SKYBLUE,
		focus_offset = -5,
		focus_line_width = 2,
		corner_radius = 8,
		idle = {
			bg_color = rl.LIGHTGRAY,
			border_color = rl.DARKGRAY,
			text_color = rl.DARKGRAY,
			border_width = 1,
		},
		hover = {
			bg_color = rl.Color{ 160, 160, 255, 255 },
			border_color = rl.DARKBLUE,
			text_color = rl.DARKGRAY,
			border_width = 2,
		},
		active = {
			bg_color = rl.DARKGRAY,
			border_color = rl.DARKGRAY,
			text_color = rl.RAYWHITE,
			border_width = 2,
		},
		disabled = {
			bg_color = rl.LIGHTGRAY,
			border_color = rl.LIGHTGRAY,
			text_color = rl.GRAY,
			border_width = 1,
		},
	}

	settings_init(&game)
	world_init(&game)

	for !rl.WindowShouldClose() && !game.exit {
		if rl.IsKeyPressed(.ESCAPE) {
			if (game.scene == .Main_menu) {
				// TODO: show a "Save and Quit?" dialog — for now, exit immediately
				game.exit = true
			}
			game.scene = .Main_menu
		}
		rl.BeginDrawing()
		switch game.scene {
		case .Main_menu:
			main_menu_draw(&game)
		case .World:
			world_draw(&game)
			world_handle_input(&game)
		case .Settings:
			settings_draw(&game)
		}
		if game.settings.show_fps {
			rl.DrawFPS(10, 10)
		}
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
	// ask if save before exit?
	rl.UnloadFont(game.ui_font)
	rl.CloseWindow()
}