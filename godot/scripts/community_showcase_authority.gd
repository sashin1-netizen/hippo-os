extends Node

# Final compatibility-renderer authority for the open-source community build.
# It runs after the older visual passes so the pinned CC0/MIT assets are what Android
# compatibility devices actually present, rather than prototype grass/ridge geometry.

const HERO_HOME := Vector3(1.15, 0.80, 1.55)
const PIG_HOME := Vector3(-3.65, 0.72, 3.20)
const DOG_HOME := Vector3(-3.85, 0.75, -2.65)
const CAMERA_DISTANCE := 7.65
const CAMERA_PITCH := -0.105

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var compatibility_world: Node3D
var ready_announced := false
var maintenance_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 30000
    set_process(false)
    call_deferred("_bind")

func _bind() -> void:
    if not _is_compatibility_renderer():
        return

    for _attempt in range(900):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            camera = _find_camera(scene_root)
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            compatibility_world = scene_root.find_child("CompatibilityOpenWorld", true, false) as Node3D
            if camera != null and hippo != null and pig != null and dog != null and compatibility_world != null:
                break
        await get_tree().process_frame

    if scene_root == null or camera == null or hippo == null or pig == null or dog == null or compatibility_world == null:
        push_warning("CommunityShowcaseAuthority could not bind to compatibility world")
        return

    _apply_authority(1.0)
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null or compatibility_world == null:
        return

    maintenance_timer -= delta
    if maintenance_timer <= 0.0:
        maintenance_timer = 0.12
        _apply_authority(delta)

    if not ready_announced and _community_animals_ready():
        ready_announced = true
        print("HippoOS community showcase ready")

func _apply_authority(delta: float) -> void:
    compatibility_world.visible = true
    _hide_non_authoritative_geometry(scene_root)
    _show_community_geometry(compatibility_world)
    _trim_foreground_clutter()
    _force_daylight()
    _stage_animals(delta)
    _fix_hud()

func _hide_non_authoritative_geometry(node: Node) -> void:
    for child in node.get_children():
        if child == compatibility_world or child == hippo or child == pig or child == dog:
            continue
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).visible = false
        _hide_non_authoritative_geometry(child)

func _show_community_geometry(node: Node) -> void:
    for child in node.get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).visible = true
        _show_community_geometry(child)

func _trim_foreground_clutter() -> void:
    # Reeds are useful at pond edges on hardware, but on the software compatibility
    # renderer their thin cards dominate the portrait composition. Trees, bushes,
    # rocks and mountains remain visible, preserving authored landscape depth.
    for node in compatibility_world.find_children("CommunityReed*", "Node3D", true, false):
        if node is Node3D:
            (node as Node3D).visible = false

func _force_daylight() -> void:
    var sky_top := Color(0.12, 0.48, 0.82)
    var sky_horizon := Color(0.68, 0.85, 0.95)
    RenderingServer.set_default_clear_color(sky_horizon)

    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null:
        return
    if world_environment.environment == null:
        world_environment.environment = Environment.new()
    var env := world_environment.environment

    # BG_COLOR is deliberately used on x86/ANGLE/SwiftShader. Godot's procedural sky
    # has produced black frames on that stack; ARM64 Mobile Vulkan keeps its full sky.
    env.background_mode = Environment.BG_COLOR
    env.background_color = sky_horizon
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.78, 0.84, 0.76)
    env.ambient_light_energy = 1.12
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.fog_enabled = true
    env.fog_light_color = Color(0.80, 0.87, 0.85)
    env.fog_light_energy = 0.42
    env.fog_density = 0.0018
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.08
    env.adjustment_contrast = 1.025
    env.adjustment_saturation = 1.02

func _stage_animals(delta: float) -> void:
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    hippo.position = hippo.position.lerp(HERO_HOME, clampf(delta * 9.0, 0.0, 1.0))
    pig.position = pig.position.lerp(PIG_HOME, clampf(delta * 7.0, 0.0, 1.0))
    dog.position = dog.position.lerp(DOG_HOME, clampf(delta * 7.0, 0.0, 1.0))

    scene_root.set("current_action", "idle")
    scene_root.set("action_timer", 1.5)
    scene_root.set("orbit_yaw", 1.53)
    scene_root.set("orbit_pitch", CAMERA_PITCH)
    scene_root.set("orbit_distance", CAMERA_DISTANCE)
    camera.fov = lerpf(camera.fov, 43.0, clampf(delta * 7.0, 0.0, 1.0))
    _face(hippo, camera.global_position, clampf(delta * 12.0, 0.0, 1.0))
    _face(pig, hippo.global_position, clampf(delta * 8.0, 0.0, 1.0))
    _face(dog, hippo.global_position, clampf(delta * 8.0, 0.0, 1.0))

func _fix_hud() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null or not bool(hud.get("built")):
        return
    var weather := hud.get("weather_label") as Label
    if weather != null:
        weather.text = "CLEAR DAY"
    var chevron := hud.get("bottom_chevron") as Control
    if chevron != null:
        chevron.visible = false

func _community_animals_ready() -> bool:
    return (
        hippo.find_child("GobkitCC0Visual", true, false) != null
        and pig.find_child("CommunityRiggedVisual", true, false) != null
        and dog.find_child("CommunityRiggedVisual", true, false) != null
    )

func _is_compatibility_renderer() -> bool:
    var method := String(RenderingServer.get_current_rendering_method()).to_lower()
    return "compatibility" in method or "gl_compatibility" in method

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
