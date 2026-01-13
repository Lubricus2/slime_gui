
package slimeGUI

import "core:unicode/utf8"
import "core:strings"
//import "core:mem"
import rl "vendor:raylib"
import "core:strconv"

Text_Buffer :: [dynamic]u8

// Insert a single rune (from keyboard)
text_buffer_insert_rune :: proc(buffer: ^Text_Buffer, char: rune, byte_index: i32) {
    if char == 0 do return
    bytes, width := utf8.encode_rune(char)
    inject_at_elems(buffer, byte_index, ..bytes[:width])
}

// Needed for pasting text from the clipboard (Raylib gives cstring)
text_buffer_insert_cstring :: proc(buffer: ^Text_Buffer, str: cstring, byte_index: i32) {
    if str == nil || len(str) == 0 do return
    s := string(str)
    // Cast string to byte slice and inject all at once
    inject_at_elems(buffer, byte_index, ..transmute([]u8)s)
}

// removes one character, left o the index
text_buffer_backspace :: proc(buffer: ^Text_Buffer, index: i32) -> i32 {
    if index <= 0 do return 0
    curr := index
    
    // Step back until we find a non-continuation byte (bits not 10xxxxxx)
    for curr > 0 {
        curr -= 1
        if (buffer[curr] & 0xC0) != 0x80 {
            break
        }
    }
    remove_range(buffer, int(curr), int(index))
    return curr
}

// Delete a sub-string starting at a byte index Length is in bytes
text_buffer_delete_sub_str :: proc(buffer: ^Text_Buffer, start_byte_index: i32, end_byte_index: i32) {
    if end_byte_index - start_byte_index <= 0 || start_byte_index >= i32(len(buffer)) do return
    remove_range(buffer, start_byte_index, end_byte_index)
}

// Returns a substring as cstring for the clipboard.
// Uses temp_allocator because the clipboard function usually copies the data immediately.
text_buffer_csubstr :: proc(buffer: ^Text_Buffer, byte_index: i32, byte_length: i32, allocator := context.temp_allocator) -> cstring {
    if byte_length <= 0 || byte_index >= i32(len(buffer)) do return ""

    return strings.clone_to_cstring(string(buffer[byte_index:byte_index+byte_length]), allocator)
}

text_buffer_draw :: proc(buffer: ^Text_Buffer, pos: rl.Vector2, style: ^Style_State, font: rl.Font, size: f32, spacing: f32) {
    // Temporarily append a null terminator
    append(buffer, 0)
    // Cast the pointer to index 0 as a cstring. 
    cstr := cstring(&buffer[0])
    
    // Draw using Raylib
    rl.DrawTextEx(font = font, text = cstr, position = pos, fontSize = size, spacing = spacing, tint = style.text_color)

    // Remove the null terminator so the buffer is "clean" for the next frame
    pop(buffer)
}

// change caret_pos and select_anchor to byte_index
// moves the byte_pos whole utf8 characters
text_buffer_move_pos_right :: proc(buffer: ^Text_Buffer, byte_pos: i32) -> i32 {
	if byte_pos >= i32(len(buffer)) do return byte_pos
    _, width := utf8.decode_rune(buffer[byte_pos:])
    return byte_pos + i32(width)
}

text_buffer_move_pos_left :: proc(buffer: ^Text_Buffer, byte_pos: i32) -> i32 {
    if byte_pos <= 0 do return 0
    curr := byte_pos
    // Scan backward for the start of the UTF-8 sequence
    for curr > 0 {
        curr -= 1
        if (buffer[curr] & 0xC0) != 0x80 {
            break
        }
    }
    return curr
}

// --- Conversion & Utilities ---

text_buffer_no_chars :: proc(buffer: ^Text_Buffer) -> i32 {
    if len(buffer) == 0 do return 0
    return i32(utf8.rune_count(buffer[:]))
}

text_buffer_from_i32 :: proc(number: i32, allocator := context.allocator) -> Text_Buffer {
    buf: [16]u8
    s := strconv.itoa(buf[:], int(number))
    res := make(Text_Buffer, allocator)
    append(&res, ..transmute([]u8)s)
    return res
}

text_buffer_to_i32 :: proc(text: ^Text_Buffer) -> (val: i32, ok: bool) {
    if len(text) == 0 do return 0, false
    s := string(text[:])
    v, success := strconv.parse_int(s)
    return i32(v), success
}

text_buffer_from_string :: proc(str: string, allocator := context.allocator) -> Text_Buffer {
    res := make(Text_Buffer, allocator)
    append(&res, ..transmute([]u8)str)
    return res
}

// Warning: returns a view of the buffer. 
// If the buffer is modified or freed, this string becomes invalid.
text_buffer_to_string :: proc(text: ^Text_Buffer) -> string {
    if len(text) == 0 do return ""
    return string(text[:])
}