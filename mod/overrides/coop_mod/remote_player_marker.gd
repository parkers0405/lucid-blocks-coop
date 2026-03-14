extends Node3D


const DEFAULT_AVATAR_ID: String = "default_blocky"
const AVATAR_SCENE: String = "res://coop_mod/avatar_assets/rigged_default/low_poly_character.glb"
const VISUAL_SMOOTHNESS: float = 14.0
const MAX_ANIMATED_SPEED: float = 4.5
const HIDE_NEAR_DISTANCE: float = 1.05
const TARGET_AVATAR_HEIGHT: float = 2.05
const GROUND_OFFSET: float = -0.01
const MOVE_ANIM_THRESHOLD: float = 0.08
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
const IMPORTED_POSE_BONES: PackedStringArray = [
    HIPS_BONE,
    SPINE_BONE_LOW,
    SPINE_BONE_MID,
    SPINE_BONE,
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
uniform vec4 base_tint : source_color = vec4(1.0);
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform float skin_blend : hint_range(0.0, 1.0) = 0.9;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);
    float max_channel = max(max(tex.r, tex.g), tex.b);
    float min_channel = min(min(tex.r, tex.g), tex.b);
    float brightness = dot(tex.rgb, vec3(0.333333, 0.333333, 0.333333));
    float saturation = max_channel - min_channel;
    float pale_mask = smoothstep(0.78, 0.92, brightness) * (1.0 - smoothstep(0.07, 0.24, saturation));
    vec3 base_rgb = tex.rgb * base_tint.rgb;
    ALBEDO = mix(base_rgb, base_rgb * skin_tint.rgb, pale_mask * skin_blend);
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


var peer_id: int = -1
var display_name: String = ""
var avatar_id: String = DEFAULT_AVATAR_ID

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


func _ready() -> void:
    top_level = true
    _rebuild_visual()
    visible = false
    visual_position = global_position


func _process(delta: float) -> void:
    if visual_root == null or not visible:
        return

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
    visual_root.rotation.x = -0.08 * hit_pulse - 0.04 * interact_pulse + deg_to_rad(4.0) * crouch_amount

    if using_imported_avatar:
        _update_imported_avatar_pose(speed_ratio)
    else:
        _update_placeholder_pose(blend)

    if label != null:
        label.position = Vector3(0.0, _get_label_height() - 0.08 * crouch_amount, 0.0)

    if is_instance_valid(Ref.player_camera):
        visual_root.visible = global_position.distance_to(Ref.player_camera.global_position) > HIDE_NEAR_DISTANCE
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
    avatar_id = _normalize_avatar_id(new_avatar_id)


func set_held_item_id(new_held_item_id: int) -> void:
    if target_held_item_id == new_held_item_id:
        return

    target_held_item_id = new_held_item_id
    _rebuild_held_item_visual()


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
    imported_anim_name = ""
    imported_base_bone_rotations.clear()

    var avatar_scene = load(AVATAR_SCENE)
    if not (avatar_scene is PackedScene):
        return false

    avatar_instance = avatar_scene.instantiate() as Node3D
    if avatar_instance == null:
        return false

    visual_root.add_child(avatar_instance)
    avatar_skeleton = _find_first_skeleton(avatar_instance)
    avatar_animation_player = _find_first_animation_player(avatar_instance)
    avatar_mesh_instance = _find_first_mesh_instance(avatar_instance)

    if avatar_skeleton == null:
        avatar_instance.queue_free()
        avatar_instance = null
        return false

    _prepare_imported_avatar_materials(avatar_instance)
    _configure_imported_avatar_root()
    _play_first_animation()
    _capture_imported_base_pose()
    _setup_hand_attachment()
    _rebuild_held_item_visual()
    return true


func _configure_imported_avatar_root() -> void:
    if avatar_instance == null:
        return

    # Auto-fit imported avatars to a reasonable player height.
    var mesh_aabb: AABB = _get_imported_avatar_bounds(avatar_instance)
    var mesh_height: float = mesh_aabb.size.y if mesh_aabb.size.y > 0.001 else 1.0
    var scale_factor: float = TARGET_AVATAR_HEIGHT / mesh_height

    imported_avatar_bounds = mesh_aabb
    avatar_instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
    avatar_instance.scale = Vector3.ONE * scale_factor
    avatar_instance.position = Vector3(0.0, -mesh_aabb.position.y * scale_factor + GROUND_OFFSET, 0.0)


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


func _capture_imported_base_pose() -> void:
    imported_base_bone_rotations.clear()
    if avatar_skeleton == null:
        return

    for bone_name in IMPORTED_POSE_BONES:
        var bone_index: int = avatar_skeleton.find_bone(bone_name)
        if bone_index == -1:
            continue
        imported_base_bone_rotations[bone_name] = avatar_skeleton.get_bone_pose_rotation(bone_index)


