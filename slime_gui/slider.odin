#+private
package slimeGUI
import rl "vendor:raylib"
//import "core:fmt"

/* 
slider UI elemet writen in Odin + raylib
TODO:
	generics so it works with any numeric type?
	discrete step for mouse controll can make sense in some uses.
	if switching between widgets wile holding down key the keytimer should be zeroed
*/

Slider :: struct {
	using Base: Widget_Base,
	value: ^i32,
	min: i32,
	max: i32,
	step: i32,   // slider movement step with arrow keys
}

slider_handle_input :: proc(slider: ^Slider) {
	using slider
	assert(value != nil, "slider_handle_input called with the value pointer == nil")

	// mouse control
	if rl.IsMouseButtonPressed(.LEFT) && hover {
		gui.active_id = id
	}
	if (active(id)) {
		if (rl.IsMouseButtonReleased(.LEFT)) {
			gui.active_id = 0
		}
		if (rl.IsMouseButtonDown(.LEFT)) {
			mxt := rl.GetMouseX()
			sl_length_pix := f32(rect.width - 2 * style.padding) 
			sl_length_val := f32(max - min)
			if sl_length_val == 0 { sl_length_val = 1 }
			new_val := min + i32((f32(mxt - i32(rect.x)) / sl_length_pix) * sl_length_val)
			value^ = clamp(new_val, min, max)
		}
	}
	// keyboard control
	if focused(tab_order) {
		if rl.IsKeyPressed(.LEFT) {
			value^ = clamp(value^ - step, min, max)
		} 
		if rl.IsKeyPressed(.RIGHT) {
			value^ = clamp(value^ + step, min, max)
		}

		// held down repeat
		gui.key_repeat_delay = 0.3   // initial delay  should be set somewhere else more central
		gui.key_repeat_rate = 0.1    // repeat interval  should be set somewhere else more central
		if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.RIGHT) {
        	gui.key_repeat_timer += rl.GetFrameTime()
        	if gui.key_repeat_timer > gui.key_repeat_delay {
        	 	// after initial delay, repeat at fixed rate
				if gui.key_repeat_timer > gui.key_repeat_delay + gui.key_repeat_rate {
	                if rl.IsKeyDown(.LEFT) {
	                    value^ = clamp(value^ - step, min, max)
	                }
	                if rl.IsKeyDown(.RIGHT) {
	                    value^ = clamp(value^ + step, min, max)
	                }
	                gui.key_repeat_timer = gui.key_repeat_delay // reset to just after delay
	            }
        	}
    	} else {
        	gui.key_repeat_timer = 0 // reset when key released
    	}
	}
}

slider_draw :: proc(slider: ^Slider) {
	using slider
	assert(style != nil, "slider_draw called with style pointer == nil")

	style_state: Style_State
	if disabled {
    	style_state = style.disabled
	} else if active(Base.id) {
    	style_state = style.active
	} else if hover {
    	style_state = style.hover
	} else {
    	style_state = style.idle
	}

	// draw the slider	
	sl_length_pix := f32(rect.width - 2 * style.padding) 
	sl_length_val := f32(max - min)
	if (sl_length_val == 0) {sl_length_val = 1}  // to avoid division by 0
	if sl_length_pix == 0 { sl_length_pix = f32(rect.width) } // recompute if needed
	val_pix := i32(f32(value^ - min) / sl_length_val * sl_length_pix)

	rect_color := style_state.bg_color
	if active(id) {
		rect_color = style.hover.bg_color
	}
	rl.DrawRectangleRec(rec = Base.rect, color = rect_color)
	rl.DrawRectangleLinesEx(rect, style_state.border_width, style_state.border_color)

	if focused(tab_order) && !disabled {
		draw_focus(rect, style)
	}
	
	rl.DrawLineEx(
    	{rect.x + style.padding, Base.rect.y + Base.rect.height/2},
    	{rect.x + rect.width - Base.style.padding, Base.rect.y + Base.rect.height/2},
    	4,
    	style_state.text_color,
	)
	centerX := i32(rect.x + style.padding) + val_pix
	centerY := i32(rect.y + rect.height/2)
	rl.DrawCircle(centerX, centerY, 8, style_state.bg_color)
	rl.DrawCircleLines(centerX, centerY, 8, style_state.text_color)
}