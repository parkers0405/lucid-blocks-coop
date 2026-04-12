#include "coop_native_patch.h"

#include <array>
#include <cstddef>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <unordered_map>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

#ifdef _WIN32
extern "C" {
uintptr_t g_coop_update_hook_0_inside = 0;
uintptr_t g_coop_update_hook_0_outside = 0;
uintptr_t g_coop_update_hook_1_inside = 0;
uintptr_t g_coop_update_hook_1_outside = 0;
uintptr_t g_coop_update_hook_2_inside = 0;
uintptr_t g_coop_update_hook_2_outside = 0;
uintptr_t g_coop_update_hook_3_inside = 0;
uintptr_t g_coop_update_hook_3_outside = 0;
uintptr_t g_coop_update_hook_4_inside = 0;
uintptr_t g_coop_update_hook_4_outside = 0;
uintptr_t g_coop_simulate_hook_1_inside = 0;
uintptr_t g_coop_simulate_hook_1_outside = 0;
uintptr_t g_coop_simulate_hook_2_inside = 0;
uintptr_t g_coop_simulate_hook_2_outside = 0;
}
#endif

namespace {

static constexpr const char *GDBLOCKS_DLL_NAME = "libgdblocks.windows.template_release.double.x86_64.dll";
static constexpr int DEFAULT_INSTANCE_RADIUS_CAP = 96;
static constexpr int DEFAULT_INSTANTIATE_CHUNKS_RENDER_DISTANCE = 96;
static constexpr int MIN_INSTANCE_RADIUS = 48;
static constexpr int MIN_RENDER_DISTANCE = 48;
static constexpr int CHUNK_AXIS_SIZE = 16;
static constexpr int MAX_CHUNK_LOOP_RADIUS = 127;
static constexpr size_t MAX_ACTIVE_REGION_CENTERS = 8;

struct PatchSite {
    const char *label;
    uint64_t instruction_rva;
    uint64_t immediate_rva;
};

struct MultiRegionHookSite {
    const char *label;
    uint64_t patch_rva;
    size_t patch_length;
    uint64_t inside_target_rva;
    uint64_t outside_target_rva;
};

struct NativeChunkCenter {
    int32_t x = 0;
    int32_t y = 0;
    int32_t z = 0;
};

enum MultiRegionHookId : uint32_t {
    UPDATE_DECORATION_EVICT = 0,
    UPDATE_STRUCTURE_EVICT = 1,
    UPDATE_DECORATION_INIT = 2,
    UPDATE_RADIUS_CHECK_A = 3,
    UPDATE_RADIUS_CHECK_B = 4,
    SIMULATE_RADIUS_CHECK_A = 5,
    SIMULATE_RADIUS_CHECK_B = 6,
};

static constexpr PatchSite INSTANCE_RADIUS_CAP_PATCH = {
    "set_instance_radius cap",
    0x0005d004,
    0x0005d006,
};

static constexpr PatchSite INSTANTIATE_DISTANCE_SQUARED_PATCH = {
    "instantiate_chunks squared radius",
    0x000589a5,
    0x000589a7,
};

static constexpr PatchSite INSTANTIATE_LOOP_START_PATCHES[] = {
    {"instantiate_chunks y loop start", 0x000588e5, 0x000588e8},
    {"instantiate_chunks x loop start", 0x00058923, 0x00058926},
    {"instantiate_chunks z loop start", 0x00058953, 0x00058956},
};

static constexpr PatchSite INSTANTIATE_LOOP_END_PATCHES[] = {
    {"instantiate_chunks z loop end", 0x00058eb6, 0x00058eb9},
    {"instantiate_chunks x loop end", 0x00058ecb, 0x00058ece},
    {"instantiate_chunks y loop end", 0x00058ee0, 0x00058ee3},
};

static constexpr uint64_t INSTANTIATE_CHUNKS_FUNCTION_RVA = 0x00058890;

static constexpr MultiRegionHookSite MULTI_REGION_HOOK_SITES[] = {
    {"update_loaded_region decoration eviction", 0x0005f04e, 12, 0x0005f14a, 0x0005f09b},
    {"update_loaded_region structure eviction", 0x0005f21f, 12, 0x0005f292, 0x0005f26c},
    {"update_loaded_region decoration init", 0x0005f730, 14, 0x0005f778, 0x0005f7a4},
    {"update_loaded_region available chunk keep", 0x0005f8f8, 15, 0x0005fa3c, 0x0005f947},
    {"update_loaded_region chunk assignment radius", 0x0005fba3, 15, 0x0005fbf4, 0x0005fd52},
    {"simulate_dynamic water tick radius", 0x0005dd41, 14, 0x0005dd8e, 0x0005dd92},
    {"simulate_dynamic surface render radius", 0x0005e02c, 16, 0x0005e07b, 0x0005e080},
};

#ifdef _WIN32

extern "C" {
void coop_update_radius_hook_1();
void coop_update_radius_hook_2();
void coop_update_radius_hook_3();
void coop_update_radius_hook_4();
void coop_update_radius_hook_5();
void coop_simulate_radius_hook_1();
void coop_simulate_radius_hook_2();
}

static std::array<NativeChunkCenter, MAX_ACTIVE_REGION_CENTERS> g_active_region_centers = {};
static uint32_t g_active_region_center_count = 0;
static bool g_multi_region_hooks_installed = false;
static std::mutex g_world_center_lock;
static std::unordered_map<const void *, std::vector<NativeChunkCenter>> g_world_active_region_centers;
static NativeChunkCenter snap_center_to_chunk(const Vector3 &position);

static bool centers_equal(const NativeChunkCenter &a, const NativeChunkCenter &b) {
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

static std::vector<NativeChunkCenter> collect_snapped_centers(const Array &centers) {
    std::vector<NativeChunkCenter> snapped_centers;
    snapped_centers.reserve(MAX_ACTIVE_REGION_CENTERS);

    for (int64_t i = 0; i < centers.size() && snapped_centers.size() < MAX_ACTIVE_REGION_CENTERS; i++) {
        Variant value = centers[i];
        if (value.get_type() != Variant::VECTOR3) {
            continue;
        }

        const NativeChunkCenter snapped = snap_center_to_chunk(static_cast<Vector3>(value));
        bool duplicate = false;
        for (const NativeChunkCenter &existing : snapped_centers) {
            if (centers_equal(existing, snapped)) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            snapped_centers.push_back(snapped);
        }
    }

    return snapped_centers;
}

template <size_t N>
static bool has_instruction_prefix(HMODULE module, uint64_t instruction_rva, const std::array<uint8_t, N> &prefix) {
    return std::memcmp(reinterpret_cast<const uint8_t *>(module) + instruction_rva, prefix.data(), prefix.size()) == 0;
}

static uint8_t *resolve_rva(HMODULE module, uint64_t rva) {
    return reinterpret_cast<uint8_t *>(module) + rva;
}

static uint32_t read_u32(HMODULE module, uint64_t rva) {
    uint32_t value = 0;
    std::memcpy(&value, resolve_rva(module, rva), sizeof(value));
    return value;
}

static int32_t read_i32(const void *base, size_t offset) {
    int32_t value = 0;
    std::memcpy(&value, reinterpret_cast<const uint8_t *>(base) + offset, sizeof(value));
    return value;
}

static int64_t read_i64(const void *base, size_t offset) {
    int64_t value = 0;
    std::memcpy(&value, reinterpret_cast<const uint8_t *>(base) + offset, sizeof(value));
    return value;
}

static uint8_t read_u8(HMODULE module, uint64_t rva) {
    return *resolve_rva(module, rva);
}

static bool patch_bytes(void *address, const void *bytes, size_t size) {
    DWORD old_protect = 0;
    if (!VirtualProtect(address, size, PAGE_EXECUTE_READWRITE, &old_protect)) {
        return false;
    }

    std::memcpy(address, bytes, size);
    FlushInstructionCache(GetCurrentProcess(), address, size);

    DWORD ignored = 0;
    VirtualProtect(address, size, old_protect, &ignored);
    return true;
}

static bool write_absolute_jump(void *address, const void *target, size_t patch_length) {
    if (patch_length < 12) {
        return false;
    }

    std::array<uint8_t, 32> patch = {};
    patch.fill(0x90);
    patch[0] = 0x48;
    patch[1] = 0xb8;

    const uint64_t target_address = reinterpret_cast<uint64_t>(target);
    std::memcpy(patch.data() + 2, &target_address, sizeof(target_address));

    patch[10] = 0xff;
    patch[11] = 0xe0;

    return patch_bytes(address, patch.data(), patch_length);
}

static HMODULE get_gdblocks_module() {
    return GetModuleHandleA(GDBLOCKS_DLL_NAME);
}

static bool patch_u32(HMODULE module, const PatchSite &site, uint32_t value) {
    return patch_bytes(resolve_rva(module, site.immediate_rva), &value, sizeof(value));
}

static bool patch_s32(HMODULE module, const PatchSite &site, int32_t value) {
    return patch_bytes(resolve_rva(module, site.immediate_rva), &value, sizeof(value));
}

static bool patch_u8(HMODULE module, const PatchSite &site, uint8_t value) {
    return patch_bytes(resolve_rva(module, site.immediate_rva), &value, sizeof(value));
}

static bool supports_instance_radius_patch(HMODULE module) {
    static constexpr std::array<uint8_t, 2> prefix = {0x41, 0xb8};
    return has_instruction_prefix(module, INSTANCE_RADIUS_CAP_PATCH.instruction_rva, prefix);
}

static bool supports_instantiate_chunks_patch(HMODULE module) {
    static constexpr std::array<uint8_t, 2> squared_compare_prefix = {0x48, 0x3d};
    static constexpr std::array<uint8_t, 3> negative_loop_prefix_y = {0x48, 0xc7, 0xc2};
    static constexpr std::array<uint8_t, 3> negative_loop_prefix_x = {0x48, 0xc7, 0xc1};
    static constexpr std::array<uint8_t, 3> negative_loop_prefix_z = {0x49, 0xc7, 0xc5};
    static constexpr std::array<uint8_t, 3> positive_loop_prefix_z = {0x49, 0x83, 0xfd};
    static constexpr std::array<uint8_t, 3> positive_loop_prefix_x = {0x48, 0x83, 0xf9};
    static constexpr std::array<uint8_t, 3> positive_loop_prefix_y = {0x48, 0x83, 0xfa};

    return has_instruction_prefix(module, INSTANTIATE_DISTANCE_SQUARED_PATCH.instruction_rva, squared_compare_prefix) &&
           has_instruction_prefix(module, INSTANTIATE_LOOP_START_PATCHES[0].instruction_rva, negative_loop_prefix_y) &&
           has_instruction_prefix(module, INSTANTIATE_LOOP_START_PATCHES[1].instruction_rva, negative_loop_prefix_x) &&
           has_instruction_prefix(module, INSTANTIATE_LOOP_START_PATCHES[2].instruction_rva, negative_loop_prefix_z) &&
           has_instruction_prefix(module, INSTANTIATE_LOOP_END_PATCHES[0].instruction_rva, positive_loop_prefix_z) &&
           has_instruction_prefix(module, INSTANTIATE_LOOP_END_PATCHES[1].instruction_rva, positive_loop_prefix_x) &&
           has_instruction_prefix(module, INSTANTIATE_LOOP_END_PATCHES[2].instruction_rva, positive_loop_prefix_y);
}

static bool supports_multi_region_hook_patch(HMODULE module) {
    static constexpr std::array<uint8_t, 6> update_deco_evict_prefix = {0x8b, 0x87, 0x10, 0x01, 0x00, 0x00};
    static constexpr std::array<uint8_t, 6> update_struct_evict_prefix = {0x8b, 0x87, 0x10, 0x01, 0x00, 0x00};
    static constexpr std::array<uint8_t, 6> update_deco_init_prefix = {0x8b, 0x8f, 0x10, 0x01, 0x00, 0x00};
    static constexpr std::array<uint8_t, 4> update_available_prefix = {0x48, 0x8b, 0x4c, 0x24};
    static constexpr std::array<uint8_t, 6> update_assign_prefix = {0x8b, 0x87, 0x10, 0x01, 0x00, 0x00};
    static constexpr std::array<uint8_t, 7> simulate_water_prefix = {0x41, 0x8b, 0x86, 0x10, 0x01, 0x00, 0x00};
    static constexpr std::array<uint8_t, 7> simulate_surface_prefix = {0x41, 0x8b, 0x86, 0x10, 0x01, 0x00, 0x00};

    return has_instruction_prefix(module, MULTI_REGION_HOOK_SITES[UPDATE_DECORATION_EVICT].patch_rva, update_deco_evict_prefix) &&
           has_instruction_prefix(module, MULTI_REGION_HOOK_SITES[UPDATE_STRUCTURE_EVICT].patch_rva, update_struct_evict_prefix) &&
           has_instruction_prefix(module, MULTI_REGION_HOOK_SITES[UPDATE_DECORATION_INIT].patch_rva, update_deco_init_prefix) &&
           has_instruction_prefix(module, MULTI_REGION_HOOK_SITES[UPDATE_RADIUS_CHECK_A].patch_rva, update_available_prefix) &&
           has_instruction_prefix(module, MULTI_REGION_HOOK_SITES[UPDATE_RADIUS_CHECK_B].patch_rva, update_assign_prefix) &&
           has_instruction_prefix(module, MULTI_REGION_HOOK_SITES[SIMULATE_RADIUS_CHECK_A].patch_rva, simulate_water_prefix) &&
           has_instruction_prefix(module, MULTI_REGION_HOOK_SITES[SIMULATE_RADIUS_CHECK_B].patch_rva, simulate_surface_prefix);
}

static int get_current_instance_radius_cap(HMODULE module) {
    return static_cast<int>(read_u32(module, INSTANCE_RADIUS_CAP_PATCH.immediate_rva));
}

static int get_current_chunk_loop_radius(HMODULE module) {
    return static_cast<int>(read_u8(module, INSTANTIATE_LOOP_END_PATCHES[0].immediate_rva));
}

static int get_current_instantiate_chunks_render_distance(HMODULE module) {
    return get_current_chunk_loop_radius(module) * CHUNK_AXIS_SIZE;
}

static uint32_t get_current_instantiate_chunks_radius_squared(HMODULE module) {
    return read_u32(module, INSTANTIATE_DISTANCE_SQUARED_PATCH.immediate_rva);
}

static bool validate_instance_radius_cap(int max_radius, int current_render_distance, String *error_message) {
    if (max_radius < MIN_INSTANCE_RADIUS) {
        *error_message = "instance_radius cap must stay at least 48.";
        return false;
    }

    if (current_render_distance > 0 && max_radius > current_render_distance) {
        *error_message = String("Refusing to raise instance_radius cap to ") +
            String::num_int64(max_radius) +
            String(" above the current chunk pool render distance of ") +
            String::num_int64(current_render_distance) +
            String(".");
        return false;
    }

    return true;
}

static bool validate_render_distance(int render_distance, int current_instance_cap, String *error_message) {
    if (render_distance < MIN_RENDER_DISTANCE) {
        *error_message = "instantiate_chunks render distance must stay at least 48.";
        return false;
    }

    if (render_distance % CHUNK_AXIS_SIZE != 0) {
        *error_message = "instantiate_chunks render distance must be a multiple of 16 because the native chunk pool is chunk-quantized.";
        return false;
    }

    if (render_distance / CHUNK_AXIS_SIZE > MAX_CHUNK_LOOP_RADIUS) {
        *error_message = String("instantiate_chunks render distance ") +
            String::num_int64(render_distance) +
            String(" is too large for the compiled loop encoding; max supported is ") +
            String::num_int64(MAX_CHUNK_LOOP_RADIUS * CHUNK_AXIS_SIZE) +
            String(".");
        return false;
    }

    if (current_instance_cap > 0 && render_distance < current_instance_cap) {
        *error_message = String("Refusing to lower instantiate_chunks render distance to ") +
            String::num_int64(render_distance) +
            String(" below the current instance_radius cap of ") +
            String::num_int64(current_instance_cap) +
            String(".");
        return false;
    }

    return true;
}

static bool patch_instantiate_chunks_render_distance(HMODULE module, int render_distance) {
    const int chunk_loop_radius = render_distance / CHUNK_AXIS_SIZE;
    const int32_t negative_loop_radius = -chunk_loop_radius;
    const uint32_t radius_squared = static_cast<uint32_t>(render_distance * render_distance);

    if (!patch_u32(module, INSTANTIATE_DISTANCE_SQUARED_PATCH, radius_squared)) {
        return false;
    }

    for (const PatchSite &site : INSTANTIATE_LOOP_START_PATCHES) {
        if (!patch_s32(module, site, negative_loop_radius)) {
            return false;
        }
    }

    for (const PatchSite &site : INSTANTIATE_LOOP_END_PATCHES) {
        if (!patch_u8(module, site, static_cast<uint8_t>(chunk_loop_radius))) {
            return false;
        }
    }

    return true;
}

static int32_t snap_axis_to_chunk(double value) {
    const int64_t floored = static_cast<int64_t>(std::floor(value));
    int64_t remainder = floored % CHUNK_AXIS_SIZE;
    if (remainder < 0) {
        remainder += CHUNK_AXIS_SIZE;
    }
    return static_cast<int32_t>(floored - remainder);
}

static NativeChunkCenter snap_center_to_chunk(const Vector3 &position) {
    NativeChunkCenter center;
    center.x = snap_axis_to_chunk(position.x);
    center.y = snap_axis_to_chunk(position.y);
    center.z = snap_axis_to_chunk(position.z);
    return center;
}

static NativeChunkCenter get_world_center_chunk(const void *world) {
    NativeChunkCenter center;
    center.x = read_i32(world, 0x100);
    center.y = read_i32(world, 0x104);
    center.z = read_i32(world, 0x108);
    return center;
}

static int64_t get_radius_for_hook_site(const void *world, uint32_t site_id) {
    switch (site_id) {
        case UPDATE_DECORATION_EVICT:
            return read_i64(world, 0x10) * 2;
        case UPDATE_STRUCTURE_EVICT:
            return read_i64(world, 0x10) + 0x300;
        case UPDATE_DECORATION_INIT:
            return read_i64(world, 0x10) + CHUNK_AXIS_SIZE;
        case UPDATE_RADIUS_CHECK_A:
        case UPDATE_RADIUS_CHECK_B:
            return read_i64(world, 0x10);
        case SIMULATE_RADIUS_CHECK_A:
        case SIMULATE_RADIUS_CHECK_B:
            return read_i64(world, 0x18);
        default:
            return 0;
    }
}

static NativeChunkCenter unpack_coordinate(const void *packed_xy_address, const void *z_address) {
    uint64_t packed_xy = 0;
    int32_t z = 0;
    std::memcpy(&packed_xy, packed_xy_address, sizeof(packed_xy));
    std::memcpy(&z, z_address, sizeof(z));

    NativeChunkCenter coordinate;
    coordinate.x = static_cast<int32_t>(packed_xy & 0xffffffffu);
    coordinate.y = static_cast<int32_t>(packed_xy >> 32);
    coordinate.z = z;
    return coordinate;
}

static NativeChunkCenter get_coordinate_for_hook_site(const void *entry_rsp, const void *rbp, uint32_t site_id) {
    const uint8_t *rsp = reinterpret_cast<const uint8_t *>(entry_rsp);
    const uint8_t *base_pointer = reinterpret_cast<const uint8_t *>(rbp);

    switch (site_id) {
        case UPDATE_DECORATION_EVICT:
        case UPDATE_STRUCTURE_EVICT:
        case UPDATE_DECORATION_INIT:
        case UPDATE_RADIUS_CHECK_A:
        case UPDATE_RADIUS_CHECK_B:
            return unpack_coordinate(rsp + 0x58, rsp + 0x60);
        case SIMULATE_RADIUS_CHECK_A:
            return unpack_coordinate(base_pointer - 0x59, base_pointer - 0x51);
        case SIMULATE_RADIUS_CHECK_B:
            return unpack_coordinate(rsp + 0x28, base_pointer - 0x79);
        default:
            return NativeChunkCenter {};
    }
}

static bool is_coordinate_in_radius(const NativeChunkCenter &coordinate, const NativeChunkCenter &center, int64_t radius) {
    if (radius <= 0) {
        return false;
    }

    const int64_t dx = static_cast<int64_t>(center.x) - static_cast<int64_t>(coordinate.x);
    const int64_t dy = static_cast<int64_t>(center.y) - static_cast<int64_t>(coordinate.y);
    const int64_t dz = static_cast<int64_t>(center.z) - static_cast<int64_t>(coordinate.z);
    const int64_t distance_squared = dx * dx + dy * dy + dz * dz;
    const int64_t radius_squared = radius * radius;
    return distance_squared < radius_squared;
}

extern "C" bool coop_evaluate_multi_region_radius(const void *world, const void *entry_rsp, const void *rbp, uint32_t site_id) {
    if (world == nullptr) {
        return false;
    }

    const NativeChunkCenter coordinate = get_coordinate_for_hook_site(entry_rsp, rbp, site_id);
    const int64_t radius = get_radius_for_hook_site(world, site_id);
    bool had_world_specific_centers = false;

    {
        std::lock_guard<std::mutex> lock(g_world_center_lock);
        auto it = g_world_active_region_centers.find(world);
        if (it != g_world_active_region_centers.end()) {
            had_world_specific_centers = !it->second.empty();
            for (const NativeChunkCenter &center : it->second) {
                if (is_coordinate_in_radius(coordinate, center, radius)) {
                    return true;
                }
            }
        }
    }

    const uint32_t active_center_count = g_active_region_center_count;
    if (active_center_count == 0) {
        if (had_world_specific_centers) {
            return false;
        }
        return is_coordinate_in_radius(coordinate, get_world_center_chunk(world), radius);
    }

    const uint32_t center_count = active_center_count > MAX_ACTIVE_REGION_CENTERS ? MAX_ACTIVE_REGION_CENTERS : active_center_count;
    for (uint32_t i = 0; i < center_count; i++) {
        if (is_coordinate_in_radius(coordinate, g_active_region_centers[i], radius)) {
            return true;
        }
    }

    return false;
}

static void store_active_region_centers(const Array &centers) {
    const std::vector<NativeChunkCenter> snapped_centers = collect_snapped_centers(centers);

    uint32_t count = 0;
    for (const NativeChunkCenter &center : snapped_centers) {
        g_active_region_centers[count] = center;
        count++;
    }

    g_active_region_center_count = count;
}

static void store_world_active_region_centers(const void *world, const Array &centers) {
    store_active_region_centers(centers);

    if (world == nullptr) {
        return;
    }

    std::vector<NativeChunkCenter> snapped_centers = collect_snapped_centers(centers);

    std::lock_guard<std::mutex> lock(g_world_center_lock);
    if (snapped_centers.empty()) {
        g_world_active_region_centers.erase(world);
    } else {
        g_world_active_region_centers[world] = std::move(snapped_centers);
    }
}

static void clear_world_active_region_centers_internal(const void *world) {
    g_active_region_center_count = 0;

    if (world == nullptr) {
        return;
    }
    std::lock_guard<std::mutex> lock(g_world_center_lock);
    g_world_active_region_centers.erase(world);
}

static void clear_active_region_centers_internal() {
    g_active_region_center_count = 0;
}

static bool install_multi_region_hooks_internal(HMODULE module) {
    if (g_multi_region_hooks_installed) {
        return true;
    }

    if (!supports_multi_region_hook_patch(module)) {
        return false;
    }

    g_coop_update_hook_0_inside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_DECORATION_EVICT].inside_target_rva));
    g_coop_update_hook_0_outside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_DECORATION_EVICT].outside_target_rva));
    g_coop_update_hook_1_inside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_STRUCTURE_EVICT].inside_target_rva));
    g_coop_update_hook_1_outside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_STRUCTURE_EVICT].outside_target_rva));
    g_coop_update_hook_2_inside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_DECORATION_INIT].inside_target_rva));
    g_coop_update_hook_2_outside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_DECORATION_INIT].outside_target_rva));
    g_coop_update_hook_3_inside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_RADIUS_CHECK_A].inside_target_rva));
    g_coop_update_hook_3_outside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_RADIUS_CHECK_A].outside_target_rva));
    g_coop_update_hook_4_inside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_RADIUS_CHECK_B].inside_target_rva));
    g_coop_update_hook_4_outside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[UPDATE_RADIUS_CHECK_B].outside_target_rva));
    g_coop_simulate_hook_1_inside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[SIMULATE_RADIUS_CHECK_A].inside_target_rva));
    g_coop_simulate_hook_1_outside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[SIMULATE_RADIUS_CHECK_A].outside_target_rva));
    g_coop_simulate_hook_2_inside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[SIMULATE_RADIUS_CHECK_B].inside_target_rva));
    g_coop_simulate_hook_2_outside = reinterpret_cast<uintptr_t>(resolve_rva(module, MULTI_REGION_HOOK_SITES[SIMULATE_RADIUS_CHECK_B].outside_target_rva));
    const void *hook_entrypoints[] = {
        reinterpret_cast<const void *>(&coop_update_radius_hook_1),
        reinterpret_cast<const void *>(&coop_update_radius_hook_2),
        reinterpret_cast<const void *>(&coop_update_radius_hook_3),
        reinterpret_cast<const void *>(&coop_update_radius_hook_4),
        reinterpret_cast<const void *>(&coop_update_radius_hook_5),
        reinterpret_cast<const void *>(&coop_simulate_radius_hook_1),
        reinterpret_cast<const void *>(&coop_simulate_radius_hook_2),
    };

    for (size_t i = 0; i < std::size(MULTI_REGION_HOOK_SITES); i++) {
        const MultiRegionHookSite &site = MULTI_REGION_HOOK_SITES[i];
        if (!write_absolute_jump(resolve_rva(module, site.patch_rva), hook_entrypoints[i], site.patch_length)) {
            return false;
        }
    }

    g_multi_region_hooks_installed = true;
    return true;
}

