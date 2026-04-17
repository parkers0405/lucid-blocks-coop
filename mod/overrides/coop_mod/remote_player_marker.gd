extends Node3D


const AvatarRegistry = preload("res://coop_mod/avatar_registry.gd")
const DEFAULT_AVATAR_ID: String = "default_blocky"
const AVATAR_SCENE: String = "res://coop_mod/avatar_assets/rigged_default/low_poly_character.glb"
const AVATAR_ASSETS_DIR: String = "res://coop_mod/avatar_assets/"
const VISUAL_SMOOTHNESS: float = 14.0
const MAX_ANIMATED_SPEED: float = 4.5
const RUN_ANIM_SPEED_THRESHOLD: float = 4.75
const HIDE_NEAR_DISTANCE: float = 0.9
const PLAYER_HEIGHT: float = 1.85
const MOVE_ANIM_THRESHOLD: float = 0.08
const HELD_ITEM_REBUILD_DELAY: float = 0.08
const LABEL_HEIGHT: float = PLAYER_HEIGHT + 0.4

const ACTION_IDLE: int = 0
const ACTION_HIT_SUSTAIN: int = 1
const ACTION_INTERACT_SUSTAIN: int = 2
const ACTION_HIT: int = 3
const ACTION_INTERACT: int = 4

# Raw Mixamo animation FBXes. Track paths use Skeleton3D:mixamorig_BoneName.
# At load time we rewrite track paths to match each avatar's actual bone names.
# No Godot retarget pipeline - raw Mixamo clips on raw Mixamo skeletons = no rest mismatch.
const RUNTIME_CLIP_PATHS: Dictionary = {
    "idle": "res://coop_mod/animation_workflow/source_fbx/core/breathing_idle.fbx",
    "idle_alt": "res://coop_mod/animation_workflow/source_fbx/core/idle.fbx",
    "walk": "res://coop_mod/animation_workflow/source_fbx/core/walk.fbx",
    "run": "res://coop_mod/animation_workflow/source_fbx/core/run.fbx",
    "jump": "res://coop_mod/animation_workflow/source_fbx/core/jump_run.fbx",
    "crouch_idle": "res://coop_mod/animation_workflow/source_fbx/core/crouch_idle.fbx",
    "crouch_walk": "res://coop_mod/animation_workflow/source_fbx/core/crouch_walk.fbx",
    "attack": "res://coop_mod/animation_workflow/source_fbx/core/attack.fbx",
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
var held_item_visual: Node3D
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
var current_runtime_clip: String = ""
var prev_yaw: float = 0.0
var yaw_delta_accumulated: float = 0.0
var held_item_rebuild_pending: bool = false
var held_item_rebuild_timer: float = 0.0
var avatar_sound_player: AudioStreamPlayer3D
var avatar_sound_cache: Dictionary = {}  # action_name -> Array[AudioStream]
var last_sound_action: String = ""
var sound_cooldown: float = 0.0


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

    if sound_cooldown > 0.0:
        sound_cooldown -= delta

    var blend: float = clampf(delta * VISUAL_SMOOTHNESS, 0.0, 1.0)
    visual_position = visual_position.lerp(target_position, blend)
    visual_yaw = lerp_angle(visual_yaw, target_yaw, blend)

    global_position = visual_position
    rotation = Vector3(0.0, visual_yaw, 0.0)

    # Track yaw changes for turn-in-place detection
    var yaw_diff: float = angle_difference(prev_yaw, target_yaw)
    yaw_delta_accumulated = lerpf(yaw_delta_accumulated, yaw_diff / maxf(delta, 0.001), clampf(delta * 6.0, 0.0, 1.0))
    prev_yaw = target_yaw

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

    if using_imported_avatar:
        _update_avatar_animation(speed_ratio)
    else:
        _update_placeholder_pose(blend)

    if label != null:
        label.position = Vector3(0.0, _get_label_height() - 0.08 * crouch_amount, 0.0)

    var player_camera: Node3D = _get_ref_player_camera()
    if is_instance_valid(player_camera):
        var is_local_peer_marker: bool = peer_id == multiplayer.get_unique_id()
        visual_root.visible = true if not is_local_peer_marker else global_position.distance_to(player_camera.global_position) > HIDE_NEAR_DISTANCE
    else:
        visual_root.visible = true


func _get_ref_singleton() -> Node:
    return get_node_or_null("/root/Ref")


func _get_ref_player_camera() -> Node3D:
    var ref_singleton: Node = _get_ref_singleton()
    if ref_singleton == null:
        return null
    return ref_singleton.get("player_camera") as Node3D


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
    print("[avatar] set_avatar_id: %s -> %s" % [avatar_id, normalized])
    avatar_id = normalized
    avatar_entry = AvatarRegistry.get_avatar_entry(avatar_id)
    print("[avatar] resolved entry id=%s path=%s" % [avatar_entry.get("id", "?"), avatar_entry.get("path", "?")])
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


func set_action_state(new_action_state: int) -> void:
    if target_action_state == new_action_state:
        return
    target_action_state = new_action_state
    if new_action_state == ACTION_HIT:
        hit_pulse = 1.0
    elif new_action_state == ACTION_INTERACT:
        interact_pulse = 1.0


func set_label_enabled(enabled: bool) -> void:
    if label != null:
        label.visible = enabled


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


# ---------------------------------------------------------------------------
# Visual rebuild
# ---------------------------------------------------------------------------

func _rebuild_visual() -> void:
    if visual_root != null:
        visual_root.queue_free()
    if label != null:
        label.queue_free()

    visual_root = Node3D.new()
    add_child(visual_root)

    using_imported_avatar = _try_build_avatar()
    if not using_imported_avatar:
        _build_placeholder()

    label = Label3D.new()
    label.text = _get_visible_name()
    label.position = Vector3(0.0, _get_label_height(), 0.0)
    label.no_depth_test = true
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)


