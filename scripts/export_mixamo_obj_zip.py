import bpy
import shutil
import sys
from mathutils import Matrix
from pathlib import Path


def main() -> None:
    argv = sys.argv
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    if len(args) != 4:
        print(
            "usage: blender --background --python export_mixamo_obj_zip.py -- input.fbx texture.png output_dir output_zip"
        )
        raise SystemExit(1)

    input_path = Path(args[0]).resolve()
    texture_path = Path(args[1]).resolve()
    output_dir = Path(args[2]).resolve()
    output_zip = Path(args[3]).resolve()

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(input_path))

    for obj in list(bpy.data.objects):
        if obj.type == "ARMATURE":
            bpy.data.objects.remove(obj, do_unlink=True)

    image = bpy.data.images.load(str(texture_path), check_existing=True)

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
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)

        material = bpy.data.materials.new(name="PimMixamo")
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

        obj.data.materials.clear()
        obj.data.materials.append(material)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj

    obj_path = output_dir / "pim_mixamo_upload.obj"
    bpy.ops.wm.obj_export(
        filepath=str(obj_path),
        export_selected_objects=True,
        export_materials=True,
    )

    shutil.copy2(texture_path, output_dir / texture_path.name)

    if output_zip.exists():
        output_zip.unlink()
    archive_base = str(output_zip.with_suffix(""))
    shutil.make_archive(archive_base, "zip", output_dir)
    print("wrote", obj_path)
    print("wrote", output_zip)


if __name__ == "__main__":
    main()