#endif

}

void CoopNativePatch::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_status"), &CoopNativePatch::get_status);
    ClassDB::bind_method(D_METHOD("patch_loaded_instance_radius_cap", "max_radius"), &CoopNativePatch::patch_loaded_instance_radius_cap);
    ClassDB::bind_method(D_METHOD("patch_loaded_instantiate_chunks_render_distance", "render_distance"), &CoopNativePatch::patch_loaded_instantiate_chunks_render_distance);
    ClassDB::bind_method(D_METHOD("patch_world_streaming_limits", "max_radius", "render_distance"), &CoopNativePatch::patch_world_streaming_limits);
    ClassDB::bind_method(D_METHOD("restore_default_world_streaming_limits"), &CoopNativePatch::restore_default_world_streaming_limits);
    ClassDB::bind_method(D_METHOD("install_multi_region_radius_hooks"), &CoopNativePatch::install_multi_region_radius_hooks);
    ClassDB::bind_method(D_METHOD("set_world_active_region_centers", "world", "centers"), &CoopNativePatch::set_world_active_region_centers);
    ClassDB::bind_method(D_METHOD("clear_world_active_region_centers", "world"), &CoopNativePatch::clear_world_active_region_centers);
    ClassDB::bind_method(D_METHOD("set_active_region_centers", "centers"), &CoopNativePatch::set_active_region_centers);
    ClassDB::bind_method(D_METHOD("clear_active_region_centers"), &CoopNativePatch::clear_active_region_centers);
}