# ---------------------------------------------------------------------------
# Avatar build - pure Godot/Mixamo, zero manual bone work
# ---------------------------------------------------------------------------

func _try_build_avatar() -> bool:
    avatar_instance = null
    avatar_skeleton = null
    avatar_animation_player = null
    avatar_mesh_instance = null
    held_item_visual = null
    held_item_rebuild_pending = false
    held_item_rebuild_timer = 0.0
    current_runtime_clip = ""

    avatar_entry = AvatarRegistry.get_avatar_entry(avatar_id)
    var avatar_path: String = str(avatar_entry.get("path", AVATAR_SCENE))
    var avatar_scene = load(avatar_path)
    if not (avatar_scene is PackedScene):
        if avatar_path != AVATAR_SCENE:
            avatar_scene = load(AVATAR_SCENE)
        if not (avatar_scene is PackedScene):
            return false

    avatar_instance = avatar_scene.instantiate() as Node3D
    if avatar_instance == null:
        return false

    visual_root.add_child(avatar_instance)
    avatar_skeleton = _find_first_skeleton(avatar_instance)
    avatar_mesh_instance = _find_first_mesh_instance(avatar_instance)

    if avatar_skeleton == null:
        avatar_instance.queue_free()
        avatar_instance = null
        return false

    # Create AnimationPlayer if the scene doesn't have one
    avatar_animation_player = _find_first_animation_player(avatar_instance)
    if avatar_animation_player == null:
        avatar_animation_player = AnimationPlayer.new()
        avatar_animation_player.name = "RuntimeAnimationPlayer"
        avatar_animation_player.root_node = NodePath("..")
        avatar_instance.add_child(avatar_animation_player)

    _prepare_materials(avatar_instance)
    _force_visible_recursive(avatar_instance)
    _scale_avatar_to_player_height()
    _load_runtime_clips()
    _setup_avatar_sounds()
    _rebuild_held_item_visual()
    return true


