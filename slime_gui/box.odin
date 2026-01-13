#+private
package slimeGUI
import rl "vendor:raylib"
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
	padding := f32(Base.style.padding)
	total_w : f32
	if layout_mode == .Horizontal {
    	if child_count > 0 {
    		for child_ref in children {
    			child_base := get_base(child_ref)
    			total_w += child_base.rect.width
    		}
    		total_w += widget_spacing * (f32(child_count) - 1)
    	}
    } else if layout_mode == .Vertical {
    	for child_ref in children {
    		child_base := get_base(child_ref)
    		total_w = max(total_w, child_base.rect.width)
    	}
    } else {
    	// Grid layot
    	if cols <= 0 { cols = 1 }
    	col_widths = make([dynamic]f32, context.temp_allocator)
    	resize(&col_widths, box.cols)
    	//col_widths := make(col_widths)
    	col_count := 0
    	for child_ref in children {
    		child_base := get_base(child_ref)
    		col_widths[col_count] = max(col_widths[col_count], child_base.rect.width)
    		col_count += 1
    		if col_count >= cols {
    			col_count = 0
    		}
    	}
		// NOW calculate total_w from the columns we tracked
        for cw in col_widths {
            total_w += cw
        }
        if cols > 1 {
            total_w += widget_spacing * f32(cols - 1)
        }
    }
    Base.rect.width  = total_w + padding * 2
}

box_fit_content_h :: proc(box: ^Box) {
	using box

	child_count := len(children)
	padding := f32(Base.style.padding)
	total_h: f32
	if layout_mode == .Horizontal {
    	for child_ref in children {
    		child_base := get_base(child_ref)
    		total_h = max(total_h, child_base.rect.height)
    	}
    } else if layout_mode == .Vertical {
    	if child_count > 0 {
    		for child_ref in children {
    			child_base := get_base(child_ref)
    			total_h += child_base.rect.height
    		}
    		total_h += widget_spacing * (f32(child_count) - 1)
    	}
    } else {
    	// GRID layout
        if cols <= 0 { cols = 1 }
    	col := 0
    	row := 0
    	row_h :f32= 0
    	for child_ref in children {
    		child_base := get_base(child_ref)
    		row_h = max(child_base.rect.height, row_h)
    		col += 1
    		if col >= cols {
    			col = 0
    			row +=1
    			total_h += row_h
    		}
    	}
    	if row > 1 {
            total_h += widget_spacing * f32(row - 1)
        }
    }
    Base.rect.height  = total_h + padding * 2 
}

to_fixed_roundness :: proc(rect: rl.Rectangle, radius_p: f32) -> f32 {
	return (radius_p * 2) / min(rect.width, rect.height)
}

box_draw :: proc(box: ^Box) {
	using box
	draw_rect(Base.rect, Base.style, Base.style.idle)
}