Dictionary CoopNativePatch::get_status() const {
    Dictionary status;
    status["target_dll"] = String(GDBLOCKS_DLL_NAME);
    status["set_instance_radius_instruction_rva"] = int64_t(INSTANCE_RADIUS_CAP_PATCH.instruction_rva);
    status["set_instance_radius_immediate_rva"] = int64_t(INSTANCE_RADIUS_CAP_PATCH.immediate_rva);
    status["instantiate_chunks_function_rva"] = int64_t(INSTANTIATE_CHUNKS_FUNCTION_RVA);
    status["instantiate_chunks_radius_squared_instruction_rva"] = int64_t(INSTANTIATE_DISTANCE_SQUARED_PATCH.instruction_rva);
    status["instantiate_chunks_radius_squared_immediate_rva"] = int64_t(INSTANTIATE_DISTANCE_SQUARED_PATCH.immediate_rva);

#ifdef _WIN32
    status["platform"] = String("windows");

    HMODULE module = get_gdblocks_module();
    status["module_loaded"] = module != nullptr;
    status["active_region_center_count"] = int64_t(g_active_region_center_count);
    status["multi_region_hooks_installed"] = g_multi_region_hooks_installed;

    if (module != nullptr) {
        const bool instance_supported = supports_instance_radius_patch(module);
        const bool instantiate_supported = supports_instantiate_chunks_patch(module);
        const bool hooks_supported = supports_multi_region_hook_patch(module);
        const int current_instance_cap = get_current_instance_radius_cap(module);
        const int current_render_distance = get_current_instantiate_chunks_render_distance(module);

        status["set_instance_radius_supported"] = instance_supported;
        status["instantiate_chunks_supported"] = instantiate_supported;
        status["multi_region_hooks_supported"] = hooks_supported;
        status["binary_supported"] = instance_supported && instantiate_supported;
        status["current_instance_radius_cap"] = int64_t(current_instance_cap);
        status["current_instantiate_chunks_render_distance"] = int64_t(current_render_distance);
        status["current_instantiate_chunks_chunk_radius"] = int64_t(get_current_chunk_loop_radius(module));
        status["current_instantiate_chunks_radius_squared"] = int64_t(get_current_instantiate_chunks_radius_squared(module));
        status["world_radius_pair_safe"] = current_render_distance >= current_instance_cap;
    }
#else
    status["platform"] = String("non_windows");
    status["module_loaded"] = false;
#endif

    return status;
}

