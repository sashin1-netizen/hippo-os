extends Node

# Last-resort renderer guard for Android/x86 compatibility devices. The normal Mobile/Vulkan
# path is untouched. This node keeps the root viewport's 3D pass enabled, restores the
# authoritative world/animal ancestor chains, removes the obsolete prototype stats card,
# and exposes a tiny x86-only render sentinel so CI can distinguish a camera/material issue
# from a disabled 3D viewport. The sentinel never ships on ARM phone builds.

const PROBE_NAME := "CompatibilityRenderSentinel"
const MAINTENANCE_INTERVAL := 0.10

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var compatibility_world: Node3D
var probe: MeshInstance3D
var timer := 0.0
var announced := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 60000
    set_process(false)
    call_deferred("_bind")

func _bind() -> void:
    if not _is_compatibility_renderer():
        return

    for _attempt in range(720):
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
        push_warning("CompatibilityRenderGuard could not bind to the authoritative sanctuary")
        return

    _enforce_render_path()
    _hide_legacy_stats()
    if OS.has_feature("x86_64"):
        _install_probe()
    _log_state("bound")
    set_process(true)

func _process(delta: float) -> void:
    timer -= delta
    if timer > 0.0:
        return
    timer = MAINTENANCE_INTERVAL
    _enforce_render_path()
    _hide_legacy_stats()
    _update_probe()
    if not announced:
        announced = true
        _log_state("maintained")

func _enforce_render_path() -> void:
    var viewport := get_viewport()
    if viewport != null:
        viewport.disable_3d = false
        RenderingServer.viewport_set_disable_3d(viewport.get_viewport_rid(), false)

    scene_root.visible = true
    camera.current = true
    camera.cull_mask = 0xFFFFF
    camera.near = 0.05
    camera.far = 300.0

    _show_chain(compatibility_world)
    _show_chain(hippo)
    _show_chain(pig)
    _show_chain(dog)
    _show_geometry_recursive(compatibility_world)
    _show_authoritative_animal(hippo, true)
    _show_authoritative_animal(pig, false)
    _show_authoritative_animal(dog, false)

func _show_chain(node: Node3D) -> void:
    if node == null:
        return
    var cursor: Node = node
    while cursor != null:
        if cursor is Node3D:
            (cursor as Node3D).visible = true
        if cursor == scene_root:
            break
        cursor = cursor.get_parent()

func _show_authoritative_animal(body: Node3D, allow_gobkit: bool) -> void:
    if body == null:
        return
    var visual := body.find_child("ProductionVisual", true, false) as Node3D
    if visual == null and allow_gobkit:
        visual = body.find_child("GobkitCC0Visual", true, false) as Node3D
    if visual == null:
        visual = body.find_child("CommunityRiggedVisual", true, false) as Node3D
    if visual == null:
        return
    _show_chain(visual)
    _show_geometry_recursive(visual)

func _show_geometry_recursive(root: Node) -> void:
    if root == null:
        return
    if root is Node3D:
        (root as Node3D).visible = true
    if root is GeometryInstance3D:
        var geometry := root as GeometryInstance3D
        geometry.visibility_range_begin = 0.0
        geometry.visibility_range_end = 0.0
        geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
        geometry.extra_cull_margin = maxf(geometry.extra_cull_margin, 16.0)
    for child in root.get_children():
        _show_geometry_recursive(child)

func _hide_legacy_stats() -> void:
    if scene_root == null:
        return
    var stats_variant: Variant = scene_root.get("stats_panel")
    if stats_variant is Control:
        (stats_variant as Control).visible = false

func _install_probe() -> void:
    if scene_root == null or probe != null:
        return
    var existing := scene_root.find_child(PROBE_NAME, true, false) as MeshInstance3D
    if existing != null:
        probe = existing
        return

    probe = MeshInstance3D.new()
    probe.name = PROBE_NAME
    var mesh := SphereMesh.new()
    mesh.radius = 0.22
    mesh.height = 0.44
    mesh.radial_segments = 20
    mesh.rings = 10
    probe.mesh = mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1.0, 0.08, 0.48)
    material.emission_enabled = true
    material.emission = Color(1.0, 0.04, 0.32)
    material.emission_energy_multiplier = 1.8
    probe.material_override = material
    probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    probe.visibility_layer = 1
    probe.extra_cull_margin = 128.0
    scene_root.add_child(probe)
    _update_probe()

func _update_probe() -> void:
    if probe == null or not is_instance_valid(probe) or camera == null or hippo == null:
        return
    probe.visible = true
    var hero_target := hippo.global_position + Vector3(0.0, 0.72, 0.0)
    var right := camera.global_transform.basis.x.normalized()
    probe.global_position = camera.global_position.lerp(hero_target, 0.78) + right * 0.72

func _log_state(stage: String) -> void:
    var viewport := get_viewport()
    var probe_screen := Vector2(-1.0, -1.0)
    var probe_behind := true
    if probe != null and camera != null:
        probe_screen = camera.unproject_position(probe.global_position)
        probe_behind = camera.is_position_behind(probe.global_position)
    print("HippoOS compatibility render guard [%s]: viewport_disable_3d=%s camera_current=%s cull_mask=%d world_visible=%s hippo_visible=%s probe=%s probe_behind=%s probe_screen=%s" % [
        stage,
        str(viewport.disable_3d if viewport != null else true),
        str(camera != null and camera.current),
        camera.cull_mask if camera != null else 0,
        str(compatibility_world != null and compatibility_world.is_visible_in_tree()),
        str(hippo != null and hippo.is_visible_in_tree()),
        str(probe != null),
        str(probe_behind),
        str(probe_screen)
    ])

func _is_compatibility_renderer() -> bool:
    var method := String(RenderingServer.get_current_rendering_method()).to_lower()
    return "compatibility" in method or "gl_compatibility" in method

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
