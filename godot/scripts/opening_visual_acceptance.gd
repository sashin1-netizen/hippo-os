extends Node

# Final first-impression correction for the authoritative OpenWorldDirector runtime.
# This does not build another habitat. It only stabilizes the opening composition long
# enough for a clean first frame, then yields positions/camera back to live gameplay.

const HIPPO_HOME := Vector3(0.0, 0.80, 0.0)
const PIG_HOME := Vector3(-4.80, 0.72, 2.20)
const DOG_HOME := Vector3(-5.00, 0.75, -2.00)
const OPENING_HOLD_SECONDS := 8.0

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var hold_until := 0.0
var maintenance_timer := 0.0
var initialized := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 9000
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(640):
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
        push_warning("OpeningVisualAcceptance could not bind to sanctuary")
        return

    # Let the asynchronous habitat/HUD builders finish before applying the final shot.
    for _frame in range(64):
        await get_tree().process_frame

    hold_until = Time.get_ticks_msec() / 1000.0 + OPENING_HOLD_SECONDS
    _stage_opening()
    _enforce_camera()
    _ensure_android_background()
    _clear_camera_lane()
    _refine_hud_header()
    initialized = true
    set_process(true)

func _process(delta: float) -> void:
    if not initialized or scene_root == null:
        return

    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return

    var now := Time.get_ticks_msec() / 1000.0
    if now < hold_until:
        _hold_opening_pose(delta)
        _enforce_camera()

    maintenance_timer -= delta
    if maintenance_timer <= 0.0:
        maintenance_timer = 0.22
        _ensure_android_background()
        _clear_camera_lane()
        _refine_hud_header()

func _stage_opening() -> void:
    hippo.position = HIPPO_HOME
    pig.position = PIG_HOME
    dog.position = DOG_HOME
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    _face_toward(hippo, camera.global_position, 1.0)
    _face_toward(pig, hippo.global_position, 1.0)
    _face_toward(dog, hippo.global_position, 1.0)

func _hold_opening_pose(delta: float) -> void:
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    hippo.position = hippo.position.lerp(HIPPO_HOME, clampf(delta * 7.0, 0.0, 1.0))
    pig.position = pig.position.lerp(PIG_HOME, clampf(delta * 5.5, 0.0, 1.0))
    dog.position = dog.position.lerp(DOG_HOME, clampf(delta * 5.5, 0.0, 1.0))
    _face_toward(hippo, camera.global_position, clampf(delta * 10.0, 0.0, 1.0))
    _face_toward(pig, hippo.global_position, clampf(delta * 7.0, 0.0, 1.0))
    _face_toward(dog, hippo.global_position, clampf(delta * 7.0, 0.0, 1.0))

func _face_toward(body: CharacterBody3D, target: Vector3, weight: float) -> void:
    var direction := target - body.global_position
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        return
    direction = direction.normalized()
    # Procedural companion anatomy is authored along local +X.
    var target_yaw := atan2(-direction.z, direction.x)
    body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(weight, 0.0, 1.0))
    body.rotation.x = 0.0
    body.rotation.z = 0.0

func _enforce_camera() -> void:
    scene_root.set("orbit_yaw", 1.46)
    scene_root.set("orbit_pitch", -0.018)
    scene_root.set("orbit_distance", 10.2)
    camera.fov = 49.0

func _ensure_android_background() -> void:
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null or world_environment.environment == null:
        return

    var environment := world_environment.environment
    var daylight := _daylight_factor()
    var sky_color := Color(0.055, 0.095, 0.18).lerp(Color(0.32, 0.63, 0.88), daylight)
    RenderingServer.set_default_clear_color(sky_color)

    # Compatibility/SwiftShader evidence can render procedural skies black even when
    # the Mobile/Vulkan phone path is correct. Use a deterministic blue background only
    # on x86/x86_64 proof devices; physical ARM phones keep the full procedural sky.
    var architecture := Engine.get_architecture_name().to_lower()
    if "x86" in architecture:
        environment.background_mode = Environment.BG_COLOR
        environment.background_color = sky_color
        environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        environment.ambient_light_color = Color(0.50, 0.59, 0.62).lerp(Color(0.72, 0.78, 0.70), daylight)
        environment.ambient_light_energy = lerpf(0.78, 1.02, daylight)

func _clear_camera_lane() -> void:
    if camera == null or hippo == null:
        return

    var hero_vector := hippo.global_position + Vector3(0.0, 0.46, 0.0) - camera.global_position
    var hero_len_sq := hero_vector.length_squared()
    if hero_len_sq < 0.01:
        return

    for root_name in ["PremiumExperienceWorld", "GrasslandsProductionLayer", "SanctuaryVisualPolish", "OpenWorldAuthority"]:
        var root := scene_root.find_child(root_name, true, false) as Node3D
        if root != null:
            _clear_lane_recursive(root, hero_vector, hero_len_sq)

func _clear_lane_recursive(node: Node, hero_vector: Vector3, hero_len_sq: float) -> void:
    for child in node.get_children():
        if _belongs_to_animal(child):
            continue
        if child is MeshInstance3D:
            var visual := child as MeshInstance3D
            var to_object := visual.global_position - camera.global_position
            var along := to_object.dot(hero_vector) / hero_len_sq
            if along > 0.05 and along < 0.93:
                var perpendicular := (to_object - hero_vector * along).length()
                if perpendicular < 2.45 and _is_blocker(visual):
                    visual.visible = false
        _clear_lane_recursive(child, hero_vector, hero_len_sq)

func _is_blocker(visual: MeshInstance3D) -> bool:
    if visual.mesh is CylinderMesh:
        var cylinder := visual.mesh as CylinderMesh
        return cylinder.height * absf(visual.scale.y) > 0.48
    if visual.mesh is SphereMesh:
        return visual.global_position.y > 0.95 and visual.scale.length() > 1.15
    if visual.mesh is BoxMesh:
        return visual.global_position.y > 0.42
    return false

func _belongs_to_animal(node: Node) -> bool:
    for animal in [hippo, pig, dog]:
        if animal != null and (node == animal or animal.is_ancestor_of(node)):
            return true
    return false

func _refine_hud_header() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null or not bool(hud.get("built")):
        return

    var brand := hud.get("brand_label") as Label
    var subtitle := hud.get("brand_subtitle") as Label
    var status := hud.get("status_panel") as Control
    if brand != null:
        brand.text = "HIPPO OS"
        brand.add_theme_font_size_override("font_size", 22)
        var size := get_viewport().get_visible_rect().size
        if size.y >= size.x:
            brand.position.x = size.x * 0.5 - 78.0
            brand.size.x = 156.0
    if subtitle != null:
        subtitle.text = "Sanctuary"
        subtitle.add_theme_font_size_override("font_size", 13)
        var size2 := get_viewport().get_visible_rect().size
        if size2.y >= size2.x:
            subtitle.position.x = size2.x * 0.5 - 78.0
            subtitle.size.x = 156.0
    if status != null:
        status.modulate.a = 0.82

func _daylight_factor() -> float:
    var mode := "auto"
    var settings_value: Variant = scene_root.get("settings")
    if typeof(settings_value) == TYPE_DICTIONARY:
        mode = str((settings_value as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
