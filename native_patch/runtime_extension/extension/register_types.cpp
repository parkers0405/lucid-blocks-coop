#include "register_types.h"

#include "coop_native_patch.h"

#include <gdextension_interface.h>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_coop_native_patch_types(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<CoopNativePatch>();
}

void uninitialize_coop_native_patch_types(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT coop_native_patch_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization) {
    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_coop_native_patch_types);
    init_obj.register_terminator(uninitialize_coop_native_patch_types);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
