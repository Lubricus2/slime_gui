package slimeGUI
import rl "vendor:raylib"
import "base:runtime"
import "core:fmt"

/*
A graphical immediate mode user interface library written in Odin on top of raylib.
Steps done each frame

2. build the new widget tree (start_box(), end_box(), button() procedures) and handle input with rectangle from precious frame.
3. Size widgets    
4. place widgets and draw them	

Todo:
tooltip support
custom tab_order
global UI scaling

more layout options 
	shrink and textwrapping, break lines
	Padding: left, right, botton, top or just one for all
	spacing: vertical, horizontal  ? 
	break widgets to a new line if they don't fit
	push/pop style on a stack
	push/pop id_salt on a stack

Better names for unions, enums and structs

problems
Input Handling & Z-Order, stuff under another widget can in some cases take the hover.

Optimizations
don't garbage collect and delete from pools every frame. Maybe stagger garbage collecten for different pools
hover/mouse handling? collision detection with mouse, use the tree structure?
only do layouting if anything has changed that makes it needed to be updated
*/

DEFAULT_PADDING :: 10.0
//ROOT_REF :: Widget_Ref{ kind = .None, idx = -1 }

Layout_Mode :: enum {
	Vertical,
	Horizontal,
	Grid,
}

// Alignments
Align_H :: enum { Left, Right, Center, }
Align_V :: enum { Top, Bottom, Center, }

// Coordinates
Absolute :: int  // coordinates from the top left of the parent
Percent :: f32

// Horizontal/Vertival place unions
Place_H :: union { 
	Align_H, 
	Absolute, 
	Percent, 
}

Place_V :: union { 
	Align_V, 
	Absolute, 
	Percent, 
}

// placement (flow vs absolute)
Flow :: enum { After_Last_Child, Below_Last_Child, } // flow marker
Place_xy :: struct { x: Place_H, y: Place_V, }

// after last child or xy coordinate
Place_Option :: union { 
	Flow, 
	Place_xy, 
}

// Size in absolute numbers
Size_Pixels :: f32

Fit :: enum {
	Fit_Parent,  	// grow to fill parent
	Fit_Content, 	// shrink to snuggly fit children
	Use_Style,
}

// fit shrink to children or grow to parent with set min/max size 
Size_Range :: struct {
	fit: Fit,
	min: Size_Pixels,
	max: Size_Pixels,
}

Size_Percent :: struct {  // grow to % of the available space left in parent with set min/max size
	percent: int,  // 0 to 100
	min: Size_Pixels,
	max: Size_Pixels,
}

Size_Option :: union { 
	Fit, 
	Size_Pixels, 
	Size_Range, 
	Size_Percent,
}

Style :: struct {
	font_size: f32,     // elements that isn't strictly text as checkbox and sliders could also be set by font size
	font: rl.Font,
	text_alignment: Align_H,
	padding: f32,
	text_spacing: f32,
	width: f32,
	height: f32,
	idle: Style_State,
	hover: Style_State,
	active: Style_State,
	disabled: Style_State,
	focus_color: rl.Color,
	focus_offset: f32,
	focus_line_width: f32,
	corner_radius: f32,  // corder radius in pixels
}

Style_State :: struct {
	bg_color: rl.Color,  // transparent is transparency = 0 none?
	border_color: rl.Color,
	text_color: rl.Color,
	border_width: f32,   // 0 could be no border
}

@private
GUI_Context :: struct {
	// Internal Stores
	buttons		: Store(Button),
	checkboxes 	: Store(Checkbox),
	sliders    	: Store(Slider),
	textboxes  	: Store(Text_Box),
	labels     	: Store(Label),
	boxes      	: Store(Box),

	//tab_order: [dynamic]int,
	root_refs : [dynamic]Widget_Ref,
	widget_stack: [dynamic]Widget_Ref, // dynamic array of index for open boxes
	default_style: ^Style,
	// GUI states
	active_id: int,  // id of the active widget the last frame
	focused_tab_index: int,
	no_of_focusable: int,
	last_created_tab_index: int,
	hover_any: bool,
	// key timer
	key_repeat_timer: f32,
	key_repeat_delay: f32,
	key_repeat_rate: f32,
}

