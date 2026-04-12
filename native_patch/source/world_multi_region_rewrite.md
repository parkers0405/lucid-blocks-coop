# Multi-Region `World` Rewrite

This is a source-level patch draft against the owner-shared `World` implementation.

It aims to keep one authoritative world while allowing the loaded chunk set to be the
union of multiple player-centered bubbles.

## Header additions

Add these members and method declarations to `World`:

```cpp
    // Compatibility: keep center_chunk for old code paths, but drive loading from all centers.
    TypedArray<Vector3i> loaded_region_centers;

    Chunk* create_chunk_instance();
    void set_loaded_region_centers(TypedArray<Vector3> centers);
    bool is_chunk_in_radius_of(Vector3i center, Vector3i coordinate, int64_t radius);
    bool is_chunk_in_any_radius(Vector3i coordinate, int64_t radius);
```

## `_bind_methods()` addition

```cpp
    ClassDB::bind_method(D_METHOD("set_loaded_region_centers", "centers"), &World::set_loaded_region_centers);
```

## `instantiate_chunks()` replacement

This keeps the existing chunk pool behavior but uses a helper so the pool can later grow
when multiple far-apart bubbles need more chunks.

```cpp
Chunk* World::create_chunk_instance() {
    Chunk* new_chunk = memnew(Chunk);

    add_child(new_chunk);

    new_chunk->world = this;

    new_chunk->block_types = block_types;
    new_chunk->is_block_foliage = is_block_foliage;
    new_chunk->is_block_floating_foliage = is_block_floating_foliage;
    new_chunk->is_block_transparent = is_block_transparent;
    new_chunk->is_block_living = is_block_living;
    new_chunk->is_block_internal = is_block_internal;
    new_chunk->is_block_top_face_randomized = is_block_top_face_randomized;
    new_chunk->biome_height_map = generator->biome_height_map;

    new_chunk->block_material = block_material;
    new_chunk->transparent_block_material = transparent_block_material;
    new_chunk->foliage_mesh->set_material_override(foliage_material);
    new_chunk->water_mesh->set_material_override(water_material);
    new_chunk->water_mesh_surface->set_material_override(water_surface_material);

    new_chunk->mark_as_garbage();
    new_chunk->set_visible(false);
    new_chunk->set_position(Vector3i(0, 0, 0));

    all_chunks.push_back(new_chunk);
    return new_chunk;
}

void World::instantiate_chunks() {
    const int max_render_distance = 96;

    all_chunks.clear();
    center_chunk = Vector3i(0, 0, 0);
    loaded_region_centers.clear();
    loaded_region_centers.push_back(center_chunk);

    int64_t max_y = max_render_distance / Chunk::CHUNK_SIZE_Y; int64_t min_y = -max_y;
    int64_t max_x = max_render_distance / Chunk::CHUNK_SIZE_X; int64_t min_x = -max_x;
    int64_t max_z = max_render_distance / Chunk::CHUNK_SIZE_Z; int64_t min_z = -max_z;
    for (int64_t chunk_y = min_y; chunk_y <= max_y; chunk_y++) {
    for (int64_t chunk_x = min_x; chunk_x <= max_x; chunk_x++) {
    for (int64_t chunk_z = min_z; chunk_z <= max_z; chunk_z++) {
        Vector3i coordinate = center_chunk + Vector3i(Chunk::CHUNK_SIZE_X * chunk_x, Chunk::CHUNK_SIZE_Y * chunk_y, Chunk::CHUNK_SIZE_Z * chunk_z);
        if (!is_chunk_in_radius(coordinate, max_render_distance)) {
            continue;
        }

        Chunk* new_chunk = create_chunk_instance();
        new_chunk->set_position(coordinate);
    }
    }
    }

    UtilityFunctions::print("Chunks instantiated.");
}
```

## Radius helpers

```cpp
bool World::is_chunk_in_radius(Vector3i coordinate, int64_t radius) {
    return is_chunk_in_radius_of(center_chunk, coordinate, radius);
}

bool World::is_chunk_in_radius_of(Vector3i center, Vector3i coordinate, int64_t radius) {
    return (center - coordinate).length_squared() < radius * radius;
}

bool World::is_chunk_in_any_radius(Vector3i coordinate, int64_t radius) {
    if (loaded_region_centers.size() == 0) {
        return is_chunk_in_radius_of(center_chunk, coordinate, radius);
    }

    for (int i = 0; i < loaded_region_centers.size(); i++) {
        Vector3i active_center = loaded_region_centers[i];
        if (is_chunk_in_radius_of(active_center, coordinate, radius)) {
            return true;
        }
    }

    return false;
}
```

