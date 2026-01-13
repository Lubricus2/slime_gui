package game
import rl "vendor:raylib"

/*
handles animations written in Odin + Raylib
*/

Animation :: struct {
	texture: rl.Texture2D,
	num_frames: int,
	frame_timer: f32,
	current_frame: int,
	frame_length:f32,
	width : i32,
	height: i32,
}

animation_init :: proc(animation: ^Animation, text_file: cstring) {
	using animation
	texture = rl.LoadTexture(text_file)
	num_frames = 4
	frame_length = 0.1
	width = texture.width
	height = texture.height
}

animation_draw :: proc(animation: ^Animation, pos: rl.Vector2, flip: bool) {
	using animation
	frame_timer += rl.GetFrameTime()
	if frame_timer > frame_length {
		current_frame += 1
		frame_timer = 0
		if current_frame >= num_frames {
			current_frame = 0
		}
	}
	animation_dest := rl.Rectangle {
		x = pos.x,
		y = pos.y,
		width = f32(width) * 4 / f32(num_frames),
		height = f32(height * 4),
	}
	animation_source := rl.Rectangle {
		x =  f32(current_frame) * f32(width) / f32(num_frames),
		y = 0,
		width = f32(width) / f32(num_frames),
		height = f32(height),
	}
	if flip {
		animation_source.width = -animation_source.width
	}
	rl.DrawTexturePro(texture = texture, source = animation_source, dest = animation_dest, origin = 0, rotation = 0, tint = rl.WHITE)
}