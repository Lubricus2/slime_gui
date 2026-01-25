package slimeGUI_test2

import rl "vendor:raylib"
import sg "../slime_gui"

/*
Test procedures for the gui library
Buggs can't place a label directly on the screen, works with buttons
*/

Test_State :: struct {
    ui_font: rl.Font,
}

t: Test_State

test_suite :: proc() {
    style := sg.get_default_style()
    style.font_size = 20
	sg.begin_gui(font = t.ui_font)
        sg.begin_box(place = sg.Place_xy{.Center, .Center}, width = .Fit_Parent, height = .Fit_Parent, layout = .Grid, cols = 3)
            sg.label("top left test this is a long text that needs to be wraped to fit the content rect, do it work with åäö and  double spaces  with more", width = 300, height = 300, align_text_v = .Top, align_text_h = .Left, overflow = .Wrap)
            sg.label("center center\ntest", width = 300, height = 300, align_text_v = .Center, align_text_h = .Center)
            sg.label("bottom right\ntest", width = 300, height = 300, align_text_v = .Bottom, align_text_h = .Right)
            sg.label("top right\ntest", width = 300, height = 300, align_text_v = .Top, align_text_h = .Right)
            sg.label("center left\ntest", width = 300, height = 300, align_text_v = .Center, align_text_h = .Left)
            sg.label("bottom center\ntest", width = 300, height = 300, align_text_v = .Bottom, align_text_h = .Center)
            sg.label("top center\ntest this is also a long text that will not fit in one line", width = 300, height = 300, align_text_v = .Top, align_text_h = .Center, overflow = .Ellipsis)
            sg.label("center right\nntest this is also a long text that will not fit in one line", width = 300, height = 300, align_text_v = .Center, align_text_h = .Right, overflow = .Clip)
            sg.label("bottom left\ntest", width = 300, height = 300, align_text_v = .Bottom, align_text_h = .Left)
        sg.end_box()
	sg.end_gui()
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(1280, 1040, "SlimeGUI Test")
    rl.SetTargetFPS(60)

    // Setup state
    t.ui_font = rl.LoadFontEx(fileName = "assets/roboto/Roboto-VariableFont_wdth,wght.ttf", fontSize = 20, codepoints = nil, codepointCount = 255)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.SKYBLUE)
        test_suite()
        rl.EndDrawing()
        free_all(context.temp_allocator)
    }
    rl.CloseWindow()
}