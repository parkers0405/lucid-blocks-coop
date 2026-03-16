#include "../include/world.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/resource_loader.hpp>

using namespace godot;


////////////////////////
//   Initialization   //
////////////////////////


void World::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_up"), &World::start_up);
    ClassDB::bind_method(D_METHOD("initialize"), &World::initialize);
    ClassDB::bind_method(D_METHOD("create_texture_atlas"), &World::create_texture_atlas);
    ClassDB::bind_method(D_METHOD("clear"), &World::clear);
    ClassDB::bind_method(D_METHOD("is_all_loaded"), &World::is_all_loaded);
    ClassDB::bind_method(D_METHOD("set_loaded_region_center", "new_center"), &World::set_loaded_region_center);
    ClassDB::bind_method(D_METHOD("simulate_dynamic"), &World::simulate_dynamic);
    ClassDB::bind_method(D_METHOD("is_position_loaded", "position"), &World::is_position_loaded);
    ClassDB::bind_method(D_METHOD("is_position_loading", "position"), &World::is_position_loading);
    ClassDB::bind_method(D_METHOD("snap_to_chunk", "position"), &World::snap_to_chunk);
    ClassDB::bind_method(D_METHOD("get_nearest_structure", "position"), &World::get_nearest_structure);
    ClassDB::bind_method(D_METHOD("is_within_structure", "position"), &World::is_within_structure);
    ClassDB::bind_method(D_METHOD("find_closest_cutscene_block", "starting_position", "collected_blockss"), &World::find_closest_cutscene_block);
    ClassDB::bind_method(D_METHOD("is_chunk_modified", "position"), &World::is_chunk_modified);
    ClassDB::bind_method(D_METHOD("modify_chunk", "position"), &World::modify_chunk);
    ClassDB::bind_method(D_METHOD("liven_chunk", "position"), &World::liven_chunk);

    ClassDB::bind_method(D_METHOD("get_block_types"), &World::get_block_types);
	ClassDB::bind_method(D_METHOD("set_block_types", "new_block_types"), &World::set_block_types);

    ClassDB::bind_method(D_METHOD("get_decorations"), &World::get_decorations);
	ClassDB::bind_method(D_METHOD("set_decorations", "new_block_types"), &World::set_decorations);

    ClassDB::bind_method(D_METHOD("get_block_material"), &World::get_block_material);
	ClassDB::bind_method(D_METHOD("set_block_material", "new_material"), &World::set_block_material);

    ClassDB::bind_method(D_METHOD("get_foliage_material"), &World::get_foliage_material);
	ClassDB::bind_method(D_METHOD("set_foliage_material", "new_material"), &World::set_foliage_material);

    ClassDB::bind_method(D_METHOD("get_water_material"), &World::get_water_material);
	ClassDB::bind_method(D_METHOD("set_water_material", "new_material"), &World::set_water_material);

    ClassDB::bind_method(D_METHOD("get_water_surface_material"), &World::get_water_surface_material);
	ClassDB::bind_method(D_METHOD("set_water_surface_material", "new_material"), &World::set_water_surface_material);

    ClassDB::bind_method(D_METHOD("get_transparent_block_material"), &World::get_transparent_block_material);
	ClassDB::bind_method(D_METHOD("set_transparent_block_material", "new_material"), &World::set_transparent_block_material);

    ClassDB::bind_method(D_METHOD("get_instance_radius"), &World::get_instance_radius);
	ClassDB::bind_method(D_METHOD("set_instance_radius", "new_radius"), &World::set_instance_radius);

    ClassDB::bind_method(D_METHOD("get_generator"), &World::get_generator);
	ClassDB::bind_method(D_METHOD("set_generator", "new_generator"), &World::set_generator);

    ClassDB::bind_method(D_METHOD("save_data", "data", "prefix"), &World::save_data);
	ClassDB::bind_method(D_METHOD("load_data", "data", "prefix"), &World::load_data);

	ClassDB::bind_method(D_METHOD("get_block_type_at", "position"), &World::get_block_type_at);
    ClassDB::bind_method(D_METHOD("is_block_solid_at", "position"), &World::is_block_solid_at);
    ClassDB::bind_method(D_METHOD("break_block_at", "position", "play_effect", "override_restrictions"), &World::break_block_at);
    ClassDB::bind_method(D_METHOD("explode_at", "position", "radius", "firey"), &World::explode_at);
    ClassDB::bind_method(D_METHOD("flood_at", "position"), &World::flood_at);

    ClassDB::bind_method(D_METHOD("place_block_at", "position", "block_type", "play_effect", "immediate_remesh"), &World::place_block_at);
    ClassDB::bind_method(D_METHOD("place_water_at", "position", "amount"), &World::place_water_at);
    ClassDB::bind_method(D_METHOD("get_water_level_at", "position"), &World::get_water_level);
    ClassDB::bind_method(D_METHOD("is_under_water", "position"), &World::is_under_water);
    ClassDB::bind_method(D_METHOD("place_fire_at", "position", "amount"), &World::place_fire_at);
    ClassDB::bind_method(D_METHOD("get_fire_at", "position"), &World::get_fire_at);
    ClassDB::bind_method(D_METHOD("fire_eligible", "position"), &World::fire_eligible);

    ClassDB::bind_method(D_METHOD("register_living_block", "position", "living_block"), &World::register_living_block);
    ClassDB::bind_method(D_METHOD("unregister_living_block", "position"), &World::unregister_living_block);
    ClassDB::bind_method(D_METHOD("get_living_block_at", "position"), &World::get_living_block_at);

    ClassDB::bind_method(D_METHOD("get_requires_texture_atlas"), &World::get_requires_texture_atlas);
	ClassDB::bind_method(D_METHOD("set_requires_texture_atlas", "new_array"), &World::set_requires_texture_atlas);

    ClassDB::bind_method(D_METHOD("set_block_indices"), &World::set_block_indices);
    ClassDB::bind_method(D_METHOD("set_fusion_table", "array", "width"), &World::set_fusion_table);

    ClassDB::bind_method(D_METHOD("set_debug_stall", "value"), &World::set_debug_stall);
    ClassDB::bind_method(D_METHOD("get_debug_stall"), &World::get_debug_stall);

    ADD_PROPERTY(
        PropertyInfo(Variant::BOOL, "debug_stall"),
        "set_debug_stall",
        "get_debug_stall"
    );

    ClassDB::bind_method(D_METHOD("force_reload"), &World::force_reload);

    ADD_PROPERTY(
        PropertyInfo(Variant::OBJECT, "generator", PROPERTY_HINT_RESOURCE_TYPE, "Generator"),
        "set_generator",
        "get_generator"
    );

    ADD_PROPERTY(
        PropertyInfo(Variant::OBJECT, "block_material", PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"),
        "set_block_material",
        "get_block_material"
    );

    ADD_PROPERTY(
        PropertyInfo(Variant::OBJECT, "foliage_material", PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"),
        "set_foliage_material",
        "get_foliage_material"
    );

    ADD_PROPERTY(
        PropertyInfo(Variant::OBJECT, "water_material", PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"),
        "set_water_material",
        "get_water_material"
    );

    ADD_PROPERTY(
        PropertyInfo(Variant::OBJECT, "water_surface_material", PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"),
        "set_water_surface_material",
        "get_water_surface_material"
    );

    ADD_PROPERTY(
        PropertyInfo(Variant::OBJECT, "transparent_block_material", PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"),
        "set_transparent_block_material",
        "get_transparent_block_material"
    );

    ADD_PROPERTY(PropertyInfo(Variant::INT, "instance_radius"), "set_instance_radius", "get_instance_radius");

    ADD_PROPERTY(
        PropertyInfo(Variant::ARRAY, "requires_texture_atlas", PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"),
        "set_requires_texture_atlas",
        "get_requires_texture_atlas"
    );

    ADD_SIGNAL(MethodInfo("fire_spread", PropertyInfo(Variant::VECTOR3, "position")));
    ADD_SIGNAL(MethodInfo("block_placed", PropertyInfo(Variant::VECTOR3, "position")));
    ADD_SIGNAL(MethodInfo("block_broken", PropertyInfo(Variant::VECTOR3, "position")));
    ADD_SIGNAL(MethodInfo("chunk_loaded", PropertyInfo(Variant::VECTOR3I, "position")));
    ADD_SIGNAL(MethodInfo("chunk_unloaded", PropertyInfo(Variant::VECTOR3I, "position")));
    ADD_SIGNAL(MethodInfo("all_loaded"));
}

World::World() { }

World::~World() { }

void World::set_block_indices() {
    for (int64_t i = 0; i < block_types.size(); i++) {
        Ref<Block> block = block_types[i];
        block->index = i;
    }
}

// We need a separate method because of some loading issues in Godot
void World::start_up() {
    break_effect_scene = ResourceLoader::get_singleton()->load("res://main/world/rendering/break_effect/break_effect.tscn");
    place_effect_scene = ResourceLoader::get_singleton()->load("res://main/world/rendering/place_effect/place_effect.tscn");
    fire_visual_scene = ResourceLoader::get_singleton()->load("res://main/world/rendering/fire_visual/fire_visual.tscn");

    is_block_foliage.resize(block_types.size());
    is_block_floating_foliage.resize(block_types.size());
    is_block_transparent.resize(block_types.size());
    is_block_living.resize(block_types.size());
    is_block_internal.resize(block_types.size());
    is_block_top_face_randomized.resize(block_types.size());
    block_index_to_id_map.resize(block_types.size());

    for (int64_t i = 0; i < block_types.size(); i++) {
        Ref<Block> block = block_types[i];
        int index = block->index; // (equal to i)     
        block_id_to_index_map[block->get_id()] = index;
        block_index_to_id_map[index] = block->get_id();
        block_name_map[block->get_internal_name()] = index;
        is_block_foliage[index] = block->foliage;
        is_block_floating_foliage[index] = block->foliage_can_float;
        is_block_transparent[index] = block->transparent;
        is_block_living[index] = block->living_block_scene_path != "";
        is_block_internal[index] = block->internal;
        is_block_top_face_randomized[index] = block->top_face_random;
    }
    
    for (int64_t i = 0; i < decorations.size(); i++) {
        Ref<Decoration> d = decorations[i];
        d->world = this;
        decoration_name_map[d->get_internal_name()] = d;
    }
}

// Called every time a world is loaded
void World::initialize() {
    generator->world = this;
    generator->initialize();

    instantiate_chunks();
}

void World::instantiate_chunks() {
    const int max_render_distance = 96;

    all_chunks.clear();
    center_chunk = Vector3i(0, 0, 0);

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

        Chunk* new_chunk = memnew(Chunk);

        add_child(new_chunk);

        new_chunk->set_position(coordinate);
        new_chunk->world = this;

        // Pass in several important maps/arrays (to prevent MT errors)
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
        
        all_chunks.push_back(new_chunk);
    }
    }
    }

    UtilityFunctions::print("Chunks instantiated.");
}

void World::clear() {
    for (uint64_t i = 0; i < all_chunks.size(); i++) {
        // remove_child(all_chunks[i]);
        all_chunks[i]->queue_free();
    }

    chunk_data.clear();
    chunk_water_data.clear();
    chunk_water_awake_data.clear();
    chunk_fire_data.clear();

    all_loaded = false;
    all_chunks.clear();
    is_chunk_loaded.clear();
    chunk_map.clear();
    water_frame = 0;
    simulated_water_subchunks = 0;
    rendered_water_chunks = 0;
    decoration_generated.clear();
    decoration_map.clear();
    decoration_count.clear();

    structure_map.clear();
}

void World::create_texture_atlas() {
    UtilityFunctions::print("Starting texture atlas creation...");
    TypedArray<Image> images;
    TypedArray<Image> metallic_images;
    TypedArray<Image> roughness_images;

    const int TEXTURE_SIZE = 15;

    int textures_used = 0;
    images.resize(block_types.size());
    metallic_images.resize(block_types.size());
    roughness_images.resize(block_types.size());
    for (int64_t i = 0; i < block_types.size(); i++) {
        Ref<Block> block = block_types[i];

        if (!block->textureless && !block->get_texture().is_valid()) {
            UtilityFunctions::printerr("Missing texture for block: ", block->get_name());
            block->textureless = true;
        }

        // Because block_types is ordered such that all textureless blocks are at the end, we can
        // stop immediately as soon as we see one. However, the shader clamps the index to the
        // texture array size, so we need one transparent image at the end so that nothing
        // is rendered.
        if (block->textureless) {
            Ref<Image> transparent_image = Image::create_empty(6 * TEXTURE_SIZE, TEXTURE_SIZE, false, Image::FORMAT_RGBA8);
            Ref<Image> white_image = Image::create_empty(6 * TEXTURE_SIZE, TEXTURE_SIZE, false, Image::FORMAT_RGBA8);
            white_image->fill(Color(1.0, 1.0, 1.0, 1.0));
            
            images[block->index] = transparent_image;
            metallic_images[block->index] = transparent_image;
            roughness_images[block->index] = white_image;
            textures_used++;
            break;
        }


        Ref<Image> original_image = block->get_texture()->get_image();
        
        if (original_image->get_format() != Image::FORMAT_RGBA8) {
            original_image = original_image->duplicate();
            original_image->convert(Image::FORMAT_RGBA8);
        }
        Ref<Image> normalized_image = Image::create_empty(6 * TEXTURE_SIZE, TEXTURE_SIZE, false, Image::FORMAT_RGBA8);
        normalized_image->blit_rect(original_image, Rect2i(0, 0, 6 * TEXTURE_SIZE, TEXTURE_SIZE), Vector2i());
        images[block->index] = normalized_image;

        Ref<Texture2D> metallic_texture = block->get_metallic_texture();
        if (metallic_texture.is_valid()) {
            Ref<Image> original_metal_image = block->get_metallic_texture()->get_image();
            if (original_metal_image->get_format() != Image::FORMAT_RGBA8) {
                original_metal_image = original_metal_image->duplicate();
                original_metal_image->convert(Image::FORMAT_RGBA8);
            }
            Ref<Image> normalized_metal_image = Image::create_empty(6 * TEXTURE_SIZE, TEXTURE_SIZE, false, Image::FORMAT_RGBA8);
            normalized_metal_image->blit_rect(original_metal_image, Rect2i(0, 0, 6 * TEXTURE_SIZE, TEXTURE_SIZE), Vector2i());
            metallic_images[block->index] = normalized_metal_image;
        } else {
            Ref<Image> transparent_image = Image::create_empty(6 * TEXTURE_SIZE, TEXTURE_SIZE, false, Image::FORMAT_RGBA8);
            metallic_images[block->index] = transparent_image;
        }

        Ref<Texture2D> roughness_texture = block->roughness_texture;
        if (roughness_texture.is_valid()) {
            Ref<Image> original_roughness_image = block->roughness_texture->get_image();
            if (original_roughness_image->get_format() != Image::FORMAT_RGBA8) {
                original_roughness_image = original_roughness_image->duplicate();
                original_roughness_image->convert(Image::FORMAT_RGBA8);
            }
            Ref<Image> normalized_roughness_image = Image::create_empty(6 * TEXTURE_SIZE, TEXTURE_SIZE, false, Image::FORMAT_RGBA8);
            normalized_roughness_image->blit_rect(original_roughness_image, Rect2i(0, 0, 6 * TEXTURE_SIZE, TEXTURE_SIZE), Vector2i());
            roughness_images[block->index] = normalized_roughness_image;
        } else {
            Ref<Image> white_image = Image::create_empty(6 * TEXTURE_SIZE, TEXTURE_SIZE, false, Image::FORMAT_RGBA8);
            white_image->fill(Color(1.0, 1.0, 1.0, 1.0));
            roughness_images[block->index] = white_image;
        }

        textures_used++;
    }

    images.resize(textures_used);
    metallic_images.resize(textures_used);
    roughness_images.resize(textures_used);

    UtilityFunctions::print("Block texture array size: ", images.size());

    Ref<Texture2DArray> atlas = memnew(Texture2DArray);
    Ref<Texture2DArray> metallic_atlas = memnew(Texture2DArray);
    Ref<Texture2DArray> roughness_atlas = memnew(Texture2DArray);
    atlas->create_from_images(images);
    metallic_atlas->create_from_images(metallic_images);
    roughness_atlas->create_from_images(roughness_images);

    requires_texture_atlas.push_back(block_material);
    requires_texture_atlas.push_back(transparent_block_material);
    requires_texture_atlas.push_back(foliage_material);
    for (int i = 0; i < requires_texture_atlas.size(); i++) {
        Ref<ShaderMaterial> material = requires_texture_atlas[i];
        material->set_shader_parameter("textures", atlas);
        material->set_shader_parameter("metallic_textures", metallic_atlas);
        material->set_shader_parameter("roughness_textures", roughness_atlas);
    }

    UtilityFunctions::print("Texture atlas created.");
}

bool World::is_all_loaded() {
    return all_loaded;
}

void World::force_reload() {
    all_loaded = false;
}


////////////////////////
//   Chunk Loading    //
////////////////////////


void World::set_loaded_region_center(Vector3 new_center) {
    Vector3i new_center_chunk = snap_to_chunk(new_center);
    if (new_center_chunk != center_chunk || !all_loaded) {
        center_chunk = new_center_chunk;
        all_loaded = false;
        update_loaded_region();
    }
}

void World::update_loaded_region() {
    if (debug_stall) {
        UtilityFunctions::print("stall: has_task: ", has_task);
        if (has_task) {
            UtilityFunctions::print("stall: task_id: ", task_id);
        }
    }

    if (has_task) {
        if (!WorkerThreadPool::get_singleton()->is_group_task_completed(task_id)) {
            return;
        }
        WorkerThreadPool::get_singleton()->wait_for_group_task_completion(task_id);
        has_task = false;
    }

    init_queue.clear();
    init_queue_positions.clear();

    bool all_decorations_generated = true;
    bool all_structures_generated = true;

    // Remove far away decorations if memory is starting to clog up
    TypedArray<Vector3i> decorated_vectors = decoration_map.keys();
    for (int i = 0; i < decorated_vectors.size(); i++) {
        Vector3i key = decorated_vectors[i];
        if (!is_chunk_in_radius(key, instance_radius * 2)) {
            decoration_map.erase(key);
            decoration_count.erase(key);
            if (decoration_generated.has(key)) {
                decoration_generated.erase(key);
            }
        }
    }

    // Also remove far away structures
    TypedArray<Vector3i> structured_vectors = structure_map.keys();
    for (int i = 0; i < structured_vectors.size(); i++) {
        Vector3i key = structured_vectors[i];
        if (!is_chunk_in_radius(key, 2 * STRUCTURE_SIZE + instance_radius)) {
            structure_map.erase(key);
        }
    }

    // Initialize dictionary spots for decorations (since placed decorations may place in adjacent chunks)
    int64_t deco_radius_x = 2 + instance_radius / Chunk::CHUNK_SIZE_X;
    int64_t deco_radius_y = 2 + instance_radius / Chunk::CHUNK_SIZE_Y;
    int64_t deco_radius_z = 2 + instance_radius / Chunk::CHUNK_SIZE_Z;
    for (int64_t y = -deco_radius_y; y <= deco_radius_y; y++) {
    for (int64_t x = -deco_radius_x; x <= deco_radius_x; x++) {
    for (int64_t z = -deco_radius_z; z <= deco_radius_z; z++) {

        Vector3i coordinate = Vector3i(Chunk::CHUNK_SIZE_X * x, Chunk::CHUNK_SIZE_Y * y, Chunk::CHUNK_SIZE_Z * z) + center_chunk;

        // Don't check for radius here

        if (!decoration_map.has(coordinate)) {
            Array decoration_array;
            decoration_array.resize(MAX_DECORATIONS);
            decoration_map[coordinate] = decoration_array;
            decoration_count[coordinate] = 0;
        }

    }
    }
    }

    deco_radius_x = 1 + instance_radius / Chunk::CHUNK_SIZE_X;
    deco_radius_y = 1 + instance_radius / Chunk::CHUNK_SIZE_Y;
    deco_radius_z = 1 + instance_radius / Chunk::CHUNK_SIZE_Z;

    // Structure initialization
    for (int64_t y = -deco_radius_y; y <= deco_radius_y; y++) {
    for (int64_t x = -deco_radius_x; x <= deco_radius_x; x++) {
    for (int64_t z = -deco_radius_z; z <= deco_radius_z; z++) {

        Vector3i coordinate = Vector3i(Chunk::CHUNK_SIZE_X * x, Chunk::CHUNK_SIZE_Y * y, Chunk::CHUNK_SIZE_Z * z) + center_chunk;
        Vector3i structure_coordinate = snap_to_nearest_structure(coordinate);
        if (!structure_map.has(structure_coordinate)) {
            all_structures_generated = false;
            init_queue_positions.push_back(structure_coordinate);
            structure_map[structure_coordinate] = nullptr;
        }
    }
    }
    }

    // Decoration initialization
    if (all_structures_generated) {
        for (int64_t y = -deco_radius_y; y <= deco_radius_y; y++) {
        for (int64_t x = -deco_radius_x; x <= deco_radius_x; x++) {
        for (int64_t z = -deco_radius_z; z <= deco_radius_z; z++) {

            Vector3i coordinate = Vector3i(Chunk::CHUNK_SIZE_X * x, Chunk::CHUNK_SIZE_Y * y, Chunk::CHUNK_SIZE_Z * z) + center_chunk;

            if (!is_chunk_in_radius(coordinate, instance_radius + 1 * Chunk::CHUNK_SIZE_X) || decoration_generated.has(coordinate)) {
                continue;
            }

            decoration_generated[coordinate] = false;
            all_decorations_generated = false;
            init_queue_positions.push_back(coordinate);
        }
        }
        }
    }

    if (all_structures_generated && all_decorations_generated) {        
        // Loop through chunks to find available ones
        std::vector<Chunk*> available_chunks;
        for (uint64_t i = 0; i < all_chunks.size(); i++) {
            Chunk* chunk = all_chunks[i];
            Vector3i coordinate = Vector3i(chunk->get_position());
            if (chunk->garbage || !is_chunk_in_radius(coordinate, instance_radius)) {
                available_chunks.push_back(chunk);
            }
        }

        // Loop through the spherical region around the center and generate chunks
        // Use a different ordering to generate closer chunks first -- helps reduce jarring loading barriers
        for (int64_t chunk_y = 0; chunk_y <= 2 * instance_radius / Chunk::CHUNK_SIZE_Y - 2; chunk_y++) {
            int64_t actual_chunk_y = (chunk_y % 2 == 0) ? -chunk_y / 2 : (chunk_y + 1) / 2;

        for (int64_t chunk_x = 0; chunk_x <= 2 * instance_radius / Chunk::CHUNK_SIZE_X; chunk_x++) {
            int64_t actual_chunk_x = (chunk_x % 2 == 0) ? -chunk_x / 2 : (chunk_x + 1) / 2;

        for (int64_t chunk_z = 0; chunk_z <= 2 * instance_radius / Chunk::CHUNK_SIZE_Z; chunk_z++) {
            int64_t actual_chunk_z = (chunk_z % 2 == 0) ? -chunk_z / 2 : (chunk_z + 1) / 2;

            Vector3i coordinate = Vector3i(
                Chunk::CHUNK_SIZE_X * actual_chunk_x,
                Chunk::CHUNK_SIZE_Y * actual_chunk_y,
                Chunk::CHUNK_SIZE_Z * actual_chunk_z) + center_chunk;

            if (is_chunk_loaded.has(coordinate) || !is_chunk_in_radius(coordinate, instance_radius)) {
                continue;
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

        for (int i = 0; i < available_chunks.size(); i++) {
            Chunk* chunk = available_chunks[i];

            if (chunk->garbage) {
                continue;
            }

            chunk->mark_as_garbage();
            unload_chunk(chunk);
        }

        available_chunks.clear();
        if (init_queue.size() > 0) {
            if (debug_stall) {
                UtilityFunctions::print("stall: chunk gen");
            }

            has_task = true;
            task_id = WorkerThreadPool::get_singleton()->add_group_task(callable_mp(this, &World::initialize_chunk), init_queue.size());
        } else {
            if (debug_stall) {
                UtilityFunctions::print("stall: all done");
            }
            all_loaded = true;
            call_deferred("emit_signal", "all_loaded");
        }
    } else if (all_structures_generated) {  
        if (init_queue_positions.size() > 0) {
            if (debug_stall) {
                UtilityFunctions::print("stall: decorations");
            }
            has_task = true;
            task_id = WorkerThreadPool::get_singleton()->add_group_task(callable_mp(this, &World::initialize_chunk_decorations), init_queue_positions.size());
        } else {
            if (debug_stall) {
                UtilityFunctions::print("stall: decorations needed but no queue, decoration_generated size: ", decoration_generated.size());
            }
        }
    } else {
        if (init_queue_positions.size() > 0) {
            if (debug_stall) {
                UtilityFunctions::print("stall: structures");
            }
            has_task = true;
            task_id = WorkerThreadPool::get_singleton()->add_group_task(callable_mp(this, &World::initialize_structure), init_queue_positions.size());
        } else {
            if (debug_stall) {
                UtilityFunctions::print("stall: structures needed but no queue");
            }
        }
    }
}

void World::unload_chunk(Chunk* chunk) {
    Vector3i coordinate = Vector3i(chunk->get_position());
    if (chunk_map.has(coordinate)) {
        chunk->clear_collision();
        chunk->set_visible(false);
        chunk_map.erase(coordinate);
        is_chunk_loaded.erase(coordinate);

        if (chunk->modified) {
            chunk_data[coordinate] = chunk->blocks;
            chunk_water_data[coordinate] = chunk->water;
            chunk_water_awake_data[coordinate] = chunk->water_chunk_awake;
            chunk_fire_data[coordinate] = chunk->fire;
        }

        emit_signal("chunk_unloaded", coordinate);
    }
}

void World::initialize_chunk(uint64_t index) {
    Chunk* chunk = Object::cast_to<Chunk>(init_queue[index]);
    Vector3i coordinate = init_queue_positions[index];

    if (chunk_data.has(coordinate)) {
        chunk->blocks = chunk_data[coordinate];
        chunk->water = chunk_water_data[coordinate];
        chunk->water_chunk_awake = chunk_water_awake_data[coordinate];
        chunk->fire = chunk_fire_data[coordinate];
        chunk->modified = true;
    } else {
        // Raw terrain data
        generator->generate(this, chunk, coordinate, Generator::LAYER_BASE);

        // Decoration data
        generator->place_decoration_blocks(this, chunk, decoration_map[coordinate], coordinate);

        // Structure data
        generator->place_structure_blocks(this, chunk, coordinate);

        // Fusion layer
        generator->generate(this, chunk, coordinate, Generator::LAYER_FUSION);

        // Fusion layer 2
        // generator->generate(this, chunk, coordinate, Generator::LAYER_FUSION_WEIRD);

        // Replace void blocks
        for (int i = 0; i < chunk->blocks.size(); i++) {
            if (chunk->blocks[i] == 1) {
                chunk->blocks[i] = 0;
            }
        }

        chunk->water_chunk_awake.fill(0);
        chunk->fire.fill(0);
        chunk->modified = false;

        call_deferred("liven_chunk", chunk, coordinate);
    }

    // HACK: desync chunk generation to prevent large amounts of remeshing in the same frame...
    std::this_thread::sleep_for(std::chrono::milliseconds(index % 7));

    chunk->calculate_block_statistics();
    chunk->never_initialized = false;
    chunk->generate_mesh(false, coordinate);
    chunk->generate_water_mesh(true, coordinate);
    chunk->generate_water_surface_mesh(true, coordinate); // This CLEARS the surface mesh

    chunk->call_deferred("initialize_fire_visuals", coordinate);
    chunk->call_deferred("make_visible");

    call_deferred("emit_signal", "chunk_loaded", coordinate);

    is_chunk_loaded[coordinate] = true;
}

void World::initialize_chunk_decorations(uint64_t index) {
    Vector3i coordinate = init_queue_positions[index];
    generator->generate_decorations(this, coordinate);
    decoration_generated[coordinate] = true;
}

void World::initialize_structure(uint64_t index) {
    Vector3i coordinate = init_queue_positions[index];
    generator->generate_structure(this, coordinate); // Updates the structure map
}


//////////////////////////////
//   Interfacing Methods    //
//////////////////////////////


void World::simulate_dynamic() {
    int64_t chunk_radius_x = water_simulate_radius / Chunk::CHUNK_SIZE_X;
    int64_t chunk_radius_y = water_simulate_radius / Chunk::CHUNK_SIZE_Y;
    int64_t chunk_radius_z = water_simulate_radius / Chunk::CHUNK_SIZE_Z;

    // First, advance the water + fire simulation of all chunks in range
    simulated_water_subchunks = 0;
    int simulated_chunks = 0;
    int rendered_chunks = 0;
    for (int64_t chunk_y = 0; chunk_y <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Y; chunk_y++) {
        int64_t actual_chunk_y = (chunk_y % 2 == 0) ? -chunk_y / 2 : (chunk_y + 1) / 2;
        if ((water_direction / 2) % 2) actual_chunk_y = -actual_chunk_y;

    for (int64_t chunk_x = 0; chunk_x <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_X; chunk_x++) {
        int64_t actual_chunk_x = (chunk_x % 2 == 0) ? -chunk_x / 2 : (chunk_x + 1) / 2;
        if (water_direction % 2) actual_chunk_x = -actual_chunk_x;

    for (int64_t chunk_z = 0; chunk_z <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Z; chunk_z++) {
        int64_t actual_chunk_z = (chunk_z % 2 == 0) ? -chunk_z / 2 : (chunk_z + 1) / 2;
        if ((water_direction / 4) % 2) actual_chunk_z = -actual_chunk_z;

        Vector3i coordinate = Vector3i(
            Chunk::CHUNK_SIZE_X * actual_chunk_x,
            Chunk::CHUNK_SIZE_Y * actual_chunk_y,
            Chunk::CHUNK_SIZE_Z * actual_chunk_z) + center_chunk;

        // Simulate chunks in a staggered way to reduce load each frame
        if ((int64_t) UtilityFunctions::abs(chunk_x + chunk_y + chunk_x) % WATER_SKIP != water_frame) {
            continue;
        }

        // Skip processing water chunks that are far away using random chance
        if (actual_chunk_x * actual_chunk_x + actual_chunk_y * actual_chunk_y + actual_chunk_z * actual_chunk_z >= 6 && UtilityFunctions::randf() < 0.75) {
            continue;
        }

        if (!is_chunk_loaded.has(coordinate) || !is_chunk_loaded[coordinate] || !is_chunk_in_radius(coordinate, water_simulate_radius)) {
            continue;
        }

        Chunk* chunk = Object::cast_to<Chunk>(chunk_map[coordinate]);
        chunk->simulate_water();
        chunk->simulate_fire();
        simulated_chunks++;
    }
    }
    }

    // Then, render any updated chunks +
    // Render all fire / water surfaces of chunks that were recently loaded
    rendered_water_chunks = 0;
    for (int64_t chunk_y = 0; chunk_y <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Y; chunk_y++) {
        int64_t actual_chunk_y = (chunk_y % 2 == 0) ? -chunk_y / 2 : (chunk_y + 1) / 2;
        if ((water_direction / 2) % 2) actual_chunk_y = -actual_chunk_y;

    for (int64_t chunk_x = 0; chunk_x <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_X; chunk_x++) {
        int64_t actual_chunk_x = (chunk_x % 2 == 0) ? -chunk_x / 2 : (chunk_x + 1) / 2;
        if (water_direction % 2) actual_chunk_x = -actual_chunk_x;

    for (int64_t chunk_z = 0; chunk_z <= 2 * water_simulate_radius / Chunk::CHUNK_SIZE_Z; chunk_z++) {
        int64_t actual_chunk_z = (chunk_z % 2 == 0) ? -chunk_z / 2 : (chunk_z + 1) / 2;
        if ((water_direction / 4) % 2) actual_chunk_z = -actual_chunk_z;

        Vector3i coordinate = Vector3i(
            Chunk::CHUNK_SIZE_X * actual_chunk_x,
            Chunk::CHUNK_SIZE_Y * actual_chunk_y,
            Chunk::CHUNK_SIZE_Z * actual_chunk_z) + center_chunk;

        if (!is_chunk_loaded.has(coordinate) || !is_chunk_loaded[coordinate] || !is_chunk_in_radius(coordinate, water_simulate_radius)) {
            continue;
        }

        Chunk* chunk = Object::cast_to<Chunk>(chunk_map[coordinate]);

        if (chunk->water_updated > 0) {
            if (rendered_water_chunks >= MAX_WATER_RERENDERED_CHUNKS_PER_FRAME && chunk->water_render_wait < 4) {
                chunk->water_render_wait++;
                continue;
            }

            // Skip processing water chunks that are far away using random chance
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

    // UtilityFunctions::print("Simulation: ", simulated_chunks, " simulated, ", rendered_chunks, " rendered");
    water_frame = (water_frame + 1) % WATER_SKIP;
    water_direction = (water_direction + 1) % 8;
}

void World::place_decoration(Ref<DecorationState> decoration_state) {
    TypedDictionary<Vector3i, bool> placed_chunks;

    Vector3i center = decoration_state->decoration->get_center_offset();
    Vector3i size = decoration_state->decoration->get_size();

    if (decoration_state->direction == DecorationState::East || decoration_state->direction == DecorationState::West) {
        center = Vector3i(center.z, center.y, center.x);
        size = Vector3i(size.z, size.y, size.x);
    }

    for (int64_t i = 0; i <= 1; i++) {
    for (int64_t j = 0; j <= 1; j++) {
    for (int64_t k = 0; k <= 1; k++) {
        Vector3i corner = decoration_state->position - center + size * Vector3i(i, j, k);
        Vector3i chunk_position = snap_to_chunk(corner);

        if (!placed_chunks.has(chunk_position)) {
            decoration_lock.lock();

            int64_t count = decoration_count[chunk_position];

            if (count >= MAX_DECORATIONS) {
                decoration_lock.unlock();
                continue;
            }

            Array decoration_list = decoration_map[chunk_position];
            decoration_list[count] = decoration_state;
            decoration_count[chunk_position] = count + 1;

            decoration_lock.unlock();

            placed_chunks[chunk_position] = true;
        }
    }
    }
    }

    placed_chunks.clear();
}

bool World::is_position_loaded(Vector3 position) {
    position = position.floor();

    Vector3i snapped_position = snap_to_chunk(position);
    return is_chunk_loaded.has(snapped_position) && is_chunk_loaded[snapped_position];
}

bool World::is_position_loading(Vector3 position) {
    position = position.floor();
    Vector3i snapped_position = snap_to_chunk(position);
    return is_chunk_loaded.has(snapped_position) && !is_chunk_loaded[snapped_position];
}

// Assumes the chunk is loaded
Chunk* World::get_chunk_at(Vector3 position) {
    position = position.floor();

    return Object::cast_to<Chunk>(chunk_map[snap_to_chunk(position)]);
}

Vector3i World::snap_to_chunk(Vector3 position) {
    position = position.floor();

    Vector3i p = Vector3i(position);

    int64_t rx = int64_t(p.x) % Chunk::CHUNK_SIZE_X;
    int64_t ry = int64_t(p.y) % Chunk::CHUNK_SIZE_Y;
    int64_t rz = int64_t(p.z) % Chunk::CHUNK_SIZE_Z;

    if (rx < 0) rx += Chunk::CHUNK_SIZE_X;
    if (ry < 0) ry += Chunk::CHUNK_SIZE_Y;
    if (rz < 0) rz += Chunk::CHUNK_SIZE_Z;

    return p - Vector3i(rx, ry, rz);
}

Vector3i World::snap_to_nearest_structure(Vector3 position) {
    position = position.floor();

    Vector3i p = Vector3i(position);

    int64_t rx = int64_t(p.x) % World::STRUCTURE_SIZE;
    int64_t ry = int64_t(p.y) % World::STRUCTURE_SIZE;
    int64_t rz = int64_t(p.z) % World::STRUCTURE_SIZE;

    if (rx < 0) rx += World::STRUCTURE_SIZE;
    if (ry < 0) ry += World::STRUCTURE_SIZE;
    if (rz < 0) rz += World::STRUCTURE_SIZE;

    return p - Vector3i(rx, ry, rz);
}

Ref<Structure> World::get_nearest_structure(Vector3 position) {
    Vector3i structure_position = snap_to_nearest_structure(position);
    if (!structure_map.has(structure_position)) {
        return nullptr;
    }
    Ref<Structure> structure = structure_map[structure_position];
    return structure;
}

bool World::is_within_structure(Vector3 position) {
    Ref<Structure> structure = get_nearest_structure(position);
    if (structure == nullptr) {
        return false;
    }
    return structure->is_within_structure(Vector3i(position));
}

Vector3i World::find_closest_cutscene_block(Vector3 starting_position, TypedDictionary<Vector3i, bool> collected_blocks) {

    Vector3i center_position = snap_to_nearest_structure(starting_position);
    Vector3i query_position = center_position;
    const int MAX_RADIUS = 24;
    for (int r = 0; r <= MAX_RADIUS; r++) {
        bool cutscene_block_found = false;
        Ref<Structure> closest_structure;
        Vector3i closest_position = center_position;

        for (int x = -r; x <= r; x++) {
        for (int y = -r; y <= r; y++) {
        for (int z = -r; z <= r; z++) {
            if (UtilityFunctions::absi(x) + UtilityFunctions::absi(y) + UtilityFunctions::absi(z) == r) {
                query_position = snap_to_nearest_structure(center_position + STRUCTURE_SIZE * Vector3i(x, y, z));
                if (!structure_map.has(query_position)) {
                    UtilityFunctions::print("Structure being generated at: ", query_position);
                    generator->generate_structure(this, query_position);
                } else {
                    UtilityFunctions::print("Structure already exists at: ", query_position);
                }

                Ref<Structure> query_structure = structure_map[query_position];

                UtilityFunctions::print("Structure name: ", query_structure->internal_name);

                if (query_structure->has_cutscene_block()) {
                    Vector3i cutscene_block_position = query_structure->get_cutscene_block_position();

                    if (collected_blocks.has(cutscene_block_position)) {
                        UtilityFunctions::print("Already collected cutscene block, skipping.");
                        continue;
                    }

                    if (!cutscene_block_found || closest_position.distance_squared_to(starting_position) > cutscene_block_position.distance_squared_to(starting_position)) {
                        closest_structure = query_structure;
                        cutscene_block_found = true;
                        closest_position = cutscene_block_position;
                        UtilityFunctions::print("Found cutscene block at: ", cutscene_block_position);
                    } else {
                        UtilityFunctions::print("Cutscene block not found or farther than nearest, skipping");
                    }
                }

                UtilityFunctions::print(" ");
            }
        }
        }
        }

        if (cutscene_block_found) {
            UtilityFunctions::print("Nearest structure: ", closest_structure->internal_name);
            return closest_position;
        }
    }

    UtilityFunctions::printerr("Could not find closest cutscene block");
    return Vector3i(0, 0, 0);
}

bool World::is_chunk_in_radius(Vector3i coordinate, int64_t radius) {
    return (center_chunk - coordinate).length_squared() < radius * radius;
}

Ref<Block> World::get_block_type_at(Vector3 position) {
    position = position.floor();

    Chunk* chunk = get_chunk_at(position);
    return block_types[chunk->get_block_index_at_global(Vector3i(position))];
}

bool World::is_block_solid_at(Vector3 position) {
    Ref<Block> block_type = get_block_type_at(position);
    return is_block_index_solid(block_type->index);
}

bool World::is_block_index_solid(int32_t index) {
    return index != 0 && !is_block_foliage[index];
}

void World::break_block_at(Vector3 position, bool play_effect, bool override_restrictions) {
    position = position.floor();

    Chunk* chunk = get_chunk_at(position);
    Ref<Block> block_type = get_block_type_at(position);

    // Fail to break cutscene blocks
    if (!override_restrictions && block_type->unbreakable) {
        return;
    }

    chunk->remove_block_at(Vector3i(position), false);

    if (play_effect) {
        Node* break_effect = break_effect_scene->instantiate();
        get_parent()->add_child(break_effect);
        break_effect->set("global_position", Vector3i(position));
        break_effect->call("initialize", block_type);
    }

    emit_signal("block_broken", position);
}

void World::explode_at(Vector3 position, int radius, bool firey) {
    TypedDictionary<Vector3i, bool> to_remesh;
    for (int i = -radius; i <= radius; i++) {
    for (int j = -radius; j <= radius; j++) {
    for (int k = -radius; k <= radius; k++) {
        if (i * i + j * j + k * k > radius * radius) {
            continue;
        }
        Vector3 explode_at = position + Vector3i(i, j, k);
        if (!is_position_loaded(explode_at)) {
            continue;
        }
        const float FIRE_CHANCE = 0.3;
        if (firey && UtilityFunctions::randf() < FIRE_CHANCE && j == -radius) {
            if (is_position_loaded(explode_at + Vector3(0, -1, 0))) {
                place_fire_at(explode_at + Vector3(0, -1, 0), 1);
            }
        }

        explode_at = explode_at.floor();

        Chunk* chunk = get_chunk_at(explode_at);

        Ref<Block> block_type = get_block_type_at(explode_at);
        if (block_type->unbreakable || !block_type->griefable) {
            continue;
        }

        chunk->remove_block_at(Vector3i(explode_at), true);
        to_remesh.set(Vector3i(chunk->get_global_position()), true);

        emit_signal("block_broken", position);
    }
    }
    }

    if (firey) {
        const float FIRE_CHANCE = 0.1;
        for (int i = -(radius + 1); i <= (radius + 1); i++) {
        for (int j = -(radius + 1); j <= (radius + 1); j++) {
        for (int k = -(radius + 1); k <= (radius + 1); k++) {
            if (i * i + j * j + k * k > (radius + 1) * (radius + 1)) {
                continue;
            }
            Vector3 burn_at = position + Vector3i(i, j, k);
            if (UtilityFunctions::randf() > FIRE_CHANCE || !is_position_loaded(burn_at)) {
                continue;
            }

            place_fire_at(burn_at, 1);
        }
        }
        }
    }

    TypedArray<Vector3i> to_remesh_array = to_remesh.keys();
    for (int i = 0; i < to_remesh_array.size(); i++) {
        Vector3i chunk_position = to_remesh_array[i];
        Chunk* chunk = get_chunk_at(chunk_position);
        chunk->generate_mesh(true, chunk_position);
        chunk->generate_water_surface_mesh(false, chunk_position);
    }
}

void World::flood_at(Vector3 position, int radius) {
    TypedDictionary<Vector3i, bool> to_remesh;
    for (int i = -radius; i <= radius; i++) {
    for (int j = -radius; j <= radius; j++) {
    for (int k = -radius; k <= radius; k++) {
        if (i * i + j * j + k * k > radius * radius) {
            continue;
        }
        Vector3 flood_at = position + Vector3i(i, j, k);
        if (!is_position_loaded(flood_at)) {
            continue;
        }

        flood_at = flood_at.floor();

        Chunk* chunk = get_chunk_at(flood_at);
        chunk->set_water_at(flood_at - chunk->get_global_position(), 255);
        to_remesh.set(Vector3i(chunk->get_global_position()), true);
    }
    }
    }
}

void World::place_block_at(Vector3 position, Ref<Block> block_type, bool play_effect, bool immediate_remesh) {
    position = position.floor();

    Chunk* chunk = get_chunk_at(position);
    bool success = chunk->place_block_at(Vector3i(position), block_type->index, immediate_remesh);

    if (!success) {
        return;
    }

    // This block has a living component
    if (block_type->living_block_scene_path != "") {
        liven_block(position, block_type);
    }

    if (play_effect) {
        Node* place_effect = place_effect_scene->instantiate();
        get_parent()->add_child(place_effect);
        place_effect->set("global_position", Vector3i(position));
        place_effect->call("initialize", block_type);
    }

    emit_signal("block_placed", Vector3i(position));
}

void World::liven_block(Vector3i position, Ref<Block> block_type) {
    if (living_block_map.has(position)) {
        UtilityFunctions::printerr("Attempted to add duplicate living block");
        return;
    }
    if (block_type->living_block_scene_path == "") {
        UtilityFunctions::printerr("Attempted to liven non-living block: ", block_type->internal_name);
        return;
    }
    Ref<PackedScene> living_block_scene = block_type->living_block_scene;
    Node3D* new_living_block = Object::cast_to<Node3D>(living_block_scene->instantiate());
    get_tree()->get_root()->call_deferred("add_child", new_living_block);
    new_living_block->call_deferred("set_global_position", position);
    new_living_block->call_deferred("generate", block_type);
    new_living_block->call_deferred("register");
}

void World::liven_chunk(Chunk* chunk, Vector3i coordinate) {
    for (int64_t y = 0; y < Chunk::CHUNK_SIZE_Y; y++) {
    for (int64_t z = 0; z < Chunk::CHUNK_SIZE_Z; z++) {
    for (int64_t x = 0; x < Chunk::CHUNK_SIZE_X; x++) {
        Vector3i local_position = Vector3i(x, y, z);
        int32_t index = chunk->get_block_index_at(local_position);
        if (chunk->is_block_living[index]) {
            liven_block(coordinate + local_position, block_types[index]);
        }
    }
    }
    }
}

void World::kill_block(Vector3i position) {
    if (!living_block_map.has(position)) {
        return;
    }
    Node3D* living_block = Object::cast_to<Node3D>(living_block_map[position]);
    living_block->set("disabled", true);
    living_block->call_deferred("before_breaking");
    living_block->call_deferred("queue_free");
}

void World::register_living_block(Vector3i position, Node3D* living_block) {
    living_block_map[position] = living_block;
}

void World::unregister_living_block(Vector3i position) {
    if (living_block_map.has(position)) {
        living_block_map.erase(position);
    }
}

Node3D* World::get_living_block_at(Vector3 position) {
    Vector3i floored_position = Vector3i(position.floor());

    if (living_block_map.has(floored_position)) {
        return Object::cast_to<Node3D>(living_block_map[floored_position]);
    }

    return nullptr;
}

void World::place_water_at(Vector3 position, uint8_t amount) {
    position = position.floor();

    Chunk* chunk = get_chunk_at(position);
    chunk->set_water_at(Vector3i(position - chunk->get_global_position()), amount);
}

uint8_t World::get_water_level(Vector3 position) {
    position = position.floor();
    Chunk* chunk = get_chunk_at(position);
    return chunk->get_water_at(Vector3i(position - chunk->get_global_position()));
}

bool World::is_under_water(Vector3 position) {
    uint8_t water_level = get_water_level(position);
    if (water_level == 0) {
        return false;
    }

    uint8_t above_water = 0;
    if (is_position_loaded(position + Vector3i(0, 1, 0))) {
        above_water = get_water_level(position + Vector3i(0, 1, 0));
    }

    return above_water > 0 || position.y - position.floor().y < water_level / 255.;
}

void World::place_fire_at(Vector3 position, uint8_t amount) {
    position = position.floor();
    Chunk* chunk = get_chunk_at(position);
    chunk->set_fire_at(Vector3i(position - chunk->get_global_position()), amount);
}

uint8_t World::get_fire_at(Vector3 position) {
    position = position.floor();
    Chunk* chunk = get_chunk_at(position);
    return chunk->get_fire_at(Vector3i(position - chunk->get_global_position()));
}

bool World::fire_eligible(Vector3 position) {
    position = position.floor();
    Chunk* chunk = get_chunk_at(position);
    return chunk->fire_eligible(Vector3i(position - chunk->get_global_position()));
}

bool World::is_chunk_modified(Vector3 position) {
    Vector3i chunk_position = snap_to_chunk(position);
    if (chunk_map.has(chunk_position)) {
        Chunk* chunk = Object::cast_to<Chunk>(chunk_map[chunk_position]);
        return chunk->modified;
    } else {
        return chunk_data.has(chunk_position);
    }
}

void World::modify_chunk(Vector3 position) {
    Vector3i chunk_position = snap_to_chunk(position);
    Chunk* chunk = Object::cast_to<Chunk>(chunk_map[chunk_position]);
    chunk->modified = true;
}


//////////////////////////////////
//         Save data            //
//////////////////////////////////


void World::save_data(Dictionary data, String prefix) {
    for (uint64_t i = 0; i < all_chunks.size(); i++) {
        Chunk* chunk = all_chunks[i];
        Vector3i coordinate = Vector3i(chunk->get_position());
        if (chunk->modified) {
            chunk_data[coordinate] = chunk->blocks;
            chunk_water_data[coordinate] = chunk->water;
            chunk_water_awake_data[coordinate] = chunk->water_chunk_awake;
            chunk_fire_data[coordinate] = chunk->fire;
        }
    }

    TypedArray<Vector3i> saved_coordinates = chunk_data.keys();
    Dictionary root;

    if (data.has(prefix + "world")) {
        root = data[prefix + "world"];
    }

    // We need to store IDs, not indices
    TypedDictionary<Vector3i, PackedInt32Array> mapped_chunk_data;
    for (uint64_t i = 0; i < saved_coordinates.size(); i++) {
        Vector3i coordinate = saved_coordinates[i];
        PackedInt32Array blocks = chunk_data[coordinate];

        PackedInt32Array blocks_id;
        blocks_id.resize(blocks.size());

        for (int64_t i = 0; i < blocks.size(); i++) {
            int32_t index = blocks[i];
            Ref<Block> block_type = block_types[index];
            blocks_id[i] = block_type->id;
        }

        mapped_chunk_data[coordinate] = blocks_id;
    }

    root[prefix + "chunk_block"] = mapped_chunk_data;
    root[prefix + "chunk_water"] = chunk_water_data.duplicate(true);
    root[prefix + "chunk_water_awake"] = chunk_water_awake_data.duplicate(true);
    root[prefix + "chunk_fire"] = chunk_fire_data.duplicate(true);

    data[prefix + "world"] = root;
}

void World::load_data(Dictionary data, String prefix) {
    Dictionary root;
    root.clear();

    if (data.has(prefix + "world")) {
        root = data[prefix + "world"];
    }

    if (root.has(prefix + "chunk_block")) {
        TypedDictionary<Vector3i, PackedInt32Array> mapped_chunk_data = root[prefix + "chunk_block"];
        TypedArray<Vector3i> saved_coordinates = mapped_chunk_data.keys();
        for (uint64_t i = 0; i < mapped_chunk_data.size(); i++) {
            Vector3i coordinate = saved_coordinates[i];
            PackedInt32Array blocks_id = mapped_chunk_data[coordinate];

            PackedInt32Array blocks;
            blocks.resize(blocks_id.size());

            for (int64_t i = 0; i < blocks_id.size(); i++) {
                int32_t id = blocks_id[i];
                blocks[i] = block_id_to_index_map[id];
            }

            chunk_data[coordinate] = blocks;
        }
    } else {
        chunk_data.clear();
    }

    if (root.has(prefix + "chunk_water")) {
        chunk_water_data = root[prefix + "chunk_water"];
        chunk_water_data = chunk_water_data.duplicate(true);
    } else {
        chunk_water_data.clear();
    }

    if (root.has(prefix + "chunk_water_awake")) {
        chunk_water_awake_data = TypedDictionary<Vector3i, PackedByteArray>(root[prefix + "chunk_water_awake"]);
        chunk_water_awake_data = chunk_water_awake_data.duplicate(true);
    } else {
        chunk_water_awake_data.clear();
    }

    if (root.has(prefix + "chunk_fire")) {
        chunk_fire_data = TypedDictionary<Vector3i, PackedByteArray>(root[prefix + "chunk_fire"]);
        chunk_fire_data = chunk_fire_data.duplicate(true);
    } else {
        chunk_fire_data.clear();
    }
}

TypedDictionary<Vector3i, int> World::initialize_challenge(Ref<Decoration> challenge_decoration, TypedDictionary<int, int> block_replace_map) {
    return TypedDictionary<Vector3i, int>();
}  

//////////////////////////////////
//   Boilerplate setter/getter  //
//////////////////////////////////


void World::set_block_types(TypedArray<Block> new_block_types) {
    block_types = new_block_types;
}

TypedArray<Block> World::get_block_types() const {
    return block_types;
}

Ref<ShaderMaterial> World::get_block_material() const {
    return block_material;
}

void World::set_block_material(Ref<ShaderMaterial> new_material) {
    block_material = new_material;
}

Ref<ShaderMaterial> World::get_foliage_material() const {
    return foliage_material;
}

void World::set_foliage_material(Ref<ShaderMaterial> new_material) {
    foliage_material = new_material;
}

Ref<ShaderMaterial> World::get_water_material() const {
    return water_material;
}

void World::set_water_material(Ref<ShaderMaterial> new_material) {
    water_material = new_material;
}

Ref<ShaderMaterial> World::get_water_surface_material() const {
    return water_surface_material;
}

void World::set_water_surface_material(Ref<ShaderMaterial> new_material) {
    water_surface_material = new_material;
}

Ref<ShaderMaterial> World::get_transparent_block_material() const {
    return transparent_block_material;
}

void World::set_transparent_block_material(Ref<ShaderMaterial> new_material) {
    transparent_block_material = new_material;
}

void World::set_instance_radius(int64_t new_radius) {
    instance_radius = UtilityFunctions::clampi(new_radius, 48, 96);
}

int64_t World::get_instance_radius() const {
    return instance_radius;
}

TypedArray<Decoration> World::get_decorations() const {
    return decorations;
}

void World::set_decorations(TypedArray<Decoration> new_decorations) {
    decorations = new_decorations;
}

Ref<Generator> World::get_generator() const {
    return generator;
}

void World::set_generator(Ref<Generator> new_generator) {
    generator = new_generator;
}

TypedArray<ShaderMaterial> World::get_requires_texture_atlas() const {
    return requires_texture_atlas;
}

void World::set_requires_texture_atlas(const TypedArray<ShaderMaterial> new_array) {
    requires_texture_atlas = new_array;
}

void World::set_fusion_table(const PackedInt32Array new_array, int width) {
    fusion_table = new_array;
    fusion_table_width = width;
}

void World::set_debug_stall(bool value) {
    debug_stall = value;
}

bool World::get_debug_stall() const {
    return debug_stall;
}