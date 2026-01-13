package game
import rl "vendor:raylib"
import sg "../slime_gui"
import "core:math/rand"
import "core:math"
import "core:strings"
import "core:strconv"
//import "core:fmt"

/*
World and player - the first things for the gameplay written in Odin + raylib
Todo:
highlight items hovered in reach
generalized inventory and crafting, grid  layout for the inventory
Buggs: crashing when interupting path and then path again
movment of the character overshot it's goal and with low framerate it can get stuck in an endless loop twitching
*/

TILE_SIZE :: 64    // pixes in a world tile
WORLD_SIZE :: 64   // height and width of the world in tiles
PLAYER_SPEED :: 400  // the speed of the player in pixels?
PLAYER_REACH :: 190

Entities :: enum {Empty, Branch, Stone, Wall, Tree}

Inventory :: struct {
    stones: i32,
    branches: i32,
}

Player :: struct {
	pos: rl.Vector2,
	vel: rl.Vector2,
	flip: bool,
	run: Animation,
	width: i32,
	height: i32,
	inventory: Inventory,
	has_goto: bool,
	goto_pos: rl.Vector2,
	has_path: bool,
	goto_path: [dynamic]rl.Vector2,
}

World :: struct {
	player: Player,
	centre: rl.Vector2,
	tiles: [][]Entities,
	flat_tiles: []Entities,
	texture_stone: rl.Texture,
	texture_branch: rl.Texture,
	texture_empty: rl.Texture,
	texture_tree: rl.Texture,
	texture_wall: rl.Texture,
	inventory_open: bool,
	style: sg.Style,
}

distance :: proc(p1: rl.Vector2, p2: rl.Vector2) -> f32 {
	return math.sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
}

// uses A* to find a path from start to goal, manhatan distance and movement to tile centres
find_path :: proc(tiles: [][]Entities, start: rl.Vector2, goal: rl.Vector2) -> [dynamic]rl.Vector2 {
	sx := int(start.x / TILE_SIZE)
    sy := int(start.y / TILE_SIZE)
    gx := int(goal.x / TILE_SIZE)
    gy := int(goal.y / TILE_SIZE)

    Node :: struct {
    	x, y: int,
    	g, h, f: int,
    	parent: ^Node,
	}

	man_dist :: proc(x1, y1, x2, y2: int) -> int {
    	return math.abs(x1 - x2) + math.abs(y1 - y2)
	}

	// Open and closed sets
    open: [dynamic]^Node
    open.allocator = context.temp_allocator
    closed: [dynamic]^Node
    closed.allocator = context.temp_allocator
    // Start node
    start_node := new(Node, context.temp_allocator)
    start_node.x = sx
    start_node.y = sy
    start_node.g = 0
    start_node.h = man_dist(sx, sy, gx, gy)
    start_node.f = start_node.h
    start_node.parent = nil
    append(&open, start_node)

    goal_node: ^Node = nil

    for len(open) > 0 {
    	// Find node with lowest f
        current_index := 0
        for i in 1 ..< len(open) {
            if open[i].f < open[current_index].f {
                current_index = i
            }
        }
        current := open[current_index]
        // Remove from open and add to closed
        unordered_remove(&open, current_index)
        append(&closed, current)

        // Goal check
        if current.x == gx && current.y == gy {
            goal_node = current
            break
        }
        // Neighbors
        dirs := [][2]int{{1,0},{-1,0},{0,1},{0,-1}}
        for dir in dirs {
            nx := current.x + dir[0]
            ny := current.y + dir[1]

            // Bounds check
            if nx < 0 || ny < 0 || nx >= len(tiles) || ny >= len(tiles[0]) {
                continue
            }
            // Skip walls
            if tiles[nx][ny] == .Wall {
                continue
            }

            // Already in closed?
            skip := false
            for c in closed {
                if c.x == nx && c.y == ny {
                    skip = true
                    break
                }
            }
            if skip { continue }

            g_cost := current.g + 1
            h_cost := man_dist(nx, ny, gx, gy)
            f_cost := g_cost + h_cost

            // Check if in open with better g
            found := false
            for i in 0 ..< len(open) {
                o := open[i]
                if o.x == nx && o.y == ny {
                    found = true
                    if g_cost < o.g {
                        o.g = g_cost
                        o.h = h_cost
                        o.f = f_cost
                        o.parent = current
                    }
                    break
                }
            }
            if !found {
                node := new(Node, context.temp_allocator)
                node.x = nx
                node.y = ny
                node.g = g_cost
                node.h = h_cost
                node.f = f_cost
                node.parent = current
                append(&open, node)
            }
        }
    }

    if goal_node == nil {
    	return [dynamic]rl.Vector2{}
	}

    // Reconstruct path from goal_node by following parent pointers
    // the path is allocated on the heap with the standard allocator, needs to be freed later
    path: [dynamic]rl.Vector2
    n: ^Node = goal_node
	for n != nil {
	    cx := f32(n.x * TILE_SIZE + TILE_SIZE/2)
	    cy := f32(n.y * TILE_SIZE + TILE_SIZE/2)
	    append(&path, rl.Vector2{cx, cy})
	    n = n.parent
	}

	// Reverse path (since we built it backwards)
	for i := 0; i < len(path) / 2; i += 1 {
	    j := len(path) - 1 - i
	    path[i], path[j] = path[j], path[i]
	}
    return path
}

