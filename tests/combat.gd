extends Node

var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("COMBAT_FAIL ", label)

func _mean_points(gel: Gel, indices: PackedInt32Array) -> Vector3:
    var mean := Vector3.ZERO
    for index in indices:
        mean += gel.softbody.get_point_transform(index)
    return mean / float(indices.size())

func _render_visibility(viewport: SubViewport, camera: Camera3D, gel: Gel, scene_path: String) -> void:
    gel.visible = true
    var target: Vector3 = gel.get_softbody_approximate_position()
    camera.position = target + Vector3(0, 0, maxf(2.0, gel.softbody.mesh.get_aabb().size.length() * 1.5))
    camera.look_at(target)
    for frame in range(2):
        await get_tree().process_frame
        await RenderingServer.frame_post_draw
    var image: Image = viewport.get_texture().get_image()
    check(image != null and image.get_width() == 256 and image.get_height() == 256, scene_path + " real viewport readback")
    if image == null or image.is_empty():
        return
    check(image.get_pixel(0, 0).a < 0.01, scene_path + " isolated viewport background is transparent")
    var center_hits: int = 0
    for y in range(126, 131):
        for x in range(126, 131):
            if image.get_pixel(x, y).a > 0.5:
                center_hits += 1
    check(center_hits > 0, scene_path + " rendered silhouette intersects camera center")
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var screenshot: String = args[2].path_join(scene_path.get_file().get_basename() + "-visibility.png")
    check(image.save_png(screenshot) == OK, scene_path + " rendered evidence saved")
    print("COMBAT_RENDER ", scene_path, " method=", RenderingServer.get_current_rendering_method(), " display=", DisplayServer.get_name(), " center_hits=", center_hits, " target=", target, " png=", screenshot)

func _attack_checks(entity: Entity, label: String) -> void:
    entity.disabled = false
    entity.invincible = false
    entity.invincible_temporary = false
    entity.armored = false
    entity.can_endure = false
    entity.health = entity.max_health
    var initial: int = entity.health
    entity.attacked(Ref.player, 2, Vector3(1, 2, 3))
    check(entity.health == initial - 2, label + " three-argument attack applies damage")
    check(entity.last_attacker == Ref.player, label + " records attacker")
    check(entity.direct_damage_cooldown and not entity.get_node("%DirectDamageTimer").is_stopped(), label + " starts damage cooldown")
    entity.attacked(Ref.player, 1, Vector3.ZERO)
    check(entity.health == initial - 3, label + " zero-position attack applies damage")
    entity.attacked(Ref.player, -1, Vector3.ONE)
    check(entity.health == initial - 2, label + " three-argument healing applies")