func _scale_avatar_to_player_height() -> void:
    if avatar_instance == null:
        return

    # Try mesh AABB first. If it's too small (microscopic export scale),
    # fall back to skeleton bone positions.
    var mesh_aabb: AABB = _get_bounds(avatar_instance)
    var model_height: float = mesh_aabb.size.y
    var floor_y: float = mesh_aabb.position.y

    if model_height < 0.1 and avatar_skeleton != null:
        # Mesh AABB is microscopic - use skeleton measurement instead
        var head_idx: int = avatar_skeleton.find_bone("mixamorig_Head")
        if head_idx == -1:
            head_idx = avatar_skeleton.find_bone("Head")
        if head_idx == -1:
            head_idx = avatar_skeleton.find_bone("head")
        var lfoot_idx: int = avatar_skeleton.find_bone("mixamorig_LeftFoot")
        if lfoot_idx == -1:
            lfoot_idx = avatar_skeleton.find_bone("LeftFoot")
        if lfoot_idx == -1:
            lfoot_idx = avatar_skeleton.find_bone("foot.L")
        var rfoot_idx: int = avatar_skeleton.find_bone("mixamorig_RightFoot")
        if rfoot_idx == -1:
            rfoot_idx = avatar_skeleton.find_bone("RightFoot")
        if rfoot_idx == -1:
            rfoot_idx = avatar_skeleton.find_bone("foot.R")

        if head_idx != -1 and lfoot_idx != -1 and rfoot_idx != -1:
            var head_pos: Vector3 = avatar_skeleton.get_bone_global_rest(head_idx).origin
            var lfoot_pos: Vector3 = avatar_skeleton.get_bone_global_rest(lfoot_idx).origin
            var rfoot_pos: Vector3 = avatar_skeleton.get_bone_global_rest(rfoot_idx).origin
            var foot_mid: Vector3 = (lfoot_pos + rfoot_pos) * 0.5
            model_height = head_pos.distance_to(foot_mid)
            floor_y = minf(lfoot_pos.y, rfoot_pos.y)

    if model_height < 0.001:
        model_height = 1.0

    var target_height: float = float(avatar_entry.get("height", PLAYER_HEIGHT))
    var scale_factor: float = target_height / model_height
    # Mixamo models face +Z, game expects -Z. Rotate 180 around Y.
    avatar_instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
    avatar_instance.scale = Vector3.ONE * scale_factor
    # Position so feet sit at Y=0
    var ground_lift: float = float(avatar_entry.get("ground_offset", 0.0))
    avatar_instance.position = Vector3(0.0, -floor_y * scale_factor + ground_lift, 0.0)
# ---------------------------------------------------------------------------
# Runtime animation clips - loaded directly, no remapping
# ---------------------------------------------------------------------------

func _load_runtime_clips() -> void:
    if avatar_animation_player == null or avatar_skeleton == null:
        return

    # Build a map from Godot humanoid standard names -> actual skeleton bone names.
    # The .res clips use %Skeleton:Hips etc, but models may use mixamorig_Hips or hips.
    var bone_map: Dictionary = _build_bone_name_map()

    # Compute the skeleton path relative to the AnimationPlayer root
    var ap_root: Node = avatar_animation_player.get_node_or_null(avatar_animation_player.root_node)
    if ap_root == null:
        ap_root = avatar_animation_player.get_parent()
    var skeleton_path: String = str(ap_root.get_path_to(avatar_skeleton)) if ap_root != null else "Skeleton3D"

    var library: AnimationLibrary = null
    var library_names = avatar_animation_player.get_animation_library_list()
    if library_names.has(&""):
        library = avatar_animation_player.get_animation_library("")
    if library == null:
        library = AnimationLibrary.new()
        avatar_animation_player.add_animation_library("", library)

    # Use per-avatar clip paths if available, otherwise use shared default clips
    var custom_clips: Dictionary = avatar_entry.get("runtime_clips", {})
    var clip_paths: Dictionary = RUNTIME_CLIP_PATHS.duplicate()
    for clip_name in custom_clips.keys():
        clip_paths[clip_name] = str(custom_clips[clip_name])

    for clip_name in clip_paths.keys():
        if library.has_animation(clip_name):
            continue
        var clip: Animation = _extract_mixamo_animation(str(clip_paths[clip_name]))
        if clip == null:
            continue
        # Only remap if using shared default clips on a non-default skeleton
        if not custom_clips.has(clip_name):
            _retarget_clip_tracks(clip, bone_map, skeleton_path)
        if clip_name in ["idle", "idle_alt", "walk", "run", "crouch_idle", "crouch_walk"]:
            clip.loop_mode = Animation.LOOP_LINEAR
        else:
            clip.loop_mode = Animation.LOOP_NONE
        library.add_animation(clip_name, clip)


