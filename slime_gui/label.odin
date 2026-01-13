#+private
package slimeGUI
import rl "vendor:raylib"

/*
	widget for showing text that is not interactable
	Todo line wrapping and widget sizing? 
*/

Label :: struct {
	using Base: Widget_Base,
	text : cstring,
}

label_fit_content_w :: proc(label: ^Label) {
	width := measure_text(label.text, label.Base.style)
	label.Base.rect.width = width + label.Base.style.padding * 2
}

label_draw :: proc(label: ^Label) {
	using label
	assert(Base.style != nil, "label_draw called with style as nil value")

	style_state: Style_State
	if Base.disabled {
    	style_state = Base.style.disabled
	} else {
    	style_state = Base.style.idle
	}

	//rl.DrawRectangleLines(posX = i32(rect.x), posY = i32(rect.y), width = i32(rect.width), height = i32(rect.height), color = style.border_color)
	ys :i32 = i32(Base.rect.height) / 2 - i32(Base.style.font_size) / 2
	position := rl.Vector2{Base.rect.x + f32(Base.style.padding), Base.rect.y + f32(ys)}
	rl.DrawTextEx(font = Base.style.font, text = text, position = position, fontSize = f32(Base.style.font_size), spacing = Base.style.text_spacing, tint = style_state.text_color)
}