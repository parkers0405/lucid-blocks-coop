"""
Re-rig Pim's mesh onto the default Mixamo skeleton.
Takes the default character's armature (with correct rest poses) and
transfers Pim's mesh onto it using automatic weights.
Output: a single FBX with the default skeleton + pim's mesh.

Usage: blender --background --python rerig_pim_to_default.py -- \
         default.fbx pim.fbx texture.png output.fbx
"""

import bpy
import sys
from mathutils import Matrix


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    if len(args) != 4:
        print(
            "Usage: blender --background --python rerig_pim_to_default.py -- default.fbx pim.fbx texture.png output.fbx"
        )
        raise SystemExit(1)

    default_fbx, pim_fbx, texture_path, output_fbx = args

    # Start clean
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Import default character (we want its armature)
    bpy.ops.import_scene.fbx(filepath=default_fbx)
    default_armature = None
    default_meshes = []
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            default_armature = obj
        elif obj.type == "MESH":
            default_meshes.append(obj)

    if default_armature is None:
        print("ERROR: No armature found in default FBX")
        raise SystemExit(1)

    # Remove default meshes - we only want the armature
    for mesh_obj in default_meshes:
        bpy.data.objects.remove(mesh_obj, do_unlink=True)

    print(
        f"Default armature: {default_armature.name} with {len(default_armature.data.bones)} bones"
    )

    # Import pim (we want its mesh)
    bpy.ops.import_scene.fbx(filepath=pim_fbx)
    pim_armature = None
    pim_meshes = []
    for obj in bpy.data.objects:
        if obj == default_armature:
            continue
        if obj.type == "ARMATURE":
            pim_armature = obj
        elif obj.type == "MESH":
            pim_meshes.append(obj)

    if not pim_meshes:
        print("ERROR: No mesh found in pim FBX")
        raise SystemExit(1)

    print(f"Pim meshes: {[m.name for m in pim_meshes]}")

    # Remove pim's armature
    if pim_armature is not None:
        bpy.data.objects.remove(pim_armature, do_unlink=True)

    import mathutils

    # Both default and pim meshes stand along WORLD Z in Blender.
    # The default armature has rot=(90°,0,0) so bone-local Y = world Z.
    # We need to match pim's mesh to the default skeleton's world-space bone positions.

    # Get the default skeleton's world-space extent (along Z since armature is rotated)
    # by checking the actual mesh bounds of the default character
    default_mesh_world_min_z = float("inf")
    default_mesh_world_max_z = float("-inf")
    for obj in bpy.data.objects:
        if (
            obj.type == "MESH"
            and obj != pim_meshes[0]
            and obj.parent == default_armature
        ):
            for v in obj.data.vertices:
                wv = obj.matrix_world @ v.co
                if wv.z < default_mesh_world_min_z:
                    default_mesh_world_min_z = wv.z
                if wv.z > default_mesh_world_max_z:
                    default_mesh_world_max_z = wv.z

    # If we removed default meshes already, use bone positions instead
    if default_mesh_world_min_z == float("inf"):
        foot = default_armature.data.bones.get("mixamorig:LeftFoot")
        head = default_armature.data.bones.get("mixamorig:Head")
        if foot and head:
            # Bone local Y maps to world Z due to 90° X rotation on armature
            default_mesh_world_min_z = (
                foot.head_local.y * 0.9
            )  # approximate foot bottom
            default_mesh_world_max_z = head.tail_local.y  # top of head

    skel_world_height = default_mesh_world_max_z - default_mesh_world_min_z
    skel_world_center_z = (default_mesh_world_max_z + default_mesh_world_min_z) / 2.0
    print(
        f"Default skeleton world Z range: [{default_mesh_world_min_z:.3f}, {default_mesh_world_max_z:.3f}] height={skel_world_height:.3f}"
    )

    for mesh_obj in pim_meshes:
        # Clear old parent
        if mesh_obj.parent is not None:
            world_mat = mesh_obj.matrix_world.copy()
            mesh_obj.parent = None
            mesh_obj.matrix_world = world_mat

        # Clear old vertex groups and armature modifiers
        mesh_obj.vertex_groups.clear()
        for mod in list(mesh_obj.modifiers):
            if mod.type == "ARMATURE":
                mesh_obj.modifiers.remove(mod)

        # Bake world transform into mesh
        mesh_obj.data.transform(mesh_obj.matrix_world)
        mesh_obj.matrix_world = Matrix.Identity(4)

        # Measure mesh world-space bounds
        verts = [v.co for v in mesh_obj.data.vertices]
        min_co = mathutils.Vector(
            (min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts))
        )
        max_co = mathutils.Vector(
            (max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts))
        )
        print(
            f"  Pim mesh bounds: X=[{min_co.x:.3f},{max_co.x:.3f}] Y=[{min_co.y:.3f},{max_co.y:.3f}] Z=[{min_co.z:.3f},{max_co.z:.3f}]"
        )

        # Pim stands along Z (tallest axis). NO rotation needed.
        mesh_z_height = max_co.z - min_co.z
        mesh_z_center = (max_co.z + min_co.z) / 2.0

        # Scale to match default skeleton Z height
        scale = skel_world_height / mesh_z_height if mesh_z_height > 0.001 else 1.0
        mesh_obj.data.transform(Matrix.Scale(scale, 4))
        print(f"  Scaled by {scale:.3f}")

        # Re-measure after scale
        verts = [v.co for v in mesh_obj.data.vertices]
        min_co_z = min(v.z for v in verts)
        max_co_z = max(v.z for v in verts)
        mesh_z_center = (max_co_z + min_co_z) / 2.0

        # Translate Z to align centers
        offset_z = skel_world_center_z - mesh_z_center
        mesh_obj.data.transform(Matrix.Translation(mathutils.Vector((0, 0, offset_z))))
        print(f"  Translated Z by {offset_z:.3f}")

        # Final check
        verts = [v.co for v in mesh_obj.data.vertices]
        final_min_z = min(v.z for v in verts)
        final_max_z = max(v.z for v in verts)
        print(f"  Final mesh Z range: [{final_min_z:.3f}, {final_max_z:.3f}]")

        # Select mesh and armature, parent with automatic weights
        bpy.ops.object.select_all(action="DESELECT")
        mesh_obj.select_set(True)
        default_armature.select_set(True)
        bpy.context.view_layer.objects.active = default_armature
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        print(
            f"  Parented {mesh_obj.name} to {default_armature.name} with auto weights"
        )
        print(f"  Vertex groups created: {len(mesh_obj.vertex_groups)}")

    # Load and assign texture
    image = bpy.data.images.load(texture_path, check_existing=True)
    material = bpy.data.materials.new(name="PimTextured")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output_node = nodes.new(type="ShaderNodeOutputMaterial")
    output_node.location = (300, 0)
    bsdf_node = nodes.new(type="ShaderNodeBsdfPrincipled")
    bsdf_node.location = (0, 0)
    image_node = nodes.new(type="ShaderNodeTexImage")
    image_node.location = (-300, 0)
    image_node.image = image
    links.new(image_node.outputs["Color"], bsdf_node.inputs["Base Color"])
    links.new(bsdf_node.outputs["BSDF"], output_node.inputs["Surface"])

    for mesh_obj in pim_meshes:
        mesh_obj.data.materials.clear()
        mesh_obj.data.materials.append(material)

    # Select everything for export
    bpy.ops.object.select_all(action="SELECT")

    # Apply all transforms before export
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Export with same axis convention as the default FBX
    bpy.ops.export_scene.fbx(
        filepath=output_fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
    )
    print(f"Exported re-rigged pim to: {output_fbx}")


if __name__ == "__main__":
    main()