func _extract_mixamo_animation(path: String) -> Animation:
    var resource = load(path)
    if resource is Animation:
        return (resource as Animation).duplicate(true)
    if not (resource is PackedScene):
        return null
    var inst: Node = (resource as PackedScene).instantiate()
    var ap: AnimationPlayer = _find_first_animation_player(inst)
    if ap == null:
        inst.queue_free()
        return null
    # Mixamo FBXes export the animation as "mixamo_com"
    var anim_name: String = "mixamo_com"
    if not ap.has_animation(anim_name):
        # Try first available animation
        var names: PackedStringArray = ap.get_animation_list()
        if names.is_empty():
            inst.queue_free()
            return null
        anim_name = names[0]
    var anim: Animation = ap.get_animation(anim_name).duplicate(true)
    inst.queue_free()
    return anim


# For each raw Mixamo FBX bone name, candidate names on the actual skeleton.
# Raw FBX tracks use mixamorig_Hips etc. Default model also uses mixamorig_Hips.
# Pim uses hips, upperarm.L etc. This maps FBX track names -> skeleton bone names.
const MIXAMO_BONE_ALIASES: Dictionary = {
    "mixamorig_Hips": ["mixamorig_Hips", "hips"],
    "mixamorig_Spine": ["mixamorig_Spine", "spine"],
    "mixamorig_Spine1": ["mixamorig_Spine1", "spine1"],
    "mixamorig_Spine2": ["mixamorig_Spine2", "chest"],
    "mixamorig_Neck": ["mixamorig_Neck", "neck"],
    "mixamorig_Head": ["mixamorig_Head", "head"],
    "mixamorig_LeftShoulder": ["mixamorig_LeftShoulder", "shoulder.L"],
    "mixamorig_LeftArm": ["mixamorig_LeftArm", "upperarm.L"],
    "mixamorig_LeftForeArm": ["mixamorig_LeftForeArm", "lowerarm.L"],
    "mixamorig_LeftHand": ["mixamorig_LeftHand", "hand.L"],
    "mixamorig_RightShoulder": ["mixamorig_RightShoulder", "shoulder.R"],
    "mixamorig_RightArm": ["mixamorig_RightArm", "upperarm.R"],
    "mixamorig_RightForeArm": ["mixamorig_RightForeArm", "lowerarm.R"],
    "mixamorig_RightHand": ["mixamorig_RightHand", "hand.R"],
    "mixamorig_LeftUpLeg": ["mixamorig_LeftUpLeg", "upperleg.L"],
    "mixamorig_LeftLeg": ["mixamorig_LeftLeg", "lowerleg.L"],
    "mixamorig_LeftFoot": ["mixamorig_LeftFoot", "foot.L"],
    "mixamorig_LeftToeBase": ["mixamorig_LeftToeBase", "toe.L"],
    "mixamorig_RightUpLeg": ["mixamorig_RightUpLeg", "upperleg.R"],
    "mixamorig_RightLeg": ["mixamorig_RightLeg", "lowerleg.R"],
    "mixamorig_RightFoot": ["mixamorig_RightFoot", "foot.R"],
    "mixamorig_RightToeBase": ["mixamorig_RightToeBase", "toe.R"],
    "mixamorig_LeftHandThumb1": ["mixamorig_LeftHandThumb1", "thumb.L"],
    "mixamorig_LeftHandThumb2": ["mixamorig_LeftHandThumb2", "thumb1.L"],
    "mixamorig_LeftHandThumb3": ["mixamorig_LeftHandThumb3", "thumb2.L"],
    "mixamorig_LeftHandIndex1": ["mixamorig_LeftHandIndex1", "index.L"],
    "mixamorig_LeftHandIndex2": ["mixamorig_LeftHandIndex2", "index1.L"],
    "mixamorig_LeftHandIndex3": ["mixamorig_LeftHandIndex3", "index2.L"],
    "mixamorig_LeftHandMiddle1": ["mixamorig_LeftHandMiddle1", "middle.L"],
    "mixamorig_LeftHandMiddle2": ["mixamorig_LeftHandMiddle2", "middle1.L"],
    "mixamorig_LeftHandMiddle3": ["mixamorig_LeftHandMiddle3", "middle2.L"],
    "mixamorig_LeftHandRing1": ["mixamorig_LeftHandRing1", "ring.L"],
    "mixamorig_LeftHandRing2": ["mixamorig_LeftHandRing2", "ring1.L"],
    "mixamorig_LeftHandRing3": ["mixamorig_LeftHandRing3", "ring2.L"],
    "mixamorig_LeftHandPinky1": ["mixamorig_LeftHandPinky1", "pinky.L"],
    "mixamorig_LeftHandPinky2": ["mixamorig_LeftHandPinky2", "pinky1.L"],
    "mixamorig_LeftHandPinky3": ["mixamorig_LeftHandPinky3", "pinky2.L"],
    "mixamorig_RightHandThumb1": ["mixamorig_RightHandThumb1", "thumb.R"],
    "mixamorig_RightHandThumb2": ["mixamorig_RightHandThumb2", "thumb1.R"],
    "mixamorig_RightHandThumb3": ["mixamorig_RightHandThumb3", "thumb2.R"],
    "mixamorig_RightHandIndex1": ["mixamorig_RightHandIndex1", "index.R"],
    "mixamorig_RightHandIndex2": ["mixamorig_RightHandIndex2", "index1.R"],
    "mixamorig_RightHandIndex3": ["mixamorig_RightHandIndex3", "index2.R"],
    "mixamorig_RightHandMiddle1": ["mixamorig_RightHandMiddle1", "middle.R"],
    "mixamorig_RightHandMiddle2": ["mixamorig_RightHandMiddle2", "middle1.R"],
    "mixamorig_RightHandMiddle3": ["mixamorig_RightHandMiddle3", "middle2.R"],
    "mixamorig_RightHandRing1": ["mixamorig_RightHandRing1", "ring.R"],
    "mixamorig_RightHandRing2": ["mixamorig_RightHandRing2", "ring1.R"],
    "mixamorig_RightHandRing3": ["mixamorig_RightHandRing3", "ring2.R"],
    "mixamorig_RightHandPinky1": ["mixamorig_RightHandPinky1", "pinky.R"],
    "mixamorig_RightHandPinky2": ["mixamorig_RightHandPinky2", "pinky1.R"],
    "mixamorig_RightHandPinky3": ["mixamorig_RightHandPinky3", "pinky2.R"],
    "mixamorig_HeadTop_End": ["mixamorig_HeadTop_End"],
}


