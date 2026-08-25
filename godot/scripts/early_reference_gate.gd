extends Node

# Fast first-frame authority used by Android and slow software renderers. The richer
# OpenWorldReferenceFinish remains the long-lived visual authority; this gate applies
# the same reference composition immediately instead of waiting dozens of rendered frames.

const HERO_HOME := Vector3(1.15, 0.80, 1.55)
const PIG_HOME := Vector3(-3.90, 0.72, 3.55)
const DOG_HOME := Vector3(-4.15, 0.75, -2.65)
const HOLD_SECONDS := 30.0

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var hold_until := 0.0
var timer := 0.0
var ready := false

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
    _enforce_fast_visuals()
    ready = true
    set_process(true)
    print("HippoOS EarlyReferenceGate active")

func _process(delta: float) -> void:
    if not ready:
        return

    if Time.get_ticks_msec() / 1000.0 < hold_until:
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
        _face(hippo, camera.global_position, clampf(delta * 12.0, 0.0, 1.0))
        _face(pig, hippo.global_position, clampf(delta * 7.0, 0.0, 1.0))
        _face(dog, hippo.global_position, clampf(delta * 7.0, 0.0, 1.0))

    timer -= delta
    if timer <= 0.0:
        timer = 0.12
        _enforce_fast_visuals()

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

func _enforce_fast_visuals() -> void:
    _fix_software_background()
    _fix_header()

    var old_polish := scene_root.find_child("SanctuaryVisualPolish", true, false) as Node3D
    if old_polish != null:
        old_polish.visible = false

    for root_name in ["PremiumExperienceWorld", "GrasslandsProductionLayer", "OpenWorldAuthority"]:
        var root := scene_root.find_child(root_name, true, false) as Node3D
        if root != null:
            root.visible = true
            _suppress_recursive(root)

    for node_name in ["SanctuaryGroundFinish", "ForegroundWatercourse", "WetBank", "DryAnimalTrail"]:
        var visual := scene_root.find_child(node_name, true, false) as GeometryInstance3D
        if visual != null:
            visual.visible = true

func _fix_software_background() -> void:
    var architecture := Engine.get_architecture_name().to_lower()
    if not "x86" in architecture:
        return
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null or world_environment.environment == null:
        return
    var env := world_environment.environment
    var daylight := _daylight_factor()
    var sky_color := Color(0.08, 0.22, 0.40).lerp(Color(0.12, 0.52, 0.86), daylight)
    RenderingServer.set_default_clear_color(sky_color)
    env.background_mode = Environment.BG_COLOR
    env.background_color = sky_color
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.48, 0.56, 0.62).lerp(Color(0.78, 0.82, 0.72), daylight)
    env.ambient_light_energy = lerpf(0.86, 1.08, daylight)
    env.fog_enabled = true
    env.fog_light_color = Color(0.48, 0.56, 0.64).lerp(Color(0.78, 0.84, 0.80), daylight)
    env.fog_light_energy = 0.52
    env.fog_density = lerpf(0.007, 0.0024, daylight)
    env.adjustment_enabled = true
    env.adjustment_brightness = lerpf(1.06, 1.13, daylight)
    env.adjustment_contrast = 1.02
    env.adjustment_saturation = 0.98

func _daylight_factor() -> float:
    var settings_value: Variant = scene_root.get("settings")
    var mode := "auto"
    if typeof(settings_value) == TYPE_DICTIONARY:
        mode = str((settings_value as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    if hour >= 6.5 and hour <= 18.15:
        return 1.0
    if hour > 18.15 and hour <= 19.35:
        return lerpf(1.0, 0.14, (hour - 18.15) / 1.20)
    if hour >= 5.3 and hour < 6.5:
        return lerpf(0.14, 1.0, (hour - 5.3) / 1.20)
    return 0.08

func _suppress_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var visual := child as MeshInstance3D
            var lower := String(visual.name).to_lower()
            var hide := false
            if "acaciacanopy" in lower or "signatureacacia" in lower or "distanttree" in lower:
                hide = true
            elif visual.mesh is CylinderMesh:
                var cylinder := visual.mesh as CylinderMesh
                var upright := absf(visual.rotation_degrees.z) < 35.0 and absf(visual.rotation_degrees.x) < 35.0
                hide = upright and cylinder.height * absf(visual.scale.y) > 0.52 and visual.global_position.y > 0.22
            elif visual.mesh is SphereMesh:
                var terrain := "ridge" in lower or "escarpment" in lower or "rock" in lower or "stone" in lower
                hide = not terrain and visual.global_position.x > -7.5 and visual.global_position.y > 0.32 and visual.scale.length() > 0.66
            if hide:
                visual.visible = false
        _suppress_recursive(child)

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
