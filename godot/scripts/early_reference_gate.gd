extends Node

# Final mobile/open-world guard for Hippo OS. This layer does not replace the simulation;
# it protects the first-frame composition, cleans renderer-specific prototype clutter,
# adds two-finger zoom, expands roaming after the opening hold, and applies a lightweight
# adaptive-quality fallback so the sanctuary stays usable on Android-class hardware.

const HERO_HOME := Vector3(1.15, 0.80, 1.55)
const PIG_HOME := Vector3(-3.90, 0.72, 3.55)
const DOG_HOME := Vector3(-4.15, 0.75, -2.65)
const HOLD_SECONDS := 30.0
const PINCH_SCALE := 0.012

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var hold_until := 0.0
var visual_timer := 0.0
var roam_timer := 0.0
var style_timer := 0.0
var is_bound := false
var touches: Dictionary = {}
var previous_pinch_distance := -1.0
var low_fps_seconds := 0.0
var recovery_seconds := 0.0
var reduced_detail := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 10000
    set_process(false)
    call_deferred("_bind")

func _bind() -> void:
    for _attempt in range(420):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            camera = _find_camera(scene_root)
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            if camera != null and hippo != null and pig != null and dog != null:
                break
        await get_tree().process_frame

    if scene_root == null or camera == null or hippo == null or pig == null or dog == null:
        push_warning("EarlyReferenceGate could not bind")
        return

    hold_until = Time.get_ticks_msec() / 1000.0 + HOLD_SECONDS
    _stage()
    _enforce_mobile_visuals()
    _style_animals()
    is_bound = true
    set_process(true)
    print("HippoOS mobile open-world guard active")

func _process(delta: float) -> void:
    if not is_bound:
        return

    var holding := Time.get_ticks_msec() / 1000.0 < hold_until
    if holding:
        hippo.velocity = Vector3.ZERO
        pig.velocity = Vector3.ZERO
        dog.velocity = Vector3.ZERO
        hippo.position = hippo.position.lerp(HERO_HOME, clampf(delta * 8.0, 0.0, 1.0))
        pig.position = pig.position.lerp(PIG_HOME, clampf(delta * 6.0, 0.0, 1.0))
        dog.position = dog.position.lerp(DOG_HOME, clampf(delta * 6.0, 0.0, 1.0))
        scene_root.set("current_action", "idle")
        scene_root.set("action_timer", 1.5)
        scene_root.set("orbit_yaw", 1.53)
        scene_root.set("orbit_pitch", -0.045)
        scene_root.set("orbit_distance", 9.0)
        camera.fov = lerpf(camera.fov, 45.0, clampf(delta * 5.0, 0.0, 1.0))
        _face(hippo, camera.global_position, clampf(delta * 12.0, 0.0, 1.0))
        _face(pig, hippo.global_position, clampf(delta * 7.0, 0.0, 1.0))
        _face(dog, hippo.global_position, clampf(delta * 7.0, 0.0, 1.0))

    visual_timer -= delta
    if visual_timer <= 0.0:
        visual_timer = 0.18
        _enforce_mobile_visuals()

    style_timer -= delta
    if style_timer <= 0.0:
        style_timer = 0.75
        _style_animals()

    roam_timer -= delta
    if roam_timer <= 0.0:
        roam_timer = 2.0
        _expand_roaming(holding)

    _adaptive_quality(delta, holding)

func _input(event: InputEvent) -> void:
    if not is_bound or scene_root == null:
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
        scene_root.set("orbit_distance", clampf(current_distance - delta_distance * PINCH_SCALE, 5.8, 12.0))
    previous_pinch_distance = distance

func _stage() -> void:
    hippo.position = HERO_HOME
    pig.position = PIG_HOME
    dog.position = DOG_HOME
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    scene_root.set("current_action", "idle")
    scene_root.set("action_timer", HOLD_SECONDS)
    scene_root.set("orbit_yaw", 1.53)
    scene_root.set("orbit_pitch", -0.045)
    scene_root.set("orbit_distance", 9.0)
    _face(hippo, camera.global_position, 1.0)
    _face(pig, hippo.global_position, 1.0)
    _face(dog, hippo.global_position, 1.0)

