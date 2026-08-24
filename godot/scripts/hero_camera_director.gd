extends Node

# Cinematic wildlife camera. Portrait mode deliberately places the selected companion
# below visual centre so sky, acacia silhouettes and distant ridges remain visible,
# matching the approved full-screen sanctuary composition.

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var smoothed_pivot := Vector3.ZERO
var initialized := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 340
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            camera = _find_camera(scene_root)
            if camera != null:
                break
        await get_tree().process_frame
    if scene_root == null or roster == null or camera == null:
        push_warning("HeroCameraDirector could not bind to the sanctuary camera")
        return
    _hide_prototype_focus_ring()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null or roster == null:
        return
    var sanctuary_hud := get_node_or_null("/root/SanctuaryHUD")
    if sanctuary_hud != null and bool(sanctuary_hud.get("bodycam_mode")):
        return
    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return

    _hide_prototype_focus_ring()
    var selected := _selected_node()
    if selected == null:
        return

    var viewport := get_viewport().get_visible_rect().size
    var portrait := viewport.y >= viewport.x
    var desired_pivot := selected.global_position + Vector3(0.0, 0.64, 0.0)
    if not initialized:
        smoothed_pivot = desired_pivot
        initialized = true
    else:
        smoothed_pivot = smoothed_pivot.lerp(desired_pivot, clampf(delta * 4.8, 0.0, 1.0))

    var yaw := float(scene_root.get("orbit_yaw"))
    var pitch := clampf(float(scene_root.get("orbit_pitch")), -0.38, 0.14)
    var requested_distance := float(scene_root.get("orbit_distance"))
    var min_distance := 5.8 if portrait else 4.9
    var max_distance := 8.2 if portrait else 7.5
    var distance := clampf(requested_distance, min_distance, max_distance)
    if portrait:
        distance = maxf(distance, 6.3)

    var horizontal := cos(pitch) * distance
    var camera_height := 0.46 if portrait else 0.30
    var desired_camera := smoothed_pivot + Vector3(
        sin(yaw) * horizontal,
        -sin(pitch) * distance + camera_height,
        cos(yaw) * horizontal
    )

    camera.global_position = camera.global_position.lerp(desired_camera, clampf(delta * 5.8, 0.0, 1.0))
    var upward_composition := 0.42 if portrait else 0.12
    camera.look_at(smoothed_pivot + Vector3(0.0, upward_composition, 0.0), Vector3.UP)
    var target_fov := 49.0 if portrait else 42.0
    camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 3.8, 0.0, 1.0))

func _selected_node() -> Node3D:
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return null
    var companions := companions_variant as Dictionary
    var species := str(roster.get("selected_species"))
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return null
    var node := (data_variant as Dictionary).get("node") as Node3D
    return node if node != null and is_instance_valid(node) else null

func _hide_prototype_focus_ring() -> void:
    if scene_root == null:
        return
    var ring := scene_root.find_child("SelectedCompanionFocus", true, false) as GeometryInstance3D
    if ring != null:
        ring.visible = false

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
