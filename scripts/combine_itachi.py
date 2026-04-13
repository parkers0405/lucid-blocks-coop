"""
Combine all itachi FBX parts into one mesh on one armature for Mixamo upload.
The key: import everything, join meshes, recalculate normals, export clean.
Usage: blender --background --python combine_itachi.py -- output.fbx
"""

import bpy
import sys


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    if len(args) != 1:
        print("Usage: blender --background --python combine_itachi.py -- output.fbx")
        raise SystemExit(1)

    output_fbx = args[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Import all parts
    parts = [
        "/tmp/itachi_check/source/extracted/T-Pose (1).fbx",
        "/tmp/itachi_check/source/extracted/face.fbx",
        "/tmp/itachi_check/source/extracted/face 2.fbx",
        "/tmp/itachi_check/source/extracted/heair.fbx",
        "/tmp/itachi_check/source/extracted/head band.fbx",
        "/tmp/itachi_check/source/extracted/body.fbx",
        "/tmp/itachi_check/source/extracted/pant.fbx",
    ]
    for p in parts:
        bpy.ops.import_scene.fbx(filepath=p)

    # Find THE armature (from T-Pose file - it has bones)
    armature = None
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE" and len(obj.data.bones) > 10:
            armature = obj
            break

    if armature is None:
        print("ERROR: No armature found")
        raise SystemExit(1)

    # Remove any duplicate/empty armatures from the other FBX imports
    for obj in list(bpy.data.objects):
        if obj.type == "ARMATURE" and obj != armature:
            bpy.data.objects.remove(obj, do_unlink=True)

    print(f"Armature: {armature.name} with {len(armature.data.bones)} bones")

    # Collect all meshes
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    print(f"Found {len(meshes)} meshes")
    for m in meshes:
        print(
            f"  {m.name}: verts={len(m.data.vertices)} parent={m.parent.name if m.parent else 'None'}"
        )

    # Parent all loose meshes to the armature (keep transform, no auto-weights)
    for mesh in meshes:
        if mesh.parent != armature:
            mesh.parent = armature
            mesh.matrix_parent_inverse = armature.matrix_world.inverted()
            # Add armature modifier if not present
            has_armature_mod = any(m.type == "ARMATURE" for m in mesh.modifiers)
            if not has_armature_mod:
                mod = mesh.modifiers.new(name="Armature", type="ARMATURE")
                mod.object = armature

    # Select all meshes and join into one
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()

    combined = bpy.context.active_object
    print(f"Combined: {combined.name} verts={len(combined.data.vertices)}")

    # Recalculate normals
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("Recalculated normals")

    # Export - use default FBX settings (no custom axis) so Mixamo gets what it expects
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=output_fbx,
        use_selection=False,
        object_types={"ARMATURE", "MESH"},
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=False,
    )
    print(f"Exported to: {output_fbx}")


if __name__ == "__main__":
    main()
