import bpy
import sys
from mathutils import Matrix


def main() -> None:
    argv = sys.argv
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    if len(args) != 2:
        print(
            "usage: blender --background --python extract_mesh_for_mixamo.py -- input.fbx output.fbx"
        )
        raise SystemExit(1)

    input_path, output_path = args

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=input_path)

    texture_path = None
    for image in bpy.data.images:
        if image.filepath:
            texture_path = bpy.path.abspath(image.filepath)
            break

    for obj in list(bpy.data.objects):
        if obj.type == "ARMATURE":
            bpy.data.objects.remove(obj, do_unlink=True)

    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for mod in list(obj.modifiers):
            if mod.type == "ARMATURE":
                obj.modifiers.remove(mod)
        if obj.parent is not None:
            world_matrix = obj.matrix_world.copy()
            obj.parent = None
            obj.matrix_world = world_matrix
        obj.vertex_groups.clear()

        # Bake world transform into the mesh so Mixamo sees a clean mesh with
        # identity object transform instead of the imported FBX hierarchy.
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)

        # Replace whatever material graph Sketchfab imported with a minimal
        # Principled + image texture setup that FBX export can actually carry.
        material = bpy.data.materials.new(name="PimMixamo")
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()

        output_node = nodes.new(type="ShaderNodeOutputMaterial")
        output_node.location = (300, 0)
        bsdf_node = nodes.new(type="ShaderNodeBsdfPrincipled")
        bsdf_node.location = (0, 0)
        links.new(bsdf_node.outputs["BSDF"], output_node.inputs["Surface"])

        if texture_path is not None:
            image_node = nodes.new(type="ShaderNodeTexImage")
            image_node.location = (-300, 0)
            image_node.image = bpy.data.images.load(texture_path, check_existing=True)
            links.new(image_node.outputs["Color"], bsdf_node.inputs["Base Color"])

        obj.data.materials.clear()
        obj.data.materials.append(material)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj

    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
    )
    print("wrote", output_path)


if __name__ == "__main__":
    main()
