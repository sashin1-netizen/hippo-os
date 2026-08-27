extends Node

# Final code-side presentation pass for the sanctuary.
# This deliberately complements (rather than replaces) licensed production GLBs:
# it improves composition, readable lighting, fallback creature presence, foreground
# clearance and mobile-safe visual grounding. ProductionVisual rigs keep authority
# over their own animation when they are present.

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var rim_light: DirectionalLight3D
var companions: Array[Node3D] = []
var fallback_visuals: Array[Node3D] = []
var fallback_base_scales: Array[Vector3] = []
var contact_shadows: Array[MeshInstance3D] = []
var distant_birds: Array[Node3D] = []
var quality_timer := 0.0
var hud_timer := 0.0
var last_viewport_size := Vector2.ZERO
var bound := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 1250
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(420):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            camera = _find_camera(scene_root)
            var hippo := scene_root.find_child("BabyHippo", true, false) as Node3D
            var pig := scene_root.find_child("PorkyPig", true, false) as Node3D
            var dog := scene_root.find_child("BaoSharPei", true, false) as Node3D
            if camera != null and hippo != null and pig != null and dog != null:
                companions = [hippo, pig, dog]
                break
        await get_tree().process_frame

    if scene_root == null or camera == null or companions.size() != 3:
        push_warning("ProductionQualityPass could not bind to the complete sanctuary")
        return

    # Let the habitat/HUD builders finish before refining their output.
    for _frame in range(8):
        await get_tree().process_frame

    _bind_environment()
    _stage_default_camera()
    _clear_hero_corridor()
    _remove_foreground_obstructions()
    _collect_fallback_visuals()
    _build_contact_shadows()
    _collect_distant_birds()
    _apply_readable_lighting()
    _restrain_hud()
    bound = true
    set_process(true)

func _process(delta: float) -> void:
    if not bound or scene_root == null:
        return

    quality_timer -= delta
    hud_timer -= delta
    if quality_timer <= 0.0:
        quality_timer = 0.35
        _bind_environment()
        _apply_readable_lighting()
    if hud_timer <= 0.0:
        hud_timer = 0.5
        _restrain_hud()

    _animate_fallback_breathing()
    _update_contact_shadows()
    _animate_distant_birds(delta)

func _bind_environment() -> void:
    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    sun_light = _find_primary_sun(scene_root)
    fill_light = scene_root.find_child("PhoneReadabilityFill", true, false) as DirectionalLight3D
    rim_light = scene_root.find_child("QualityRimLight", true, false) as DirectionalLight3D
    if rim_light == null:
        rim_light = DirectionalLight3D.new()
        rim_light.name = "QualityRimLight"
        rim_light.rotation_degrees = Vector3(-32.0, -138.0, 0.0)
        rim_light.shadow_enabled = false
        scene_root.add_child(rim_light)

func _stage_default_camera() -> void:
    # The original scene already uses 9 m. The previous portrait director clamped it
    # closer, which made Mochi fill the frame. Preserve user orbit changes, but give
    # a new/default sanctuary a three-quarter wildlife-documentary angle.
    var yaw := float(scene_root.get("orbit_yaw"))
    if absf(yaw) < 0.05:
        scene_root.set("orbit_yaw", 0.58)
    var distance := float(scene_root.get("orbit_distance"))
    if distance < 8.8:
        scene_root.set("orbit_distance", 9.2)

func _clear_hero_corridor() -> void:
    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass == null or grass.multimesh == null:
        return
    var multi := grass.multimesh
    for i in range(multi.instance_count):
        var transform := multi.get_instance_transform(i)
        var p := transform.origin
        # Keep a low, natural foreground around the hero and a clean camera lane.
        var hero_zone := Vector2(p.x, p.z).length() < 3.4
        var camera_lane := absf(p.x) < 2.4 and p.z > 0.8
        if hero_zone or camera_lane:
            transform.basis = transform.basis.scaled(Vector3(0.86, 0.38, 0.86))
            transform.origin.y *= 0.42
            multi.set_instance_transform(i, transform)

func _remove_foreground_obstructions() -> void:
    var premium := scene_root.find_child("PremiumExperienceWorld", true, false) as Node3D
    if premium == null:
        return
    for child in premium.get_children():
        if not (child is GeometryInstance3D):
            continue
        var visual := child as GeometryInstance3D
        var p := (child as Node3D).position
        # The procedural enrichment crossbar sat directly between the camera and
        # Mochi. Keep enrichment outside the hero corridor until final authored art.
        if p.z > 3.15 and absf(p.x) < 1.35 and p.y < 1.9:
            visual.visible = false

func _collect_fallback_visuals() -> void:
    fallback_visuals.clear()
    fallback_base_scales.clear()
    if companions.is_empty():
        return

    # Porky and Bao already receive species-specific breathing, gait, tail and ear
    # motion from CompanionRoster. Only add this low-amplitude fallback breathing to
    # Mochi, whose current placeholder otherwise reads more rigidly. Production rigs
    # remain untouched.
    var hippo := companions[0]
    if hippo.find_child("ProductionVisual", false, false) != null:
        return
    var visual := hippo.get_node_or_null("Visual") as Node3D
    if visual == null:
        for child in hippo.get_children():
            if child is Node3D and not child is CollisionShape3D:
                visual = child as Node3D
                break
    if visual != null:
        fallback_visuals.append(visual)
        fallback_base_scales.append(visual.scale)

