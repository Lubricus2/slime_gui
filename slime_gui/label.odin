#+private
package slimeGUI
import "core:strings"
import rl "vendor:raylib"
import "core:fmt"

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

// swithces white spaces to line breaks so the text fits in the max_width, hadles fonts with kerning.
text_wrap :: proc(ctext: cstring, max_width: f32, style: ^Style) -> cstring {
    if ctext == "" || max_width <= 0 do return ctext

    font := style.font
    if font.texture.id == 0 { font = rl.GetFontDefault() }
    fontSize := style.font_size
    spacing := style.text_spacing

    // Quick full check
    if rl.MeasureTextEx(font, ctext, fontSize, spacing).x <= max_width {
        return ctext
    }

    builder := strings.builder_make(context.temp_allocator)
    words := strings.split(string(ctext), " ", context.temp_allocator)

    current_line_width: f32 = 0

    // Pre-calculate width of a single space
    space_width := rl.MeasureTextEx(font, " ", fontSize, spacing).x

    for word in words {
        if word == "" do continue

        if current_line_width == 0 {
            // First word of line: Measure normally
            half_sandwich := fmt.tprint(word, " ", sep="")
            word_cstr := strings.clone_to_cstring(half_sandwich, context.temp_allocator)
            word_width := rl.MeasureTextEx(font, word_cstr, fontSize, spacing).x
            strings.write_string(&builder, word)
            current_line_width = word_width - space_width
        } else {
            /* --- THE SANDWICH STRATEGY ---  
             measure with spaces at the begining and end of the word to capture the kerning both 
             in the begining and end and later substract the extra white space width
       		*/
            sandwich := fmt.tprint(" ", word, " ", sep="")
            sandwich_cstr := strings.clone_to_cstring(sandwich, context.temp_allocator)
            sandwich_width := rl.MeasureTextEx(font, sandwich_cstr, fontSize, spacing).x
            added_width := sandwich_width - space_width
            
            if current_line_width + added_width <= max_width {
                // It fits
                strings.write_string(&builder, " ")
                strings.write_string(&builder, word)
                current_line_width += added_width
            } else {
                // Wrap
                strings.write_string(&builder, "\n")
                strings.write_string(&builder, word)

                // Re-measure just the word for the new line start
                half_sandwich := fmt.tprint(word, " ", sep="")
                word_cstr := strings.clone_to_cstring(half_sandwich, context.temp_allocator)
                current_line_width = rl.MeasureTextEx(font, word_cstr, fontSize, spacing).x - space_width
            }
        }
    }
    return strings.clone_to_cstring(strings.to_string(builder), context.temp_allocator)
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