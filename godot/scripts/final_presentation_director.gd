extends Node

# Single final presentation authority for Hippo OS.
# Gameplay, saves, audio, companion AI, HUD, camera service and production asset loading
# remain separate authoritative systems. This director only owns final scene composition,
# lighting, visibility, launch staging and visual-proof readiness.

const HERO_HOME := Vector3(1.15, 0.80, 1.55)
const PIG_HOME := Vector3(-3.65, 0.72, 3.20)
const DOG_HOME := Vector3(-3.85, 0.75, -2.65)
const OPENING_HOLD_SECONDS := 24.0
const PINCH_SCALE := 0.012
const PRESENTATION_DISTANCE := 7.85
const PRESENTATION_PITCH := -0.085
const READINESS_DEBUG_SECONDS := 5.0

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var compatibility_world: Node3D
var initialized := false
var ready_announced := false
var hold_until := 0.0
var maintenance_timer := 0.0
var readiness_debug_timer := 0.0
var touches: Dictionary = {}
var previous_pinch_distance := -1.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 40000
    set_process(false)
    call_deferred("_bind")

func _bind() -> void:
    for _attempt in range(900):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            camera = _find_camera(scene_root)
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            compatibility_world = scene_root.find_child("CompatibilityOpenWorld", true, false) as Node3D
            var compatibility_ready := not _is_compatibility_renderer() or compatibility_world != null
            if camera != null and hippo != null and pig != null and dog != null and compatibility_ready:
                break
        await get_tree().process_frame

    if scene_root == null or camera == null or hippo == null or pig == null or dog == null:
        push_warning("FinalPresentationDirector could not bind to sanctuary")
        return
    if _is_compatibility_renderer() and compatibility_world == null:
        push_warning("FinalPresentationDirector could not bind to CompatibilityOpenWorld")
        return

    # Let one-time builders and asset loading settle. Builders are quarantined only after
    # their useful world root exists, so consolidation never races the build itself.
    for _frame in range(8):
        await get_tree().process_frame

    camera.current = true
    camera.cull_mask = 0xFFFFF
    camera.near = 0.05
    camera.far = 300.0

    scene_root.set_meta("presentation_min_distance_portrait", 7.4)
    scene_root.set_meta("presentation_max_distance_portrait", 10.8)
    scene_root.set_meta("presentation_target_fov_portrait", 46.0)

    hold_until = Time.get_ticks_msec() / 1000.0 + OPENING_HOLD_SECONDS
    _apply_presentation(1.0)
    initialized = true
    readiness_debug_timer = 0.0
    set_process(true)
    print("HippoOS final presentation authority active")

func _process(delta: float) -> void:
    if not initialized:
        return

    maintenance_timer -= delta
    if maintenance_timer <= 0.0:
        maintenance_timer = 0.12
        _apply_presentation(delta)

    if ready_announced:
        return

    var animals_ready := _authoritative_animals_ready()
    var world_ready := _authoritative_world_ready()
    var camera_ready := _camera_frames_hero()
    if animals_ready and world_ready and camera_ready:
        ready_announced = true
        _log_visual_diagnostics("showcase-ready")
        print("HippoOS community showcase ready")
        return

    readiness_debug_timer -= delta
    if readiness_debug_timer <= 0.0:
        readiness_debug_timer = READINESS_DEBUG_SECONDS
        _log_visual_diagnostics("waiting")

func _input(event: InputEvent) -> void:
    if not initialized or scene_root == null:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            touches[touch.index] = touch.position
        else:
            touches.erase(touch.index)
        _apply_pinch_zoom()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        touches[drag.index] = drag.position
        if touches.size() >= 2:
            _apply_pinch_zoom()
            get_viewport().set_input_as_handled()

func _apply_pinch_zoom() -> void:
    var keys := touches.keys()
    if keys.size() < 2:
        previous_pinch_distance = -1.0
        return
    var first: Vector2 = touches[keys[0]]
    var second: Vector2 = touches[keys[1]]
    var distance := first.distance_to(second)
    if previous_pinch_distance > 0.0:
        var delta_distance := distance - previous_pinch_distance
        var current_distance := float(scene_root.get("orbit_distance"))
        scene_root.set("orbit_distance", clampf(current_distance - delta_distance * PINCH_SCALE, 7.2, 12.0))
    previous_pinch_distance = distance

