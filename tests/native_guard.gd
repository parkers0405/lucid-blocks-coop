extends RefCounted


static func run() -> int:
    var runtime_dir: String = OS.get_executable_path().get_base_dir()
    if not FileAccess.file_exists(runtime_dir.path_join(".coop-test-runtime")):
        print("NATIVE_GUARD_FAIL requires disposable test runtime")
        return 1
    var ref_script = load("res://main/autoload/ref.gd")
    var failures := 0
    for digest in ["", "unknown", "B25C20E9AE4CF0C21CBC015CDF58A8F4C3F0C5B8AA1652F81A071F471CD2CFEA"]:
        if ref_script.is_native_patch_build_validated(digest):
            failures += 1
    var patch_dir = runtime_dir.path_join("coop-native-patch")
    var extension = patch_dir.path_join("coop_native_patch.gdextension")
    if FileAccess.file_exists(extension):
        print("NATIVE_GUARD_FAIL existing extension fixture")
        return failures + 1
    if DirAccess.make_dir_recursive_absolute(patch_dir) != OK:
        print("NATIVE_GUARD_FAIL fixture directory")
        return failures + 1
    var file = FileAccess.open(extension, FileAccess.WRITE)
    file.store_string("invalid extension fixture; loading this must fail")
    file.close()
    Ref._bootstrap_native_patch()
    if Ref.coop_native_patch != null or GDExtensionManager.is_extension_loaded(extension):
        failures += 1
    DirAccess.remove_absolute(extension)
    DirAccess.remove_absolute(patch_dir)
    print("NATIVE_GUARD_RESULT assertions=4 failures=", failures)
    return failures
