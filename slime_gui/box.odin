#+private
package slimeGUI
//import "core:fmt"
/*
graphical container for other widgets, helps with layouts
*/

Box :: struct {
	using Base: Widget_Base,
	layout_mode: Layout_Mode,  // arange widgets top to down or left to right
	children: [dynamic]Widget_Ref,
	widget_spacing: f32,
	cols: int,
	col_widths: [dynamic]f32,
}

box_draw :: proc(box: ^Box) {
	using box
	draw_rect(rect, style, style.idle)
}