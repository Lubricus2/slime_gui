#+private
package slimeGUI
//import "core:strings"
import rl "vendor:raylib"
//import "core:fmt"
import "core:mem"

/*
	widget for showing text that is not interactable
	Todo: line wrapping and widget sizing? 
	Todo: text clipping and scrolling
	Todo: cache for text wrapping / wrapping performance
	Todo: integrate text_wrap() and label_fit_content_h() into the layouting system with stuff getting done in the right order
*/

Label :: struct {
	using Base: Widget_Base,
	text : cstring,
	align_text_h: Align_H,
	align_text_v: Align_V,
	wrap: bool,
}

// c style pointer hell magic for efficient handling of c string idioticity 
// line breaks should be Unix style for it to work properly
text_wrap :: proc(ctext: cstring, max_width: f32, style: ^Style) -> cstring {
    if ctext == nil || max_width <= 0 do return ctext  // || ctext[0] == 0

    font := style.font
    if font.texture.id == 0 { font = rl.GetFontDefault() }
    
    input_len := len(ctext)
    // Allocate to an mutable buffer with len +2 to ensure we have room for a temporary null if the string ends abruptly
    buf := make([]u8, input_len + 2, context.temp_allocator)
    mem.copy(&buf[0], ([^]u8)(ctext), input_len)
    buf[input_len] = 0
    buf[input_len + 1] = 0
    
    ptr := ([^]u8)(&buf[0])
    space_width := rl.MeasureTextEx(font, " ", style.font_size, style.text_spacing).x
    
    current_line_width: f32 = 0
    word_start := 0
    
    for i := 0; i <= input_len; i += 1 {
        curr := ptr[i]
        
        // Word boundary
        if curr == ' ' || curr == '\n' || curr == 0 {
            if i > word_start {
                word_width: f32 = 0
                
                if current_line_width == 0 || word_start == 0 {
                    // --- Case: Start of Line (Trailing Sandwich) ---
                    // Measure "word "
                    // We need to null-terminate at i + 1 to include the space at ptr[i]
                    orig_next := ptr[i + 1]
                    ptr[i + 1] = 0
                    
                    // Measure from word_start to i (which is a space)
                    full_m := rl.MeasureTextEx(font, cstring(&ptr[word_start]), style.font_size, style.text_spacing).x
                    word_width = full_m - space_width
                    
                    ptr[i + 1] = orig_next
                    current_line_width = word_width
                } else {
                    // --- Case: Full Sandwich ---
                    // Measure " word "
                    // word_start-1 is the leading space. i is the trailing space.
                    orig_next := ptr[i + 1]
                    ptr[i + 1] = 0
                    
                    // This now measures: [Space][Word][Space][Null]
                    sandwich_m := rl.MeasureTextEx(font, cstring(&ptr[word_start - 1]), style.font_size, style.text_spacing).x
                    added_width := sandwich_m - space_width
                    
                    ptr[i + 1] = orig_next
                    
                    if current_line_width + added_width <= max_width {
                        current_line_width += added_width
                    } else {
                        // WRAP
                        ptr[word_start - 1] = '\n'
                        
                        // Re-measure word as start of line ("word ")
                        orig_next_wrap := ptr[i + 1]
                        ptr[i + 1] = 0
                        full_m := rl.MeasureTextEx(font, cstring(&ptr[word_start]), style.font_size, style.text_spacing).x
                        current_line_width = full_m - space_width
                        ptr[i + 1] = orig_next_wrap
                    }
                }
            }
            if curr == '\n' {
                current_line_width = 0
            }
            word_start = i + 1
        }
        if curr == 0 do break
    }
    return cstring(&buf[0])
}

label_fit_content_w :: proc(label: ^Label) {
	width := measure_text(label.text, label.style)
	label.rect.width = width + label.style.padding * 2
}

label_fit_content_h :: proc(label: ^Label) {
	dim := rl.MeasureTextEx(label.style.font, label.text, label.style.font_size, label.style.text_spacing)
	label.rect.height = dim.y + label.style.padding * 2
}

label_draw :: proc(label: ^Label) {
	using label
	assert(style != nil, "label_draw called with style as nil value")

	style_state: Style_State
	if disabled {
    	style_state = style.disabled
	} else {
    	style_state = style.idle
	}

	if style_state.border_width > 0 {
		rl.DrawRectangleLinesEx(rec = rect, lineThick = style_state.border_width, color = style_state.border_color)
	}

	// hard breaks and text wrapping, when is the rect.width/height known?
	// fix only measure text when needed
	font := style.font
    if font.texture.id == 0 { 
        font = rl.GetFontDefault() 
    }

    wrapped_text := text
    if wrap {
    	text_max_w := rect.width - 2 * style.padding
    	wrapped_text = text_wrap(ctext = text, max_width = text_max_w, style = style)
    } 

	dim := rl.MeasureTextEx(font, text, style.font_size, style.text_spacing)

	xs:  f32
	switch align_text_h {
		case .Left: xs = style.padding
		case .Center: xs = rect.width / 2.0 - dim.x / 2.0
		case .Right: xs = rect.width - dim.x - 2 * style.padding
	}

	ys: f32
	switch align_text_v {
		case .Top: ys = style.padding
		case .Center: ys = rect.height / 2.0 - dim.y / 2.0
		case .Bottom: ys = rect.height - dim.y - 2 * style.padding
	}
	
	position := rl.Vector2{rect.x + xs, rect.y + ys}
	
	rl.DrawTextEx(font = style.font, text = wrapped_text, position = position, fontSize = style.font_size, spacing = style.text_spacing, tint = style_state.text_color)
}