bool CoopNativePatch::patch_loaded_instance_radius_cap(int max_radius) {
#ifndef _WIN32
    UtilityFunctions::printerr("[lucid-blocks-coop] Native patch is only implemented for Windows builds.");
    return false;
#else
    HMODULE module = get_gdblocks_module();
    if (module == nullptr) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Could not find loaded gdblocks DLL.");
        return false;
    }

    if (!supports_instance_radius_patch(module)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] This gdblocks DLL does not match the known set_instance_radius patch site.");
        return false;
    }

    String error_message;
    if (!validate_instance_radius_cap(max_radius, get_current_instantiate_chunks_render_distance(module), &error_message)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] ", error_message);
        return false;
    }

    const uint32_t patched_cap = static_cast<uint32_t>(max_radius);
    if (!patch_u32(module, INSTANCE_RADIUS_CAP_PATCH, patched_cap)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Failed to patch instance radius cap.");
        return false;
    }

    UtilityFunctions::print("[lucid-blocks-coop] Patched native instance radius cap to ", int64_t(patched_cap), ".");
    return true;
#endif
}

bool CoopNativePatch::patch_loaded_instantiate_chunks_render_distance(int render_distance) {
#ifndef _WIN32
    UtilityFunctions::printerr("[lucid-blocks-coop] Native patch is only implemented for Windows builds.");
    return false;
#else
    HMODULE module = get_gdblocks_module();
    if (module == nullptr) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Could not find loaded gdblocks DLL.");
        return false;
    }

    if (!supports_instantiate_chunks_patch(module)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] This gdblocks DLL does not match the known instantiate_chunks patch sites.");
        return false;
    }

    String error_message;
    if (!validate_render_distance(render_distance, get_current_instance_radius_cap(module), &error_message)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] ", error_message);
        return false;
    }

    if (!patch_instantiate_chunks_render_distance(module, render_distance)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Failed to patch instantiate_chunks render distance.");
        return false;
    }

    UtilityFunctions::print(
        "[lucid-blocks-coop] Patched instantiate_chunks render distance to ",
        int64_t(render_distance),
        " (chunk loop radius ",
        int64_t(render_distance / CHUNK_AXIS_SIZE),
        ")."
    );
    return true;
