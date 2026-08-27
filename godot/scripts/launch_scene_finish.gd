extends Node

# Final opening-shot director for the procedural fallback build.
# It keeps gameplay systems authoritative while making the first sanctuary frame read
# like a composed wildlife scene: clean foreground, restrained water, clear hero bank,
# distant supporting companions and a daylight-safe environment.

const HIPPO_HOME := Vector3(0.0, 0.80, 0.20)
const PIG_HOME := Vector3(-2.00, 0.72, -5.00)
const DOG_HOME := Vector3(-5.00, 0.75, -1.20)

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var timer := 0.0
var opening_applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 3100
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(520):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            camera = _find_camera(scene_root)
            if camera != null and scene_root.find_child("BabyHippo", true, false) != null:
                break
        await get_tree().process_frame

    if scene_root == null or roster == null or camera == null:
        push_warning("LaunchSceneFinish could not bind to sanctuary")
        return

    for _frame in range(42):
        await get_tree().process_frame

    _apply_opening_shot()
    _build_hero_bank()
    _clear_foreground_clutter()
    _stage_companions()
    _apply_environment_finish()
    opening_applied = true
    set_process(true)

func _process(delta: float) -> void:
    if not opening_applied or scene_root == null:
        return
    timer -= delta
    if timer <= 0.0:
        timer = 0.70
        _clear_foreground_clutter()
        _maintain_companion_depth()
        _apply_environment_finish()

func _apply_opening_shot() -> void:
    # Mochi is authored facing local +X. Move the camera closer to that forward axis
    # so the face leads the frame and the body recedes behind it instead of hiding it.
    scene_root.set("orbit_yaw", 1.15)
    scene_root.set("orbit_pitch", -0.020)
    scene_root.set("orbit_distance", 11.8)
    if camera != null:
        camera.fov = 50.0

func _build_hero_bank() -> void:
    var existing := scene_root.find_child("HeroMudBank", true, false)
    if existing != null:
        return
    var bank := MeshInstance3D.new()
    bank.name = "HeroMudBank"
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(6.6, 5.0)
    mesh.subdivide_width = 8
    mesh.subdivide_depth = 6
    bank.mesh = mesh
    bank.position = Vector3(-0.35, 0.052, 0.55)
    bank.rotation_degrees.y = -6.0
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.205, 0.175, 0.105)
    material.roughness = 0.96
    material.metallic = 0.0
    bank.material_override = material
    bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scene_root.add_child(bank)

func _clear_foreground_clutter() -> void:
    var hippo := scene_root.find_child("BabyHippo", true, false) as Node3D
    if hippo == null:
        return

    # Retire overlapping legacy decoration worlds from the production opening. The
    # grasslands layer plus the base sanctuary remain, so gameplay zones are untouched.
    for root_name in ["PremiumExperienceWorld", "SanctuaryVisualPolish"]:
        var legacy_root := scene_root.find_child(root_name, true, false) as Node3D
        if legacy_root != null:
            legacy_root.visible = false

    # Remove the original ring of tall prototype stems. The feeding bowl is shorter
    # than this threshold and remains interactive.
    for child in scene_root.get_children():
        if not (child is MeshInstance3D):
            continue
        var direct_visual := child as MeshInstance3D
        if direct_visual.mesh is CylinderMesh:
            var direct_cylinder := direct_visual.mesh as CylinderMesh
            if direct_cylinder.height > 0.40:
                direct_visual.visible = false

    for pad_node in scene_root.find_children("LilyPad*", "MeshInstance3D", true, false):
        if pad_node is MeshInstance3D:
            (pad_node as MeshInstance3D).visible = false

    var water := scene_root.find_child("ForegroundWatercourse", true, false) as MeshInstance3D
    if water != null:
        water.scale = Vector3(0.42, 1.0, 0.17)
        water.position = Vector3(3.05, 0.038, 4.15)

    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass != null and grass.multimesh != null and not bool(grass.get_meta("launch_corridor_cleared_v2", false)):
        var multi := grass.multimesh
        for i in range(multi.instance_count):
            var transform := multi.get_instance_transform(i)
            var p := transform.origin
            var hero_distance := Vector2(p.x - HIPPO_HOME.x, p.z - HIPPO_HOME.z).length()
            if hero_distance < 4.45:
                transform.basis = transform.basis.scaled(Vector3(0.025, 0.025, 0.025))
            elif hero_distance < 5.75:
                transform.basis = transform.basis.scaled(Vector3(0.46, 0.40, 0.46))
            multi.set_instance_transform(i, transform)
        grass.set_meta("launch_corridor_cleared_v2", true)

    # Clear every tall procedural tree/reed/canopy near the hero, not only one layer.
    # This removes the central trunk that survived the earlier camera-cone pass.
    for world_name in ["GrasslandsProductionLayer", "PremiumExperienceWorld", "SanctuaryVisualPolish"]:
        var world := scene_root.find_child(world_name, true, false) as Node3D
        if world == null:
            continue
        for child in world.get_children():
            if not (child is MeshInstance3D):
                continue
            var visual := child as MeshInstance3D
            if visual.name == "DistantRidge" or visual.name == "DistantBird":
                continue
            var p2 := Vector2(visual.global_position.x - HIPPO_HOME.x, visual.global_position.z - HIPPO_HOME.z)
            if p2.length() > 8.0:
                continue
            if visual.mesh is CylinderMesh:
                var cylinder := visual.mesh as CylinderMesh
                if cylinder.height > 0.34:
                    visual.visible = false
            elif visual.mesh is SphereMesh and visual.global_position.y > 0.48:
                visual.visible = false

