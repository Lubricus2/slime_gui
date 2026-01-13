package slimeGUI
import rl "vendor:raylib"
import "base:runtime"
//import "core:fmt"

/*
A graphical immediate mode user interface library written in Odin on top of raylib.
Steps done each frame

2. build the new widget tree (start_box(), end_box(), button() procedures) and handle input with rectangle from precious frame.
3. Size widgets    
4. place widgets and draw them	

Todo:
test suit, especially for the layout engine
tooltip support
custom tab_order
centrailize click logic for focusable widgets?
adding some way to say an widget is disabled
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
only do layouting if anything has changed needing it to be updated
*/

DEFAULT_PADDING :: 10.0

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
	corner_radius: f32,  // corder radius in pixels
}

Style_State :: struct {
	bg_color: rl.Color,
	border_color: rl.Color,
	text_color: rl.Color,
	border_thickness: f32,
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
	corner_radius = 8,
	idle = {
		bg_color = rl.LIGHTGRAY,
		border_color = rl.DARKGRAY,
		text_color = rl.DARKGRAY,
		border_thickness = 1,
	},
	hover = {
		bg_color = rl.Color{ 160, 160, 255, 255 },
		border_color = rl.DARKBLUE,
		text_color = rl.DARKGRAY,
		border_thickness = 2,
	},
	active = {
		bg_color = rl.DARKGRAY,
		border_color = rl.DARKGRAY,
		text_color = rl.RAYWHITE,
		border_thickness = 2,
	},
	disabled = {
		bg_color = rl.LIGHTGRAY,
		border_color = rl.LIGHTGRAY,
		text_color = rl.GRAY,
		border_thickness = 1,
	},
}

@private
Widget_Kind :: enum { Button, Checkbox, Slider, Text_Box, Label, Box, }

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
	//children: [dynamic]Widget_Ref,  // array of children idx for container style widgets as Box
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
    }
    return nil
}

begin_gui :: proc(style: ^Style = nil, font: rl.Font = {} ) {
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
        //parent := get_base(parent_ref)
        parent := &gui.boxes.items[parent_ref.idx]
        // Add myself to parent's children
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
    comp.Base.id = id
    comp.Base.parent_ref = {}
    //clear(&comp.children)
    if style == {} {
    	comp.Base.style = gui.default_style
	} else {
    	comp.Base.style = style
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
	comp, idx := build_widget(&gui.boxes, id_salt, c_loc, style)
	// Reset ephemeral base data
	clear(&comp.children)
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    // Update Box specific Data
    comp.layout_mode = layout
    comp.widget_spacing = spacing
    comp.cols = cols
     // Create reference
	ref := Widget_Ref{ kind = .Box, idx = idx }
	append_to_stack(ref, &comp.Base)  
	// Push this box so subsequent buttons/labels become its children
    append(&gui.widget_stack, ref)
}

// the end build procedure for Box
end_box :: proc() {
	if len(gui.widget_stack) == 0 { return }
    pop(&gui.widget_stack)
}

// the builder procedure for button
button :: proc(text: cstring, style: ^Style = nil, width: Size_Option = .Use_Style, height: Size_Option = .Use_Style, place: Place_Option = .After_Last_Child, id_salt := 0, c_loc := #caller_location) -> bool {
	comp, idx := build_widget(&gui.buttons, id_salt, c_loc, style)
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
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

checkbox :: proc(checked: ^bool, style: ^Style = nil, width :Size_Option = .Use_Style, height :Size_Option  = .Use_Style, place: Place_Option = .After_Last_Child, id_salt := 0, c_loc := #caller_location) {
	comp, idx := build_widget(&gui.checkboxes, id_salt, c_loc, style)
    // Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
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

slider :: proc(min: i32, max: i32, step: i32, value: ^i32, style: ^Style = nil, width :Size_Option = .Use_Style, height : Size_Option = .Use_Style, place: Place_Option = .After_Last_Child, id_salt := 0, c_loc := #caller_location) {
	comp, idx := build_widget(&gui.sliders, id_salt, c_loc, style)
    // Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
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

text_box :: proc(value: ^Text_Buffer, is_commited: ^bool = nil, style: ^Style = nil, width :Size_Option = .Use_Style, height: Size_Option = .Use_Style, place: Place_Option = .After_Last_Child, is_rune_valid :proc(rune)->bool = nil, is_text_valid :proc(^Text_Buffer)->bool = nil,  id_salt := 0, c_loc := #caller_location) {
	comp, idx := build_widget(&gui.textboxes, id_salt, c_loc, style)
	// Acquire from Pool
    // Reset ephemeral base data
    comp.width_opt = width
    comp.height_opt = height
    comp.place_opt = place
    comp.tab_order = gui.no_of_focusable
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
    }
}

@private
draw_rect :: proc(rect: rl.Rectangle, style: ^Style, style_state: Style_State) {
	if style.corner_radius == 0 {
		rl.DrawRectangleRec(rec = rect, color = style_state.bg_color)
		if (style_state.border_color != style_state.bg_color) {
			rl.DrawRectangleLinesEx(rec = rect, lineThick = style_state.border_thickness, color = style_state.border_color)
		}
	} else {
		roundness := to_fixed_roundness(rect, style.corner_radius)
		rl.DrawRectangleRounded(rec = rect, roundness = roundness, segments = 8, color = style_state.bg_color)
		if (style_state.border_color != style_state.bg_color) {
			rl.DrawRectangleRoundedLinesEx(rec = rect, roundness = roundness, segments = 8, lineThick = style_state.border_thickness, color = style_state.border_color)
		}
	}
}

@private
draw_focus :: proc(rect: rl.Rectangle, style: ^Style) {
	off :f32= -5
	line_w :f32= 2
	rl.DrawRectangleLinesEx(rec = {x = rect.x - off, y = rect.y - off, width = rect.width + off * 2, height = rect.height + off * 2, }, lineThick = line_w, color = style.focus_color)
}