func _build_bone_name_map() -> Dictionary:
    # Returns: mixamo_fbx_bone_name -> actual_bone_name_on_this_skeleton
    # e.g. for default: "mixamorig_Hips" -> "mixamorig_Hips" (identity)
    # e.g. for pim: "mixamorig_Hips" -> "hips"
    var result: Dictionary = {}
    if avatar_skeleton == null:
        return result
    for mixamo_name in MIXAMO_BONE_ALIASES.keys():
        var candidates: Array = MIXAMO_BONE_ALIASES[mixamo_name]
        for candidate in candidates:
            if avatar_skeleton.find_bone(str(candidate)) != -1:
                result[mixamo_name] = str(candidate)
                break
    print("[avatar] bone_map: %d/%d mapped" % [result.size(), MIXAMO_BONE_ALIASES.size()])
    for key in ["mixamorig_Hips", "mixamorig_Head", "mixamorig_LeftArm", "mixamorig_RightArm", "mixamorig_LeftFoot"]:
        print("[avatar]   %s -> %s" % [key, result.get(key, "MISSING")])
    return result


func _retarget_clip_tracks(clip: Animation, bone_map: Dictionary, skeleton_path: String) -> void:
    # Rewrite track paths from %Skeleton:HumanoidName -> skeleton_path:actual_bone_name
    var tracks_to_remove: Array[int] = []
    var rewritten: int = 0
    for i in range(clip.get_track_count()):
        var path_str: String = str(clip.track_get_path(i))
        var colon_idx: int = path_str.find(":")
        if colon_idx == -1:
            continue
        var bone_name: String = path_str.substr(colon_idx + 1)
        if bone_map.has(bone_name):
            clip.track_set_path(i, NodePath("%s:%s" % [skeleton_path, bone_map[bone_name]]))
            rewritten += 1
        else:
            tracks_to_remove.append(i)
    for idx in range(tracks_to_remove.size() - 1, -1, -1):
        clip.remove_track(tracks_to_remove[idx])
    print("[avatar] retarget: rewritten=%d removed=%d remaining=%d skeleton_path=%s" % [rewritten, tracks_to_remove.size(), clip.get_track_count(), skeleton_path])