func _apply_presentation(delta: float) -> void:
    _refresh_builder_worlds()
    _quarantine_legacy_builders()
    _enforce_world_visibility()
    _enforce_daylight()
    _maintain_opening(delta)
    _fix_hud()
    _hide_prototype_focus_ring()

func _refresh_builder_worlds() -> void:
    if compatibility_world == null or not is_instance_valid(compatibility_world):
        compatibility_world = scene_root.find_child("CompatibilityOpenWorld", true, false) as Node3D

func _quarantine_legacy_builders() -> void:
    # OpenWorldDirector and CompatibilityMobileFallback are retained only because they
    # construct useful world roots. Their recurring presentation loops stop once those
    # roots exist. FinalPresentationDirector is then the sole visual authority.
    var open_world_builder := get_node_or_null("/root/OpenWorldDirector")
    var open_world_root := scene_root.find_child("OpenWorldAuthority", true, false) as Node3D
    if open_world_builder != null and open_world_root != null:
        open_world_builder.set_process(false)
        open_world_builder.set_physics_process(false)

    var compatibility_builder := get_node_or_null("/root/CompatibilityMobileFallback")
    if compatibility_builder != null and compatibility_world != null:
        compatibility_builder.set_process(false)
        compatibility_builder.set_physics_process(false)

func _maintain_opening(delta: float) -> void:
    var holding := Time.get_ticks_msec() / 1000.0 < hold_until
    if not holding:
        return

    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    hippo.position = hippo.position.lerp(HERO_HOME, clampf(delta * 9.0, 0.0, 1.0))
    pig.position = pig.position.lerp(PIG_HOME, clampf(delta * 7.0, 0.0, 1.0))
    dog.position = dog.position.lerp(DOG_HOME, clampf(delta * 7.0, 0.0, 1.0))

    scene_root.set("current_action", "idle")
    scene_root.set("action_timer", 1.5)
    scene_root.set("orbit_yaw", 1.53)
    scene_root.set("orbit_pitch", PRESENTATION_PITCH)
    scene_root.set("orbit_distance", PRESENTATION_DISTANCE)

    _face(hippo, camera.global_position, clampf(delta * 12.0, 0.0, 1.0))
    _face(pig, hippo.global_position, clampf(delta * 8.0, 0.0, 1.0))
    _face(dog, hippo.global_position, clampf(delta * 8.0, 0.0, 1.0))

func _enforce_world_visibility() -> void:
    if _is_compatibility_renderer():
        if compatibility_world != null:
            compatibility_world.visible = true
            _retire_compatibility_prototype_geometry()
            _show_geometry_recursive(compatibility_world)
            _show_authoritative_animal_visual(hippo, true)
            _show_authoritative_animal_visual(pig, false)
            _show_authoritative_animal_visual(dog, false)
            _trim_compatibility_clutter()
        return

    # Mobile/Vulkan: keep authored production world builders, but retire known prototype
    # visual roots. No broad recursive hiding is used on production hardware.
    for root_name in ["SanctuaryVisualPolish", "PremiumExperienceWorld"]:
        var obsolete := scene_root.find_child(root_name, true, false) as Node3D
        if obsolete != null:
            obsolete.visible = false

    for root_name in ["GrasslandsProductionLayer", "OpenWorldAuthority"]:
        var useful := scene_root.find_child(root_name, true, false) as Node3D
        if useful != null:
            useful.visible = true

    for node_name in ["SanctuaryGroundFinish", "ForegroundWatercourse", "WetBank", "DryAnimalTrail"]:
        var visual := scene_root.find_child(node_name, true, false) as GeometryInstance3D
        if visual != null:
            visual.visible = true