func _setup_hand_attachment() -> void:
    if avatar_skeleton == null:
        return

    avatar_hand_attachment = BoneAttachment3D.new()
    avatar_hand_attachment.name = "RemoteHeldItemAttachment"
    avatar_hand_attachment.bone_name = RIGHT_HAND_BONE
    avatar_skeleton.add_child(avatar_hand_attachment)
    avatar_hand_attachment.position = Vector3(0.0, 0.0, 0.0)
    avatar_hand_attachment.rotation_degrees = Vector3(0.0, 0.0, 0.0)


func _prepare_imported_avatar_materials(root: Node) -> void:
    if root is MeshInstance3D:
        var mesh_node := root as MeshInstance3D
        var material_count: int = mesh_node.get_surface_override_material_count()
        if material_count == 0 and mesh_node.mesh != null:
            material_count = mesh_node.mesh.get_surface_count()
        for surface_index in range(material_count):
            var source_material: Material = mesh_node.get_active_material(surface_index)
            if source_material is BaseMaterial3D:
                var duplicated := (source_material as BaseMaterial3D).duplicate() as BaseMaterial3D
                duplicated.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                duplicated.cull_mode = BaseMaterial3D.CULL_DISABLED
                mesh_node.set_surface_override_material(surface_index, _make_imported_avatar_material(duplicated))

    for child in root.get_children():
        _prepare_imported_avatar_materials(child)


func _make_imported_avatar_material(source_material: BaseMaterial3D) -> Material:
    if source_material.albedo_texture == null:
        var tinted_material := source_material.duplicate() as BaseMaterial3D
        tinted_material.albedo_color = tinted_material.albedo_color * target_skin_color
        return tinted_material

    var shader_material := ShaderMaterial.new()
    shader_material.shader = _get_imported_skin_shader()
    shader_material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
    shader_material.set_shader_parameter("base_tint", source_material.albedo_color)
    shader_material.set_shader_parameter("skin_tint", target_skin_color)
    shader_material.set_shader_parameter("skin_blend", 0.92)
    return shader_material


func _get_imported_skin_shader() -> Shader:
    if imported_skin_shader == null:
        imported_skin_shader = Shader.new()
        imported_skin_shader.code = IMPORTED_SKIN_SHADER_CODE
    return imported_skin_shader


func _apply_imported_avatar_skin_tint(root: Node) -> void:
    if root is MeshInstance3D:
        var mesh_node := root as MeshInstance3D
        var material_count: int = mesh_node.get_surface_override_material_count()
        for surface_index in range(material_count):
            var material: Material = mesh_node.get_surface_override_material(surface_index)
            if material is ShaderMaterial:
                (material as ShaderMaterial).set_shader_parameter("skin_tint", target_skin_color)
            elif material is BaseMaterial3D:
                (material as BaseMaterial3D).albedo_color = target_skin_color

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

    avatar_instance.rotation_degrees.x = rad_to_deg(clampf(target_pitch, deg_to_rad(-18.0), deg_to_rad(18.0)) * 0.35)

    if avatar_animation_player != null and imported_anim_name != "":
        avatar_animation_player.pause()
        avatar_animation_player.seek(0.0, true)

    _apply_imported_locomotion_pose(speed_ratio)

    if _has_imported_action_pose():
        _apply_imported_action_pose()


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

    var hips_euler := Vector3(7.0 * crouch_blend + 2.0 * move_amount * absf(walk_push), 0.0, 0.0)
    var spine_low_euler := Vector3(-5.0 * crouch_blend - 2.0 * move_amount * absf(walk_push), 0.0, 0.0)
    var spine_mid_euler := Vector3(-4.0 * crouch_blend, 0.0, 0.0)
    var spine_top_euler := Vector3(1.5 * crouch_blend, 0.0, 0.0)

    var arm_swing_scale: float = 24.0 * move_amount * (1.0 - 0.5 * crouch_blend)
    var left_arm_euler := Vector3(2.0 * crouch_blend, 0.0, 8.0 * crouch_blend + arm_swing_scale * walk_swing)
    var right_arm_euler := Vector3(2.0 * crouch_blend, 0.0, -8.0 * crouch_blend - arm_swing_scale * walk_swing)
    var left_forearm_euler := Vector3.ZERO
    var right_forearm_euler := Vector3.ZERO

    var upper_leg_base: float = 26.0 * crouch_blend
    var upper_leg_swing: float = 34.0 * move_amount * (1.0 - 0.45 * crouch_blend)
    var lower_leg_base: float = -30.0 * crouch_blend
    var lower_leg_stride_scale: float = 24.0 * move_amount
    var foot_base: float = 10.0 * crouch_blend
    var foot_stride_scale: float = 18.0 * move_amount

    var left_up_leg_euler := Vector3(upper_leg_base + upper_leg_swing * left_stride, 0.0, 0.0)
    var right_up_leg_euler := Vector3(upper_leg_base + upper_leg_swing * right_stride, 0.0, 0.0)
    var left_leg_euler := Vector3(lower_leg_base - lower_leg_stride_scale * left_knee_drive - 8.0 * crouch_walk_blend, 0.0, 0.0)
    var right_leg_euler := Vector3(lower_leg_base - lower_leg_stride_scale * right_knee_drive - 8.0 * crouch_walk_blend, 0.0, 0.0)
    var left_foot_euler := Vector3(foot_base + foot_stride_scale * maxf(0.0, -left_stride) + 7.0 * crouch_walk_blend, 0.0, 0.0)
    var right_foot_euler := Vector3(foot_base + foot_stride_scale * maxf(0.0, -right_stride) + 7.0 * crouch_walk_blend, 0.0, 0.0)

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

    var hit_right_arm_windup := Vector3(2.0, 0.0, -20.0)
    var hit_right_arm_strike := Vector3(-8.0, 0.0, -78.0)
    var place_right_arm_windup := Vector3(1.0, 0.0, -14.0)
    var place_right_arm_strike := Vector3(-4.0, 0.0, -52.0)

    var hit_right_forearm_windup := Vector3(0.0, 0.0, 8.0)
    var hit_right_forearm_strike := Vector3(0.0, 0.0, 10.0)
    var place_right_forearm_windup := Vector3(0.0, 0.0, 4.0)
    var place_right_forearm_strike := Vector3(0.0, 0.0, 6.0)

    var hit_left_arm_windup := Vector3.ZERO
    var hit_left_arm_strike := Vector3(6.0, 0.0, 10.0)
    var place_left_arm_windup := Vector3.ZERO
    var place_left_arm_strike := Vector3(4.0, 0.0, 7.0)

    var hit_left_forearm_windup := Vector3.ZERO
    var hit_left_forearm_strike := Vector3.ZERO
    var place_left_forearm_windup := Vector3.ZERO
    var place_left_forearm_strike := Vector3.ZERO

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


