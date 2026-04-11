extends Node3D


const AvatarRegistry = preload("res://coop_mod/avatar_registry.gd")
const DEFAULT_AVATAR_ID: String = "default_blocky"
const AVATAR_SCENE: String = "res://coop_mod/avatar_assets/rigged_default/low_poly_character.glb"
const AVATAR_ASSETS_DIR: String = "res://coop_mod/avatar_assets/"
const VISUAL_SMOOTHNESS: float = 14.0
const MAX_ANIMATED_SPEED: float = 4.5
const HIDE_NEAR_DISTANCE: float = 0.9
const TARGET_AVATAR_HEIGHT: float = 2.05
const GROUND_OFFSET: float = -0.01
const MOVE_ANIM_THRESHOLD: float = 0.08
const HELD_ITEM_REBUILD_DELAY: float = 0.08
const RIGHT_HAND_BONE: String = "mixamorig_RightHand_022"
const HIPS_BONE: String = "mixamorig_Hips_01"
const SPINE_BONE_LOW: String = "mixamorig_Spine_02"
const SPINE_BONE_MID: String = "mixamorig_Spine1_03"
const SPINE_BONE: String = "mixamorig_Spine2_04"
const RIGHT_ARM_BONE: String = "mixamorig_RightArm_00"
const RIGHT_FOREARM_BONE: String = "mixamorig_RightForeArm_021"
const LEFT_ARM_BONE: String = "mixamorig_LeftArm_09"
const LEFT_FOREARM_BONE: String = "mixamorig_LeftForeArm_010"
const LEFT_UP_LEG_BONE: String = "mixamorig_LeftUpLeg_031"
const LEFT_LEG_BONE: String = "mixamorig_LeftLeg_032"
const LEFT_FOOT_BONE: String = "mixamorig_LeftFoot_033"
const RIGHT_UP_LEG_BONE: String = "mixamorig_RightUpLeg_036"
const RIGHT_LEG_BONE: String = "mixamorig_RightLeg_037"
const RIGHT_FOOT_BONE: String = "mixamorig_RightFoot_038"
const NECK_BONE: String = "mixamorig_Neck_05"
const HEAD_BONE: String = "mixamorig_Head_06"
const IMPORTED_POSE_BONES: PackedStringArray = [
    HIPS_BONE,
    SPINE_BONE_LOW,
    SPINE_BONE_MID,
    SPINE_BONE,
    NECK_BONE,
    HEAD_BONE,
    RIGHT_ARM_BONE,
    RIGHT_FOREARM_BONE,
    LEFT_ARM_BONE,
    LEFT_FOREARM_BONE,
    LEFT_UP_LEG_BONE,
    LEFT_LEG_BONE,
    LEFT_FOOT_BONE,
    RIGHT_UP_LEG_BONE,
    RIGHT_LEG_BONE,
    RIGHT_FOOT_BONE,
]
const IMPORTED_LABEL_HEIGHT: float = TARGET_AVATAR_HEIGHT + 0.26
const IMPORTED_SKIN_SHADER_CODE: String = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D human_texture : source_color, filter_nearest;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform float skin_blend : hint_range(0.0, 1.0) = 0.9;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);

    // Sample the human hand texture using the model's own UVs (single sample, no tiling)
    vec4 human_tex = texture(human_texture, UV);

    float max_channel = max(max(tex.r, tex.g), tex.b);
    float min_channel = min(min(tex.r, tex.g), tex.b);
    float brightness = dot(tex.rgb, vec3(0.333333, 0.333333, 0.333333));
    float saturation = max_channel - min_channel;

    // Detect all skin areas on the model (wide threshold to catch arms, face, legs, torso)
    float pale_mask = smoothstep(0.35, 0.65, brightness) * (1.0 - smoothstep(0.12, 0.45, saturation));

    vec3 base_rgb = tex.rgb * base_tint.rgb;

    // Tint the skin areas with the human hand color, blended with the player's chosen skin tint
    vec3 skin_color = human_tex.rgb * skin_tint.rgb;
    ALBEDO = mix(base_rgb, skin_color, pale_mask * skin_blend);
    ALPHA = tex.a * base_tint.a;
    ALPHA_SCISSOR_THRESHOLD = 0.2;
    ROUGHNESS = 1.0;
}
"""

const ACTION_IDLE: int = 0
const ACTION_HIT_SUSTAIN: int = 1
const ACTION_INTERACT_SUSTAIN: int = 2
const ACTION_HIT: int = 3
const ACTION_INTERACT: int = 4
const DEFAULT_RUNTIME_CLIP_PATHS: Dictionary = {
    "idle": "res://coop_mod/animation_workflow/source_fbx/core/breathing_idle.fbx",
    "idle_alt": "res://coop_mod/animation_workflow/source_fbx/core/idle.fbx",
    "walk": "res://coop_mod/animation_workflow/source_fbx/core/walk.fbx",
    "jump": "res://coop_mod/animation_workflow/source_fbx/core/jump.fbx",
    "crouch_idle": "res://coop_mod/animation_workflow/source_fbx/core/crouch_idle.fbx",
    "crouch_walk": "res://coop_mod/animation_workflow/source_fbx/core/crouch_walk.fbx",
    "attack": "res://coop_mod/animation_workflow/generated/default_runtime/attack_combo_fixed.res",
    "hit_react": "res://coop_mod/animation_workflow/source_fbx/core/hit_react.fbx",
    "turn_left": "res://coop_mod/animation_workflow/source_fbx/core/turn_left.fbx",
    "turn_right": "res://coop_mod/animation_workflow/source_fbx/core/turn_right.fbx",
    "death": "res://coop_mod/animation_workflow/source_fbx/core/death.fbx",
}


var peer_id: int = -1
var display_name: String = ""
var avatar_id: String = DEFAULT_AVATAR_ID
var avatar_entry: Dictionary = {}

var visual_root: Node3D
var avatar_instance: Node3D
var avatar_skeleton: Skeleton3D
var avatar_animation_player: AnimationPlayer
var avatar_mesh_instance: MeshInstance3D
var avatar_hand_attachment: BoneAttachment3D
var held_item_visual: Node3D
var imported_anim_name: String = ""
var placeholder_body: MeshInstance3D
var placeholder_head_pivot: Node3D
var placeholder_head: MeshInstance3D
var placeholder_hand_attachment: Node3D
var label: Label3D

var target_position: Vector3 = Vector3.ZERO
var visual_position: Vector3 = Vector3.ZERO
var target_yaw: float = 0.0
var visual_yaw: float = 0.0
var target_pitch: float = 0.0
var target_crouching: bool = false
var target_grounded: bool = true
var target_move_speed: float = 0.0
var target_held_item_id: int = -1
var target_action_state: int = ACTION_IDLE
var target_skin_color: Color = Color.WHITE

var crouch_amount: float = 0.0
var walk_phase: float = 0.0
var bob_amount: float = 0.0
var using_imported_avatar: bool = false
var hit_pulse: float = 0.0
var interact_pulse: float = 0.0
var action_cycle: float = 0.0
var imported_avatar_bounds: AABB = AABB(Vector3.ZERO, Vector3.ONE)
var imported_skin_shader: Shader
var imported_base_bone_rotations: Dictionary = {}
var runtime_clip_mode: bool = false
var current_runtime_clip: String = ""
var runtime_clip_cache: Dictionary = {}
var held_item_rebuild_pending: bool = false
var held_item_rebuild_timer: float = 0.0


func _ready() -> void:
    top_level = true
    avatar_entry = AvatarRegistry.get_avatar_entry(avatar_id)
    _rebuild_visual()
    visible = false
    visual_position = global_position


func _process(delta: float) -> void:
    if visual_root == null or not visible:
        return

    if held_item_rebuild_pending:
        held_item_rebuild_timer = maxf(held_item_rebuild_timer - delta, 0.0)
        if held_item_rebuild_timer <= 0.0:
            held_item_rebuild_pending = false
            _rebuild_held_item_visual()

    var blend: float = clampf(delta * VISUAL_SMOOTHNESS, 0.0, 1.0)
    visual_position = visual_position.lerp(target_position, blend)
    visual_yaw = lerp_angle(visual_yaw, target_yaw, blend)

    global_position = visual_position
    rotation = Vector3(0.0, visual_yaw, 0.0)

    var speed_ratio: float = clampf(target_move_speed / MAX_ANIMATED_SPEED, 0.0, 1.0)
    if target_grounded and target_move_speed > 0.08:
        walk_phase = wrapf(walk_phase + delta * lerpf(2.7, 7.5, speed_ratio), 0.0, TAU)
        bob_amount = sin(walk_phase * 2.0) * lerpf(0.004, 0.012, speed_ratio)
    else:
        bob_amount = lerpf(bob_amount, 0.0, blend)

    crouch_amount = move_toward(crouch_amount, 1.0 if target_crouching else 0.0, delta * 8.0)
    hit_pulse = move_toward(hit_pulse, 0.0, delta * 4.8)
    interact_pulse = move_toward(interact_pulse, 0.0, delta * 4.2)
    if target_action_state == ACTION_HIT_SUSTAIN or target_action_state == ACTION_INTERACT_SUSTAIN:
        action_cycle = wrapf(action_cycle + delta * 9.5, 0.0, TAU)
    else:
        action_cycle = move_toward(action_cycle, 0.0, delta * 10.0)
    var crouch_root_drop: float = 0.04 if using_imported_avatar else 0.13
    visual_root.position.y = -crouch_root_drop * crouch_amount + bob_amount
    visual_root.scale = Vector3.ONE * (0.96 - 0.05 * crouch_amount)
    visual_root.rotation.x = _get_visual_pitch_tilt_radians() - 0.08 * hit_pulse - 0.04 * interact_pulse + deg_to_rad(4.0) * crouch_amount

    if using_imported_avatar:
        _update_imported_avatar_pose(speed_ratio)
    else:
        _update_placeholder_pose(blend)

    if label != null:
        label.position = Vector3(0.0, _get_label_height() - 0.08 * crouch_amount, 0.0)

    if is_instance_valid(Ref.player_camera):
        var is_local_peer_marker: bool = peer_id == multiplayer.get_unique_id()
        visual_root.visible = true if not is_local_peer_marker else global_position.distance_to(Ref.player_camera.global_position) > HIDE_NEAR_DISTANCE
    else:
        visual_root.visible = true


func setup(new_peer_id: int) -> void:
    peer_id = new_peer_id
    if is_node_ready() and not using_imported_avatar:
        _apply_placeholder_palette()


func set_display_name(new_display_name: String) -> void:
    display_name = new_display_name.strip_edges()
    if label != null:
        label.text = _get_visible_name()


func set_avatar_id(new_avatar_id: String) -> void:
    var normalized := _normalize_avatar_id(new_avatar_id)
    if avatar_id == normalized:
        return
    avatar_id = normalized
    avatar_entry = AvatarRegistry.get_avatar_entry(avatar_id)
    if is_node_ready():
        _rebuild_visual()


func set_held_item_id(new_held_item_id: int) -> void:
    if target_held_item_id == new_held_item_id:
        return

    target_held_item_id = new_held_item_id
    held_item_rebuild_pending = true
    held_item_rebuild_timer = HELD_ITEM_REBUILD_DELAY


func set_skin_color(new_skin_color: Color) -> void:
    if target_skin_color.is_equal_approx(new_skin_color):
        return

    target_skin_color = new_skin_color
    if using_imported_avatar and avatar_instance != null:
        _apply_imported_avatar_skin_tint(avatar_instance)


func set_action_state(new_action_state: int) -> void:
    if target_action_state == new_action_state:
        return

    target_action_state = new_action_state
    if new_action_state == ACTION_HIT:
        hit_pulse = 1.0
    elif new_action_state == ACTION_INTERACT:
        interact_pulse = 1.0


func apply_state(active: bool, world_position: Vector3, yaw: float, pitch: float, crouching: bool, grounded: bool, move_speed: float, _action_state: int) -> void:
    if visual_root == null or label == null:
        call_deferred("apply_state", active, world_position, yaw, pitch, crouching, grounded, move_speed, _action_state)
        return

    if active and not visible:
        visual_position = world_position
        visual_yaw = yaw
        global_position = world_position
        rotation = Vector3(0.0, yaw, 0.0)

    visible = active
    if not active:
        return

    target_position = world_position
    target_yaw = yaw
    target_pitch = pitch
    target_crouching = crouching
    target_grounded = grounded
    target_move_speed = move_speed
    set_action_state(_action_state)


func _rebuild_visual() -> void:
    if visual_root != null:
        visual_root.queue_free()
    if label != null:
        label.queue_free()

    visual_root = Node3D.new()
    add_child(visual_root)

    using_imported_avatar = _try_build_imported_avatar()
    if not using_imported_avatar:
        _build_placeholder()

    label = Label3D.new()
    label.text = _get_visible_name()
    label.position = Vector3(0.0, _get_label_height(), 0.0)
    label.no_depth_test = true
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)


func _try_build_imported_avatar() -> bool:
    avatar_instance = null
    avatar_skeleton = null
    avatar_animation_player = null
    avatar_mesh_instance = null
    avatar_hand_attachment = null
    held_item_visual = null
    held_item_rebuild_pending = false
    held_item_rebuild_timer = 0.0
    imported_anim_name = ""
    imported_base_bone_rotations.clear()
    runtime_clip_mode = false
    current_runtime_clip = ""

    avatar_entry = AvatarRegistry.get_avatar_entry(avatar_id)
    var avatar_path: String = str(avatar_entry.get("path", AVATAR_SCENE))
    var avatar_scene = load(avatar_path)
    if not (avatar_scene is PackedScene):
        # Fallback to default if custom avatar failed
        if avatar_path != AVATAR_SCENE:
            avatar_scene = load(AVATAR_SCENE)
        if not (avatar_scene is PackedScene):
            return false

    avatar_instance = avatar_scene.instantiate() as Node3D
    if avatar_instance == null:
        return false

    visual_root.add_child(avatar_instance)
    avatar_skeleton = _find_first_skeleton(avatar_instance)
    avatar_animation_player = _find_first_animation_player(avatar_instance)
    if avatar_animation_player == null and str(avatar_entry.get("animation_mode", "procedural")) == "mixamo_fbx_runtime":
        avatar_animation_player = AnimationPlayer.new()
        avatar_animation_player.name = "RuntimeAnimationPlayer"
        avatar_animation_player.root_node = NodePath("..")
        avatar_instance.add_child(avatar_animation_player)
    avatar_mesh_instance = _find_first_mesh_instance(avatar_instance)

    if avatar_skeleton == null:
        avatar_instance.queue_free()
        avatar_instance = null
        return false

    _prepare_imported_avatar_materials(avatar_instance)
    _configure_imported_avatar_root()
    _play_first_animation()
    _capture_imported_base_pose()
    _ensure_runtime_clip_animations()
    _setup_hand_attachment()
    _rebuild_held_item_visual()
    return true


func _configure_imported_avatar_root() -> void:
    if avatar_instance == null:
        return

    # Auto-fit imported avatars to a reasonable player height.
    var mesh_aabb: AABB = _get_imported_avatar_bounds(avatar_instance)
    var mesh_height: float = mesh_aabb.size.y if mesh_aabb.size.y > 0.001 else 1.0
    var target_height: float = float(avatar_entry.get("height", TARGET_AVATAR_HEIGHT))
    var ground_offset: float = float(avatar_entry.get("ground_offset", GROUND_OFFSET))
    var scale_factor: float = target_height / mesh_height

    imported_avatar_bounds = mesh_aabb
    avatar_instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
    avatar_instance.scale = Vector3.ONE * scale_factor
    avatar_instance.position = Vector3(0.0, -mesh_aabb.position.y * scale_factor + ground_offset, 0.0)


func _play_first_animation() -> void:
    if avatar_animation_player == null:
        return

    var names: PackedStringArray = avatar_animation_player.get_animation_list()
    if names.is_empty():
        return
    imported_anim_name = names[0]
    avatar_animation_player.play(imported_anim_name)
    avatar_animation_player.speed_scale = 0.0
    avatar_animation_player.seek(0.0, true)


func _extract_animation_from_scene(path: String) -> Animation:
    if runtime_clip_cache.has(path):
        var cached_anim: Animation = runtime_clip_cache[path]
        return _remap_runtime_animation_for_avatar(cached_anim.duplicate(true)) if cached_anim != null else null

    var scene = load(path)
    if scene is Animation:
        var direct_anim: Animation = (scene as Animation).duplicate(true)
        runtime_clip_cache[path] = direct_anim
        return _remap_runtime_animation_for_avatar(direct_anim.duplicate(true))
    if not (scene is PackedScene):
        return null

    var inst = (scene as PackedScene).instantiate()
    var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
    if ap == null or not ap.has_animation("mixamo_com"):
        inst.queue_free()
        return null

    var anim: Animation = ap.get_animation("mixamo_com").duplicate(true)
    runtime_clip_cache[path] = anim
    inst.queue_free()
    return _remap_runtime_animation_for_avatar(anim.duplicate(true))


func _should_remap_runtime_tracks() -> bool:
    return bool(avatar_entry.get("runtime_track_remap", false))


func _get_runtime_skeleton_track_prefix() -> String:
    if avatar_animation_player == null or avatar_skeleton == null:
        return ""
    var root_node_path: NodePath = avatar_animation_player.root_node
    var animation_root: Node = avatar_animation_player.get_node_or_null(root_node_path)
    if animation_root == null:
        animation_root = avatar_animation_player.get_parent()
    if animation_root == null:
        return ""
    return str(animation_root.get_path_to(avatar_skeleton))


func _get_canonical_bone_name_for_alias(alias_name: String) -> String:
    var cleaned_alias: String = alias_name.strip_edges()
    if cleaned_alias == "":
        return ""

    for bone_name in IMPORTED_POSE_BONES:
        for candidate in _get_bone_aliases(bone_name):
            if cleaned_alias == candidate:
                return bone_name
    if cleaned_alias == RIGHT_HAND_BONE:
        return RIGHT_HAND_BONE
    for candidate in _get_bone_aliases(RIGHT_HAND_BONE):
        if cleaned_alias == candidate:
            return RIGHT_HAND_BONE
    return ""


func _remap_runtime_animation_for_avatar(animation: Animation) -> Animation:
    if animation == null or not _should_remap_runtime_tracks():
        return animation

    var skeleton_track_prefix: String = _get_runtime_skeleton_track_prefix()
    if skeleton_track_prefix == "":
        return animation

    var tracks_to_remove: Array[int] = []
    for track_index in range(animation.get_track_count()):
        var track_path_text: String = str(animation.track_get_path(track_index))
        var split_index: int = track_path_text.find(":")
        if split_index == -1:
            continue

        var source_bone_name: String = track_path_text.substr(split_index + 1)
        var canonical_bone_name: String = _get_canonical_bone_name_for_alias(source_bone_name)
        if canonical_bone_name == "":
            tracks_to_remove.append(track_index)
            continue

        var target_bone_name: String = _find_imported_bone_name(canonical_bone_name)
        if target_bone_name == "":
            tracks_to_remove.append(track_index)
            continue

        animation.track_set_path(track_index, NodePath("%s:%s" % [skeleton_track_prefix, target_bone_name]))

    for remove_index in range(tracks_to_remove.size() - 1, -1, -1):
        animation.remove_track(tracks_to_remove[remove_index])
    return animation


func _ensure_runtime_clip_animations() -> void:
    runtime_clip_mode = str(avatar_entry.get("animation_mode", "procedural")) == "mixamo_fbx_runtime"
    if not runtime_clip_mode or avatar_animation_player == null:
        return

    var library: AnimationLibrary = null
    var library_names = avatar_animation_player.get_animation_library_list()
    if library_names.has(&""):
        library = avatar_animation_player.get_animation_library("")
    if library == null:
        library = AnimationLibrary.new()
        avatar_animation_player.add_animation_library("", library)

    for clip_name in DEFAULT_RUNTIME_CLIP_PATHS.keys():
        if library.has_animation(clip_name):
            continue
        var anim: Animation = _extract_animation_from_scene(str(DEFAULT_RUNTIME_CLIP_PATHS[clip_name]))
        if anim == null:
            continue
        if clip_name in ["idle", "idle_alt", "walk", "crouch_idle", "crouch_walk"]:
            anim.loop_mode = Animation.LOOP_LINEAR
        else:
            anim.loop_mode = Animation.LOOP_NONE
        library.add_animation(clip_name, anim)


func _choose_runtime_clip(speed_ratio: float) -> String:
    if target_action_state == ACTION_HIT or target_action_state == ACTION_HIT_SUSTAIN:
        return "attack"
    if target_action_state == ACTION_INTERACT or target_action_state == ACTION_INTERACT_SUSTAIN:
        return "attack"
    if not target_grounded:
        return "jump"
    if target_crouching:
        return "crouch_walk" if speed_ratio > MOVE_ANIM_THRESHOLD else "crouch_idle"
    if speed_ratio > MOVE_ANIM_THRESHOLD:
        return "walk"
    return "idle"


func _play_runtime_clip(clip_name: String, speed_ratio: float) -> void:
    if avatar_animation_player == null or clip_name == "":
        return
    if not avatar_animation_player.has_animation(clip_name):
        return

    if current_runtime_clip != clip_name:
        current_runtime_clip = clip_name
        avatar_animation_player.play(clip_name, 0.18)

    var clip_speed: float = 1.0
    if clip_name == "walk":
        clip_speed = lerpf(0.85, 1.6, speed_ratio)
    elif clip_name == "crouch_walk":
        clip_speed = lerpf(0.8, 1.2, speed_ratio)
    elif clip_name == "jump":
        clip_speed = 1.28
    elif clip_name == "idle" or clip_name == "idle_alt" or clip_name == "crouch_idle":
        clip_speed = 1.0
    avatar_animation_player.speed_scale = clip_speed


func _get_bone_aliases(bone_name: String) -> PackedStringArray:
    match bone_name:
        HIPS_BONE:
            return [HIPS_BONE, "mixamorig_Hips", "mixamorig1_Hips", "mixamorig:Hips", "mixamorig_Hips_00", "Hips", "hips", "Hips_01", "hips_00"]
        SPINE_BONE_LOW:
            return [SPINE_BONE_LOW, "mixamorig_Spine", "mixamorig1_Spine", "mixamorig:Spine", "mixamorig_Spine_01", "Spine", "spine", "Spine_02", "spine_01"]
        SPINE_BONE_MID:
            return [SPINE_BONE_MID, "mixamorig_Spine1", "mixamorig1_Spine1", "mixamorig:Spine1", "mixamorig_Spine1_02", "Spine1", "spine1", "Spine1_03", "Chest_00", "spine1_02"]
        SPINE_BONE:
            return [SPINE_BONE, "mixamorig_Spine2", "mixamorig1_Spine2", "mixamorig:Spine2", "mixamorig_Spine2_03", "Spine2", "spine2", "Spine2_04", "Spine2_03", "spine2_03", "Chest", "chest", "Chest_00"]
        NECK_BONE:
            return [NECK_BONE, "mixamorig_Neck", "mixamorig1_Neck", "mixamorig:Neck", "mixamorig_Neck_04", "Neck", "neck", "Neck_03", "neck_03"]
        HEAD_BONE:
            return [HEAD_BONE, "mixamorig_Head", "mixamorig1_Head", "mixamorig:Head", "mixamorig_Head_05", "Head", "head", "Head_04", "head_04"]
        RIGHT_ARM_BONE:
            return [RIGHT_ARM_BONE, "mixamorig_RightArm", "mixamorig1_RightArm", "mixamorig:RightArm", "mixamorig_RightArm_012", "RightArm", "RightArm_024", "UpperArm.R", "upperarm.R", "upperarm.R_024"]
        RIGHT_FOREARM_BONE:
            return [RIGHT_FOREARM_BONE, "mixamorig_RightForeArm", "mixamorig1_RightForeArm", "mixamorig:RightForeArm", "mixamorig_RightForeArm_013", "RightForeArm", "RightForeArm_025", "LowerArm.R", "lowerarm.R", "lowerarm.R_025"]
        RIGHT_HAND_BONE:
            return [RIGHT_HAND_BONE, "mixamorig_RightHand", "mixamorig1_RightHand", "mixamorig:RightHand", "mixamorig_RightHand_014", "RightHand", "RightHand_026", "Hand.R", "hand.R", "hand.R_026"]
        LEFT_ARM_BONE:
            return [LEFT_ARM_BONE, "mixamorig_LeftArm", "mixamorig1_LeftArm", "mixamorig:LeftArm", "mixamorig_LeftArm_08", "LeftArm", "LeftArm_08", "UpperArm.L", "upperarm.L", "upperarm.L_08"]
        LEFT_FOREARM_BONE:
            return [LEFT_FOREARM_BONE, "mixamorig_LeftForeArm", "mixamorig1_LeftForeArm", "mixamorig:LeftForeArm", "mixamorig_LeftForeArm_09", "LeftForeArm", "LeftForeArm_09", "LowerArm.L", "lowerarm.L", "lowerarm.L_09"]
        LEFT_UP_LEG_BONE:
            return [LEFT_UP_LEG_BONE, "mixamorig_LeftUpLeg", "mixamorig1_LeftUpLeg", "mixamorig:LeftUpLeg", "mixamorig_LeftUpLeg_015", "LeftUpLeg", "UpperLeg.L", "upperleg.L", "LeftLeg_039", "upperleg.L_039"]
        LEFT_LEG_BONE:
            return [LEFT_LEG_BONE, "mixamorig_LeftLeg", "mixamorig1_LeftLeg", "mixamorig:LeftLeg", "mixamorig_LeftLeg_016", "LeftLeg", "LowerLeg.L", "lowerleg.L", "LeftKnee_040", "lowerleg.L_040"]
        LEFT_FOOT_BONE:
            return [LEFT_FOOT_BONE, "mixamorig_LeftFoot", "mixamorig1_LeftFoot", "mixamorig:LeftFoot", "mixamorig_LeftFoot_017", "LeftFoot", "Foot.L", "foot.L", "LeftAnkle_041", "foot.L_041"]
        RIGHT_UP_LEG_BONE:
            return [RIGHT_UP_LEG_BONE, "mixamorig_RightUpLeg", "mixamorig1_RightUpLeg", "mixamorig:RightUpLeg", "mixamorig_RightUpLeg_020", "RightUpLeg", "UpperLeg.R", "upperleg.R", "RightLeg_042", "upperleg.R_043"]
        RIGHT_LEG_BONE:
            return [RIGHT_LEG_BONE, "mixamorig_RightLeg", "mixamorig1_RightLeg", "mixamorig:RightLeg", "mixamorig_RightLeg_021", "RightLeg", "LowerLeg.R", "lowerleg.R", "RightKnee_043", "lowerleg.R_044"]
        RIGHT_FOOT_BONE:
            return [RIGHT_FOOT_BONE, "mixamorig_RightFoot", "mixamorig1_RightFoot", "mixamorig:RightFoot", "mixamorig_RightFoot_022", "RightFoot", "Foot.R", "foot.R", "RightAnkle_044", "foot.R_045"]
        _:
            return [bone_name]


func _find_imported_bone_name(bone_name: String) -> String:
    if avatar_skeleton == null:
        return ""

    var bone_overrides: Dictionary = avatar_entry.get("bone_overrides", {})
    if bone_overrides.has(bone_name):
        var override_name: String = str(bone_overrides.get(bone_name, ""))
        if override_name != "" and avatar_skeleton.find_bone(override_name) != -1:
            return override_name

    for candidate in _get_bone_aliases(bone_name):
        if avatar_skeleton.find_bone(candidate) != -1:
            return candidate
    return ""


func _capture_imported_base_pose() -> void:
    imported_base_bone_rotations.clear()
    if avatar_skeleton == null:
        return

    for bone_name in IMPORTED_POSE_BONES:
        var resolved_bone_name: String = _find_imported_bone_name(bone_name)
        var bone_index: int = avatar_skeleton.find_bone(resolved_bone_name)
        if bone_index == -1:
            continue
        imported_base_bone_rotations[bone_name] = avatar_skeleton.get_bone_pose_rotation(bone_index)


func _setup_hand_attachment() -> void:
    if avatar_skeleton == null:
        return

    var hand_bone_name: String = _find_imported_bone_name(RIGHT_HAND_BONE)
    if hand_bone_name == "":
        return

    avatar_hand_attachment = BoneAttachment3D.new()
    avatar_hand_attachment.name = "RemoteHeldItemAttachment"
    avatar_hand_attachment.bone_name = hand_bone_name
    avatar_skeleton.add_child(avatar_hand_attachment)
    avatar_hand_attachment.position = Vector3.ZERO
    avatar_hand_attachment.rotation_degrees = Vector3(0.0, 0.0, 0.0)


func _prepare_imported_avatar_materials(root: Node) -> void:
    var skin_mode: String = str(avatar_entry.get("skin_mode", "passthrough"))
    var texture_override_path: String = str(avatar_entry.get("texture_override", "")).strip_edges()
    var texture_override: Texture2D = load(texture_override_path) as Texture2D if texture_override_path != "" else null
    _prepare_imported_avatar_materials_recursive(root, skin_mode, texture_override)


func _prepare_imported_avatar_materials_recursive(root: Node, skin_mode: String, texture_override: Texture2D) -> void:
    if root is MeshInstance3D:
        var mesh_node := root as MeshInstance3D
        var surface_count: int = 0
        if mesh_node.mesh != null:
            surface_count = mesh_node.mesh.get_surface_count()
        for surface_index in range(surface_count):
            if skin_mode == "default_shader":
                var source_material: Material = mesh_node.get_active_material(surface_index)
                if source_material is BaseMaterial3D:
                    var duplicated := (source_material as BaseMaterial3D).duplicate() as BaseMaterial3D
                    duplicated.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                    duplicated.cull_mode = BaseMaterial3D.CULL_DISABLED
                    mesh_node.set_surface_override_material(surface_index, _make_imported_avatar_material(duplicated))
                else:
                    var fallback := StandardMaterial3D.new()
                    fallback.albedo_color = _get_default_avatar_skin_color()
                    fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                    fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
                    fallback.roughness = 1.0
                    mesh_node.set_surface_override_material(surface_index, fallback)
            elif texture_override != null:
                mesh_node.set_surface_override_material(surface_index, _make_passthrough_texture_material(texture_override))

    for child in root.get_children():
        _prepare_imported_avatar_materials_recursive(child, skin_mode, texture_override)


func _get_default_avatar_skin_color() -> Color:
    var raw_color = avatar_entry.get("default_skin_color", [0.87, 0.75, 0.65])
    var base_skin := Color(0.87, 0.75, 0.65)
    if raw_color is Array and raw_color.size() >= 3:
        base_skin = Color(float(raw_color[0]), float(raw_color[1]), float(raw_color[2]))
    elif raw_color is Color:
        base_skin = raw_color

    var tint: Color = target_skin_color if target_skin_color != Color.WHITE else Color.WHITE
    return Color(base_skin.r * tint.r, base_skin.g * tint.g, base_skin.b * tint.b, 1.0)


func _make_imported_avatar_material(source_material: BaseMaterial3D) -> Material:
    var material := StandardMaterial3D.new()
    material.albedo_color = _get_default_avatar_skin_color()
    material.roughness = 1.0
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _make_passthrough_texture_material(texture: Texture2D) -> Material:
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    material.alpha_scissor_threshold = 0.1
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _get_imported_skin_shader() -> Shader:
    if imported_skin_shader == null:
        imported_skin_shader = Shader.new()
        imported_skin_shader.code = IMPORTED_SKIN_SHADER_CODE
    return imported_skin_shader


func _apply_imported_avatar_skin_tint(root: Node) -> void:
    if str(avatar_entry.get("skin_mode", "passthrough")) != "default_shader":
        return
    if root is MeshInstance3D:
        var mesh_node := root as MeshInstance3D
        var material_count: int = mesh_node.get_surface_override_material_count()
        for surface_index in range(material_count):
            var material: Material = mesh_node.get_surface_override_material(surface_index)
            if material is BaseMaterial3D:
                (material as BaseMaterial3D).albedo_color = _get_default_avatar_skin_color()

    for child in root.get_children():
        _apply_imported_avatar_skin_tint(child)


func _find_first_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root as Skeleton3D
    for child in root.get_children():
        var found := _find_first_skeleton(child)
        if found != null:
            return found
    return null


func _find_first_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found := _find_first_animation_player(child)
        if found != null:
            return found
    return null


func _find_first_mesh_instance(root: Node) -> MeshInstance3D:
    if root is MeshInstance3D:
        return root as MeshInstance3D
    for child in root.get_children():
        var found := _find_first_mesh_instance(child)
        if found != null:
            return found
    return null


func _get_imported_avatar_bounds(root: Node3D) -> AABB:
    var mesh_bounds: Array = []
    _collect_imported_mesh_bounds(root, Transform3D.IDENTITY, mesh_bounds, true)
    if mesh_bounds.is_empty():
        return AABB(Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 1.7, 0.7))

    var merged: AABB = mesh_bounds[0]
    for index in range(1, mesh_bounds.size()):
        merged = merged.merge(mesh_bounds[index])
    return merged


func _collect_imported_mesh_bounds(node: Node, parent_transform: Transform3D, mesh_bounds: Array, skip_node_transform: bool = false) -> void:
    var current_transform: Transform3D = parent_transform
    if node is Node3D and not skip_node_transform:
        current_transform = parent_transform * (node as Node3D).transform

    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh != null:
            mesh_bounds.append(_transform_aabb(mesh_node.get_aabb(), current_transform))

    for child in node.get_children():
        _collect_imported_mesh_bounds(child, current_transform, mesh_bounds, false)


func _transform_aabb(source_aabb: AABB, transform: Transform3D) -> AABB:
    var corners: Array = [
        source_aabb.position,
        source_aabb.position + Vector3(source_aabb.size.x, 0.0, 0.0),
        source_aabb.position + Vector3(0.0, source_aabb.size.y, 0.0),
        source_aabb.position + Vector3(0.0, 0.0, source_aabb.size.z),
        source_aabb.position + Vector3(source_aabb.size.x, source_aabb.size.y, 0.0),
        source_aabb.position + Vector3(source_aabb.size.x, 0.0, source_aabb.size.z),
        source_aabb.position + Vector3(0.0, source_aabb.size.y, source_aabb.size.z),
        source_aabb.position + source_aabb.size,
    ]

    var first_corner: Vector3 = transform * corners[0]
    var transformed_aabb := AABB(first_corner, Vector3.ZERO)
    for index in range(1, corners.size()):
        transformed_aabb = transformed_aabb.expand(transform * corners[index])
    return transformed_aabb


func _update_imported_avatar_pose(speed_ratio: float) -> void:
    if avatar_instance == null:
        return

    # Head/neck bones handle the look direction, no whole-body tilt
    avatar_instance.rotation_degrees.x = 0.0

    if runtime_clip_mode:
        var desired_clip: String = _choose_runtime_clip(speed_ratio)
        _play_runtime_clip(desired_clip, speed_ratio)
        call_deferred("_apply_runtime_look_pose")
        return

    if avatar_animation_player != null and imported_anim_name != "":
        avatar_animation_player.pause()
        avatar_animation_player.seek(0.0, true)

    _apply_imported_locomotion_pose(speed_ratio)

    if _has_imported_action_pose():
        _apply_imported_action_pose()

    _apply_imported_look_pose()


func _apply_imported_locomotion_pose(speed_ratio: float) -> void:
    var move_amount: float = clampf(inverse_lerp(MOVE_ANIM_THRESHOLD, 1.0, speed_ratio), 0.0, 1.0)
    var walk_swing: float = sin(walk_phase)
    var walk_push: float = sin(walk_phase + PI * 0.5)
    var left_stride: float = walk_swing * move_amount
    var right_stride: float = -walk_swing * move_amount
    var left_knee_drive: float = maxf(0.0, left_stride)
    var right_knee_drive: float = maxf(0.0, right_stride)
    var crouch_blend: float = crouch_amount
    var crouch_walk_blend: float = crouch_blend * move_amount

    # Idle breathing (gentle sine wave that plays even when standing still)
    var idle_blend: float = 1.0 - move_amount
    var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
    var breathe: float = sin(time_sec * 1.8) * idle_blend
    var idle_sway: float = sin(time_sec * 0.7) * idle_blend

    # Hips: deep forward tilt when crouching + side-to-side sway when walking + breathe (centered around 0)
    var hip_sway_y: float = 3.5 * walk_swing * move_amount
    var hips_euler := Vector3(18.0 * crouch_blend + 2.0 * move_amount * absf(walk_push) + 0.3 * breathe, hip_sway_y, idle_sway * 0.8)

    # Spine: hunch forward when crouching + counter-rotate twist + breathe
    var spine_twist: float = -2.5 * walk_swing * move_amount
    var spine_low_euler := Vector3(-10.0 * crouch_blend - 2.0 * move_amount * absf(walk_push) - 0.8 * breathe, spine_twist, 0.0)
    var spine_mid_euler := Vector3(-8.0 * crouch_blend + 0.5 * breathe, spine_twist * 0.5, 0.0)
    var spine_top_euler := Vector3(4.0 * crouch_blend + 0.3 * breathe, -spine_twist * 0.3, 0.0)

    # Arms: tuck in tight when crouching + swing with walk + idle sway
    var arm_swing_scale: float = 28.0 * move_amount * (1.0 - 0.6 * crouch_blend)
    var idle_arm_swing: float = 2.0 * sin(time_sec * 1.2) * idle_blend
    var crouch_arm_tuck: float = 18.0 * crouch_blend
    var left_arm_euler := Vector3(6.0 * crouch_blend, 0.0, crouch_arm_tuck + arm_swing_scale * walk_swing + idle_arm_swing)
    var right_arm_euler := Vector3(6.0 * crouch_blend, 0.0, -crouch_arm_tuck - arm_swing_scale * walk_swing - idle_arm_swing)
    # Elbows: bend more when crouching (arms tucked to body) + walking bend
    var elbow_bend: float = 6.0 * move_amount * absf(walk_swing)
    var crouch_elbow: float = 20.0 * crouch_blend
    var left_forearm_euler := Vector3(0.0, 0.0, -elbow_bend - crouch_elbow - 4.0 * idle_blend)
    var right_forearm_euler := Vector3(0.0, 0.0, elbow_bend + crouch_elbow + 4.0 * idle_blend)

    var locomotion_arm_offset_x: float = float(avatar_entry.get("locomotion_arm_offset_x", 0.0))
    var locomotion_arm_offset_y: float = float(avatar_entry.get("locomotion_arm_offset_y", 0.0))
    var locomotion_arm_offset_z: float = float(avatar_entry.get("locomotion_arm_offset_z", 0.0))
    var locomotion_forearm_offset_x: float = float(avatar_entry.get("locomotion_forearm_offset_x", 0.0))
    var locomotion_forearm_offset_z: float = float(avatar_entry.get("locomotion_forearm_offset_z", 0.0))
    left_arm_euler.x += locomotion_arm_offset_x
    right_arm_euler.x += locomotion_arm_offset_x
    left_arm_euler.y += locomotion_arm_offset_y
    right_arm_euler.y -= locomotion_arm_offset_y
    left_arm_euler.z += locomotion_arm_offset_z
    right_arm_euler.z -= locomotion_arm_offset_z
    left_forearm_euler.x += locomotion_forearm_offset_x
    right_forearm_euler.x += locomotion_forearm_offset_x
    left_forearm_euler.z -= locomotion_forearm_offset_z
    right_forearm_euler.z += locomotion_forearm_offset_z

    # Legs: deep knee bend when crouching + wider stride walking
    var upper_leg_base: float = 45.0 * crouch_blend
    var upper_leg_swing: float = 38.0 * move_amount * (1.0 - 0.45 * crouch_blend)
    var lower_leg_base: float = -55.0 * crouch_blend
    var lower_leg_stride_scale: float = 28.0 * move_amount
    var foot_base: float = 18.0 * crouch_blend
    var foot_stride_scale: float = 22.0 * move_amount

    var locomotion_leg_scale: float = float(avatar_entry.get("locomotion_leg_scale", 1.0))
    var locomotion_leg_yaw: float = float(avatar_entry.get("locomotion_leg_yaw", 0.0))
    var locomotion_foot_yaw: float = float(avatar_entry.get("locomotion_foot_yaw", 0.0))
    var left_up_leg_euler := Vector3(upper_leg_base + upper_leg_swing * left_stride * locomotion_leg_scale, locomotion_leg_yaw, 0.0)
    var right_up_leg_euler := Vector3(upper_leg_base + upper_leg_swing * right_stride * locomotion_leg_scale, -locomotion_leg_yaw, 0.0)
    var left_leg_euler := Vector3(lower_leg_base - lower_leg_stride_scale * left_knee_drive - 8.0 * crouch_walk_blend, 0.0, 0.0)
    var right_leg_euler := Vector3(lower_leg_base - lower_leg_stride_scale * right_knee_drive - 8.0 * crouch_walk_blend, 0.0, 0.0)
    var left_foot_euler := Vector3(foot_base + foot_stride_scale * maxf(0.0, -left_stride) * locomotion_leg_scale + 7.0 * crouch_walk_blend, locomotion_foot_yaw, 0.0)
    var right_foot_euler := Vector3(foot_base + foot_stride_scale * maxf(0.0, -right_stride) * locomotion_leg_scale + 7.0 * crouch_walk_blend, -locomotion_foot_yaw, 0.0)

    _set_imported_bone_euler(HIPS_BONE, _degrees_to_radians(hips_euler))
    _set_imported_bone_euler(SPINE_BONE_LOW, _degrees_to_radians(spine_low_euler))
    _set_imported_bone_euler(SPINE_BONE_MID, _degrees_to_radians(spine_mid_euler))
    _set_imported_bone_euler(SPINE_BONE, _degrees_to_radians(spine_top_euler))
    _set_imported_bone_euler(LEFT_ARM_BONE, _degrees_to_radians(left_arm_euler))
    _set_imported_bone_euler(RIGHT_ARM_BONE, _degrees_to_radians(right_arm_euler))
    _set_imported_bone_euler(LEFT_FOREARM_BONE, _degrees_to_radians(left_forearm_euler))
    _set_imported_bone_euler(RIGHT_FOREARM_BONE, _degrees_to_radians(right_forearm_euler))
    _set_imported_bone_euler(LEFT_UP_LEG_BONE, _degrees_to_radians(left_up_leg_euler))
    _set_imported_bone_euler(RIGHT_UP_LEG_BONE, _degrees_to_radians(right_up_leg_euler))
    _set_imported_bone_euler(LEFT_LEG_BONE, _degrees_to_radians(left_leg_euler))
    _set_imported_bone_euler(RIGHT_LEG_BONE, _degrees_to_radians(right_leg_euler))
    _set_imported_bone_euler(LEFT_FOOT_BONE, _degrees_to_radians(left_foot_euler))
    _set_imported_bone_euler(RIGHT_FOOT_BONE, _degrees_to_radians(right_foot_euler))


func _apply_imported_action_pose() -> void:
    if avatar_skeleton == null:
        return

    var action_pose: Dictionary = _get_imported_action_pose()
    if not bool(action_pose.get("active", false)):
        return

    var phase: float = float(action_pose.get("phase", 0.0))
    var strength: float = float(action_pose.get("strength", 0.0))
    var place_bias: float = float(action_pose.get("place_bias", 0.0))

    var hit_spine_windup := Vector3(-2.0, 0.0, 0.0)
    var hit_spine_strike := Vector3(6.0, 0.0, 0.0)
    var place_spine_windup := Vector3(-1.0, 0.0, 0.0)
    var place_spine_strike := Vector3(4.0, 0.0, 0.0)

    var hit_right_arm_windup := Vector3(15.0, 10.0, -25.0)
    var hit_right_arm_strike := Vector3(-12.0, -8.0, -85.0)
    var place_right_arm_windup := Vector3(8.0, 5.0, -18.0)
    var place_right_arm_strike := Vector3(-6.0, -4.0, -58.0)

    var hit_right_forearm_windup := Vector3(-25.0, 0.0, 15.0)
    var hit_right_forearm_strike := Vector3(10.0, 0.0, -30.0)
    var place_right_forearm_windup := Vector3(-15.0, 0.0, 8.0)
    var place_right_forearm_strike := Vector3(5.0, 0.0, -18.0)

    var hit_left_arm_windup := Vector3(-5.0, 0.0, 8.0)
    var hit_left_arm_strike := Vector3(10.0, 0.0, 15.0)
    var place_left_arm_windup := Vector3(-3.0, 0.0, 5.0)
    var place_left_arm_strike := Vector3(6.0, 0.0, 10.0)

    var hit_left_forearm_windup := Vector3(0.0, 0.0, -8.0)
    var hit_left_forearm_strike := Vector3(0.0, 0.0, 5.0)
    var place_left_forearm_windup := Vector3(0.0, 0.0, -4.0)
    var place_left_forearm_strike := Vector3(0.0, 0.0, 3.0)

    var spine_euler: Vector3 = _sample_action_euler(
        phase,
        hit_spine_windup.lerp(place_spine_windup, place_bias),
        hit_spine_strike.lerp(place_spine_strike, place_bias)
    ) * strength
    var right_arm_euler: Vector3 = _sample_action_euler(
        phase,
        hit_right_arm_windup.lerp(place_right_arm_windup, place_bias),
        hit_right_arm_strike.lerp(place_right_arm_strike, place_bias)
    ) * strength
    var right_forearm_euler: Vector3 = _sample_action_euler(
        phase,
        hit_right_forearm_windup.lerp(place_right_forearm_windup, place_bias),
        hit_right_forearm_strike.lerp(place_right_forearm_strike, place_bias)
    ) * strength
    var left_arm_euler: Vector3 = _sample_action_euler(
        phase,
        hit_left_arm_windup.lerp(place_left_arm_windup, place_bias),
        hit_left_arm_strike.lerp(place_left_arm_strike, place_bias)
    ) * strength
    var left_forearm_euler: Vector3 = _sample_action_euler(
        phase,
        hit_left_forearm_windup.lerp(place_left_forearm_windup, place_bias),
        hit_left_forearm_strike.lerp(place_left_forearm_strike, place_bias)
    ) * strength

    _set_imported_bone_euler(SPINE_BONE, _degrees_to_radians(spine_euler))
    _set_imported_bone_euler(RIGHT_ARM_BONE, _degrees_to_radians(right_arm_euler))
    _set_imported_bone_euler(RIGHT_FOREARM_BONE, _degrees_to_radians(right_forearm_euler))
    _set_imported_bone_euler(LEFT_ARM_BONE, _degrees_to_radians(left_arm_euler))
    _set_imported_bone_euler(LEFT_FOREARM_BONE, _degrees_to_radians(left_forearm_euler))


func _has_imported_action_pose() -> bool:
    return target_action_state != ACTION_IDLE or hit_pulse > 0.01 or interact_pulse > 0.01


func _get_imported_action_pose() -> Dictionary:
    if target_action_state == ACTION_HIT_SUSTAIN:
        return {
            "active": true,
            "phase": 0.5 - 0.5 * cos(action_cycle),
            "strength": 1.0,
            "place_bias": 0.0,
        }
    if target_action_state == ACTION_INTERACT_SUSTAIN:
        return {
            "active": true,
            "phase": 0.5 - 0.5 * cos(action_cycle),
            "strength": 0.9,
            "place_bias": 1.0,
        }
    if hit_pulse > 0.001:
        var hit_phase: float = clampf(1.0 - hit_pulse, 0.0, 1.0)
        return {
            "active": true,
            "phase": hit_phase,
            "strength": sin(hit_phase * PI),
            "place_bias": 0.0,
        }
    if interact_pulse > 0.001:
        var interact_phase: float = clampf(1.0 - interact_pulse, 0.0, 1.0)
        return {
            "active": true,
            "phase": interact_phase,
            "strength": sin(interact_phase * PI),
            "place_bias": 1.0,
        }
    return {"active": false}


func _sample_action_euler(phase: float, windup_euler: Vector3, strike_euler: Vector3) -> Vector3:
    if phase <= 0.22:
        return windup_euler * _ease_action_phase(phase / 0.22)
    if phase <= 0.66:
        return windup_euler.lerp(strike_euler, _ease_action_phase((phase - 0.22) / 0.44))
    return strike_euler.lerp(Vector3.ZERO, _ease_action_phase((phase - 0.66) / 0.34))


func _ease_action_phase(value: float) -> float:
    var clamped: float = clampf(value, 0.0, 1.0)
    return clamped * clamped * (3.0 - 2.0 * clamped)


func _get_clamped_target_pitch_degrees() -> float:
    var up_max_deg: float = float(avatar_entry.get("look_up_max_deg", 50.0))
    var down_max_deg: float = float(avatar_entry.get("look_down_max_deg", 72.0))
    return clampf(rad_to_deg(target_pitch), -down_max_deg, up_max_deg)


func _get_pitch_sign(setting_name: String) -> float:
    if avatar_entry.has(setting_name):
        return float(avatar_entry.get(setting_name, 1.0))
    return float(avatar_entry.get("look_sign", 1.0))


func _is_looking_down() -> bool:
    return _get_clamped_target_pitch_degrees() < 0.0


func _apply_directional_pitch_multiplier(pitch_deg: float, up_setting: String, down_setting: String, up_default: float = 1.0, down_default: float = 1.0) -> float:
    var direction_scale: float = up_default
    if _is_looking_down():
        direction_scale = float(avatar_entry.get(down_setting, down_default))
    else:
        direction_scale = float(avatar_entry.get(up_setting, up_default))
    return pitch_deg * direction_scale


func _get_body_pitch_degrees() -> float:
    return _get_clamped_target_pitch_degrees() * _get_pitch_sign("body_look_sign")


func _get_head_pitch_degrees() -> float:
    var head_pitch_deg: float = _get_clamped_target_pitch_degrees() * _get_pitch_sign("head_look_sign")
    head_pitch_deg += float(avatar_entry.get("neutral_bias_deg", 0.0))
    return head_pitch_deg


func _get_attack_pitch_degrees() -> float:
    return _get_clamped_target_pitch_degrees() * _get_pitch_sign("attack_look_sign")


func _get_visual_pitch_tilt_radians() -> float:
    var body_pitch_scale: float = float(avatar_entry.get("body_pitch_scale", 0.18))
    var body_pitch_max_deg: float = float(avatar_entry.get("body_pitch_max_deg", 8.0))
    var body_pitch_deg: float = clampf(_get_body_pitch_degrees() * body_pitch_scale, -body_pitch_max_deg, body_pitch_max_deg)
    return deg_to_rad(body_pitch_deg)


func _get_action_overlay_weight() -> float:
    if target_action_state == ACTION_HIT_SUSTAIN or target_action_state == ACTION_INTERACT_SUSTAIN:
        return 1.0
    return maxf(hit_pulse, interact_pulse)


func _apply_pitch_overlay_to_current_pose() -> void:
    if avatar_skeleton == null:
        return

    var body_pitch_deg: float = _get_body_pitch_degrees()
    var head_pitch_deg: float = _apply_directional_pitch_multiplier(
        _get_head_pitch_degrees(),
        "head_up_scale_mult",
        "head_down_scale_mult",
        1.2,
        1.7
    )
    var neck_pitch_deg: float = _apply_directional_pitch_multiplier(
        _get_head_pitch_degrees(),
        "neck_up_scale_mult",
        "neck_down_scale_mult",
        1.0,
        1.28
    )
    var torso_pitch_scale: float = float(avatar_entry.get("torso_pitch_scale", 0.28))
    var attack_pitch_scale: float = float(avatar_entry.get("attack_pitch_scale", 0.32))
    var action_weight: float = _get_action_overlay_weight()
    var head_scale: float = float(avatar_entry.get("head_scale", 0.6))
    var neck_scale: float = float(avatar_entry.get("neck_scale", 0.4))
    var torso_pitch_deg: float = body_pitch_deg * torso_pitch_scale
    var strike_pitch_deg: float = _get_attack_pitch_degrees() * attack_pitch_scale * action_weight

    _set_imported_bone_euler_current(HIPS_BONE, _degrees_to_radians(Vector3(torso_pitch_deg * 0.10, 0.0, 0.0)))
    _set_imported_bone_euler_current(SPINE_BONE_LOW, _degrees_to_radians(Vector3(torso_pitch_deg * 0.22, 0.0, 0.0)))
    _set_imported_bone_euler_current(SPINE_BONE_MID, _degrees_to_radians(Vector3(torso_pitch_deg * 0.30, 0.0, 0.0)))
    _set_imported_bone_euler_current(SPINE_BONE, _degrees_to_radians(Vector3(torso_pitch_deg * 0.38, 0.0, 0.0)))
    if runtime_clip_mode:
        _set_imported_bone_euler_current(HEAD_BONE, _degrees_to_radians(Vector3(head_pitch_deg * head_scale, 0.0, 0.0)))
        _set_imported_bone_euler_current(NECK_BONE, _degrees_to_radians(Vector3(neck_pitch_deg * neck_scale, 0.0, 0.0)))
    else:
        _set_imported_bone_euler(HEAD_BONE, _degrees_to_radians(Vector3(head_pitch_deg * head_scale, 0.0, 0.0)))
        _set_imported_bone_euler(NECK_BONE, _degrees_to_radians(Vector3(neck_pitch_deg * neck_scale, 0.0, 0.0)))

    if strike_pitch_deg == 0.0:
        return

    _set_imported_bone_euler_current(RIGHT_ARM_BONE, _degrees_to_radians(Vector3(strike_pitch_deg, 0.0, 0.0)))
    _set_imported_bone_euler_current(RIGHT_FOREARM_BONE, _degrees_to_radians(Vector3(strike_pitch_deg * 0.55, 0.0, 0.0)))
    _set_imported_bone_euler_current(LEFT_ARM_BONE, _degrees_to_radians(Vector3(strike_pitch_deg * 0.45, 0.0, 0.0)))
    _set_imported_bone_euler_current(LEFT_FOREARM_BONE, _degrees_to_radians(Vector3(strike_pitch_deg * 0.22, 0.0, 0.0)))


func _degrees_to_radians(euler_degrees: Vector3) -> Vector3:
    return Vector3(
        deg_to_rad(euler_degrees.x),
        deg_to_rad(euler_degrees.y),
        deg_to_rad(euler_degrees.z)
    )


func _set_imported_bone_euler(bone_name: String, euler: Vector3) -> void:
    if avatar_skeleton == null:
        return

    var resolved_bone_name: String = _find_imported_bone_name(bone_name)
    var bone_index: int = avatar_skeleton.find_bone(resolved_bone_name)
    if bone_index == -1:
        return

    var delta_rotation: Quaternion = Basis.from_euler(euler).get_rotation_quaternion()
    var base_rotation: Quaternion = imported_base_bone_rotations.get(bone_name, avatar_skeleton.get_bone_pose_rotation(bone_index))
    avatar_skeleton.set_bone_pose_rotation(bone_index, base_rotation * delta_rotation)


func _set_imported_bone_euler_current(bone_name: String, euler: Vector3) -> void:
    if avatar_skeleton == null:
        return

    var resolved_bone_name: String = _find_imported_bone_name(bone_name)
    var bone_index: int = avatar_skeleton.find_bone(resolved_bone_name)
    if bone_index == -1:
        return

    var delta_rotation: Quaternion = Basis.from_euler(euler).get_rotation_quaternion()
    var current_rotation: Quaternion = avatar_skeleton.get_bone_pose_rotation(bone_index)
    avatar_skeleton.set_bone_pose_rotation(bone_index, current_rotation * delta_rotation)


func _apply_runtime_look_pose() -> void:
    _apply_pitch_overlay_to_current_pose()


func _build_placeholder() -> void:
    placeholder_body = MeshInstance3D.new()
    var body := CapsuleMesh.new()
    body.radius = 0.18
    body.mid_height = 0.7
    placeholder_body.mesh = body
    placeholder_body.position = Vector3(0.0, 0.52, 0.0)
    visual_root.add_child(placeholder_body)

    placeholder_head_pivot = Node3D.new()
    placeholder_head_pivot.position = Vector3(0.0, 0.92, 0.0)
    visual_root.add_child(placeholder_head_pivot)

    placeholder_head = MeshInstance3D.new()
    var head := SphereMesh.new()
    head.radius = 0.2
    head.height = 0.4
    placeholder_head.mesh = head
    placeholder_head.position = Vector3(0.0, 0.2, 0.0)
    placeholder_head_pivot.add_child(placeholder_head)

    placeholder_hand_attachment = Node3D.new()
    placeholder_hand_attachment.name = "PlaceholderHeldItemAttachment"
    placeholder_hand_attachment.position = Vector3(0.24, 0.6, -0.03)
    placeholder_hand_attachment.rotation_degrees = Vector3(18.0, -20.0, -72.0)
    visual_root.add_child(placeholder_hand_attachment)

    _apply_placeholder_palette()
    _rebuild_held_item_visual()


func _update_placeholder_pose(blend: float) -> void:
    if placeholder_head_pivot != null:
        placeholder_head_pivot.position = Vector3(0.0, 0.92 - 0.06 * crouch_amount, 0.0)
        var placeholder_pitch_rad: float = deg_to_rad(clampf(_get_head_pitch_degrees(), -28.0, 28.0))
        placeholder_head_pivot.rotation.x = lerpf(placeholder_head_pivot.rotation.x, placeholder_pitch_rad * 0.7, blend)
    if placeholder_hand_attachment != null:
        placeholder_hand_attachment.position = Vector3(0.24, 0.6 - 0.07 * crouch_amount, -0.03)
        var placeholder_attack_pitch_deg: float = clampf(_get_attack_pitch_degrees() * 0.45, -12.0, 12.0)
        placeholder_hand_attachment.rotation_degrees = Vector3(18.0 + 12.0 * hit_pulse + placeholder_attack_pitch_deg, -20.0, -72.0 + 8.0 * sin(walk_phase))


func _apply_placeholder_palette() -> void:
    var hue: float = fposmod(float(peer_id) * 0.17, 1.0)
    var body_color := Color.from_hsv(hue, 0.45, 0.95)
    var head_color := Color.from_hsv(hue, 0.15, 0.92)
    if placeholder_body != null:
        placeholder_body.material_override = _make_material(body_color)
    if placeholder_head != null:
        placeholder_head.material_override = _make_material(head_color)


func _rebuild_held_item_visual() -> void:
    if held_item_visual != null:
        held_item_visual.queue_free()
        held_item_visual = null
    return


func _make_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _get_label_height() -> float:
    return IMPORTED_LABEL_HEIGHT if using_imported_avatar else 2.02


func _make_textured_material(texture: Texture2D) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    material.alpha_scissor_threshold = 0.2
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _normalize_avatar_id(raw_avatar_id: String) -> String:
    var normalized := raw_avatar_id.strip_edges().to_lower()
    return normalized if normalized != "" else DEFAULT_AVATAR_ID


func _get_visible_name() -> String:
    return display_name if display_name != "" else "P%s" % peer_id


func _resolve_avatar_path(id: String) -> String:
    # Check for a folder matching the avatar_id with a .glb inside
    # Expected structure: res://coop_mod/avatar_assets/<id>/<anything>.glb
    var folder_path: String = AVATAR_ASSETS_DIR + id + "/"
    if ResourceLoader.exists(folder_path):
        pass  # Can't list dirs easily at runtime

    # Try common naming patterns
    for candidate in [
        AVATAR_ASSETS_DIR + id + "/" + id + ".glb",
        AVATAR_ASSETS_DIR + id + ".glb",
        AVATAR_ASSETS_DIR + id + "/model.glb",
        AVATAR_ASSETS_DIR + id + "/character.glb",
    ]:
        if ResourceLoader.exists(candidate):
            return candidate

    # Try the rigged_default subfolder naming (matches existing structure)
    var rigged_path: String = AVATAR_ASSETS_DIR + "rigged_" + id + "/"
    for suffix in [id + ".glb", "low_poly_character.glb", "model.glb", "character.glb"]:
        var full: String = rigged_path + suffix
        if ResourceLoader.exists(full):
            return full

    return AVATAR_SCENE

func _apply_imported_look_pose() -> void:
    _apply_pitch_overlay_to_current_pose()

func _apply_imported_holding_pose() -> void:
    # Right arm: forward and slightly across body, like holding something at chest height
    var arm_euler = Vector3(8.0, 12.0, -55.0)
    # Forearm: strong elbow bend so hand comes up in front of chest
    var forearm_euler = Vector3(-15.0, 0.0, -35.0)
    # Hand: grip angle - wrist tilted so item points forward and slightly up
    var hand_euler = Vector3(-25.0, 15.0, 10.0)
    _set_imported_bone_euler(RIGHT_ARM_BONE, _degrees_to_radians(arm_euler))
    _set_imported_bone_euler(RIGHT_FOREARM_BONE, _degrees_to_radians(forearm_euler))
    _set_imported_bone_euler(RIGHT_HAND_BONE, _degrees_to_radians(hand_euler))