func _retire_compatibility_prototype_geometry() -> void:
    # Compatibility used to recursively hide every non-authoritative mesh in the scene.
    # That was too broad and could leave a valid world/animal hierarchy with hidden
    # ancestors. Retire only known prototype/direct roots and leave simulation parents,
    # authored animal visuals and CompatibilityOpenWorld untouched.
    for root_name in ["SanctuaryVisualPolish", "PremiumExperienceWorld", "GrasslandsProductionLayer", "OpenWorldAuthority"]:
        var obsolete := scene_root.find_child(root_name, true, false) as Node3D
        if obsolete != null and obsolete != compatibility_world:
            obsolete.visible = false

    for child in scene_root.get_children():
        if child == compatibility_world or child == hippo:
            continue
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).visible = false
        elif child is StaticBody3D:
            for geometry in child.find_children("*", "GeometryInstance3D", true, false):
                if geometry is GeometryInstance3D:
                    (geometry as GeometryInstance3D).visible = false

func _show_authoritative_animal_visual(body: Node3D, allow_gobkit: bool) -> void:
    if body == null:
        return
    body.visible = true
    var visual := _authoritative_visual_root(body, allow_gobkit)
    if visual != null:
        visual.visible = true
        _show_geometry_recursive(visual)

func _show_geometry_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is Node3D:
            (child as Node3D).visible = true
        _show_geometry_recursive(child)

func _trim_compatibility_clutter() -> void:
    if compatibility_world == null:
        return
    for node in compatibility_world.find_children("CommunityReed*", "Node3D", true, false):
        if node is Node3D:
            (node as Node3D).visible = false

func _enforce_daylight() -> void:
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null:
        return
    if world_environment.environment == null:
        world_environment.environment = Environment.new()

    var env := world_environment.environment
    var compatibility := _is_compatibility_renderer()
    var sky_top := Color(0.12, 0.48, 0.82)
    var sky_horizon := Color(0.68, 0.85, 0.95)
    RenderingServer.set_default_clear_color(sky_horizon)

    var sky := env.sky
    var sky_material: ProceduralSkyMaterial
    if sky == null or not (sky.sky_material is ProceduralSkyMaterial):
        sky = Sky.new()
        sky.radiance_size = Sky.RADIANCE_SIZE_128
        sky_material = ProceduralSkyMaterial.new()
        sky.sky_material = sky_material
        env.sky = sky
    else:
        sky_material = sky.sky_material as ProceduralSkyMaterial
    sky_material.sky_top_color = sky_top
    sky_material.sky_horizon_color = sky_horizon
    sky_material.ground_horizon_color = Color(0.50, 0.58, 0.32)
    sky_material.ground_bottom_color = Color(0.08, 0.10, 0.06)
    sky_material.sun_angle_max = 18.0
    sky_material.sun_curve = 0.05
    sky_material.use_debanding = true
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    if compatibility:
        env.ambient_light_color = Color(0.78, 0.84, 0.76)

    env.ambient_light_energy = 1.08
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.80, 0.87, 0.85)
    env.fog_light_energy = 0.44
    env.fog_density = 0.0018 if compatibility else 0.0024
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.08
    env.adjustment_contrast = 1.025
    env.adjustment_saturation = 1.02

func _fix_hud() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null or not bool(hud.get("built")):
        return

    var brand := hud.get("brand_label") as Label
    var subtitle := hud.get("brand_subtitle") as Label
    var weather := hud.get("weather_label") as Label
    var chevron := hud.get("bottom_chevron") as Control

    if brand != null:
        brand.text = "HIPPO OS"
        brand.add_theme_font_size_override("font_size", 22)
    if subtitle != null:
        subtitle.text = "Sanctuary"
        subtitle.add_theme_font_size_override("font_size", 13)
    if weather != null:
        weather.text = "CLEAR DAY"
    if chevron != null:
        chevron.visible = false

func _hide_prototype_focus_ring() -> void:
    var ring := scene_root.find_child("SelectedCompanionFocus", true, false) as GeometryInstance3D
    if ring != null:
        ring.visible = false

func _authoritative_animals_ready() -> bool:
    return _animal_visual_ready(hippo, true) and _animal_visual_ready(pig, false) and _animal_visual_ready(dog, false)

func _authoritative_visual_root(body: Node3D, allow_gobkit: bool) -> Node3D:
    if body == null:
        return null
    var production := body.find_child("ProductionVisual", true, false) as Node3D
    if production != null:
        return production
    if allow_gobkit:
        var gobkit := body.find_child("GobkitCC0Visual", true, false) as Node3D
        if gobkit != null:
            return gobkit
    return body.find_child("CommunityRiggedVisual", true, false) as Node3D