default_style := Style {
	font_size = 32,     // elements that isn't strictly text as checkbox and sliders could also be set by font size
	//font = nil, // how hanle font?
	text_alignment = .Center,
	text_spacing = 3,
	padding = 6,
	width = 256,
	height = 54,
	focus_color = rl.SKYBLUE,
	focus_offset = -5,
	focus_line_width = 2,
	corner_radius = 8,
	idle = {
		bg_color = rl.LIGHTGRAY,
		border_color = rl.DARKGRAY,
		text_color = rl.DARKGRAY,
		border_width = 1,
	},
	hover = {
		bg_color = rl.Color{ 160, 160, 255, 255 },
		border_color = rl.DARKBLUE,
		text_color = rl.DARKGRAY,
		border_width = 2,
	},
	active = {
		bg_color = rl.DARKGRAY,
		border_color = rl.DARKGRAY,
		text_color = rl.RAYWHITE,
		border_width = 2,
	},
	disabled = {
		bg_color = rl.LIGHTGRAY,
		border_color = rl.LIGHTGRAY,
		text_color = rl.GRAY,
		border_width = 1,
	},
}

@private
Widget_Kind :: enum { None = 0, Button, Checkbox, Slider, Text_Box, Label, Box, }

@private
gui: GUI_Context

@private
Widget_Ref :: struct {
	kind: Widget_Kind,
	idx: int,
}

/*
base struct for widgets
*/
@private
Widget_Base :: struct {
 	id: int,			// unique id made from the caller position outside the library
 	parent_ref: Widget_Ref,		// index to the parent
	// Layout
	rect: rl.Rectangle,		// the calculated size and place
	width_opt: Size_Option,
	height_opt: Size_Option,
	place_opt: Place_Option,
	style: ^Style,
	// States
	hover: bool,
	disabled: bool,
 	tab_order: int,
}

@private
get_base :: proc(ref: Widget_Ref) -> ^Widget_Base {
	//fmt.printfln("ref kind = %v", ref.kind)
	if ref.kind == .None {
        fmt.printfln("CRITICAL: get_base called with .None kind. Index: %d", ref.idx)
        panic("Uninitialized Widget_Ref")
    }
    assert(ref.idx >= 0, "Widget index cannot be negative")
	switch ref.kind {
    case .Button:
        return &gui.buttons.items[ref.idx].Base
    case .Box:
        return &gui.boxes.items[ref.idx].Base
    case .Label:
    	return &gui.labels.items[ref.idx].Base
    case .Text_Box:
    	return &gui.textboxes.items[ref.idx].Base
    case .Checkbox:
    	return &gui.checkboxes.items[ref.idx].Base
    case .Slider:
    	return &gui.sliders.items[ref.idx].Base
    case .None:
    	panic("Attempted to get_base of an uninitialized Widget_Ref")
    }
    return nil
}

begin_gui :: proc(style: ^Style = nil, font: rl.Font = {} ) {
	//assert(font.texture.id > 0, "Passed an invalid/unloaded font to begin_gui")
	// Ensure we didn't leave widgets on the stack from the last frame
    if len(gui.widget_stack) != 0 {
        fmt.println("ERROR: Widget stack was not empty at start of frame. Missing end_box calls.")
        clear(&gui.widget_stack)
    }

	if style != nil {
		gui.default_style = style
	} else {
		gui.default_style = &default_style
	}
	if font != {} {
		gui.default_style.font = font
	}

	// Clear marks on pools; build will mark the ones we keep
    store_sweep_mark(&gui.textboxes)
    store_sweep_mark(&gui.buttons)
    store_sweep_mark(&gui.checkboxes)
    store_sweep_mark(&gui.sliders)
    store_sweep_mark(&gui.labels)
    store_sweep_mark(&gui.boxes)
    clear(&gui.widget_stack)
    clear(&gui.root_refs)
    gui.last_created_tab_index = 0

    if !gui.hover_any && gui.active_id == 0  {
		rl.SetMouseCursor(.DEFAULT)
	}
	gui.hover_any = false
	
	// keyboard controll for focus widgets, 
	if rl.IsKeyPressed(.DOWN) || (rl.IsKeyPressed(.TAB) && !(rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT))) { 
		gui.focused_tab_index += 1
		if gui.focused_tab_index > gui.no_of_focusable - 1 {gui.focused_tab_index = 0}
		gui.focused_tab_index = clamp(gui.focused_tab_index, 0, gui.no_of_focusable - 1)
	}
	if rl.IsKeyPressed(.UP) || (rl.IsKeyPressed(.TAB) && (rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT))) { 
	    gui.focused_tab_index -= 1
	    if gui.focused_tab_index < 0 {gui.focused_tab_index = gui.no_of_focusable - 1}
	    gui.focused_tab_index = clamp(gui.focused_tab_index, 0, gui.no_of_focusable - 1)
	}
	gui.no_of_focusable = 0  // counter for the amount of focusable widgets in a frame for keyboard suport
}