func _enforce_mobile_visuals() -> void:
    var holding := Time.get_ticks_msec() / 1000.0 < hold_until
    _fix_reference_daylight(holding)
    _fix_header()
    _hide_bottom_chevron()
    _clean_world_recursive(scene_root)
    _style_water()

    var old_polish := scene_root.find_child("SanctuaryVisualPolish", true, false) as Node3D
    if old_polish != null:
        old_polish.visible = false

    for root_name in ["PremiumExperienceWorld", "GrasslandsProductionLayer", "OpenWorldAuthority"]:
        var root := scene_root.find_child(root_name, true, false) as Node3D
        if root != null:
            root.visible = true

    for node_name in ["SanctuaryGroundFinish", "ForegroundWatercourse", "WetBank", "DryAnimalTrail"]:
        var visual := scene_root.find_child(node_name, true, false) as GeometryInstance3D
        if visual != null:
            visual.visible = true

func _fix_reference_daylight(holding: bool) -> void:
    if not holding:
        return
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null or world_environment.environment == null:
        return

    var env := world_environment.environment
    var sky_color := Color(0.24, 0.61, 0.91)
    RenderingServer.set_default_clear_color(sky_color)
    env.background_mode = Environment.BG_COLOR
    env.background_color = sky_color
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.82, 0.84, 0.75)
    env.ambient_light_energy = 1.10
    env.fog_enabled = true
    env.fog_light_color = Color(0.82, 0.87, 0.83)
    env.fog_light_energy = 0.50
    env.fog_density = 0.0022
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.12
    env.adjustment_contrast = 1.02
    env.adjustment_saturation = 0.98

func _clean_world_recursive(node: Node) -> void:
    var software_renderer := "x86" in Engine.get_architecture_name().to_lower()
    for child in node.get_children():
        if child == hippo or child == pig or child == dog:
            continue

        if child is MultiMeshInstance3D:
            var multi := child as MultiMeshInstance3D
            if software_renderer:
                multi.visible = false
        elif child is MeshInstance3D:
            var visual := child as MeshInstance3D
            var lower := String(visual.name).to_lower()
            var distance_to_camera := visual.global_position.distance_to(camera.global_position)

            if software_renderer and ("grass" in lower or "reed" in lower or "shrub" in lower or "scrub" in lower or "foliage" in lower or "canopy" in lower or "branch" in lower or "trunk" in lower or "tree" in lower):
                visual.visible = false
            elif visual.mesh is CylinderMesh:
                var cylinder := visual.mesh as CylinderMesh
                var vertical_extent := cylinder.height * absf(visual.global_transform.basis.get_scale().y)
                var radius := maxf(cylinder.top_radius, cylinder.bottom_radius)
                var gs := visual.global_transform.basis.get_scale().abs()
                var horizontal_extent := radius * maxf(gs.x, gs.z) * 2.0
                if distance_to_camera < 10.5 and vertical_extent > 0.72 and horizontal_extent < 0.58:
                    visual.visible = false
            elif software_renderer and visual.mesh is QuadMesh:
                visual.visible = false
            elif software_renderer and visual.mesh is SphereMesh:
                var local_size := visual.get_aabb().size
                var scale_value := visual.global_transform.basis.get_scale().abs()
                var world_size := Vector3(local_size.x * scale_value.x, local_size.y * scale_value.y, local_size.z * scale_value.z)
                var max_dimension := maxf(world_size.x, maxf(world_size.y, world_size.z))
                var terrain := "ridge" in lower or "escarpment" in lower or "rock" in lower or "stone" in lower
                if not terrain and max_dimension < 0.42 and visual.global_position.y > 0.18 and visual.global_position.distance_to(hippo.global_position) < 8.0:
                    visual.visible = false

        _clean_world_recursive(child)

func _style_water() -> void:
    var stream := scene_root.find_child("ForegroundWatercourse", true, false) as MeshInstance3D
    if stream == null:
        return
    var material := stream.material_override as StandardMaterial3D
    if material == null:
        material = StandardMaterial3D.new()
        stream.material_override = material
    material.albedo_color = Color(0.105, 0.215, 0.185)
    material.roughness = 0.28
    material.metallic = 0.04

func _style_animals() -> void:
    _style_animal(hippo, "hippo")
    _style_animal(pig, "pig")
    _style_animal(dog, "dog")

func _style_animal(body: Node3D, species: String) -> void:
    if body == null or body.find_child("ProductionVisual", true, false) != null:
        return
    _style_animal_recursive(body, species)

