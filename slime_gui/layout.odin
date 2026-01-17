#+private
package slimeGUI
import "core:fmt"
import rl "vendor:raylib"

// compute column width for boxes with the .Grid layout
compute_grid_widths :: proc(box: ^Box) {
    //if box.layout_mode != .Grid || len(box.children) == 0 do return
    if len(box.children) == 0 do return
    
    cols := max(1, box.cols)
    // The array is already initialized in begin_box, so just reset values
    /*
    for i in 0..<len(box.col_widths) {
        box.col_widths[i] = 0
    }
    */

    for child_ref, i in box.children {
        child := get_base(child_ref)
        col_idx := i % cols  // modulu to wrap around the column index
        box.col_widths[col_idx] = max(box.col_widths[col_idx], child.rect.width)
    }
}

// bottom-up sizing
compute_sizes :: proc(ref: Widget_Ref) {	
	w_base := get_base(ref)
	assert(w_base.style != nil, "style group is nil in the compute_size proc")
	// Recurse First (Bottom-Up)
    if ref.kind == .Box {
        box := &gui.boxes.items[ref.idx]
        for child_ref in box.children {
            compute_sizes(child_ref)
        }
        compute_grid_widths(box)
    }

    // helper to check if this is a root widget
    is_root := w_base.parent_ref == Widget_Ref{}

    // Calculate My Size
    switch &w in w_base.width_opt {
    case Size_Pixels:
    	w_base.rect.width = w
    case Fit:
    	switch w {
    	case .Use_Style:
    		w_base.rect.width = f32(w_base.style.width)
    	case .Fit_Content:
	        if ref.kind == .Box {
	        	box_fit_content_w(&gui.boxes.pool.items[ref.idx])
	    	} else if ref.kind == .Label {
	    		label_fit_content_w(&gui.labels.pool.items[ref.idx])
	    	} else {
	    		fmt.printfln("width .fit_content is not supporterd for the widget kind: %v", ref.kind)
	    	}
    	case .Fit_Parent:
    		if is_root {
    			w_base.rect.width = f32(rl.GetScreenWidth()) // Fix: Fill screen if root
    		} else {
    			// must be done in a second pass of the tree / compute_size_grow_c() proc so set to 0 for now
    			w_base.rect.width = 0
    		}
    	}
    case Size_Range:
    	// todo: calc the same as Fit with clamp min/max
    	if ref.kind == .Box {
            box_fit_content_w(&gui.boxes.pool.items[ref.idx])
        } else if ref.kind == .Label {
            label_fit_content_w(&gui.labels.pool.items[ref.idx])
        } else {
            fmt.printfln("width .fit_content is not supporterd for the widget kind: %v", ref.kind)
        }
        w_base.rect.width = max(w_base.rect.width, w.min)
        if w.max != 0 {
            w_base.rect.width = min(w_base.rect.width, w.max)
        }
    	//w_base.rect.width = clamp(w_base.rect.width, w.min, w.max)
    case Size_Percent:
   		if is_root {
             // Fix: Percent of screen if root
            w_base.rect.width = f32(rl.GetScreenWidth()) * (f32(w.percent) / 100.0)
            w_base.rect.width = max(w_base.rect.width, w.min)
            if w.max != 0 {
                w_base.rect.width = min(w_base.rect.width, w.max)
            }
        } else {
        	// must be done in a second pass of the tree / compute_size_grow_c() proc so set to 0 for now
            w_base.rect.width = 0
        }
	}
	switch &h in w_base.height_opt {
	case Size_Pixels:
    	w_base.rect.height = h
    case Fit:
    	switch h {
    	case .Use_Style:
    		w_base.rect.height = f32(w_base.style.height)
    	case .Fit_Content:
    		// calculate size of the childre with the layout options in box // how handle Layouts for roots?
    		
    		if ref.kind == .Box {
	        	box_fit_content_h(&gui.boxes.pool.items[ref.idx])
	    	} else {
	    		fmt.println("height .fit_content is not supporterd for the widget kind: %v", ref.kind)
	    	}
    	case .Fit_Parent:
    		if is_root {
                w_base.rect.height = f32(rl.GetScreenHeight()) // Fix: Fill screen if root
            } else {
            	// must be done in a seccond pass of the tree so set to 0 for now
                w_base.rect.height = 0
            }
    	}
    case Size_Range:
    	if ref.kind == .Box {
            box_fit_content_h(&gui.boxes.pool.items[ref.idx])
        } else {
            fmt.println("height .fit_content is not supporterd for the widget kind: %v", ref.kind)
        }
    	//w_base.rect.height = clamp(w_base.rect.height, h.min, h.max)
        w_base.rect.height = max(w_base.rect.height, h.min)
        if h.max != 0 {
            w_base.rect.height = min(w_base.rect.height, h.max)
        }
    case Size_Percent:
    	if is_root {
            w_base.rect.height = f32(rl.GetScreenHeight()) * (f32(h.percent) / 100.0)
            w_base.rect.height = max(w_base.rect.height, h.min)
            if h.max != 0 {
                w_base.rect.height = min(w_base.rect.height, h.max)
            }
        } else {
            // must be done in a second pass of the tree so set to 0 for now
            w_base.rect.height = 0
        }
	}
}