get_default_style :: proc() -> ^Style  {
	return &default_style
}

@private
focused :: proc(tab_index: int) -> bool{
	return gui.focused_tab_index == tab_index
}

@private
active :: proc(id: int) -> bool {
	return gui.active_id == id
}

// building the widget tree
@private
append_to_stack :: proc(ref: Widget_Ref, base: ^Widget_Base) {
	if len(gui.widget_stack) > 0 {
        parent_ref := gui.widget_stack[len(gui.widget_stack)-1]
        parent := &gui.boxes.items[parent_ref.idx]
        // Add myself to parent's children
        // CHEAP CHECK: Is the child actually the parent?
    	assert(ref != parent_ref, "UI Circular Reference: A widget cannot be a child of itself. Did you forget id_salt in a loop/recursion?")
        append(&parent.children, ref)
        base.parent_ref = parent_ref
    } else {
        // I am a root widget
        append(&gui.root_refs, ref)
        base.parent_ref = {}
    }
}

@private
// Creates a unique id from the caller location data and id_salt, safer variant
hash_loc :: proc(c_loc: runtime.Source_Code_Location, id_salt: int) -> int {
    // FNV-1a hashing
    //Constants for 64-bit
    FNV_PRIME  : u64 : 1099511628211
    FNV_OFFSET : u64 : 1469598103934665603
    h := FNV_OFFSET
    // hash the file path
    for b in c_loc.file_path {
        h = (h ~ u64(b)) * FNV_PRIME
    }
    // Mix the Integers
    h = (h ~ u64(c_loc.line))   * FNV_PRIME
    h = (h ~ u64(c_loc.column)) * FNV_PRIME
    h = (h ~ u64(id_salt))      * FNV_PRIME
    return int(h)
}

/*
// Creates a unique id from the caller location data and id_salt, faster variant
hash_loc :: proc(c_loc: runtime.Source_Code_Location, id_salt: int) -> int {
    h := u64(c_loc.line) | (u64(c_loc.column) << 32)
    raw_path := transmute(runtime.Raw_String)c_loc.file_path
    h = h ~ u64(uintptr(raw_path.data))
    if id_salt != 0 {
    	h = h ~ u64(id_salt)
    }
    return int(h)
}*/

@private
build_widget :: proc(store: ^Store($T), id_salt: int, c_loc: runtime.Source_Code_Location, style: ^Style) -> (^T, int) {
	id := hash_loc(c_loc, id_salt)
    idx := store_acquire(store, id)
    comp := &store.items[idx]
    // Common reset logic
    comp.id = id
    comp.parent_ref = {}
    if style == {} {
    	comp.style = gui.default_style
	} else {
    	comp.style = style
	}
    return comp, idx
}

@private
handle_common :: proc(w_base: ^Widget_Base, cursor: rl.MouseCursor) {
	mp := rl.GetMousePosition()
	// set hover, active widget should lock the input to only that widget.
	if !w_base.disabled && (gui.active_id == 0 || active(w_base.id)) {
		//fmt.printfln("set hover: %v", w_base.rect)
		w_base.hover = rl.CheckCollisionPointRec(mp, w_base.rect)
		if w_base.hover {
			gui.hover_any = true
			rl.SetMouseCursor(cursor)
		}
	}
	// set focused with mouse
	if gui.active_id == 0 && rl.IsMouseButtonPressed(.LEFT) && !w_base.disabled && w_base.hover {
	       gui.focused_tab_index = w_base.tab_order
	}
}