#endif
}

bool CoopNativePatch::patch_world_streaming_limits(int max_radius, int render_distance) {
#ifndef _WIN32
    UtilityFunctions::printerr("[lucid-blocks-coop] Native patch is only implemented for Windows builds.");
    return false;
#else
    HMODULE module = get_gdblocks_module();
    if (module == nullptr) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Could not find loaded gdblocks DLL.");
        return false;
    }

    if (!supports_instance_radius_patch(module) || !supports_instantiate_chunks_patch(module)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] This gdblocks DLL does not match the known world streaming patch sites.");
        return false;
    }

    String render_error;
    if (!validate_render_distance(render_distance, max_radius, &render_error)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] ", render_error);
        return false;
    }

    String radius_error;
    if (!validate_instance_radius_cap(max_radius, render_distance, &radius_error)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] ", radius_error);
        return false;
    }

    if (!patch_instantiate_chunks_render_distance(module, render_distance)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Failed to patch instantiate_chunks render distance.");
        return false;
    }

    const uint32_t patched_cap = static_cast<uint32_t>(max_radius);
    if (!patch_u32(module, INSTANCE_RADIUS_CAP_PATCH, patched_cap)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Failed to patch instance radius cap.");
        return false;
    }

    UtilityFunctions::print(
        "[lucid-blocks-coop] Patched world streaming limits: instance_radius cap=",
        int64_t(patched_cap),
        ", instantiate_chunks render distance=",
        int64_t(render_distance),
        "."
    );
    return true;
