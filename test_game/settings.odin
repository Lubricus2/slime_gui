package game
import rl "vendor:raylib"
import sg "../slime_gui"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"

/*
	Settings management (read/save) and UI wiring.
	TODO:	
		set criteria for valid player name with some good feedback to user
*/

Settings :: struct {
	// setting variables
	frame_cap: i32,
	frame_cap_dstr: sg.Text_Buffer,
	frame_cap2: i32,
	frame_cap_dstr_is_commited: bool,
	fps_cap_slider_min: i32,
	fps_cap_slider_max: i32,
	fps_cap_step: i32,
	show_fps: bool,
	player_name: sg.Text_Buffer,
	player_name_is_commited: bool,
}

settings_draw :: proc(game: ^Game) {
	using game.settings

	style := game.style
	box_style := style
	box_style.padding = 20
	//style.font = rl.GetFontDefault()

	is_digit := proc(c: rune) -> bool {
		return c >= '0' && c <= '9'
	}
	
	is_text_valid := proc(str: ^sg.Text_Buffer) -> bool {
		frame_cap, OK := sg.text_buffer_to_i32(str)
		if !OK {return false}
		return frame_cap >= 16 && frame_cap <= 256 
	}
	
	rl.ClearBackground(rl.RAYWHITE)
	sg.begin_gui(&style)
    sg.begin_box(spacing = 16, style = &box_style, place = sg.Place_xy{.Center, .Center})
    	sg.label(text = "Max frame rate")
    	sg.begin_box(layout = .Horizontal, spacing = 16)
    		sg.slider(min = fps_cap_slider_min, max = fps_cap_slider_max, step = 10, value = &frame_cap)
    		sg.text_box(value = &frame_cap_dstr, is_commited = &frame_cap_dstr_is_commited, is_rune_valid = is_digit, is_text_valid = is_text_valid)
    	sg.end_box()
    	sg.begin_box(layout = .Horizontal, spacing = 16)
    		sg.label(text = "Show frame rate")
    		sg.checkbox(&show_fps)
    	sg.end_box()
    	sg.begin_box(layout = .Horizontal, spacing = 16)
    		sg.label(text = "Plöyer name")
    		sg.text_box(value = &player_name, is_commited = &player_name_is_commited)
    	sg.end_box()
		if sg.button(text = "Save") {
			frame_cap = clamp(frame_cap, i32(fps_cap_slider_min), i32(fps_cap_slider_max))
			rl.SetTargetFPS(frame_cap)
			settings_save(&game.settings)
		}
		if sg.button(text = "back") {
			game.scene = .Main_menu
		}
	sg.end_box()

	// sync slider and editable textbox showing value
	if frame_cap != frame_cap2 {
		frame_cap_dstr = sg.text_buffer_from_i32(frame_cap)
	} 
	else if (frame_cap_dstr_is_commited) {
		frame_cap, _ = sg.text_buffer_to_i32(&frame_cap_dstr)
		frame_cap_dstr_is_commited = false
	}
	frame_cap2 = frame_cap	
	sg.end_gui()
}

// read settings from file
settings_read :: proc(settings: ^Settings) {
	using settings

	data, ok := os.read_entire_file("settings.txt", context.temp_allocator)
	if !ok {
		// could not read file, set default values
		frame_cap = 60
		show_fps = false
		return
	}
	
	content := string(data)
	//fmt.printf("content: %v\nlen: %v\n", content, len(content))

	for line in strings.split_lines_iterator(&content) {
		linet := strings.trim_space(line)
		if linet == "" || strings.has_prefix(linet, "//") { continue } // skip empty lines and commented lines 
		fs := strings.fields(linet, context.temp_allocator)

		if len(fs) < 2 { continue }
		key := fs[0]
		val := fs[1]
		switch key {
		case "frame_cap":
			frame_cap64, OK := strconv.parse_int(val)
			if (OK) {
				frame_cap = clamp(i32(frame_cap64), i32(fps_cap_slider_min), i32(fps_cap_slider_max))
			} else {
				frame_cap = 60
			}
		case "show_fps":
			show_fps, _ = strconv.parse_bool(val)
		case"player_name": 
			player_name = sg.text_buffer_from_string(val)
		}
	}
}

settings_init :: proc(game: ^Game) {
	using game.settings
	fps_cap_slider_min = 16
	fps_cap_slider_max = 256
	settings_read(&game.settings)
	rl.SetTargetFPS(frame_cap) //frame_cap
}

// saves settings to file
// allocations, should stuff be freed?
settings_save :: proc(settings: ^Settings) {
	using settings
	file_body := fmt.tprintf("frame_cap %d\nshow_fps %t\nplayer_name %s", frame_cap, show_fps, sg.text_buffer_to_string(&player_name))
    ok := os.write_entire_file("settings.txt", transmute([]byte)(file_body))
    if !ok {
        fmt.println("Error writing file settings.txt")
    }
}