#+private
package slimeGUI
import rl "vendor:raylib"
//import "core:strings"
import "core:fmt"
import "core:unicode/utf8"

/*
Text input box written in Odin + raylib
procedures is using the temp allocator so be sure to add free_all(context.temp_allocator) to the end of the main loop

Todo: better code
	Generics for callback function, use the rawpointer in the context for callbacks?
Todo: add feutures
	Ctr arrow jump word, CTR shift select word
	several key presses/mouse clicks in one frame not just the characters
	user input if the value is not valid
	suport multiple rows? enter = new line, move cursor up/down with arrow up down
	scrolling if text is to long?
	holding down keys as backspace and arrows should trigger at a good speed first trigger slower
	defocus when clicking outside the box, not just in another widget
*/

Text_Box :: struct {
	// public
	using Base: Widget_Base,
	text: ^Text_Buffer,
	is_commited: ^bool,
	caret_pos: i32,  // caret postion
	sel_anchor_pos: i32,
	was_focused: bool,
	is_rune_valid: proc(rune)->bool , // callback function to test if rune is valid
	is_text_valid: proc(^Text_Buffer)->bool, // callback function to test if text is valid
	// private don't change	
	// buffers
	//positions: []i32,  // positions of runes in rune_array, has to be updated with text_box_data_changed
	//chars_pressed: [8]rune,  // buffer for chars pressed in one frame
}

text_box_get_pix_pos :: proc(text_box : ^Text_Box, byte_pos: i32) -> i32 {
	using text_box
	if byte_pos <= 0 { return 0 }
	if int(byte_pos) >= len(text) {
        // Measure the whole string, temporarily add a null termination
        append(text, 0) 
        v := rl.MeasureTextEx(style.font, cstring(&text[0]), style.font_size, style.text_spacing)
        pop(text)
        return i32(v.x)
    }
    // The "Swap Trick" for temporary null termination:
    original_char := text[byte_pos]
    text[byte_pos] = 0 // Temporarily null-terminate
    // Measure starting from the beginning
    v := rl.MeasureTextEx(style.font, cstring(&text[0]), style.font_size, style.text_spacing)
    text[byte_pos] = original_char // Restore original character
    return i32(v.x)
}

char_to_byte_index :: proc(buffer: ^Text_Buffer, char_index: i32) -> i32 {
    byte_idx: i32 = 0
    for _ in 0..<char_index {
        if int(byte_idx) >= len(buffer) do break
        _, width := utf8.decode_rune(buffer[byte_idx:])
        byte_idx += i32(width)
    }
    return byte_idx
}

// due to text kerning individual text width's isn't enough for calculating string length, position is in byte but has to respect utf8
text_box_find_caret_pos :: proc(text_box: ^Text_Box, mouse_pos: rl.Vector2, rect: rl.Rectangle) -> i32 {
    using text_box

    target_x := i32(mouse_pos.x - rect.x) - i32(style.padding)
    
    // Search within the number of characters (UTF-8 safe)
    high_char := text_buffer_no_chars(text)
    low_char: i32 = 0
    
    for low_char < high_char {
        mid_char := low_char + (high_char - low_char) / 2
        // Convert the character count to a byte offset for measurement
        mid_byte := char_to_byte_index(text, mid_char)
        px_pos := text_box_get_pix_pos(text_box, mid_byte)

        if px_pos < target_x {
            low_char = mid_char + 1
        } else {
            high_char = mid_char
        }
    }
    // Now 'low_char' is the character index closest to the mouse.
    // We want to determine if the mouse is closer to the left or right side of this character.
    if low_char == 0 do return 0
    byte_right := char_to_byte_index(text, low_char)
    byte_left  := char_to_byte_index(text, low_char - 1)
    
    pos_right := text_box_get_pix_pos(text_box, byte_right)
    pos_left  := text_box_get_pix_pos(text_box, byte_left)
    
    if (target_x - pos_left) < (pos_right - target_x) {
        return byte_left
    }
    return byte_right
}

