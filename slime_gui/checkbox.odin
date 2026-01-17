#+private
package slimeGUI
import rl "vendor:raylib"
//import "core:fmt"

/*
Simple Check box control for raylib + Odin.
Togles when clicked as a button not just pressed, feels better with less accidental togles

Todo:
	better graphics and sound + animations
	text to the right or use a separate Label?
*/

Checkbox :: struct {
	using Base: Widget_Base,
	checked: ^bool,  // mouse over
}

checkbox_handle_input :: proc(checkbox: ^Checkbox) {
	using checkbox
	assert(checked != nil, "checkbox_handle_input called with the checked pointer == nil")

	// mouse controll
	if (rl.IsMouseButtonPressed(.LEFT) && Base.hover) {
		gui.active_id = Base.id
	}
	if (rl.IsMouseButtonReleased(.LEFT) && active(Base.id)) {
		if Base.hover  {
			checked^ = !(checked^)
		}
		gui.active_id = 0
	}

	//keyboard control
	if focused(Base.tab_order) && (rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE))  {
		checked^ = !checked^
	}
}

checkbox_draw :: proc(checkbox: ^Checkbox) {
	using checkbox
	assert(Base.style != nil, "checkbox_draw called with the style pointer == nil")

	style_state: Style_State
	if Base.disabled {
    	style_state = Base.style.disabled
	} else if active(Base.id) {
    	style_state = Base.style.active
	} else if Base.hover {
    	style_state = Base.style.hover
	} else {
    	style_state = Base.style.idle
	}

	rl.DrawRectangleRec(rec = Base.rect, color = style_state.bg_color)
	rl.DrawRectangleLinesEx(rect, style_state.border_width, style_state.border_color)
	
	if focused(tab_order) && !disabled {
		draw_focus(rect, style)
	}

    // Draw outline of inner square
    inner_size := f32(Base.style.font_size)

	inner := rl.Rectangle{
        x = Base.rect.x + f32(Base.style.padding),
        y = Base.rect.y + (Base.rect.height - inner_size)/2,
        width = inner_size,
        height = inner_size,
    }
    rl.DrawRectangleLinesEx(inner, 2.0, rl.BLACK)

    // check mark
    cm_pad :: 5
    if checked^ {
        rl.DrawLineEx({inner.x + cm_pad, inner.y + inner.height/2}, {inner.x + inner.width/2, inner.y + inner.height - cm_pad}, 3.0, rl.BLACK)
        rl.DrawLineEx({inner.x + inner.width/2, inner.y + inner.height - cm_pad}, {inner.x + inner.width - cm_pad, inner.y + cm_pad}, 3.0, rl.BLACK)
    }
}