#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string.h>

extern IMAGE_DOS_HEADER __ImageBase;

typedef char GDExtensionBool;
typedef void *GDExtensionInterfaceGetProcAddress;
typedef void *GDExtensionClassLibraryPtr;
typedef void *GDExtensionInitialization;

typedef GDExtensionBool (__cdecl *gdblocks_init_fn)(
    GDExtensionInterfaceGetProcAddress,
    GDExtensionClassLibraryPtr,
    GDExtensionInitialization *);

static HMODULE real_module;
static gdblocks_init_fn real_gdblocks_init;

static int load_real_gdblocks(void) {
    char proxy_path[MAX_PATH];
    char real_path[MAX_PATH];
    char *file_name;

    if (real_gdblocks_init != NULL) {
        return 1;
    }

    if (GetModuleFileNameA((HMODULE)&__ImageBase, proxy_path, sizeof(proxy_path)) == 0) {
        return 0;
    }

    file_name = strrchr(proxy_path, '\\');
    if (file_name == NULL) {
        return 0;
    }

    lstrcpyA(real_path, proxy_path);
    lstrcpyA(file_name + 1, "libgdblocks.windows.template_release.double.x86_64.original.dll");

    real_module = LoadLibraryA(real_path);
    if (real_module == NULL) {
        return 0;
    }

    real_gdblocks_init = (gdblocks_init_fn)GetProcAddress(real_module, "gdblocks_init");
    return real_gdblocks_init != NULL;
}

static void apply_world_loader_patch_if_ready(void) {
    /*
     * Placeholder.
     *
     * Future work:
     * - verify DLL hash before patching
     * - install trampoline / byte patch for World::set_loaded_region_center
     *   and World::update_loaded_region
     * - expose any new script-callable helper if needed
     */
}

__declspec(dllexport)
GDExtensionBool __cdecl gdblocks_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization *initialization) {
    if (!load_real_gdblocks()) {
        return 0;
    }

    apply_world_loader_patch_if_ready();
    return real_gdblocks_init(get_proc_address, library, initialization);
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)instance;
    (void)reason;
    (void)reserved;
    return TRUE;
}

#else

typedef int gdblocks_proxy_windows_only;

#endif