text_box_handle_input :: proc(text_box : ^Text_Box) {
	using text_box
	assert(text_box != nil, "text_boxe_handle with text_box == nil")

	// mouse controll	
	if rl.IsMouseButtonPressed(.LEFT) && Base.hover {
		caret_pos = text_box_find_caret_pos(text_box, rl.GetMousePosition(), Base.rect)
		sel_anchor_pos = caret_pos
		gui.active_id = Base.id
	} 
	if (rl.IsMouseButtonReleased(.LEFT) && active(Base.id) ) {
		gui.active_id = 0
	}

	commit :: proc(text_box : ^Text_Box) {
		if text_box.is_commited != nil {
			if text_box.is_text_valid != nil {
				if text_box.is_text_valid(text_box.text) {
					text_box.is_commited^ = true
					fmt.println("text is valid")
				} else {
					fmt.println("text is not valid")
				}
			} else {
				fmt.println("text_box.is_text_valid is nil")
			}
		} 
	}
	// on blur the text box has lost focus
	if text_box.was_focused && !focused(Base.tab_order) {
    	commit(text_box)
	}
	text_box.was_focused = focused(Base.tab_order)

	if focused(Base.tab_order) {
		if (rl.IsMouseButtonDown(.LEFT) && active(Base.id) && Base.hover) {  // start selection
			selp := text_box_find_caret_pos(text_box, rl.GetMousePosition(), Base.rect)
			if (selp != caret_pos) {
				caret_pos = selp
			}
		}
		// insert the pressed characters into the rune array at the point of caret_pos
		char := rl.GetCharPressed()
		for char > 0 { 
			if sel_anchor_pos != caret_pos {
            	text_box_del_sel(text_box)
        	}
			if is_rune_valid != nil {
				if is_rune_valid(char) {
					text_buffer_insert_rune(text, char, caret_pos)
					caret_pos = text_buffer_move_pos_right(text, caret_pos)
					sel_anchor_pos = caret_pos
				}
			} else {
				text_buffer_insert_rune(text, char, caret_pos)
				caret_pos = text_buffer_move_pos_right(text, caret_pos)
				sel_anchor_pos = caret_pos
			}
			char = rl.GetCharPressed()
		}

		// keyboard controll, navigation & edit keys
		// how handle multiple keypresses in one frame?
		// commit changes and check if value is valid, how do user feedback if not?
		if rl.IsKeyPressed(.ENTER) {
			commit(text_box)
		}

		// delete one character or the selected text
		if rl.IsKeyPressed(.BACKSPACE) 
		{
			if caret_pos != sel_anchor_pos {
				text_box_del_sel(text_box)
			}
			else if caret_pos > 0 {
				caret_pos = text_buffer_backspace(text, caret_pos)
            	sel_anchor_pos = caret_pos
            }
        }
        // Handle left arrow key: move caret left, select with shift
        if rl.IsKeyPressed(.LEFT) { 
        	caret_pos = text_buffer_move_pos_left(text, caret_pos)
        	if !is_shift() {
            	sel_anchor_pos = caret_pos
        	}
		}
		// Handle right arrow key: move caret right, select with shift
		if rl.IsKeyPressed(.RIGHT) { 
			caret_pos = text_buffer_move_pos_right(text, caret_pos)
        	if !is_shift() {
            	sel_anchor_pos = caret_pos
        	}
		}
		if rl.IsKeyPressed(.HOME) 
		{
			caret_pos = 0
			sel_anchor_pos = 0
		}
		if rl.IsKeyPressed(.END) {
			caret_pos = text_buffer_no_chars(text)
			sel_anchor_pos = caret_pos
		}
		if rl.IsKeyPressed(.C) && is_ctrl() {
			if sel_anchor_pos != caret_pos {
				sel_string := text_box_get_selection(text_box)
				rl.SetClipboardText(sel_string)
			}
		}
		if rl.IsKeyPressed(.V) && is_ctrl() {
			if sel_anchor_pos != caret_pos {
				text_box_del_sel(text_box)
			}
			cstr := rl.GetClipboardText()
			text_box_insert_string(text_box, cstr)
		}
		if rl.IsKeyPressed(.X) && is_ctrl() {
			if sel_anchor_pos != caret_pos {
				sel_string := text_box_get_selection(text_box)
				rl.SetClipboardText(sel_string)
				text_box_del_sel(text_box)
			}
		}
		if rl.IsKeyPressed(.A) && is_ctrl() {
			caret_pos = text_buffer_no_chars(text)
			sel_anchor_pos = 0
		}
		if rl.IsKeyPressed(.DELETE) {
			if sel_anchor_pos != caret_pos {
				text_box_del_sel(text_box)
			} else if caret_pos < text_buffer_no_chars(text) {
				caret_pos = text_buffer_move_pos_right(text, caret_pos)
				caret_pos = text_buffer_backspace(text, caret_pos)
            	sel_anchor_pos = caret_pos
			} 
		}
	} 
}

