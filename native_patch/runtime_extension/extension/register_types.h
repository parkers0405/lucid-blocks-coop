#pragma once

#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>

void initialize_coop_native_patch_types(godot::ModuleInitializationLevel p_level);
void uninitialize_coop_native_patch_types(godot::ModuleInitializationLevel p_level);
