Coop mod animation workflow

This folder belongs to the actual coop mod project at `mod/overrides/`.

Use this project, not `lucid-blocks-decompiled/`, when you want to build better reusable player animation assets for the coop mod.

What is included

- `mixamo_bone_map.tres`
  - bone map for Mixamo-style humanoid rigs
- `locomotion_library.res`
  - open humanoid locomotion animation library
- Godot addon: `res://addons/mixamo_animation_retargeter/`
  - right-click FBX retargeting tool inside the Godot editor

Recommended workflow

1. Open the Godot project at `mod/overrides/project.godot`
2. Make sure the plugin `Mixamo Animation Retargeter` is enabled
3. Import a humanoid player model (`.glb` or `.fbx`) into `coop_mod/avatar_assets/<avatar_id>/`
4. If the rig is Mixamo-compatible, reimport the skeleton with `mixamo_bone_map.tres`
5. Put source animation FBX files in `coop_mod/animation_workflow/source_fbx/`
6. Right-click the FBX files and choose `Retarget Mixamo Animation`
7. Save the resulting animation `.res` files into `coop_mod/animation_workflow/generated/<set_name>/`
8. Add the generated animations to an AnimationLibrary or a local avatar scene
9. Point the coop avatar manifest at the new scene/model and tune its `avatar.json`

Best import choice

- Character models: `.glb` is great
- Animation clips: `.fbx` is better for this workflow

Why FBX is better here

- the installed retargeter addon works directly on FBX files
- Mixamo-style animation packs are usually distributed as FBX clips
- Godot retargeting is much smoother when the clips come in as separate FBX animation files
- we can keep avatars as GLB while using FBX only for the animation source set

Good legal free sources

- RaidTheory Mixamo Animation Retargeter
- Godot4 Open Animation Libraries / Mixamo-compatible locomotion library
- Ready Player Me animation library (great source set, but usually needs more retargeting)

Goal

The long-term goal is:

- one reusable animation base for the coop mod
- avatar manifests for per-model scale/bones/materials
- imported characters that reuse the same animation set instead of procedural-only motion