## `set_loaded_region_center()` and new `set_loaded_region_centers()`

```cpp
void World::set_loaded_region_center(Vector3 new_center) {
    TypedArray<Vector3> centers;
    centers.push_back(new_center);
    set_loaded_region_centers(centers);
}

void World::set_loaded_region_centers(TypedArray<Vector3> centers) {
    TypedDictionary<Vector3i, bool> unique_centers;
    TypedArray<Vector3i> snapped_centers;

    for (int i = 0; i < centers.size(); i++) {
        Vector3i snapped = snap_to_chunk(centers[i]);
        if (unique_centers.has(snapped)) {
            continue;
        }
        unique_centers[snapped] = true;
        snapped_centers.push_back(snapped);
    }

    if (snapped_centers.size() == 0) {
        snapped_centers.push_back(center_chunk);
    }

    bool changed = snapped_centers.size() != loaded_region_centers.size();
    if (!changed) {
        for (int i = 0; i < snapped_centers.size(); i++) {
            if (Vector3i(snapped_centers[i]) != Vector3i(loaded_region_centers[i])) {
                changed = true;
                break;
            }
        }
    }

    if (changed || !all_loaded) {
        loaded_region_centers = snapped_centers;
        center_chunk = loaded_region_centers[0];
        all_loaded = false;
        update_loaded_region();
    }
}
```

## `update_loaded_region()` replacement