func _animate_fallback_breathing() -> void:
    if fallback_visuals.is_empty():
        return
    var now := float(Time.get_ticks_msec()) / 1000.0
    for i in range(fallback_visuals.size()):
        var visual := fallback_visuals[i]
        if not is_instance_valid(visual):
            continue
        var base := fallback_base_scales[i]
        var phase := now * 1.18 + float(i) * 1.7
        var breath := sin(phase)
        var settle := sin(phase * 0.47 + 0.8)
        visual.scale = Vector3(
            base.x * (1.0 + breath * 0.0025),
            base.y * (1.0 + breath * 0.0060),
            base.z * (1.0 + breath * 0.0035 + settle * 0.0015)
        )

func _build_contact_shadows() -> void:
    for shadow in contact_shadows:
        if is_instance_valid(shadow):
            shadow.queue_free()
    contact_shadows.clear()

    var root := scene_root.find_child("ProductionContactShadows", true, false) as Node3D
    if root == null:
        root = Node3D.new()
        root.name = "ProductionContactShadows"
        scene_root.add_child(root)

    var sizes: Array[Vector2] = [Vector2(2.35, 1.30), Vector2(1.55, 0.92), Vector2(1.48, 0.88)]
    for i in range(companions.size()):
        var shadow := MeshInstance3D.new()
        shadow.name = "CompanionContactShadow%d" % i
        var plane := PlaneMesh.new()
        plane.size = sizes[i]
        shadow.mesh = plane
        var material := StandardMaterial3D.new()
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = Color(0.015, 0.020, 0.014, 0.22)
        material.roughness = 1.0
        shadow.material_override = material
        shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(shadow)
        contact_shadows.append(shadow)
    _update_contact_shadows()

func _update_contact_shadows() -> void:
    for i in range(mini(companions.size(), contact_shadows.size())):
        var companion := companions[i]
        var shadow := contact_shadows[i]
        if not is_instance_valid(companion) or not is_instance_valid(shadow):
            continue
        shadow.global_position = Vector3(companion.global_position.x, 0.034, companion.global_position.z)
        shadow.rotation = Vector3.ZERO
        shadow.visible = companion.global_position.y < 1.55

func _collect_distant_birds() -> void:
    distant_birds.clear()
    var birds := scene_root.find_children("DistantBird", "Node3D", true, false)
    for bird in birds:
        if bird is Node3D:
            distant_birds.append(bird as Node3D)

func _animate_distant_birds(delta: float) -> void:
    if distant_birds.is_empty():
        return
    for i in range(distant_birds.size()):
        var bird := distant_birds[i]
        if not is_instance_valid(bird):
            continue
        bird.position.x += delta * (0.16 + float(i % 3) * 0.035)
        bird.position.y += sin(float(Time.get_ticks_msec()) * 0.0013 + float(i)) * delta * 0.018
        if bird.position.x > 6.8:
            bird.position.x = -6.8

func _apply_readable_lighting() -> void:
    if world_environment == null or world_environment.environment == null:
        return
    var daylight := _daylight_factor()
    var environment := world_environment.environment

    # Keep the sanctuary photographic rather than murky. Night remains blue/cool,
    # but animals, water and terrain retain enough midtone information on phone OLEDs.
    var night_ambient := Color(0.29, 0.36, 0.50)
    var day_ambient := Color(0.68, 0.76, 0.62)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = night_ambient.lerp(day_ambient, daylight)
    environment.ambient_light_energy = lerpf(1.16, 1.08, daylight)
    environment.fog_light_color = Color(0.34, 0.40, 0.48).lerp(Color(0.78, 0.82, 0.70), daylight)
    environment.fog_light_energy = lerpf(0.62, 0.86, daylight)
    environment.fog_density = lerpf(0.0075, 0.0048, daylight)
    environment.fog_sky_affect = lerpf(0.22, 0.16, daylight)

    if is_instance_valid(sun_light):
        sun_light.light_color = Color(0.62, 0.70, 0.92).lerp(Color(1.0, 0.92, 0.78), daylight)
        sun_light.light_energy = lerpf(0.62, 1.58, daylight)
        sun_light.shadow_enabled = true
    if is_instance_valid(fill_light):
        fill_light.light_color = Color(0.52, 0.63, 0.92).lerp(Color(0.88, 0.94, 0.86), daylight)
        fill_light.light_energy = lerpf(0.48, 0.30, daylight)
    if is_instance_valid(rim_light):
        rim_light.light_color = Color(0.43, 0.55, 0.86).lerp(Color(1.0, 0.78, 0.50), daylight)
        rim_light.light_energy = lerpf(0.24, 0.17, daylight)

func _restrain_hud() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null or not bool(hud.get("built")):
        return
    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size != last_viewport_size:
        last_viewport_size = viewport_size

    # Reduce the prototype-dashboard feeling without removing any functionality.
    var companion_panel := hud.get("companion_panel") as Control
    var status_panel := hud.get("status_panel") as Control
    var minimap_panel := hud.get("minimap_panel") as Control
    var orbit_panel := hud.get("orbit_panel") as Control
    var bottom_panel := hud.get("bottom_panel") as Control
    if companion_panel != null:
        companion_panel.modulate.a = 0.88
    if status_panel != null:
        status_panel.modulate.a = 0.84
    if minimap_panel != null:
        minimap_panel.modulate.a = 0.86
    if orbit_panel != null:
        orbit_panel.modulate.a = 0.72
    if bottom_panel != null:
        bottom_panel.modulate.a = 0.86

func _daylight_factor() -> float:
    var mode := "auto"
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) == TYPE_DICTIONARY:
        mode = str((settings_variant as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)

func _find_primary_sun(root: Node) -> DirectionalLight3D:
    var lights := root.find_children("*", "DirectionalLight3D", true, false)
    for node in lights:
        if node is DirectionalLight3D and node.name != "PhoneReadabilityFill" and node.name != "QualityRimLight":
            return node as DirectionalLight3D
    return null

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
