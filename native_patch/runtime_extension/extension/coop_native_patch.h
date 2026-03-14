#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class CoopNativePatch : public Object {
    GDCLASS(CoopNativePatch, Object)

protected:
    static void _bind_methods();

public:
    Dictionary get_status() const;
    bool patch_loaded_instance_radius_cap(int max_radius);
    bool patch_loaded_instantiate_chunks_render_distance(int render_distance);
    bool patch_world_streaming_limits(int max_radius, int render_distance);
    bool restore_default_world_streaming_limits();
    bool install_multi_region_radius_hooks();
    void set_active_region_centers(Array centers);
    void clear_active_region_centers();
};

}