func _style_animal_recursive(node: Node, species: String) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var visual := child as MeshInstance3D
            var lower := String(visual.name).to_lower()
            if "eye" in lower or "nostril" in lower or "pupil" in lower:
                continue
            var material := visual.material_override as StandardMaterial3D
            if material != null:
                if species == "hippo":
                    material.albedo_color = Color(0.31, 0.245, 0.235) if ("snout" in lower or "belly" in lower or "chin" in lower) else Color(0.235, 0.205, 0.205)
                    material.roughness = 0.48
                    material.metallic = 0.015
                elif species == "pig":
                    material.albedo_color = Color(0.245, 0.225, 0.195) if "snout" in lower else Color(0.165, 0.155, 0.145)
                    material.roughness = 0.62
                    material.metallic = 0.0
                else:
                    material.albedo_color = Color(0.47, 0.285, 0.135) if ("muzzle" in lower or "snout" in lower) else Color(0.405, 0.225, 0.105)
                    material.roughness = 0.58
                    material.metallic = 0.0
        _style_animal_recursive(child, species)

func _fix_header() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null or not bool(hud.get("built")):
        return
    var brand := hud.get("brand_label") as Label
    var subtitle := hud.get("brand_subtitle") as Label
    if brand != null:
        brand.text = "HIPPO OS"
        brand.add_theme_font_size_override("font_size", 22)
        var viewport := get_viewport().get_visible_rect().size
        if viewport.y >= viewport.x:
            brand.position.x = viewport.x * 0.5 - 78.0
            brand.size.x = 156.0
    if subtitle != null:
        subtitle.text = "Sanctuary"
        subtitle.add_theme_font_size_override("font_size", 13)
        var viewport2 := get_viewport().get_visible_rect().size
        if viewport2.y >= viewport2.x:
            subtitle.position.x = viewport2.x * 0.5 - 78.0
            subtitle.size.x = 156.0

func _hide_bottom_chevron() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud != null:
        var direct_chevron := hud.get("bottom_chevron") as Control
        if direct_chevron != null:
            direct_chevron.visible = false
    _hide_center_chevrons_recursive(get_tree().root)

func _hide_center_chevrons_recursive(node: Node) -> void:
    var viewport := get_viewport().get_visible_rect().size
    for child in node.get_children():
        if child is Button:
            var button := child as Button
            var text := button.text.strip_edges()
            if text == "^" or text == "⌃" or text == "▲":
                var rect := button.get_global_rect()
                var center := rect.position + rect.size * 0.5
                if center.y > viewport.y * 0.70 and absf(center.x - viewport.x * 0.5) < viewport.x * 0.18:
                    button.visible = false
        _hide_center_chevrons_recursive(child)

func _expand_roaming(holding: bool) -> void:
    if holding:
        return
    var action := String(scene_root.get("current_action"))
    if action != "wander" and action != "explore" and action != "play":
        return
    var target_value: Variant = scene_root.get("wander_target")
    if typeof(target_value) != TYPE_VECTOR3:
        return
    var target := target_value as Vector3
    if target.distance_to(hippo.global_position) > 3.5:
        return
    var angle := randf_range(0.0, TAU)
    var radius := randf_range(5.0, 9.0)
    scene_root.set("wander_target", Vector3(cos(angle) * radius, hippo.position.y, sin(angle) * radius))

func _adaptive_quality(delta: float, holding: bool) -> void:
    if holding:
        low_fps_seconds = 0.0
        recovery_seconds = 0.0
        return
    var fps := float(Performance.get_monitor(Performance.TIME_FPS))
    if fps <= 0.0:
        return
    if fps < 27.0:
        low_fps_seconds += delta
        recovery_seconds = 0.0
    elif fps > 44.0:
        recovery_seconds += delta
        low_fps_seconds = maxf(0.0, low_fps_seconds - delta * 0.5)
    else:
        low_fps_seconds = maxf(0.0, low_fps_seconds - delta * 0.25)
        recovery_seconds = maxf(0.0, recovery_seconds - delta * 0.25)

    if low_fps_seconds >= 4.0 and not reduced_detail:
        reduced_detail = true
        _set_optional_detail(false)
    elif recovery_seconds >= 6.0 and reduced_detail:
        reduced_detail = false
        _set_optional_detail(true)

func _set_optional_detail(enabled: bool) -> void:
    for name in ["OpenWorldScrub", "GrassField", "AcaciaCanopy", "SignatureAcaciaCanopy"]:
        var matches := scene_root.find_children(name, "", true, false)
        for match in matches:
            if match is Node3D:
                (match as Node3D).visible = enabled and not ("x86" in Engine.get_architecture_name().to_lower())

func _face(body: CharacterBody3D, target: Vector3, weight: float) -> void:
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