```cpp
void World::update_loaded_region() {
    if (has_task) {
        if (!WorkerThreadPool::get_singleton()->is_group_task_completed(task_id)) {
            return;
        }
        WorkerThreadPool::get_singleton()->wait_for_group_task_completion(task_id);
        has_task = false;
    }

    init_queue.clear();
    init_queue_positions.clear();

    if (loaded_region_centers.size() == 0) {
        loaded_region_centers.push_back(center_chunk);
    }
    center_chunk = loaded_region_centers[0];

    bool all_decorations_generated = true;
    bool all_structures_generated = true;

    TypedArray<Vector3i> decorated_vectors = decoration_map.keys();
    for (int i = 0; i < decorated_vectors.size(); i++) {
        Vector3i key = decorated_vectors[i];
        if (!is_chunk_in_any_radius(key, instance_radius * 2)) {
            decoration_map.erase(key);
            decoration_count.erase(key);
            if (decoration_generated.has(key)) {
                decoration_generated.erase(key);
            }
        }
    }

    TypedArray<Vector3i> structured_vectors = structure_map.keys();
    for (int i = 0; i < structured_vectors.size(); i++) {
        Vector3i key = structured_vectors[i];
        if (!is_chunk_in_any_radius(key, 2 * STRUCTURE_SIZE + instance_radius)) {
            structure_map.erase(key);
        }
    }

    int64_t deco_radius_x = 2 + instance_radius / Chunk::CHUNK_SIZE_X;
    int64_t deco_radius_y = 2 + instance_radius / Chunk::CHUNK_SIZE_Y;
    int64_t deco_radius_z = 2 + instance_radius / Chunk::CHUNK_SIZE_Z;
    TypedDictionary<Vector3i, bool> seen_coordinates;

    for (int center_index = 0; center_index < loaded_region_centers.size(); center_index++) {
        Vector3i active_center = loaded_region_centers[center_index];
        for (int64_t y = -deco_radius_y; y <= deco_radius_y; y++) {
        for (int64_t x = -deco_radius_x; x <= deco_radius_x; x++) {
        for (int64_t z = -deco_radius_z; z <= deco_radius_z; z++) {
            Vector3i coordinate = Vector3i(Chunk::CHUNK_SIZE_X * x, Chunk::CHUNK_SIZE_Y * y, Chunk::CHUNK_SIZE_Z * z) + active_center;
            if (seen_coordinates.has(coordinate)) {
                continue;
            }
            seen_coordinates[coordinate] = true;

            if (!decoration_map.has(coordinate)) {
                Array decoration_array;
                decoration_array.resize(MAX_DECORATIONS);
                decoration_map[coordinate] = decoration_array;
                decoration_count[coordinate] = 0;
            }
        }
        }
        }
    }

    deco_radius_x = 1 + instance_radius / Chunk::CHUNK_SIZE_X;
    deco_radius_y = 1 + instance_radius / Chunk::CHUNK_SIZE_Y;
    deco_radius_z = 1 + instance_radius / Chunk::CHUNK_SIZE_Z;
    seen_coordinates.clear();

    for (int center_index = 0; center_index < loaded_region_centers.size(); center_index++) {
        Vector3i active_center = loaded_region_centers[center_index];
        for (int64_t y = -deco_radius_y; y <= deco_radius_y; y++) {
        for (int64_t x = -deco_radius_x; x <= deco_radius_x; x++) {
        for (int64_t z = -deco_radius_z; z <= deco_radius_z; z++) {
            Vector3i coordinate = Vector3i(Chunk::CHUNK_SIZE_X * x, Chunk::CHUNK_SIZE_Y * y, Chunk::CHUNK_SIZE_Z * z) + active_center;
            Vector3i structure_coordinate = snap_to_nearest_structure(coordinate);
            if (seen_coordinates.has(structure_coordinate)) {
                continue;
            }
            seen_coordinates[structure_coordinate] = true;

            if (!structure_map.has(structure_coordinate)) {
                all_structures_generated = false;
                init_queue_positions.push_back(structure_coordinate);
                structure_map[structure_coordinate] = nullptr;
            }
        }
        }
        }
    }

    if (all_structures_generated) {
        seen_coordinates.clear();
        for (int center_index = 0; center_index < loaded_region_centers.size(); center_index++) {
            Vector3i active_center = loaded_region_centers[center_index];
            for (int64_t y = -deco_radius_y; y <= deco_radius_y; y++) {
            for (int64_t x = -deco_radius_x; x <= deco_radius_x; x++) {
            for (int64_t z = -deco_radius_z; z <= deco_radius_z; z++) {
                Vector3i coordinate = Vector3i(Chunk::CHUNK_SIZE_X * x, Chunk::CHUNK_SIZE_Y * y, Chunk::CHUNK_SIZE_Z * z) + active_center;

                if (!is_chunk_in_radius_of(active_center, coordinate, instance_radius + Chunk::CHUNK_SIZE_X)) {
                    continue;
                }
                if (seen_coordinates.has(coordinate) || decoration_generated.has(coordinate)) {
                    continue;
                }

                seen_coordinates[coordinate] = true;
                decoration_generated[coordinate] = false;
                all_decorations_generated = false;
                init_queue_positions.push_back(coordinate);
            }
            }
            }
        }
    }

    if (all_structures_generated && all_decorations_generated) {
        std::vector<Chunk*> available_chunks;
        for (uint64_t i = 0; i < all_chunks.size(); i++) {
            Chunk* chunk = all_chunks[i];
            Vector3i coordinate = Vector3i(chunk->get_position());
            if (chunk->garbage || !is_chunk_in_any_radius(coordinate, instance_radius)) {
                available_chunks.push_back(chunk);
            }
        }

        TypedDictionary<Vector3i, bool> queued_chunk_coordinates;
        for (int64_t chunk_y = 0; chunk_y <= 2 * instance_radius / Chunk::CHUNK_SIZE_Y - 2; chunk_y++) {
            int64_t actual_chunk_y = (chunk_y % 2 == 0) ? -chunk_y / 2 : (chunk_y + 1) / 2;

        for (int64_t chunk_x = 0; chunk_x <= 2 * instance_radius / Chunk::CHUNK_SIZE_X; chunk_x++) {
            int64_t actual_chunk_x = (chunk_x % 2 == 0) ? -chunk_x / 2 : (chunk_x + 1) / 2;

        for (int64_t chunk_z = 0; chunk_z <= 2 * instance_radius / Chunk::CHUNK_SIZE_Z; chunk_z++) {
            int64_t actual_chunk_z = (chunk_z % 2 == 0) ? -chunk_z / 2 : (chunk_z + 1) / 2;
            Vector3i offset = Vector3i(
                Chunk::CHUNK_SIZE_X * actual_chunk_x,
                Chunk::CHUNK_SIZE_Y * actual_chunk_y,
                Chunk::CHUNK_SIZE_Z * actual_chunk_z);

            for (int center_index = 0; center_index < loaded_region_centers.size(); center_index++) {
                Vector3i active_center = loaded_region_centers[center_index];
                Vector3i coordinate = offset + active_center;

                if (!is_chunk_in_radius_of(active_center, coordinate, instance_radius)) {
                    continue;
                }
                if (queued_chunk_coordinates.has(coordinate) || is_chunk_loaded.has(coordinate)) {
                    continue;
                }

                queued_chunk_coordinates[coordinate] = true;

                if (available_chunks.size() == 0) {
                    Chunk* extra_chunk = create_chunk_instance();
                    extra_chunk->mark_as_garbage();
                    available_chunks.push_back(extra_chunk);
                }

                Chunk* new_chunk = available_chunks.back();
                available_chunks.pop_back();

                if (!new_chunk->garbage) {
                    unload_chunk(new_chunk);
                }

                new_chunk->set_position(coordinate);
                new_chunk->mark_as_used();

                init_queue.push_back(new_chunk);
                init_queue_positions.push_back(coordinate);
                is_chunk_loaded[coordinate] = false;
                chunk_map[coordinate] = new_chunk;
            }
        }
        }
        }

        for (int i = 0; i < (int)available_chunks.size(); i++) {
            Chunk* chunk = available_chunks[i];
            if (chunk->garbage) {
                continue;
            }
            chunk->mark_as_garbage();
            unload_chunk(chunk);
        }

        if (init_queue.size() > 0) {
            has_task = true;
            task_id = WorkerThreadPool::get_singleton()->add_group_task(callable_mp(this, &World::initialize_chunk), init_queue.size());
        } else {
            all_loaded = true;
            call_deferred("emit_signal", "all_loaded");
        }
    } else if (all_structures_generated) {
        if (init_queue_positions.size() > 0) {
            has_task = true;
            task_id = WorkerThreadPool::get_singleton()->add_group_task(callable_mp(this, &World::initialize_chunk_decorations), init_queue_positions.size());
        }
    } else {
        if (init_queue_positions.size() > 0) {
            has_task = true;
            task_id = WorkerThreadPool::get_singleton()->add_group_task(callable_mp(this, &World::initialize_structure), init_queue_positions.size());
        }
    }
}
```