func _stage_companions() -> void:
    var companions := _companions()
    if companions.is_empty():
        return
    var hippo := _node_for(companions, "hippo")
    var pig := _node_for(companions, "pig")
    var dog := _node_for(companions, "sharpei")
    if hippo != null:
        hippo.position = HIPPO_HOME
    if pig != null:
        pig.position = PIG_HOME
        pig.velocity = Vector3.ZERO
        _set_companion_state(companions, "pig", PIG_HOME, "watch")
    if dog != null:
        dog.position = DOG_HOME
        dog.velocity = Vector3.ZERO
        _set_companion_state(companions, "sharpei", DOG_HOME, "watch")
    roster.set("companions", companions)

func _maintain_companion_depth() -> void:
    var companions := _companions()
    if companions.is_empty():
        return
    var pig := _node_for(companions, "pig")
    var dog := _node_for(companions, "sharpei")
    if pig != null and pig.position.distance_to(PIG_HOME) > 1.25:
        _set_companion_state(companions, "pig", PIG_HOME, "wander")
    if dog != null and dog.position.distance_to(DOG_HOME) > 1.25:
        _set_companion_state(companions, "sharpei", DOG_HOME, "watch")
    roster.set("companions", companions)

func _apply_environment_finish() -> void:
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null or world_environment.environment == null:
        return
    var environment := world_environment.environment
    var daylight := _daylight_factor()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.025, 0.055, 0.120).lerp(Color(0.31, 0.59, 0.82), daylight)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.36, 0.44, 0.62).lerp(Color(0.70, 0.74, 0.65), daylight)
    environment.ambient_light_energy = lerpf(0.76, 1.08, daylight)
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.20, 0.25, 0.36).lerp(Color(0.71, 0.77, 0.71), daylight)
    environment.fog_light_energy = lerpf(0.28, 0.58, daylight)
    environment.fog_density = lerpf(0.012, 0.006, daylight)
    environment.adjustment_enabled = true
    environment.adjustment_brightness = lerpf(1.04, 1.10, daylight)
    environment.adjustment_contrast = lerpf(1.01, 1.04, daylight)
    environment.adjustment_saturation = lerpf(0.88, 0.92, daylight)

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

func _companions() -> Dictionary:
    var value: Variant = roster.get("companions") if roster != null else {}
    return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _node_for(companions: Dictionary, species: String) -> CharacterBody3D:
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return null
    var node := (data_variant as Dictionary).get("node") as CharacterBody3D
    return node if node != null and is_instance_valid(node) else null

func _set_companion_state(companions: Dictionary, species: String, target: Vector3, action: String) -> void:
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return
    var data := data_variant as Dictionary
    data["target"] = target
    data["action"] = action
    data["action_timer"] = randf_range(4.5, 7.5)
    companions[species] = data

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