text_box_del_sel :: proc(text_box: ^Text_Box) {
	using text_box
	start := min(caret_pos, sel_anchor_pos)
    end   := max(caret_pos, sel_anchor_pos)
	text_buffer_delete_sub_str(text, start, end)
	caret_pos = start
	sel_anchor_pos = caret_pos
}

text_box_get_selection :: proc(text_box : ^Text_Box) -> cstring {
	using text_box
    
    start := min(caret_pos, sel_anchor_pos)
    end   := max(caret_pos, sel_anchor_pos)
    
    // Safety check
    if start == end do return ""
	dstr := text_buffer_csubstr(text, start, end - start)
	return dstr
}

// insert string at caret_pos
// Todo: validate str before inserting, remove forbidden character
text_box_insert_string :: proc(text_box: ^Text_Box, str: cstring) {
	using text_box
	if str == nil || len(str) == 0 do return
	bytes_added := i32(len(str))
	if bytes_added > 0 {
		text_buffer_insert_cstring(text, str, caret_pos)
		caret_pos += bytes_added
		sel_anchor_pos = caret_pos
	}
}

text_box_draw :: proc(text_box: ^Text_Box) {
	using text_box
	//frame_timer += rl.GetFrameTime()

	style_state: Style_State
	if disabled {
    	style_state = style.disabled
	} else if active(id) {
    	style_state = style.active
	} else if hover {
    	style_state = style.hover
	} else {
    	style_state = style.idle
	}

	rl.DrawRectangleRec(rec = Base.rect, color = Base.style.idle.bg_color)
	rl.DrawRectangleLinesEx(Base.rect, style_state.border_width, style_state.border_color)

	if focused(tab_order) && !disabled {
		draw_focus(rect, style)
	}

	// draw the selection
	if sel_anchor_pos != caret_pos {
		start := min(caret_pos, sel_anchor_pos)
        end   := max(caret_pos, sel_anchor_pos)

		px_start := text_box_get_pix_pos(text_box, start)
		px_end := text_box_get_pix_pos(text_box, end)
		//fmt.printf("sel_start: %v sel_end: %v cstr_start: %v px_start: %v\n", sel_start, sel_end, cstr_start, px_start)
		selrect := rl.Rectangle{
			x = rect.x + f32(px_start) + 5, 
			y = rect.y + 2, 
			width = f32(px_end-px_start), 
			height = rect.height - 4,
		}
		rl.DrawRectangleRec(rec = selrect, color = style.hover.bg_color)
	}

    // draw the text
    ys :i32 = i32(Base.rect.height) / 2 - i32(Base.style.font_size) / 2
    pos := rl.Vector2{Base.rect.x + f32(Base.style.padding), Base.rect.y + f32(ys)}
    text_buffer_draw(text, pos, &style_state, style.font, style.font_size, style.text_spacing)

    // Caret 
    if focused(Base.tab_order) {
    	/*
    	caret_pos_pix := text_box_get_pix_pos(text_box, caret_pos)
    	rl.DrawText(text = "|", posX = i32(Base.rect.x) + i32(Base.style.padding) + caret_pos_pix, posY = i32(Base.rect.y) + ys, fontSize = i32(Base.style.font_size), color = rl.MAROON)
    	*/
    	px := text_box_get_pix_pos(text_box, caret_pos)
        rl.DrawLineEx(
            {pos.x + f32(px), pos.y}, 
            {pos.x + f32(px), pos.y + f32(Base.style.font_size)}, 
            3,
            rl.MAROON,
        )
    }
}	