compute_size_grow :: proc(ref: Widget_Ref) {
	//w_base := get_base(ref)
    if ref.kind == .Box {
    	box := gui.boxes.pool.items[ref.idx]
        assert(box.style != nil, fmt.tprintfln("Box [idx:%d] has no style assigned", ref.idx))

        layout := box.layout_mode
        spacing := box.widget_spacing
        padding := f32(box.style.padding)
        
        // The space available inside this box
        parent_content_w := box.rect.width - 2 * padding
        parent_content_h := box.rect.height - 2 * padding

        // Counters for space logic
        fixed_width_used: f32
        fixed_height_used: f32
        
        expand_w_count: i32
        expand_h_count: i32
        
        child_count := len(box.children)

        // 1. First Pass: Measure fixed items and count expanders
        for child_ref in box.children {
            child := get_base(child_ref)
            
            // --- WIDTH CALCULATION ---
            #partial switch w in child.width_opt {
            case Size_Pixels:
                fixed_width_used += w
            case Size_Percent:
                // Percent is "fixed" relative to parent, so we calculate it now
                spacing_total := spacing * f32(max(0, child_count - 1))
                child.rect.width = (parent_content_w - spacing_total) * (f32(w.percent) / 100.0) 
                child.rect.width = max(child.rect.width, w.min)
                if w.max != 0 {
                    child.rect.width = min(child.rect.width, w.max)
                }
                fixed_width_used += child.rect.width
            case Fit:
                if w == .Fit_Content || w == .Use_Style {
                     fixed_width_used += child.rect.width
                } else if w == .Fit_Parent {
                    expand_w_count += 1
                }
            case Size_Range:
                if w.fit == .Fit_Content || w.fit == .Use_Style {
                     fixed_width_used += child.rect.width
                } else if w.fit == .Fit_Parent {
                    expand_w_count += 1
                }
            }

            // --- HEIGHT CALCULATION ---
            #partial switch h in child.height_opt {
            case Size_Pixels:
                fixed_height_used += h
            case Size_Percent:
                spacing_total := spacing * f32(max(0, child_count - 1))
                child.rect.height = (parent_content_h - spacing_total) * (f32(h.percent) / 100.0)
                child.rect.height = max(child.rect.height, h.min)
                if h.max != 0 {
                    child.rect.height = min(child.rect.height, h.max)
                }
                fixed_height_used += child.rect.height
            case Fit:
                if h == .Fit_Content || h == .Use_Style {
                     fixed_height_used += child.rect.height
                } else if h == .Fit_Parent {
                    expand_h_count += 1
                }
            case Size_Range:
                if h.fit == .Fit_Content || h.fit == .Use_Style {
                     fixed_height_used += child.rect.height
                } else if h.fit == .Fit_Parent {
                    expand_h_count += 1
                }
            }
        }

        // Calculate the "Flex" size (shared space)
        // Only applies if we are layouting in that direction
        
        flex_w: f32
        if layout == .Horizontal && expand_w_count > 0 {
            total_spacing := spacing * f32(max(0, child_count - 1))
            remaining := parent_content_w - fixed_width_used - total_spacing
            if remaining < 0 { remaining = 0 }
            flex_w = remaining / f32(expand_w_count)
        }

        flex_h: f32
        if layout == .Vertical && expand_h_count > 0 {
            total_spacing := spacing * f32(max(0, child_count - 1))
            remaining := parent_content_h - fixed_height_used - total_spacing
            if remaining < 0 { remaining = 0 }
            flex_h = remaining / f32(expand_h_count)
        }

        // Second Pass: Apply calculated sizes to .fit_parent children
        for child_ref in box.children {
            child := get_base(child_ref)

            // --- APPLY WIDTH ---
            is_expand_w := false
            if f, ok := child.width_opt.(Fit); ok && f == .Fit_Parent { is_expand_w = true }
            if f, ok := child.width_opt.(Size_Range); ok && f.fit == .Fit_Parent { is_expand_w = true }

            if is_expand_w {
                if layout == .Horizontal {
                    // Share space with siblings
                    child.rect.width = flex_w
                } else {
                    // Vertical layout: fit_parent means "take full width"
                    child.rect.width = parent_content_w
                }
            }

            // --- APPLY HEIGHT ---
            is_expand_h := false
            if f, ok := child.height_opt.(Fit); ok && f == .Fit_Parent { is_expand_h = true }
            if f, ok := child.height_opt.(Size_Range); ok && f.fit == .Fit_Parent { is_expand_h = true }

            if is_expand_h {
                if layout == .Vertical {
                    // Share space with siblings
                    child.rect.height = flex_h
                } else {
                    // Horizontal layout: fit_parent means "take full height"
                    child.rect.height = parent_content_h
                }
            }
        }
        // Recurse down
    	for child_ref in box.children {
        	compute_size_grow(child_ref)
    	}
    }    
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