## `simulate_dynamic()` replacement

This keeps the existing staggered water/fire behavior, but applies it to the union of all active centers.

```cpp
void World::simulate_dynamic() {
    if (loaded_region_centers.size() == 0) {
        loaded_region_centers.push_back(center_chunk);
    }
    center_chunk = loaded_region_centers[0];

    simulated_water_subchunks = 0;
    int simulated_chunks = 0;
    int rendered_chunks = 0;

    TypedDictionary<Vector3i, bool> touched_chunks;

    for (int64_t chunk_y = 0; chunk_y <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Y; chunk_y++) {
        int64_t actual_chunk_y = (chunk_y % 2 == 0) ? -chunk_y / 2 : (chunk_y + 1) / 2;
        if ((water_direction / 2) % 2) actual_chunk_y = -actual_chunk_y;

    for (int64_t chunk_x = 0; chunk_x <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_X; chunk_x++) {
        int64_t actual_chunk_x = (chunk_x % 2 == 0) ? -chunk_x / 2 : (chunk_x + 1) / 2;
        if (water_direction % 2) actual_chunk_x = -actual_chunk_x;

    for (int64_t chunk_z = 0; chunk_z <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Z; chunk_z++) {
        int64_t actual_chunk_z = (chunk_z % 2 == 0) ? -chunk_z / 2 : (chunk_z + 1) / 2;
        if ((water_direction / 4) % 2) actual_chunk_z = -actual_chunk_z;

        if ((int64_t) UtilityFunctions::abs(chunk_x + chunk_y + chunk_x) % WATER_SKIP != water_frame) {
            continue;
        }
        if (actual_chunk_x * actual_chunk_x + actual_chunk_y * actual_chunk_y + actual_chunk_z * actual_chunk_z >= 6 && UtilityFunctions::randf() < 0.75) {
            continue;
        }

        Vector3i offset = Vector3i(
            Chunk::CHUNK_SIZE_X * actual_chunk_x,
            Chunk::CHUNK_SIZE_Y * actual_chunk_y,
            Chunk::CHUNK_SIZE_Z * actual_chunk_z);

        for (int center_index = 0; center_index < loaded_region_centers.size(); center_index++) {
            Vector3i active_center = loaded_region_centers[center_index];
            Vector3i coordinate = offset + active_center;

            if (!is_chunk_in_radius_of(active_center, coordinate, water_simulate_radius)) {
                continue;
            }
            if (touched_chunks.has(coordinate)) {
                continue;
            }
            touched_chunks[coordinate] = true;

            if (!is_chunk_loaded.has(coordinate) || !is_chunk_loaded[coordinate]) {
                continue;
            }

            Chunk* chunk = Object::cast_to<Chunk>(chunk_map[coordinate]);
            chunk->simulate_water();
            chunk->simulate_fire();
            simulated_chunks++;
        }
    }
    }
    }

    rendered_water_chunks = 0;
    touched_chunks.clear();
    for (int64_t chunk_y = 0; chunk_y <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Y; chunk_y++) {
        int64_t actual_chunk_y = (chunk_y % 2 == 0) ? -chunk_y / 2 : (chunk_y + 1) / 2;
        if ((water_direction / 2) % 2) actual_chunk_y = -actual_chunk_y;

    for (int64_t chunk_x = 0; chunk_x <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_X; chunk_x++) {
        int64_t actual_chunk_x = (chunk_x % 2 == 0) ? -chunk_x / 2 : (chunk_x + 1) / 2;
        if (water_direction % 2) actual_chunk_x = -actual_chunk_x;

    for (int64_t chunk_z = 0; chunk_z <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Z; chunk_z++) {
        int64_t actual_chunk_z = (chunk_z % 2 == 0) ? -chunk_z / 2 : (chunk_z + 1) / 2;
        if ((water_direction / 4) % 2) actual_chunk_z = -actual_chunk_z;

        Vector3i offset = Vector3i(
            Chunk::CHUNK_SIZE_X * actual_chunk_x,
            Chunk::CHUNK_SIZE_Y * actual_chunk_y,
            Chunk::CHUNK_SIZE_Z * actual_chunk_z);

        for (int center_index = 0; center_index < loaded_region_centers.size(); center_index++) {
            Vector3i active_center = loaded_region_centers[center_index];
            Vector3i coordinate = offset + active_center;

            if (!is_chunk_in_radius_of(active_center, coordinate, water_simulate_radius)) {
                continue;
            }
            if (touched_chunks.has(coordinate)) {
                continue;
            }
            touched_chunks[coordinate] = true;

            if (!is_chunk_loaded.has(coordinate) || !is_chunk_loaded[coordinate]) {
                continue;
            }

            Chunk* chunk = Object::cast_to<Chunk>(chunk_map[coordinate]);

            if (chunk->water_updated > 0) {
                if (rendered_water_chunks >= MAX_WATER_RERENDERED_CHUNKS_PER_FRAME && chunk->water_render_wait < 4) {
                    chunk->water_render_wait++;
                    continue;
                }

                if (actual_chunk_x * actual_chunk_x + actual_chunk_y * actual_chunk_y + actual_chunk_z * actual_chunk_z >= 4 && UtilityFunctions::randf() < 0.5) {
                    chunk->water_render_wait++;
                    continue;
                }

                rendered_chunks++;
                chunk->generate_water_mesh(false, coordinate);
                chunk->generate_water_surface_mesh(false, coordinate);
                chunk->water_updated--;
                chunk->water_render_wait = 0;
                rendered_water_chunks++;
            } else if (!chunk->water_surface_meshed) {
                rendered_chunks++;
                chunk->generate_water_surface_mesh(false, coordinate);
            }
        }
    }
    }
    }

    water_frame = (water_frame + 1) % WATER_SKIP;
    water_direction = (water_direction + 1) % 8;
}
```

## Notes

- This patch intentionally keeps `center_chunk` for compatibility, but it becomes the first active center only.
- The important semantic change is that chunk residency, decoration residency, structure residency, and water/fire simulation all switch from `center_chunk` to `loaded_region_centers` union logic.
- This rewrite also removes the single-bubble chunk pool assumption by dynamically allocating extra `Chunk` instances if the pool is exhausted.