// the start build procedure for Box
begin_box :: proc(style: ^Style = nil, width: Size_Option = .Fit_Content, height: Size_Option = .Fit_Content, place: Place_Option = .After_Last_Child, layout: Layout_Mode = .Vertical, spacing: f32 = DEFAULT_PADDING, cols: int = 1, id_salt := 0, c_loc := #caller_location) {
	assert(len(gui.widget_stack) < 128, "Widget stack overflow: Did you forget to call end_box()?")
	comp, idx := build_widget(&gui.boxes, id_salt, c_loc, style)
	// Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    // Update Box specific Data
    comp.children = make([dynamic]Widget_Ref, 0, 8, context.temp_allocator)
    comp.layout_mode = layout
    comp.widget_spacing = spacing
    comp.cols = cols
    comp.col_widths = make([dynamic]f32, 0, cols, context.temp_allocator)
    for _ in 0..<cols do append(&comp.col_widths, 0.0)
     // Create reference
	ref := Widget_Ref{ kind = .Box, idx = idx }
	append_to_stack(ref, &comp.Base)  
	// Push this box so subsequent buttons/labels become its children
    append(&gui.widget_stack, ref)
}

// the end build procedure for Box
end_box :: proc() {
	assert(len(gui.widget_stack) > 0, "Widget stack underflow: Called end_box() too many times")
	if len(gui.widget_stack) == 0 { return }
    pop(&gui.widget_stack)
}

// the builder procedure for button
button :: proc(text: cstring, style: ^Style = nil, width: Size_Option = .Use_Style, height: Size_Option = .Use_Style, place: Place_Option = .After_Last_Child, id_salt := 0, c_loc := #caller_location, disabled := false) -> bool {
	comp, idx := build_widget(&gui.buttons, id_salt, c_loc, style)
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
    comp.disabled = disabled
    gui.no_of_focusable +=  1 
    // Update Button specific Data
	comp.title = text
	// Create reference
	ref := Widget_Ref{ kind = .Button, idx = idx }
	// Link to parent (The Stack)
	append_to_stack(ref, &comp.Base)
	handle_common(&comp.Base, .POINTING_HAND)
    return button_is_clicked(comp)
}

label :: proc(text: cstring, style: ^Style = nil, width :Size_Option = .Use_Style, height : Size_Option = .Use_Style, place: Place_Option = .After_Last_Child, id_salt := 0, c_loc := #caller_location) {
	comp, idx := build_widget(&gui.labels, id_salt, c_loc, style)
    // Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    // Update Label specific Data
	comp.text = text
	// Create reference
	ref := Widget_Ref{ kind = .Label, idx = idx }
	// Link to parent (The Stack)
	append_to_stack(ref, &comp.Base)
}

checkbox :: proc(checked: ^bool, style: ^Style = nil, width :Size_Option = .Use_Style, height :Size_Option  = .Use_Style, place: Place_Option = .After_Last_Child, id_salt := 0, c_loc := #caller_location, disabled := false) {
	comp, idx := build_widget(&gui.checkboxes, id_salt, c_loc, style)
    // Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
    comp.disabled = disabled
    gui.no_of_focusable +=  1 
    // Update Checkbox specific Data
   	comp.checked = checked
	// Create reference
	ref := Widget_Ref{ kind = .Checkbox, idx = idx }
	// Link to parent (The Stack)
	append_to_stack(ref, &comp.Base)
	handle_common(&comp.Base, .POINTING_HAND)
	checkbox_handle_input(comp)
}

slider :: proc(min: i32, max: i32, step: i32, value: ^i32, style: ^Style = nil, width :Size_Option = .Use_Style, height : Size_Option = .Use_Style, place: Place_Option = .After_Last_Child, id_salt := 0, c_loc := #caller_location, disabled := false) {
	comp, idx := build_widget(&gui.sliders, id_salt, c_loc, style)
    // Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
    comp.disabled = disabled
    gui.no_of_focusable +=  1 
    // Update Slider specific Data
	comp.min = min
   	comp.max = max
   	comp.step = step
   	comp.value = value
	// Create reference
	ref := Widget_Ref{ kind = .Slider, idx = idx }
	// Link to parent (The Stack) and drawlist
	append_to_stack(ref, &comp.Base)
	handle_common(&comp.Base, .RESIZE_EW)
	slider_handle_input(comp)
}