func run() -> int:
    print("COMBAT_SUITE_START")
    if DisplayServer.get_name() == "headless":
        print("COMBAT_RENDER_BLOCKED real renderer required")
        return 1
    var viewport := SubViewport.new()
    viewport.size = Vector2i(256, 256)
    viewport.own_world_3d = true
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0, 0, 0, 0)
    viewport.add_child(environment)
    var camera := Camera3D.new()
    camera.current = true
    viewport.add_child(camera)
    var entities: Array[Entity] = []
    var base: Entity = load("res://main/entity/entity.tscn").instantiate()
    # The base template leaves its marker exports to derived scenes.
    base.head = Marker3D.new()
    base.hand = Marker3D.new()
    base.add_child(base.head)
    base.add_child(base.hand)
    base.disabled_by_visibility = false
    base.disabled_by_distance = false
    add_child(base)
    base.process_mode = Node.PROCESS_MODE_DISABLED
    base.set_physics_process(false)
    base.set_process(false)
    _attack_checks(base, "Entity template")
    entities.append(base)
    for scene_path in ["res://main/entity/gel/gel.tscn", "res://main/entity/gel/mini_gel.tscn"]:
        var gel: Gel = load(scene_path).instantiate()
        gel.position = Vector3(100.0 * (entities.size() + 1), 20, 0)
        gel.disabled_by_visibility = false
        gel.disabled_by_distance = false
        viewport.add_child(gel)
        gel.process_mode = Node.PROCESS_MODE_DISABLED
        gel.set_physics_process(false)
        gel.set_process(false)
        gel.jump_timer.stop()
        gel.softbody.process_mode = Node.PROCESS_MODE_ALWAYS
        var vertices: PackedVector3Array = gel.softbody.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        check(gel.major_indices == PackedInt32Array([8, 9, 26, 27, 44, 45]), scene_path + " current major indices")
        check(gel.minor_indices == gel.major_indices, scene_path + " current minor defaults")
        var valid: bool = true
        for index in gel.major_indices:
            valid = valid and index >= 0 and index < vertices.size()
        check(valid, scene_path + " indices fit actual original mesh")
        var paused_before: bool = get_tree().paused
        get_tree().paused = false
        await get_tree().physics_frame
        await get_tree().process_frame
        await get_tree().physics_frame
        await get_tree().process_frame
        get_tree().paused = paused_before
        await _render_visibility(viewport, camera, gel, scene_path)
        gel.global_position = Vector3(7, 8, 9)
        gel.override_position()
        check(gel.softbody.global_position.is_equal_approx(gel.global_position), scene_path + " preserved position aligns actual softbody")
        gel.is_mini = false
        check(gel.get_softbody_approximate_position().is_equal_approx(_mean_points(gel, gel.major_indices)), scene_path + " major position sample")
        gel.minor_indices = PackedInt32Array([0, 1, 2, 3, 4, 5])
        gel.is_mini = true
        check(gel.get_softbody_approximate_position().is_equal_approx(_mean_points(gel, gel.minor_indices)), scene_path + " mini branch honors minor overrides")
        _attack_checks(gel, scene_path)
        check(gel.bothersome == Ref.player, scene_path + " attack chooses attacker target")
        print("COMBAT_SCENE ", scene_path, " vertices=", vertices.size(), " health=", gel.health)
        entities.append(gel)
    var projectiles: Array[Node] = []
    for path in ["res://main/entity/mimos/mimos.tscn", "res://main/entity/mipos/mipos.tscn"]:
        var target: Entity = load(path).instantiate()
        add_child(target)
        target.process_mode = Node.PROCESS_MODE_DISABLED
        target.set_physics_process(false)
        target.set_process(false)
        target.disabled = false
        target.can_endure = false
        if target.has_node("%Bleed"):
            target.get_node("%Bleed").enabled = false
        var health_before: int = target.health
        var hit_position := Vector3(2, 3, 4)
        Attack.basic_attack_override_direction(Ref.player, target, 2, hit_position, Vector3.UP)
        check(target.health == health_before - 2, path + " existing Attack applies damage")
        check(target.target_impact_positions[0].is_equal_approx(target.model.to_local(hit_position)), path + " caller forwards actual hit position")
        var heart: Heart = load("res://main/items/held_item/held_heart_thrower/heart/heart.tscn").instantiate()
        heart.destroy_loot = null
        add_child(heart)
        heart.process_mode = Node.PROCESS_MODE_DISABLED
        heart.set_physics_process(false)
        heart.entity_owner = Ref.player
        heart.linear_velocity = Vector3(10, 0, 0)
        heart.previous_linear_velocity = heart.linear_velocity
        heart.global_position = Vector3(4, 3, 2)
        heart.deal_damage(target)
        check(target.health == health_before - 1, path + " existing heart caller heals")
        check(target.target_impact_positions[1].is_equal_approx(target.model.to_local(heart.global_position)), path + " heart forwards actual hit position")
        entities.append(target)
        projectiles.append(heart)
    var manager = Ref.coop_manager
    manager.reconnect_pending = true
    manager._set_reconnect_overlay_visible(true)
    manager.reconnect_overlay_subtitle.text = "Retrying in 1.0s (attempt 4)"
    var reason: String = "Different game version: expected 5.1.0"
    manager._finish_compatibility_failure(reason)
    check(not manager.reconnect_pending, "production rejection stops automatic retry")
    check(manager.reconnect_overlay.visible, "terminal rejection remains actionable")
    check(manager.reconnect_overlay_title.text == "CONNECTION REJECTED", "terminal title replaces reconnecting")
    check(manager.reconnect_overlay_subtitle.text == reason and manager.status_message == reason, "terminal reason replaces stale retry text")
    var button_names: Array[String] = []
    for button in manager.reconnect_overlay.find_children("*", "Button", true, false):
        if button.visible and not button.disabled:
            button_names.append(button.text)
    check(button_names.has("Reconnect") and button_names.has("Leave"), "terminal rejection keeps reconnect and leave actions")
    manager._set_reconnect_overlay_visible(false)
    # Damage/heal coroutines use pause-sensitive timers; let them release before freeing actors.
    var paused_before_cleanup: bool = get_tree().paused
    get_tree().paused = false
    await get_tree().create_timer(0.5, true).timeout
    get_tree().paused = paused_before_cleanup
    for entity in entities:
        check(entity.modulate.is_equal_approx(Color.WHITE), "damage/heal feedback completes before disposal: " + entity.get_script().resource_path + " color=" + str(entity.modulate))
    for projectile in projectiles:
        projectile.free()
    projectiles.clear()
    for entity in entities:
        if is_instance_valid(entity.modulate_tween):
            entity.modulate_tween.kill()
        entity.free()
    entities.clear()
    viewport.free()
    print("COMBAT_RESULT ", checks, " checks ", failures, " failures")
    return failures
