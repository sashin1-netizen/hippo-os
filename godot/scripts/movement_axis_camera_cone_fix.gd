extends Node

# The procedural companion geometry is authored along local +X, while Godot look_at()
# points local -Z at its target. Correct that 90-degree mismatch after the behaviour
# controllers run, and keep the documentary camera cone free of procedural trunks,
# canopies and oversized foreground clutter.

const HERO_HOME := Vector3(0.0, 0.80, 0.70)

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var cleanup_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 2850
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(480):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            camera = _find_camera(scene_root)
            if hippo != null and pig != null and dog != null and camera != null:
                break
        await get_tree().process_frame

    if scene_root == null or hippo == null or camera == null:
        push_warning("MovementAxisCameraConeFix could not bind to sanctuary")
        return

    for _frame in range(30):
        await get_tree().process_frame
    _clear_camera_cone()
    _reduce_foreground_density()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null or hippo == null or camera == null:
        return

    _correct_animal_orientation(delta)
    _keep_hippo_in_hero_zone()

    cleanup_timer -= delta
    if cleanup_timer <= 0.0:
        cleanup_timer = 0.75
        _clear_camera_cone()
        _enforce_water_scale()

func _correct_animal_orientation(delta: float) -> void:
    _orient_body(hippo, _hippo_attention_direction(), delta, 7.0)
    if pig != null:
        _orient_body(pig, _companion_attention_direction(pig), delta, 5.5)
    if dog != null:
        _orient_body(dog, _companion_attention_direction(dog), delta, 5.5)

func _orient_body(body: CharacterBody3D, fallback_direction: Vector3, delta: float, speed: float) -> void:
    if body == null or not is_instance_valid(body):
        return
    var direction := Vector3(body.velocity.x, 0.0, body.velocity.z)
    if direction.length_squared() < 0.012:
        direction = fallback_direction
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        return
    direction = direction.normalized()

    # Local +X is the anatomical forward axis for all current procedural companions.
    var target_yaw := atan2(-direction.z, direction.x)
    body.rotation.y = lerp_angle(body.rotation.y, target_yaw, 1.0 - exp(-speed * delta))
    body.rotation.x = 0.0
    body.rotation.z = 0.0

func _hippo_attention_direction() -> Vector3:
    if camera == null or hippo == null:
        return Vector3(1.0, 0.0, 0.0)
    var direction := camera.global_position - hippo.global_position
    direction.y = 0.0
    return direction.normalized()

func _companion_attention_direction(body: CharacterBody3D) -> Vector3:
    if hippo == null or body == null:
        return Vector3(1.0, 0.0, 0.0)
    var direction := hippo.global_position - body.global_position
    direction.y = 0.0
    return direction.normalized()

func _keep_hippo_in_hero_zone() -> void:
    var action := str(scene_root.get("current_action"))
    if action != "wander" and action != "explore" and action != "play":
        return
    var offset := Vector2(hippo.position.x - HERO_HOME.x, hippo.position.z - HERO_HOME.z)
    if offset.length() > 2.35:
        scene_root.set("wander_target", Vector3(HERO_HOME.x, hippo.position.y, HERO_HOME.z))
    if offset.length() > 3.45:
        hippo.position.x = lerpf(hippo.position.x, HERO_HOME.x, 0.12)
        hippo.position.z = lerpf(hippo.position.z, HERO_HOME.z, 0.12)

func _clear_camera_cone() -> void:
    if camera == null or hippo == null:
        return
    var roots: Array[Node3D] = []
    for root_name in ["GrasslandsProductionLayer", "SanctuaryVisualPolish", "PremiumExperienceWorld"]:
        var root := scene_root.find_child(root_name, true, false) as Node3D
        if root != null:
            roots.append(root)

    var camera_to_hero := hippo.global_position + Vector3(0.0, 0.40, 0.0) - camera.global_position
    var hero_len_sq := camera_to_hero.length_squared()
    if hero_len_sq < 0.01:
        return

    for root in roots:
        for child in root.get_children():
            if not (child is MeshInstance3D):
                continue
            var visual := child as MeshInstance3D
            var to_object := visual.global_position - camera.global_position
            var along := to_object.dot(camera_to_hero) / hero_len_sq
            if along <= 0.08 or along >= 0.90:
                continue
            var perpendicular := (to_object - camera_to_hero * along).length()
            if perpendicular > 2.05:
                continue
            if _is_foreground_blocker(visual):
                visual.visible = false

func _is_foreground_blocker(visual: MeshInstance3D) -> bool:
    if visual.mesh is CylinderMesh:
        var cylinder := visual.mesh as CylinderMesh
        return cylinder.height > 0.55
    if visual.mesh is BoxMesh:
        return visual.global_position.y > 0.18
    if visual.mesh is SphereMesh:
        # Large raised spheres are procedural canopies/shrubs. Low spheres are rocks
        # and remain visible to ground the habitat.
        return visual.global_position.y > 0.72 and visual.scale.length() > 0.75
    return false

func _reduce_foreground_density() -> void:
    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass != null and grass.multimesh != null and not bool(grass.get_meta("hero_density_reduced", false)):
        var multi := grass.multimesh
        for i in range(multi.instance_count):
            var transform := multi.get_instance_transform(i)
            if i % 3 == 1:
                transform.basis = transform.basis.scaled(Vector3(0.04, 0.04, 0.04))
            else:
                transform.basis = transform.basis.scaled(Vector3(0.78, 0.68, 0.78))
            multi.set_instance_transform(i, transform)
        grass.set_meta("hero_density_reduced", true)
    _enforce_water_scale()

func _enforce_water_scale() -> void:
    var water := scene_root.find_child("ForegroundWatercourse", true, false) as MeshInstance3D
    if water != null:
        water.scale = Vector3(0.64, 1.0, 0.30)
        water.position = Vector3(2.20, 0.035, 3.10)

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