measure_text :: proc(text: cstring, style: ^Style) -> f32 {
	width: f32
	if (style.font != {}) {
		dim := rl.MeasureTextEx(style.font, text, style.font_size, style.text_spacing)
		width = dim.x
	} else {
		width = f32(rl.MeasureText(text, i32(style.font_size)))
	}
	return width
}

is_ctrl :: proc() -> bool {
    return rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
}

is_shift :: proc() -> bool {
    return rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
}

text_box :: proc(value: ^Text_Buffer, is_commited: ^bool = nil, style: ^Style = nil, width :Size_Option = .Use_Style, height: Size_Option = .Use_Style, place: Place_Option = .After_Last_Child, is_rune_valid :proc(rune)->bool = nil, is_text_valid :proc(^Text_Buffer)->bool = nil,  id_salt := 0, c_loc := #caller_location, disabled := false) {
	comp, idx := build_widget(&gui.textboxes, id_salt, c_loc, style)
	// Acquire from Pool
    // Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
    comp.disabled = disabled
    gui.no_of_focusable +=  1 
    // Update Text_box specific Data
    comp.text           = value
    comp.is_rune_valid  = is_rune_valid
    comp.is_commited    = is_commited
    comp.is_text_valid  = is_text_valid
    // Create reference
	ref := Widget_Ref{ kind = .Text_Box, idx = idx }
	// Link to parent (The Stack) and drawlist
	append_to_stack(ref, &comp.Base)
	handle_common(&comp.Base, .IBEAM)
	text_box_handle_input(comp)
}

// do the layouting and draws everything
end_gui :: proc() {
	for root_ref in gui.root_refs {
		compute_sizes(root_ref)
	}
	for root_ref in gui.root_refs {
		compute_size_grow(root_ref)
	}
	for root_ref in gui.root_refs {
		place_tree(root_ref, 0, 0)
	}
	// Defocus widgets
	if rl.IsMouseButtonPressed(.LEFT) && !gui.hover_any {
    	gui.focused_tab_index = -1 // Or 0, depending on what represents "no focus"
    	gui.active_id = 0         // Also clear active ID to be safe
	}
}

@private
draw_ref :: proc(ref: Widget_Ref) {
	switch ref.kind {
    case .Button:
    	button_draw(&gui.buttons.items[ref.idx])
    case .Slider:
    	slider_draw(&gui.sliders.items[ref.idx])
    case .Text_Box:
    	text_box_draw(&gui.textboxes.items[ref.idx]) 
    case .Checkbox:
    	checkbox_draw(&gui.checkboxes.items[ref.idx])
    case .Label:
    	label_draw(&gui.labels.items[ref.idx])
    case .Box:
    	box_draw(&gui.boxes.items[ref.idx])
    case .None:
    	panic("called draw_ref with an None ref kind")
    }
}