world_init :: proc(game: ^Game) {
	using game.world

	flat_tiles = make([]Entities, WORLD_SIZE * WORLD_SIZE, context.allocator)
	tiles = make([][]Entities, WORLD_SIZE, context.allocator)
	for  i in 0..< WORLD_SIZE {
		tiles[i] = flat_tiles[i * WORLD_SIZE : (i + 1) * WORLD_SIZE]  // slice the flat slices for even more flatnes
	}

	screen_width := rl.GetScreenWidth()
	screen_height := rl.GetScreenHeight()
	centre = rl.Vector2{f32(screen_width) / 2.0, f32(screen_height) / 2.0} 
	player.pos = {f32(WORLD_SIZE * TILE_SIZE / 2), f32(WORLD_SIZE * TILE_SIZE / 2)}  // starting possition in the midle of the world
	player.width = 64
	player.height = 64
	animation_init(&player.run, "assets/cat_run.png")
	texture_stone = rl.LoadTexture("assets/stone.png")
	texture_branch = rl.LoadTexture("assets/branch.png")
	texture_empty = rl.LoadTexture("assets/ground.png")
	texture_wall = rl.LoadTexture("assets/wall.png")
	texture_tree = rl.LoadTexture("assets/tree.png")
	stone_chance :: 0.08
	branch_chance :: 0.08
	wall_chance :: 0.04
	tree_chance :: 0.04
	for i in 0..< WORLD_SIZE {
		for j in 0..< WORLD_SIZE {
			rnd := rand.float32()
			//fmt.println(rnd)
			if rnd < branch_chance {
				tiles[i][j] = .Branch
			} else if rnd < stone_chance + branch_chance {
				tiles[i][j] = .Stone
			} else if rnd < stone_chance + branch_chance + wall_chance {
				tiles[i][j] = .Wall
			} else if rnd < stone_chance + branch_chance + wall_chance + tree_chance {
				tiles[i][j] = .Tree
			} else {
				tiles[i][j] = .Empty
			}
		}
	}
	// UI
	inventory_open = false
	style = game.style
}

world_handle_input :: proc(game: ^Game) {
	using game.world

	if rl.IsKeyPressed(.I) {
		inventory_open = !inventory_open
	}
}

