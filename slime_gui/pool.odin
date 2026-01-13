package slimeGUI
//import "core:fmt"

// pool, stores items in a dynamic arrays
Pool :: struct($T: typeid) {
	items: [dynamic]T,
	used: [dynamic]bool,		// mark bits (parallel to items)
	free_list: [dynamic]int,  	// indices abailable for reuse
}

Pool_iterator :: struct($T: typeid) {
	index: int,
	data: ^Pool(T),
} 

make_pool_iterator :: proc(data: ^Pool($T)) -> Pool_iterator(T) {
	return Pool_iterator(T){index = 0, data = data}
}

pool_iterator :: proc(it: ^Pool_iterator($T)) -> (val: ^T, idx: int, cond: bool) {
	cond = it.index < len(it.data.items)
	for ; cond; cond = it.index < len(it.data.items) {
		if !it.data.used[it.index] {
			it.index += 1
			continue
		}
		val = &it.data.items[it.index]
		idx = it.index
		it.index += 1
		break
	}
	return
}

// may return items with old dirty data when acquire a new item
pool_acquire :: proc(p: ^Pool($T)) -> int {
	if len(p.free_list) > 0 {
		// if available reuse old slot
		idx := pop(&p.free_list)
		p.used[idx]  = true
		return idx
	} else {
		// if a new slot is needed
		idx := len(p.items)
    	append(&p.items, T{}) 
    	append(&p.used, true)
    	return idx
	}
}

pool_append :: proc(p: ^Pool($T), val: T) -> int{
	idx := pool_acquire(p)
	p.items[idx] = val
	return idx
}

pool_release :: proc(p: ^Pool($T), idx: int) {
	if 0 <= idx && idx < len(p.items) && p.used[idx] {
        p.used[idx] = false
        append(&p.free_list, idx)
    }
}

pool_mark_clear :: proc(p: ^Pool($T)) {	
	for i in 0..<len(p.used) {
        p.used[i] = false
    }
}

// Optional: sweep everything NOT used_this_frame (if you want auto-release)
pool_sweep_unused :: proc(p: ^Pool($T)) {
	clear(&p.free_list)
    for i in 0..<len(p.items) {
        if !p.used[i] {
            // push to free list (idempotent if already there)
            append(&p.free_list, i)
        }
    }
}

Store :: struct($T: typeid) {
	using pool: Pool(T),
	//pool: Pool(T),
	id_to_idx: map[int]int,
}

store_get_or_create :: proc(store: ^Store($T), id: int) ->(^T, bool) {
	idx, found := store.id_to_idx[id]
	if found {
		store.pool.used[idx] = true
		return &store.pool.items[idx], true
	} else {
		new_idx := pool_acquire(&store.pool)
		store.id_to_idx[id] = new_idx
		return &store.pool.items[new_idx], false
	}
}  

// may return items with old dirty data when acquire a new item
store_acquire :: proc(store: ^Store($T), id: int) -> int {
	idx, found := store.id_to_idx[id]
	if found {
		store.pool.used[idx] = true
		return idx
	} else {
		new_idx := pool_acquire(&store.pool)
		store.id_to_idx[id] = new_idx
		return new_idx
	}
}

// Call this at the end of every frame
store_sweep :: proc(store: ^Store($T)) {
	// it may not be needed to make it in two steps in newer version in Odin test later with one pass
	// Collect keys safely using temp_allocator
	to_delete := make([dynamic]int, context.temp_allocator)
	for id, idx in store.id_to_idx {
        if !store.pool.used[idx] {
            append(&to_delete, id)
        }
    }
    // Delete from map
    for id in to_delete {
    	delete_key(&store.id_to_idx, id)
    }
    // Sync the pool's free_list
    pool_sweep_unused(&store.pool)
}

store_mark_clear :: proc(store: ^Store($T)) {
	pool_mark_clear(&store.pool)
}

store_sweep_mark :: proc(store: ^Store($T)) {
	store_sweep(store)
	pool_mark_clear(&store.pool)
}