#endif
}

bool CoopNativePatch::restore_default_world_streaming_limits() {
    return patch_world_streaming_limits(
        DEFAULT_INSTANCE_RADIUS_CAP,
        DEFAULT_INSTANTIATE_CHUNKS_RENDER_DISTANCE
    );
}

bool CoopNativePatch::install_multi_region_radius_hooks() {
#ifndef _WIN32
    UtilityFunctions::printerr("[lucid-blocks-coop] Native multi-region hooks are only implemented for Windows builds.");
    return false;
#else
    HMODULE module = get_gdblocks_module();
    if (module == nullptr) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Could not find loaded gdblocks DLL.");
        return false;
    }

    if (!install_multi_region_hooks_internal(module)) {
        UtilityFunctions::printerr("[lucid-blocks-coop] Failed to install native multi-region radius hooks.");
        return false;
    }

    UtilityFunctions::print("[lucid-blocks-coop] Installed native multi-region radius hooks.");
    return true;
#endif
}

void CoopNativePatch::set_world_active_region_centers(Object *world, Array centers) {
#ifdef _WIN32
    HMODULE module = get_gdblocks_module();
    if (module != nullptr && !g_multi_region_hooks_installed) {
        install_multi_region_hooks_internal(module);
    }
    store_world_active_region_centers(world, centers);
#else
    (void)world;
    (void)centers;
#endif
}

void CoopNativePatch::clear_world_active_region_centers(Object *world) {
#ifdef _WIN32
    clear_world_active_region_centers_internal(world);
#else
    (void)world;
#endif
}

void CoopNativePatch::set_active_region_centers(Array centers) {
#ifdef _WIN32
    HMODULE module = get_gdblocks_module();
    if (module != nullptr && !g_multi_region_hooks_installed) {
        install_multi_region_hooks_internal(module);
    }
    store_active_region_centers(centers);
#else
    (void)centers;
#endif
}

void CoopNativePatch::clear_active_region_centers() {
#ifdef _WIN32
    clear_active_region_centers_internal();
#endif
}