func _animal_visual_ready(body: Node3D, allow_gobkit: bool) -> bool:
    var visual := _authoritative_visual_root(body, allow_gobkit)
    return visual != null and _node3d_visible_in_tree(visual) and _visible_mesh_count(visual) > 0

func _authoritative_world_ready() -> bool:
    if _is_compatibility_renderer():
        return compatibility_world != null and is_instance_valid(compatibility_world) and _node3d_visible_in_tree(compatibility_world) and _visible_mesh_count(compatibility_world) >= 3
    var grasslands := scene_root.find_child("GrasslandsProductionLayer", true, false) as Node3D
    var open_world := scene_root.find_child("OpenWorldAuthority", true, false) as Node3D
    var grasslands_ready := grasslands != null and _node3d_visible_in_tree(grasslands) and _visible_mesh_count(grasslands) > 0
    var open_world_ready := open_world != null and _node3d_visible_in_tree(open_world) and _visible_mesh_count(open_world) > 0
    return grasslands_ready or open_world_ready

func _camera_frames_hero() -> bool:
    if camera == null or hippo == null or not camera.current:
        return false
    var to_hero := hippo.global_position - camera.global_position
    var distance := to_hero.length()
    if distance < 4.0 or distance > 16.0:
        return false
    var forward := -camera.global_transform.basis.z.normalized()
    return forward.dot(to_hero.normalized()) >= 0.72

func _visible_mesh_count(root: Node3D) -> int:
    if root == null:
        return 0
    var count := 0
    if root is GeometryInstance3D and root.visible and _node3d_visible_in_tree(root):
        count += 1
    for node in root.find_children("*", "GeometryInstance3D", true, false):
        if node is GeometryInstance3D:
            var geometry := node as GeometryInstance3D
            if geometry.visible and _node3d_visible_in_tree(geometry):
                count += 1
    return count

func _node3d_visible_in_tree(node: Node3D) -> bool:
    if node == null:
        return false
    var cursor: Node = node
    while cursor != null:
        if cursor is Node3D and not (cursor as Node3D).visible:
            return false
        if cursor == scene_root:
            break
        cursor = cursor.get_parent()
    return true

func _log_visual_diagnostics(stage: String) -> void:
    if scene_root == null:
        return
    var renderer := String(RenderingServer.get_current_rendering_method())
    var world_meshes := _visible_mesh_count(compatibility_world) if compatibility_world != null else 0
    var hippo_visual := _authoritative_visual_root(hippo, true)
    var pig_visual := _authoritative_visual_root(pig, false)
    var dog_visual := _authoritative_visual_root(dog, false)
    var camera_position := camera.global_position if camera != null else Vector3.ZERO
    var camera_forward := -camera.global_transform.basis.z.normalized() if camera != null else Vector3.ZERO
    print("HippoOS presentation diag [%s]: renderer=%s camera_current=%s camera=%s forward=%s hippo=%s world_visible=%s world_meshes=%d hippo_meshes=%d pig_meshes=%d dog_meshes=%d camera_frames_hero=%s" % [
        stage,
        renderer,
        str(camera != null and camera.current),
        str(camera_position),
        str(camera_forward),
        str(hippo.global_position if hippo != null else Vector3.ZERO),
        str(compatibility_world != null and _node3d_visible_in_tree(compatibility_world)),
        world_meshes,
        _visible_mesh_count(hippo_visual),
        _visible_mesh_count(pig_visual),
        _visible_mesh_count(dog_visual),
        str(_camera_frames_hero())
    ])

func _is_compatibility_renderer() -> bool:
    var method := String(RenderingServer.get_current_rendering_method()).to_lower()
    return "compatibility" in method or "gl_compatibility" in method

func _face(body: CharacterBody3D, target: Vector3, weight: float) -> void:
    if body == null:
        return
    var direction := target - body.global_position
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        return
    direction = direction.normalized()
    var target_yaw := atan2(-direction.z, direction.x)
    body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(weight, 0.0, 1.0))
    body.rotation.x = 0.0
    body.rotation.z = 0.0

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