func _degrees_to_radians(euler_degrees: Vector3) -> Vector3:
    return Vector3(
        deg_to_rad(euler_degrees.x),
        deg_to_rad(euler_degrees.y),
        deg_to_rad(euler_degrees.z)
    )


func _set_imported_bone_euler(bone_name: String, euler: Vector3) -> void:
    if avatar_skeleton == null:
        return

    var bone_index: int = avatar_skeleton.find_bone(bone_name)
    if bone_index == -1:
        return

    var delta_rotation: Quaternion = Basis.from_euler(euler).get_rotation_quaternion()
    var base_rotation: Quaternion = imported_base_bone_rotations.get(bone_name, avatar_skeleton.get_bone_pose_rotation(bone_index))
    avatar_skeleton.set_bone_pose_rotation(bone_index, base_rotation * delta_rotation)


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

    _apply_placeholder_palette()


func _update_placeholder_pose(blend: float) -> void:
    if placeholder_head_pivot != null:
        placeholder_head_pivot.position = Vector3(0.0, 0.92 - 0.06 * crouch_amount, 0.0)
        placeholder_head_pivot.rotation.x = lerpf(placeholder_head_pivot.rotation.x, clampf(target_pitch, deg_to_rad(-28.0), deg_to_rad(28.0)) * 0.7, blend)


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

    if avatar_hand_attachment == null or target_held_item_id < 0:
        return

    var item = ItemMap.map(target_held_item_id)
    if item == null:
        return

    held_item_visual = Node3D.new()
    avatar_hand_attachment.add_child(held_item_visual)
    held_item_visual.position = Vector3(0.02, 0.07, 0.0)

    if item is Block and not item.foliage and not item.override_icon and item.texture != null:
        var block_mesh := MeshInstance3D.new()
        var cube := BoxMesh.new()
        cube.size = Vector3(0.14, 0.14, 0.14)
        block_mesh.mesh = cube
        block_mesh.material_override = _make_textured_material(item.texture)
        block_mesh.rotation_degrees = Vector3(-10.0, 22.0, 0.0)
        held_item_visual.add_child(block_mesh)
        return

    var item_mesh := MeshInstance3D.new()
    var slab := BoxMesh.new()
    var item_name: String = str(item.internal_name)
    var is_long_item: bool = item_name.contains("sword") or item_name.contains("pick") or item_name.contains("axe") or item_name.contains("shovel") or item_name.contains("wand") or item_name.contains("hook") or item_name.contains("knife")
    slab.size = Vector3(0.08, 0.24 if is_long_item else 0.15, 0.025)
    item_mesh.mesh = slab
    item_mesh.rotation_degrees = Vector3(0.0, 0.0, 10.0)
    if item.icon != null:
        item_mesh.material_override = _make_textured_material(item.icon)
    else:
        item_mesh.material_override = _make_material(Color(0.74, 0.74, 0.74))
    held_item_visual.add_child(item_mesh)


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