world_draw_inventory :: proc(game: ^Game) {
	using game.world
	if inventory_open {
		branches := player.inventory.branches
		stones := player.inventory.stones
		sg.begin_gui(&style)
    	sg.begin_box(layout = .Grid, cols = 2, spacing = 2, place = sg.Place_xy{.Left, .Top})
    		sg.label("Stones:", width = .Fit_Content)
    		buf: [8]byte
			ststr := strconv.write_int(buf[:], i64(stones), 10)
			ststrc := strings.clone_to_cstring(ststr)
			sg.label(text = ststrc,  width = .Fit_Content)
			sg.label("Branches:", width = .Fit_Content)
			brstr := strconv.write_int(buf[:], i64(branches), 10)
			brstrc := strings.clone_to_cstring(brstr)
			sg.label(text = brstrc,  width = .Fit_Content)
		sg.end_box()
		sg.end_gui()
	}
}

world_draw :: proc(game: ^Game) {
	using game.world

	rl.ClearBackground(rl.BLACK)
	
	// player movement
	player.vel.x = 0
	player.vel.y = 0
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		player.vel.x = -PLAYER_SPEED
		player.flip = true
	} 
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		player.vel.x = PLAYER_SPEED
		player.flip = false
	} 
	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		player.vel.y = -PLAYER_SPEED
	} 
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		player.vel.y = PLAYER_SPEED
	} 	
	if player.vel.x != 0 && player.vel.y != 0 {
    	player.vel = rl.Vector2Normalize(player.vel) * PLAYER_SPEED
	}
	if player.has_goto {
		dir := rl.Vector2Normalize(player.goto_pos - player.pos)
		player.vel = dir * PLAYER_SPEED
		if distance(player.pos, player.goto_pos) < 5 {
        	player.has_goto = false // reached target
        }
	}

	if player.has_path && len(player.goto_path) > 0 {
		target := player.goto_path[0]
    	dir := rl.Vector2Normalize(target - player.pos)
    	player.vel = dir * PLAYER_SPEED

    	if distance(player.pos, target) < 5 {
        	// Reached this waypoint
        	ordered_remove(&player.goto_path, 0)
       		if len(player.goto_path) == 0 {
            	player.has_goto = false
            	delete(player.goto_path)  // the path was allocated on the heap by the find_path() procedure and has to be deleted
        	}
    	}
	}

	// camera movement
	camera := rl.Camera2D{
    	target = player.pos,
    	offset = centre,
    	zoom = 1,
    	rotation = 0,
	}

	rl.BeginMode2D(camera)
	
	mp_screen := rl.GetMousePosition()
	mp_world := rl.GetScreenToWorld2D(mp_screen, camera)

	//draw map
	texture: rl.Texture

	start_tile_x := i32(camera.target.x - centre.x) / TILE_SIZE 
	start_tile_x = clamp(start_tile_x, 0,  WORLD_SIZE - 1)

	start_tile_y := i32(camera.target.y - centre.y) / TILE_SIZE
	start_tile_y = clamp(start_tile_y, 0, WORLD_SIZE - 1)

	end_tile_x := i32(camera.target.x + centre.x) / TILE_SIZE + 1
	end_tile_x = clamp(end_tile_x, 0, WORLD_SIZE - 1)

	end_tile_y := i32(camera.target.y + centre.y) / TILE_SIZE + 1
	end_tile_y = clamp(end_tile_y, 0, WORLD_SIZE - 1)

	//player_tile_x := (i32(player.pos.x) + screen_width / 2) / TILE_SIZE
	//player_tile_y := (i32(player.pos.y) + screen_height / 2) / TILE_SIZE

	for i in start_tile_x ..< end_tile_x {
		for j in start_tile_y ..< end_tile_y {
			entity := tiles[i][j]
			switch entity {
			case .Empty:
				texture = texture_empty
			case .Branch:
				texture = texture_branch
			case .Stone:
				texture = texture_stone
			case .Wall:
				texture = texture_wall
			case .Tree:
				texture = texture_tree
			}
			tpos: rl.Vector2
			tpos.x = f32(i * TILE_SIZE)
			tpos.y = f32(j * TILE_SIZE)
			rl.DrawTextureEx(texture, tpos, 0, 1, rl.WHITE)
			trect: rl.Rectangle
			trect.x = f32(i * TILE_SIZE)
			trect.y = f32(j * TILE_SIZE)
			trect.width = TILE_SIZE
			trect.height = TILE_SIZE
		}
	} 

	// mouse on hover and interaction with entities
	mouse_tile_x := int(mp_world.x / TILE_SIZE)
	mouse_tile_y := int(mp_world.y / TILE_SIZE)
	mouse_tile_x = clamp(mouse_tile_x, 0, int(WORLD_SIZE - 1))
	mouse_tile_y = clamp(mouse_tile_y, 0, int(WORLD_SIZE - 1))

	// the rect of the tile the mouse is hovering over
	mouse_rect := rl.Rectangle {
		x = f32(mouse_tile_x * TILE_SIZE),
		y = f32(mouse_tile_y * TILE_SIZE),
		width = TILE_SIZE,
		height = TILE_SIZE,
	}

	if (tiles[mouse_tile_x][mouse_tile_y] == .Stone || tiles[mouse_tile_x][mouse_tile_y] == .Branch) {

		mouse_tile_center := rl.Vector2 {
			f32(mouse_tile_x * TILE_SIZE + TILE_SIZE/2),
			f32(mouse_tile_y * TILE_SIZE + TILE_SIZE/2),
		}

		dist := distance(mouse_tile_center, player.pos)
		if dist < PLAYER_REACH {
			rl.DrawRectangleLinesEx(rec = mouse_rect, lineThick = 3, color = rl.ORANGE)
			if (rl.IsMouseButtonPressed(.LEFT)) {
				if tiles[mouse_tile_x][mouse_tile_y] == .Stone {
   					player.inventory.stones += 1
				} else if tiles[mouse_tile_x][mouse_tile_y] == .Branch {
    				player.inventory.branches += 1
				}
				tiles[mouse_tile_x][mouse_tile_y] = .Empty
			}
		}
	}

	// click-to-move logic
	if rl.IsMouseButtonPressed(.LEFT) && tiles[mouse_tile_x][mouse_tile_y] != .Wall {
    	player.goto_pos = mp_world
    	player.has_goto = true
    	if len(player.goto_path) > 0 {
        	delete(player.goto_path)
    	}
    	player.has_path = false
	}

	// click-to-move logic with pathing
	if rl.IsMouseButtonPressed(.RIGHT) && tiles[mouse_tile_x][mouse_tile_y] != .Wall {
		if len(player.goto_path) > 0 {
        	delete(player.goto_path)
    	}
		player.goto_path = find_path(tiles[:][:], player.pos, mp_world)
    	player.has_path = true
    	player.has_goto = false
	}

	// collision detection and make entities.wall not possible to walk through
	next_pos := player.pos + player.vel * rl.GetFrameTime()

	tile_x := int(next_pos.x / TILE_SIZE)
	tile_y := int(next_pos.y / TILE_SIZE)
	if tiles[tile_x][tile_y] != .Wall {
    	player.pos = next_pos
	}

	// make it impossible to walk outside the world borders
	player.pos.x = clamp(player.pos.x, 0, f32(WORLD_SIZE * TILE_SIZE - player.width))
	player.pos.y = clamp(player.pos.y, 0, f32(WORLD_SIZE * TILE_SIZE - player.height))

	//draw player
	draw_pos := rl.Vector2{player.pos.x - f32(player.width) / 2.0, player.pos.y - f32(player.height) / 2.0}
	animation_draw(&player.run, draw_pos, player.flip)
	rl.EndMode2D()

	world_draw_inventory(game)
}

world_save :: proc(world: ^World) {
	using world
	//Todo: save serialize world state, stones, braches, player position and inventory etc
	// json?
}

world_load :: proc(world: ^World) {
	using world
	//todo: load deserialize world state, stones, braches, player position and inventory etc
	// json?
}
