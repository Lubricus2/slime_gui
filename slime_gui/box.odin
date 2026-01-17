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

box_fit_content_w :: proc(box: ^Box) {
	using box

	child_count := len(children)
	cols = max(1, box.cols)
	if child_count == 0 {
        rect.width = style.padding * 2
        return
    }
	total_w : f32

	switch layout_mode {
	case .Horizontal:
    	for child_ref in children {
    		total_w += get_base(child_ref).rect.width
    	}
    	total_w += widget_spacing * (f32(child_count) - 1)
    case .Vertical:
    	for child_ref in children {
    		total_w = max(total_w, get_base(child_ref).rect.width)
    	}
    case .Grid:
    	/*
    	cols = max(1, box.cols)
    	for child_ref, i in children {
    		child_base := get_base(child_ref)
    		col_idx := i % cols  // modulu for wraping number
    		col_widths[col_idx] = max(col_widths[col_idx], child_base.rect.width)
    	}*/
    	compute_grid_widths(box) // Centralized calculation
		// NOW calculate total_w from the columns we tracked
        for cw in col_widths {
            total_w += cw
        }
        total_w += widget_spacing * f32(cols - 1)
	}
    rect.width = total_w + style.padding * 2
}

box_fit_content_h :: proc(box: ^Box) {
	using box

	child_count := len(children)
	if child_count == 0 {
        rect.height = style.padding * 2
        return
    }

	total_h: f32
	switch layout_mode {
	case .Horizontal:
    	for child_ref in children {
    		total_h = max(total_h, get_base(child_ref).rect.height)
    	}
    case .Vertical:
    	for child_ref in children {
    		total_h += get_base(child_ref).rect.height
    	}
    	total_h += widget_spacing * (f32(child_count) - 1)
    case .Grid:
    	col := 0
    	row := 0
    	row_h :f32= 0
    	for child_ref in children {
    		child_base := get_base(child_ref)
    		row_h = max(child_base.rect.height, row_h)
    		col += 1
    		if col >= cols {
    			total_h += row_h
    			row +=1
    			col = 0
    			row_h = 0
    		}
    	}
    	if col > 0 {
        	total_h += row_h
        	row += 1
    	}
        total_h += widget_spacing * f32(row - 1)
    }
    rect.height  = total_h + style.padding * 2 
}

box_draw :: proc(box: ^Box) {
	using box
	draw_rect(rect, style, style.idle)
}