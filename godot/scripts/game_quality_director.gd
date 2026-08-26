extends Node

# Production game-quality pass for capable Android/ARM devices.
# The Compatibility/OpenGL renderer is deliberately left alone because it is the
# low-end/CI fallback and has a much tighter shader budget.

const TARGET_FOV := 44.0
const NEAR_PLANE := 0.05
const FAR_PLANE := 360.0

var scene_root: Node3D
var camera: Camera3D
var applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 39000
    call_deferred("_apply_when_ready")

func _apply_when_ready() -> void:
    if _is_compatibility_renderer():
        print("HippoOS game quality: compatibility profile active")
        return

    for _attempt in range(720):
        var current := get_tree().current_scene
        if current is Node3D:
            scene_root = current as Node3D
            camera = _find_camera(scene_root)
            if camera != null and scene_root.find_child("BabyHippo", true, false) != null:
                break
        await get_tree().process_frame

    if scene_root == null or camera == null:
        push_warning("GameQualityDirector could not bind to sanctuary")
        return

    # Let authored world/animal assets finish attaching before changing their quality state.
    for _frame in range(12):
        await get_tree().process_frame

    _configure_viewport()
    _configure_camera()
    _configure_environment()
    _configure_sun()
    _configure_world_geometry()
    _configure_companion_geometry()
    applied = true
    print("HippoOS game quality: production mobile profile active")

func _configure_viewport() -> void:
    var viewport := get_viewport()
    if viewport == null:
        return
    var architecture := Engine.get_architecture_name().to_lower()
    if "arm" in architecture or "aarch64" in architecture:
        viewport.msaa_3d = Viewport.MSAA_4X
    else:
        viewport.msaa_3d = Viewport.MSAA_2X
    viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

func _configure_camera() -> void:
    camera.current = true
    camera.fov = TARGET_FOV
    camera.near = NEAR_PLANE
    camera.far = FAR_PLANE
    camera.keep_aspect = Camera3D.KEEP_HEIGHT

func _configure_environment() -> void:
    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment == null or world_environment.environment == null:
        return
    var env := world_environment.environment
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.04
    env.adjustment_contrast = 1.045
    env.adjustment_saturation = 1.035
    env.fog_enabled = true
    env.fog_density = minf(env.fog_density, 0.0022) if env.fog_density > 0.0 else 0.0022

func _configure_sun() -> void:
    var sun := _find_directional_light(scene_root)
    if sun == null:
        return
    sun.shadow_enabled = true
    sun.light_energy = clampf(sun.light_energy, 1.15, 1.55)
    sun.light_color = Color(1.0, 0.955, 0.88)
    sun.shadow_bias = 0.035
    sun.shadow_normal_bias = 1.1

func _configure_world_geometry() -> void:
    for root_name in ["GrasslandsProductionLayer", "OpenWorldAuthority", "PBRHabitat", "GrasslandsSanctuary"]:
        var root := scene_root.find_child(root_name, true, false) as Node3D
        if root != null:
            _upgrade_geometry_tree(root, false)

func _configure_companion_geometry() -> void:
    for body_name in ["BabyHippo", "PorkyPig", "BaoSharPei"]:
        var body := scene_root.find_child(body_name, true, false) as Node3D
        if body == null:
            continue
        var visual := body.find_child("ProductionVisual", true, false) as Node3D
        if visual == null:
            visual = body.find_child("CommunityRiggedVisual", true, false) as Node3D
        if visual == null and body_name == "BabyHippo":
            visual = body.find_child("GobkitCC0Visual", true, false) as Node3D
        if visual != null:
            _upgrade_geometry_tree(visual, true)

func _upgrade_geometry_tree(root: Node, companion: bool) -> void:
    if root is GeometryInstance3D:
        var geometry := root as GeometryInstance3D
        geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        geometry.extra_cull_margin = maxf(geometry.extra_cull_margin, 1.0 if companion else 0.25)
        if companion:
            geometry.visibility_range_begin = 0.0
            geometry.visibility_range_end = 0.0
            geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
    for child in root.get_children():
        _upgrade_geometry_tree(child, companion)

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null

func _find_directional_light(node: Node) -> DirectionalLight3D:
    if node is DirectionalLight3D:
        return node as DirectionalLight3D
    for child in node.get_children():
        var found := _find_directional_light(child)
        if found != null:
            return found
    return null

func _is_compatibility_renderer() -> bool:
    var method := String(RenderingServer.get_current_rendering_method()).to_lower()
    return "compatibility" in method or "gl_compatibility" in method
