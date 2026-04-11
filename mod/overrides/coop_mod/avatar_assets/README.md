Current default avatar:
- `rigged_default/low_poly_character.glb`

Drop-in avatar workflow:
- make a folder in `avatar_assets/`, for example `avatar_assets/my_robot/`
- put your character `.glb` inside that folder
- add an optional `avatar.json` manifest to tune scale, look, skin mode, and bone mapping
- open `/char-select` in game and the avatar appears automatically

Recommended starting point:
- `GLB` format
- one humanoid armature
- one visible skinned mesh
- textures embedded or shipped next to the model

Suggested folder layout:
- `avatar_assets/<id>/model.glb`
- `avatar_assets/<id>/avatar.json`

Example `avatar.json`:
```json
{
  "id": "my_robot",
  "name": "My Robot",
  "model": "model.glb",
  "height": 1.9,
  "ground_offset": -0.02,
  "preview_height": 1.7,
  "preview_yaw": 160.0,
  "skin_mode": "passthrough",
  "look_sign": -1.0,
  "neutral_bias_deg": 0.0,
  "head_scale": 0.6,
  "neck_scale": 0.4,
  "show_held_items": false,
  "locomotion_arm_offset_z": 0.0,
  "locomotion_forearm_offset_z": 0.0,
  "bone_overrides": {
    "mixamorig_RightHand_022": "hand.R_026",
    "mixamorig_Head_06": "head_04"
  }
}
```

`skin_mode` values:
- `default_shader` = use the default player skin tint/hand texture shader
- `passthrough` = keep the avatar's own original materials/textures

The mod falls back to a simple built-in placeholder if an avatar import fails.