func _choose_clip(speed_ratio: float) -> String:
    if target_action_state == ACTION_HIT or target_action_state == ACTION_HIT_SUSTAIN:
        return "attack"
    if target_action_state == ACTION_INTERACT or target_action_state == ACTION_INTERACT_SUSTAIN:
        return "attack"
    if not target_grounded:
        return "jump"
    if target_crouching:
        return "crouch_walk" if speed_ratio > MOVE_ANIM_THRESHOLD else "crouch_idle"
    if target_move_speed >= RUN_ANIM_SPEED_THRESHOLD:
        return "run"
    if speed_ratio > MOVE_ANIM_THRESHOLD:
        return "walk"

    # Idle - check for turning in place or looking down
    var turn_threshold: float = 0.8  # radians/sec of yaw change
    if absf(yaw_delta_accumulated) > turn_threshold:
        if yaw_delta_accumulated < 0.0:
            return "turn_left"
        else:
            return "turn_right"

    # Looking down while idle (pitch beyond 40 degrees in either direction)
    if absf(target_pitch) > deg_to_rad(40.0):
        if avatar_animation_player != null and avatar_animation_player.has_animation("looking_down"):
            return "looking_down"

    return "idle"


func _play_clip(clip_name: String, speed_ratio: float) -> void:
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
    elif clip_name == "run":
        clip_speed = lerpf(0.92, 1.18, clampf(inverse_lerp(RUN_ANIM_SPEED_THRESHOLD, RUN_ANIM_SPEED_THRESHOLD + 1.6, target_move_speed), 0.0, 1.0))
    elif clip_name == "crouch_walk":
        clip_speed = lerpf(0.8, 1.2, speed_ratio)
    elif clip_name == "jump":
        clip_speed = 1.28
    elif clip_name == "idle" or clip_name == "idle_alt" or clip_name == "crouch_idle":
        clip_speed = 1.0
    avatar_animation_player.speed_scale = clip_speed


func _update_avatar_animation(speed_ratio: float) -> void:
    if avatar_instance == null:
        return
    var desired_clip: String = _choose_clip(speed_ratio)
    _play_clip(desired_clip, speed_ratio)
    _play_avatar_action_sound(desired_clip)


