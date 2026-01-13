package slimeGUI_test
import rl "vendor:raylib"
import sg "../slime_gui"

Test :: struct {
	go_play: bool,
	go_settings: bool,
	go_exit: bool,
	ui_font: rl.Font,
}
test: Test

test_layouts :: proc() {
	sg.begin_gui(font = test.ui_font)  // 
	sg.begin_box(width = 400, height = 300, place = sg.Place_xy{.Right, .Top})
		sg.button(text = "Play", width = .Fit_Parent, height = .Fit_Parent)
		sg.button(text = "Settings")
		sg.button(text = "Exit")
	sg.end_box()
	sg.begin_box(layout = .Grid, cols = 2, place = sg.Place_xy{.Left, .Top})
		sg.label("Play", width = .Fit_Content)
		sg.button(text = "Play")
		sg.label("Settings", width = .Fit_Content)
		sg.button(text = "Settings")
		sg.label("Exit", width = .Fit_Content)
		sg.button(text = "Exit")
	sg.end_box()
	sg.begin_box(layout = .Grid, cols = 2, place = sg.Place_xy{.Left, .Bottom})
		sg.label("testing", width = 160)
		sg.button(text = "Play")
		sg.label("hmpff", width = 160)
		sg.button(text = "Settings")
	sg.end_box()
	sg.end_gui()
}

// test layouts
main :: proc() {
	rl.InitWindow(1280, 840, "My First Game")
	rl.SetTargetFPS(60) //frame_cap

	test.ui_font = rl.LoadFontEx("assets/roboto/Roboto-VariableFont_wdth,wght.ttf", 32, nil, 0)
	
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		test_layouts()
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
	rl.UnloadFont(test.ui_font)
	rl.CloseWindow()
}