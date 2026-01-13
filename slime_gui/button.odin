#+private
package slimeGUI
import rl "vendor:raylib"
//import "core:fmt"

/*
Simple button control for raylib + Odin.
Todo : Animations and sound  
Only one click is registred for each is clicked check, should it return number of clicks?
*/

Button :: struct {
	using Base: Widget_Base,
	title: cstring,
}

// checking if button is clicked and is handling the is active logic
button_is_clicked :: proc(button: ^Button) -> bool {
	assert(button != nil, "i_button_is_clicked called with button == nil")
	is_clicked: bool
	
	// mouse control
	if rl.IsMouseButtonPressed(.LEFT) && button.hover {
		gui.active_id = button.id
	}
	/* the button should only count as clicked if it's active = "the mouse button was previosly been pressed inside it"
	 and the mouse button is realeased inside it = hover */
	if rl.IsMouseButtonReleased(.LEFT) && active(button.id) {
		if button.hover {
			is_clicked = true
		}
		gui.active_id = 0
	}
	// Keyboard controll
	if gui.focused_tab_index == button.tab_order && (rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE)) {
		is_clicked = true
	}
	return is_clicked
}

button_draw :: proc(button: ^Button) {
	//using button
	assert(button.style != nil, "button_draw called with style pointer == nil")
	
	style_state: Style_State
	if button.disabled {
    	style_state = button.style.disabled
	} else if active(button.id) {
    	style_state = button.style.active
	} else if button.hover {
    	style_state = button.style.hover
	} else {
    	style_state = button.style.idle
	}

	draw_rect(button.rect, button.style, style_state)

	if focused(button.tab_order) && !button.disabled {
		draw_focus(button.rect, button.style)
	}
	ys := button.rect.height / 2 - button.style.font_size / 2
	xs: f32
	if button.style.text_alignment == .Center {
		//text_width := rl.MeasureTextEx(base.style_group.font, title, base.style_group.font_size, base.style_group.text_spacing)
		text_width := measure_text(button.title, button.style)
		xs = button.rect.width / 2 - text_width / 2
	} else {
		xs = f32(button.style.padding)
	}
	position := rl.Vector2{button.rect.x + xs, button.rect.y + ys}
	rl.DrawTextEx(font = button.style.font, text = button.title, position = position, fontSize = button.style.font_size, spacing = button.style.text_spacing, tint = style_state.text_color)
}