// placement on the screen/window, is done after the sizing 
// should root/screen have layouts like vertical, horizontal and grid?
place_tree :: proc(ref: Widget_Ref, x: f32, y: f32) {
	w_base := get_base(ref)
	assert(w_base.style != nil, "style is nil in place_tree") 

    parent_rect: rl.Rectangle
    if w_base.parent_ref == {} {  // == root so use the whole screen
    	parent_rect = rl.Rectangle{x =0.0, y = 0.0, width = f32(rl.GetScreenWidth()), height = f32(rl.GetScreenHeight())}
    } else {
    	parent := get_base(w_base.parent_ref)
    	parent_rect = parent.rect  // creates a copy so the parent are not changed
    	padding := f32(parent.style.padding)
    	parent_rect.x += padding
    	parent_rect.y += padding
    	parent_rect.width -= 2 * padding
    	parent_rect.height -= 2 * padding
    }
	switch p in w_base.place_opt {
    case Flow:
    	// is calculated from the parent, so don't work with roots they all get 0,0
    	w_base.rect.x = x
    	w_base.rect.y = y
    case Place_xy:
	    switch plx in p.x {
	    case Align_H:
	    	switch plx {
	    	case .Center:
				w_base.rect.x = parent_rect.x + parent_rect.width / 2 - w_base.rect.width / 2
			case .Right:
				w_base.rect.x = parent_rect.x + parent_rect.width - w_base.rect.width
			case .Left:
				w_base.rect.x = parent_rect.x
	    	}
		case Absolute:
			w_base.rect.x  = parent_rect.x + f32(plx)
		case Percent:
			w_base.rect.x = parent_rect.x + parent_rect.width / 100.0 * plx
	    }
	    switch ply in p.y {
	    case Align_V:
	    	switch ply {
	    	case .Center:
				w_base.rect.y = parent_rect.y + parent_rect.height / 2 - w_base.rect.height / 2
			case .Top:
				w_base.rect.y = parent_rect.y
			case .Bottom:
				w_base.rect.y = parent_rect.y + parent_rect.height - w_base.rect.height
	    	}
	    case Absolute:
	    	w_base.rect.y = parent_rect.y + f32(ply)
	    case Percent:
	    	w_base.rect.y = parent_rect.y + parent_rect.height / 100.0 * ply
	    }
    }

    draw_ref(ref)  // if drawing moved here no separate pass is needed but moves drawing before input handling should be ok if the input  handling also is moved,
    // calculate the children of Boxs that has flow
    offset_x := w_base.rect.x + w_base.style.padding
    offset_y := w_base.rect.y + w_base.style.padding
    col_num: int
    if ref.kind == .Box {
    	box := &gui.boxes.pool.items[ref.idx]
    	spacing := box.widget_spacing
        children := box.children

    	switch box.layout_mode {
    	case .Horizontal:
			for child_ref in children {
				child := get_base(child_ref)
    			place_tree(child_ref, offset_x, offset_y)
    			offset_x += child.rect.width + spacing
    		}
    	case .Vertical:
			for child_ref in children {
				child := get_base(child_ref)
    			place_tree(child_ref, offset_x, offset_y)
    			offset_y += child.rect.height + spacing
    		}
    	case .Grid:
			cols := box.cols
            assert(cols > 0, "Box layout set to .Grid but cols is 0 or negative")
            if cols <= 0 { cols = 1 }
            // Place children
            row_max_h: f32
            start_x := offset_x 

            for child_ref in children {
                child := get_base(child_ref)
                place_tree(child_ref, offset_x, offset_y)
                // Track tallest item in this row so we know how much to step down later
                row_max_h = max(row_max_h, child.rect.height)
                // Move X by the COLUMN width (not child width) to keep alignment
                offset_x += box.col_widths[col_num] + spacing
                col_num += 1
                if col_num >= cols {
                    col_num = 0
                    offset_x = start_x
                    // Move Y down by the tallest item in the row we just finished
                    offset_y += row_max_h + spacing 
                    row_max_h = 0
                }
            }
        }
	}
}