func _setup_avatar_sounds() -> void:
    avatar_sound_cache.clear()
    var sounds_config: Dictionary = avatar_entry.get("sounds", {})
    if sounds_config.is_empty():
        return

    avatar_sound_player = AudioStreamPlayer3D.new()
    avatar_sound_player.bus = "SFX"
    avatar_sound_player.volume_db = -8.0
    avatar_sound_player.max_distance = 32.0
    add_child(avatar_sound_player)

    for action_name in sounds_config.keys():
        var paths: Array = sounds_config[action_name]
        var streams: Array = []
        for path in paths:
            var stream = load(str(path))
            if stream is AudioStream:
                streams.append(stream)
        if not streams.is_empty():
            avatar_sound_cache[action_name] = streams


func _play_avatar_action_sound(clip_name: String) -> void:
    if avatar_sound_player == null or avatar_sound_cache.is_empty():
        return
    if sound_cooldown > 0.0:
        return

    var action: String = ""
    var chance: float = 0.0
    var cooldown_time: float = 0.0
    match clip_name:
        "attack":
            action = "attack"
            chance = 0.008
            cooldown_time = 15.0
        "jump":
            action = "jump"
            chance = 0.005
            cooldown_time = 20.0
        "hit_react":
            action = "hurt"
            chance = 0.015
            cooldown_time = 12.0
        "death":
            action = "death"
            chance = 0.25
            cooldown_time = 10.0
        _:
            last_sound_action = ""
            return

    # Random chance every time - no guaranteed first play
    if randf() > chance:
        last_sound_action = action
        return
    last_sound_action = action

    if not avatar_sound_cache.has(action):
        return

    var streams: Array = avatar_sound_cache[action]
    if streams.is_empty():
        return

    sound_cooldown = cooldown_time
    var stream: AudioStream = streams[randi() % streams.size()]
    avatar_sound_player.stream = stream
    avatar_sound_player.play()


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

func _prepare_materials(root: Node) -> void:
    var texture_override_path: String = str(avatar_entry.get("texture_override", "")).strip_edges()
    var texture_override: Texture2D = load(texture_override_path) as Texture2D if texture_override_path != "" else null

    # Load multi-texture map if available
    var multi_textures: Dictionary = {}
    var multi_config: Dictionary = avatar_entry.get("multi_texture", {})
    for tex_name in multi_config.keys():
        var tex = load(str(multi_config[tex_name]))
        if tex is Texture2D:
            multi_textures[str(tex_name)] = tex

    _prepare_materials_recursive(root, texture_override, multi_textures)


func _prepare_materials_recursive(root: Node, texture_override: Texture2D, multi_textures: Dictionary) -> void:
    if root is MeshInstance3D:
        var mesh_node := root as MeshInstance3D
        mesh_node.visible = true
        if mesh_node.mesh != null:
            if texture_override != null:
                for surface_index in range(mesh_node.mesh.get_surface_count()):
                    mesh_node.set_surface_override_material(surface_index, _make_texture_material(texture_override))
            elif not multi_textures.is_empty():
                _apply_multi_textures(mesh_node, multi_textures)
    for child in root.get_children():
        _prepare_materials_recursive(child, texture_override, multi_textures)


func _apply_multi_textures(mesh_node: MeshInstance3D, multi_textures: Dictionary) -> void:
    if mesh_node.mesh == null:
        return
    # Try to apply textures by matching material slot names to texture names
    # If we can't match, apply the largest texture as fallback
    var fallback_texture: Texture2D = null
    var largest_size: int = 0
    for tex_name in multi_textures.keys():
        var tex: Texture2D = multi_textures[tex_name]
        var size: int = tex.get_width() * tex.get_height()
        if size > largest_size:
            largest_size = size
            fallback_texture = tex

    for surface_index in range(mesh_node.mesh.get_surface_count()):
        var mat = mesh_node.mesh.surface_get_material(surface_index)
        var mat_name: String = mat.resource_name if mat != null else ""
        var matched: bool = false
        for tex_name in multi_textures.keys():
            if mat_name.containsn(tex_name) or tex_name.containsn(mat_name):
                mesh_node.set_surface_override_material(surface_index, _make_texture_material(multi_textures[tex_name]))
                matched = true
                break
        if not matched and fallback_texture != null:
            mesh_node.set_surface_override_material(surface_index, _make_texture_material(fallback_texture))