// raylib draws the line for DrawRectangleRoundedLinesEx outside the rectangle, 
// moving it inside don't work if the linewith > radius. So here we go with a custom rectangle with rounded cornders
@private
draw_rounded_border :: proc(rect: rl.Rectangle, radius: f32, thick: f32, color: rl.Color) {
    if thick <= 0 || color.a == 0 do return

    // Clamp radius to half size to avoid drawing circles larger than the box
    r := min(radius, min(rect.width, rect.height) / 2)
    
    // The "Inner Radius" is 0 if the border is thicker than the corner radius.
    // This is what creates the "Filled Wedge" for the sharp inner corner case.
    inner_r := max(0, r - thick)

    // Draw 4 Corner Rings
    // Top-Left (180 to 270 degrees)
    rl.DrawRing({rect.x + r, rect.y + r}, inner_r, r, 180, 270, 16, color)
    // Top-Right (270 to 360/0 degrees)
    rl.DrawRing({rect.x + rect.width - r, rect.y + r}, inner_r, r, 270, 360, 16, color)
    // Bottom-Right (0 to 90 degrees)
    rl.DrawRing({rect.x + rect.width - r, rect.y + rect.height - r}, inner_r, r, 0, 90, 16, color)
    // Bottom-Left (90 to 180 degrees)
    rl.DrawRing({rect.x + r, rect.y + rect.height - r}, inner_r, r, 90, 180, 16, color)

    // Note: We extend the rectangles into the corners if 'thick > r' to fill the gap.
    
    // Top Bar (between the curve starts)
    rl.DrawRectangleRec({
        x = rect.x + r, 
        y = rect.y, 
        width = rect.width - 2*r, 
        height = thick,
    }, color)

    // Bottom Bar
    rl.DrawRectangleRec({
        x = rect.x + r, 
        y = rect.y + rect.height - thick, 
        width = rect.width - 2*r, 
        height = thick,
    }, color)

    // Left Bar (Vertical)
    // Note: We adjust height to avoid overdrawing the Top/Bottom bars if thickness is small,
    // but if thickness is large, we rely on the overlap to fill the sharp inner corner.
    rl.DrawRectangleRec({
        x = rect.x, 
        y = rect.y + r, 
        width = thick, 
        height = rect.height - 2*r,
    }, color)

    // Right Bar
    rl.DrawRectangleRec({
        x = rect.x + rect.width - thick, 
        y = rect.y + r, 
        width = thick, 
        height = rect.height - 2*r,
    }, color)
    
    // FIX for "Sharp Inner Corner" Gaps
    // If thickness > radius, the rectangular bars above stop at 'r', but the 
    // wedge stops at 'r' too. We need to fill the square area inside the corner.
    if thick > r {
        // Top-Left Inner Filler
        rl.DrawRectangleRec({rect.x + r, rect.y + r, thick - r, thick - r}, color)
        // Top-Right Inner Filler
        rl.DrawRectangleRec({rect.x + rect.width - thick, rect.y + r, thick - r, thick - r}, color)
        // Bottom-Left Inner Filler
        rl.DrawRectangleRec({rect.x + r, rect.y + rect.height - thick, thick - r, thick - r}, color)
        // Bottom-Right Inner Filler
        rl.DrawRectangleRec({rect.x + rect.width - thick, rect.y + rect.height - thick, thick - r, thick - r}, color)
    }
}

@private
draw_rect :: proc(rect: rl.Rectangle, style: ^Style, style_state: Style_State) {
	if style.corner_radius == 0 {
		if style_state.bg_color.a > 0 {
			rl.DrawRectangleRec(rec = rect, color = style_state.bg_color)
		}
		if style_state.border_color != style_state.bg_color && style_state.border_width > 0 && style_state.border_color.a > 0 {
			rl.DrawRectangleLinesEx(rec = rect, lineThick = style_state.border_width, color = style_state.border_color)
		}
	} else {
		
		if style_state.bg_color.a > 0 {
			bg_roundness := (style.corner_radius * 2) / min(rect.width, rect.height)
			rl.DrawRectangleRounded(rec = rect, roundness = bg_roundness, segments = 8, color = style_state.bg_color)
		}
		if style_state.border_color != style_state.bg_color && style_state.border_width > 0 && style_state.border_color.a > 0 {
			draw_rounded_border(rect = rect, radius = style.corner_radius, thick = style_state.border_width, color = style_state.border_color)
			/*
			inner_rect := rl.Rectangle{
            	x      = rect.x + style_state.border_width,
            	y      = rect.y + style_state.border_width,
           	 	width  = rect.width - style_state.border_width * 2,
            	height = rect.height - style_state.border_width * 2,
        	}
        	adjusted_radius := max(0, style.corner_radius - style_state.border_width)
			border_roundness := (adjusted_radius * 2) / min(inner_rect.width, inner_rect.height)
			rl.DrawRectangleRoundedLinesEx(rec = inner_rect, roundness = border_roundness, segments = 8, lineThick = style_state.border_width, color = style_state.border_color)
			*/
		}
	}
}

@private
draw_focus :: proc(rect: rl.Rectangle, style: ^Style) {
	off := style.focus_offset
	line_w := style.focus_line_width
	if style.focus_line_width > 0 && style.focus_color.a > 0 {
		rl.DrawRectangleLinesEx(rec = {x = rect.x - off, y = rect.y - off, width = rect.width + off * 2, height = rect.height + off * 2, }, lineThick = line_w, color = style.focus_color)
	}	
}