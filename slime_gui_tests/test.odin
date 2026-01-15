/*
Test procedures for the gui library
*/

package slimeGUI_test

import rl "vendor:raylib"
import sg "../slime_gui"
import "core:fmt"

Test_State :: struct {
    ui_font:      rl.Font,
    check_val:    bool,
    slider_val:   i32,
    text_input:   sg.Text_Buffer,
    scroll_pos:   f32,
    show_stress:      bool,
    grid_cols:        i32,
    nest_depth:       i32,
    paradox_enabled:  bool,
}

t: Test_State

test_suite :: proc() {
    sg.begin_gui(font = t.ui_font)

    // 1. TOP BAR - Testing Horizontal Layout and Absolute Centering
    sg.begin_box( width = .Fit_Content, height = 60, layout = .Horizontal, place = sg.Place_xy{.Right, .Top},)
        sg.label("SYSTEM STRESS TEST", width = .Fit_Content)
        sg.button("Header 1", width = 200)
        sg.button("Header 2", width = 200)
        if sg.button("Reset Values", width = 200) { 
        	t.slider_val = 50
        	t.check_val = false
        }
    sg.end_box()

    
    // 2. NESTED LAYOUT TEST (Left Side)
    // Testing boxes inside boxes with mixed sizing
    sg.begin_box(width = 300, height = .Fit_Parent, place = sg.Place_xy{.Left, .Center}, style = sg.get_default_style(),)
        sg.label("--- Nested Test ---")
        
        // Inner box 1
        sg.begin_box(layout = .Vertical, spacing = 2, width = .Fit_Parent)
            sg.button("Nested A")
            // Inner box 2 (nested deeper)
            sg.begin_box(layout = .Horizontal, width = .Fit_Parent)
                sg.button("B1", width = sg.Size_Percent{percent = 50})  //
                sg.button("B2", width = sg.Size_Percent{percent = 50, min = 40, max = 200}) // sg.Size_Percent{percent = 50}
            sg.end_box()
        sg.end_box()
        
        sg.label("--- Inputs ---")
        sg.checkbox(&t.check_val)
        sg.slider(0, 100, 5, &t.slider_val, width = .Fit_Parent)
        sg.label(fmt.ctprintf("Val: %d", t.slider_val))
    sg.end_box()

    // 3. GRID TEST (Right Side)
    // Testing alignment within grid cells
    sg.begin_box( layout = .Grid, cols = 3, width = 800,  height = 400, place = sg.Place_xy{.Right, .Center},)
        // Row 1
        sg.button("G1")
        sg.button("G2")
        sg.button("G3")
        // Row 2 - Dynamic labels
        sg.label(t.check_val ? "ON" : "OFF")
        sg.button("G5")
        sg.label("...")
    sg.end_box()

    // 4. OVERFLOW / LARGE CONTENT TEST (Bottom)
    // Testing if Fit_Content correctly expands parent
    sg.begin_box(layout = .Horizontal, width = .Fit_Parent, height = .Fit_Content, place = sg.Place_xy{.Center, .Bottom}, )
        for i in 0..<8 {
            sg.button(fmt.ctprintf("Btn %d", i), width = 100, id_salt = i)
        }
    sg.end_box()

    sg.end_gui()
}

/*
test_suite :: proc() {
    sg.begin_gui(font = t.ui_font)

    // --- CONTROL PANEL (TOP) ---
    sg.begin_box(width = .Fit_Parent, height = 80, layout = .Horizontal)
        sg.checkbox(&t.show_stress, style = sg.get_default_style())
        sg.label("Show Stress Tests")
        
        if t.show_stress {
            sg.label("Grid Cols:")
            // Use your slider to live-mutate the grid layout
            sg.slider(1, 20, 1, &t.grid_cols, width = 150)
            
            sg.label("Nest Depth:")
            sg.slider(1, 50, 1, &t.nest_depth, width = 150)

            sg.checkbox(&t.paradox_enabled)
            sg.label("Enable Paradox")
        }
    sg.end_box()

    if t.show_stress {
        // --- TEST A: THE RECURSIVE DEEP-NEST ---
        // Tests coordinate translation across many layers
        sg.begin_box(width = 300, height = 400, place = sg.Place_xy{.Left, .Center})
            sg.label("Deep Nesting Test")
            draw_deep_nest(t.nest_depth)
        sg.end_box()

        // --- TEST B: THE LAYOUT PARADOX ---
        // What happens if a Parent is .Fit_Content but the Child is .Fit_Parent?
        // Logic: Parent says "How big are you?", Child says "As big as you!"
        if t.paradox_enabled {
            sg.begin_box(width = .Fit_Content, height = 200, layout = .Vertical, place = sg.Place_xy{.Center, .Center})
                sg.label("THE PARADOX BOX")
                sg.begin_box(width = .Fit_Parent, height = 50, style = sg.get_default_style())
                    sg.label("I am Fit_Parent in a Fit_Content box")
                sg.end_box()
            sg.end_box()
        }

        // --- TEST C: GRID MUTATION STRESS ---
        // Rapidly changing columns and high child counts
        sg.begin_box(layout = .Grid, cols = int(t.grid_cols), width = 400, height = .Fit_Content, place = sg.Place_xy{.Right, .Top})
            for i in 0..<30 {
                sg.button(fmt.ctprintf("G %d", i), id_salt = i)
            }
        sg.end_box()
    } else {
        // ... your original test suite code here ...
    }

    sg.end_gui()
}

// Helper to test recursion
draw_deep_nest :: proc(depth: i32) {
    if depth <= 0 do return
    
    // Slight padding/margin creates a "tunnel" effect
    sg.begin_box(width = .Fit_Parent, height = .Fit_Parent, layout = .Vertical, spacing = 2)
        sg.label(fmt.ctprintf("D: %d", depth))
        draw_deep_nest(depth - 1)
    sg.end_box()
}*/

main :: proc() {
    t.grid_cols = 3
    t.nest_depth = 5

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
    rl.InitWindow(1280, 840, "SlimeGUI Test")
    rl.SetTargetFPS(60)

    // Setup state
    t.ui_font = rl.GetFontDefault()
    t.slider_val = 50

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.DARKGRAY)
        
        test_suite()
        
        rl.EndDrawing()
        free_all(context.temp_allocator)
    }

    rl.CloseWindow()
}