func _force_visible_recursive(root: Node) -> void:
    if root is GeometryInstance3D:
        var geometry := root as GeometryInstance3D
        geometry.visible = true
        geometry.extra_cull_margin = 2.0
        geometry.ignore_occlusion_culling = false
        geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in root.get_children():
        _force_visible_recursive(child)


func _make_texture_material(texture: Texture2D) -> Material:
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


# ---------------------------------------------------------------------------
# Scene tree helpers
# ---------------------------------------------------------------------------

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


func _get_bounds(root: Node3D) -> AABB:
    var mesh_bounds: Array = []
    _collect_mesh_bounds(root, Transform3D.IDENTITY, mesh_bounds, true)
    if mesh_bounds.is_empty():
        return AABB(Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 1.7, 0.7))
    var merged: AABB = mesh_bounds[0]
    for index in range(1, mesh_bounds.size()):
        merged = merged.merge(mesh_bounds[index])
    return merged


func _collect_mesh_bounds(node: Node, parent_transform: Transform3D, mesh_bounds: Array, skip_node_transform: bool = false) -> void:
    var current_transform: Transform3D = parent_transform
    if node is Node3D and not skip_node_transform:
        current_transform = parent_transform * (node as Node3D).transform
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh != null:
            mesh_bounds.append(_transform_aabb(mesh_node.get_aabb(), current_transform))
    for child in node.get_children():
        _collect_mesh_bounds(child, current_transform, mesh_bounds, false)


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


# ---------------------------------------------------------------------------
# Placeholder (fallback when no avatar model loads)
# ---------------------------------------------------------------------------

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
        var placeholder_pitch_rad: float = deg_to_rad(clampf(rad_to_deg(target_pitch), -28.0, 28.0))
        placeholder_head_pivot.rotation.x = lerpf(placeholder_head_pivot.rotation.x, placeholder_pitch_rad * 0.7, blend)
    if placeholder_hand_attachment != null:
        placeholder_hand_attachment.position = Vector3(0.24, 0.6 - 0.07 * crouch_amount, -0.03)
        placeholder_hand_attachment.rotation_degrees = Vector3(18.0 + 12.0 * hit_pulse, -20.0, -72.0 + 8.0 * sin(walk_phase))


func _apply_placeholder_palette() -> void:
    var hue: float = fposmod(float(peer_id) * 0.17, 1.0)
    var body_color := Color.from_hsv(hue, 0.45, 0.95)
    var head_color := Color.from_hsv(hue, 0.15, 0.92)
    if placeholder_body != null:
        placeholder_body.material_override = _make_color_material(body_color)
    if placeholder_head != null:
        placeholder_head.material_override = _make_color_material(head_color)


# ---------------------------------------------------------------------------
# Held items
# ---------------------------------------------------------------------------

func _rebuild_held_item_visual() -> void:
    if held_item_visual != null:
        held_item_visual.queue_free()
        held_item_visual = null
    return


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _make_color_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _get_label_height() -> float:
    return LABEL_HEIGHT if using_imported_avatar else 2.02


func _normalize_avatar_id(raw_avatar_id: String) -> String:
    var normalized := raw_avatar_id.strip_edges().to_lower()
    return normalized if normalized != "" else DEFAULT_AVATAR_ID


func _get_visible_name() -> String:
    return display_name if display_name != "" else "P%s" % peer_id
