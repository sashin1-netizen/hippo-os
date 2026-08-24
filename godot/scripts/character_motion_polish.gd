extends Node

# Secondary procedural motion layer for the current original hippo placeholder.

var scene_root: Node = null
var hippo: CharacterBody3D = null
var visual: Node3D = null
var head: Node3D = null
var snout: Node3D = null
var chin: Node3D = null
var nostril_l: Node3D = null
var nostril_r: Node3D = null
var mouth: MeshInstance3D = null
var mouth_material: StandardMaterial3D = null

var base_snout_position: Vector3 = Vector3.ZERO
var base_chin_position: Vector3 = Vector3.ZERO
var base_nostril_l_scale: Vector3 = Vector3.ONE
var base_nostril_r_scale: Vector3 = Vector3.ONE
var base_visual_rotation: Vector3 = Vector3.ZERO
var last_feed_count: int = 0
var last_action: String = ""
var chew_timer: float = 0.0
var yawn_timer: float = 0.0
var wake_timer: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 90

func _process(delta: float) -> void:
    _ensure_binding()
    if not is_instance_valid(scene_root) or not is_instance_valid(hippo):
        return
    chew_timer = maxf(0.0, chew_timer - delta)
    yawn_timer = maxf(0.0, yawn_timer - delta)
    wake_timer = maxf(0.0, wake_timer - delta)
    _track_interactions_and_actions()
    _animate_head_and_body(delta)
    _animate_mouth()
    _animate_nostrils()

func _ensure_binding() -> void:
    var current_scene: Node = get_tree().current_scene
    if current_scene == null:
        return
    if scene_root == current_scene and is_instance_valid(hippo):
        return

    scene_root = current_scene
    hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
    if hippo == null:
        return
    visual = hippo.get_child(1) as Node3D if hippo.get_child_count() > 1 else hippo
    head = hippo.find_child("Head", true, false) as Node3D
    snout = hippo.find_child("Snout", true, false) as Node3D
    chin = hippo.find_child("Chin", true, false) as Node3D
    nostril_l = hippo.find_child("NostrilL", true, false) as Node3D
    nostril_r = hippo.find_child("NostrilR", true, false) as Node3D

    if is_instance_valid(snout):
        base_snout_position = snout.position
    if is_instance_valid(chin):
        base_chin_position = chin.position
    if is_instance_valid(nostril_l):
        base_nostril_l_scale = nostril_l.scale
    if is_instance_valid(nostril_r):
        base_nostril_r_scale = nostril_r.scale
    if is_instance_valid(visual):
        base_visual_rotation = visual.rotation

    _build_mouth()
    var counts: Variant = scene_root.get("interaction_counts")
    if typeof(counts) == TYPE_DICTIONARY:
        last_feed_count = int((counts as Dictionary).get("feed", 0))
    last_action = str(scene_root.get("current_action"))

func _build_mouth() -> void:
    if not is_instance_valid(visual) or is_instance_valid(mouth):
        return
    mouth = MeshInstance3D.new()
    mouth.name = "MouthInterior"
    mouth.mesh = SphereMesh.new()
    mouth.position = Vector3(1.88, 0.18, 0.0)
    mouth.scale = Vector3(0.42, 0.045, 0.42)
    mouth_material = StandardMaterial3D.new()
    mouth_material.albedo_color = Color(0.16, 0.035, 0.055)
    mouth_material.roughness = 0.62
    mouth.material_override = mouth_material
    visual.add_child(mouth)

func _track_interactions_and_actions() -> void:
    var counts: Variant = scene_root.get("interaction_counts")
    if typeof(counts) == TYPE_DICTIONARY:
        var feed_count: int = int((counts as Dictionary).get("feed", 0))
        if feed_count > last_feed_count:
            chew_timer = 1.65
        last_feed_count = feed_count

    var action: String = str(scene_root.get("current_action"))
    if action != last_action:
        if action == "sleep" and randf() < 0.42:
            yawn_timer = 1.35
        elif last_action == "sleep":
            wake_timer = 1.0
        last_action = action

func _animate_head_and_body(delta: float) -> void:
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var action: String = str(scene_root.get("current_action"))
    var loaded_settings: Variant = scene_root.get("settings")
    var reduced_motion: bool = false
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        reduced_motion = bool((loaded_settings as Dictionary).get("reduced_motion", false))
    var motion_scale: float = 0.35 if reduced_motion else 1.0

    if is_instance_valid(head):
        var target_yaw: float = 0.0
        match action:
            "approach": target_yaw = sin(now * 0.85) * 0.09
            "explore": target_yaw = sin(now * 0.62) * 0.13
            "play": target_yaw = sin(now * 1.8) * 0.11
            "sleep": target_yaw = -0.12 + sin(now * 0.28) * 0.025
            _: target_yaw = sin(now * 0.42) * 0.045
        head.rotation.y = lerpf(head.rotation.y, target_yaw * motion_scale, 1.0 - exp(-6.0 * delta))

    if is_instance_valid(visual):
        var speed: float = hippo.velocity.length()
        var target_lean: float = 0.0
        if speed > 1.25:
            target_lean = -0.035
        elif speed > 0.2:
            target_lean = -0.015
        if action == "sleep":
            target_lean = 0.025
        visual.rotation.z = lerpf(visual.rotation.z, base_visual_rotation.z + target_lean * motion_scale, 1.0 - exp(-7.0 * delta))

func _animate_mouth() -> void:
    if not is_instance_valid(chin) or not is_instance_valid(snout) or not is_instance_valid(mouth):
        return
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var open_amount: float = 0.0
    if chew_timer > 0.0:
        open_amount = (sin(now * 15.0) * 0.5 + 0.5) * 0.12
    elif yawn_timer > 0.0:
        var phase: float = 1.0 - yawn_timer / 1.35
        open_amount = sin(phase * PI) * 0.24
    elif wake_timer > 0.0:
        open_amount = sin((1.0 - wake_timer) * PI) * 0.05
    chin.position = base_chin_position + Vector3(0.0, -open_amount, 0.0)
    snout.position = base_snout_position + Vector3(0.0, open_amount * 0.10, 0.0)
    mouth.scale.y = 0.045 + open_amount * 0.62
    mouth.visible = open_amount > 0.012

func _animate_nostrils() -> void:
    if not is_instance_valid(nostril_l) or not is_instance_valid(nostril_r):
        return
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var action: String = str(scene_root.get("current_action"))
    var sniff_speed: float = 3.2
    var amplitude: float = 0.08
    if action == "explore":
        sniff_speed = 5.4
        amplitude = 0.18
    elif action == "approach":
        sniff_speed = 4.3
        amplitude = 0.13
    elif action == "sleep":
        sniff_speed = 1.45
        amplitude = 0.045
    var flare: float = 1.0 + (sin(now * sniff_speed) * 0.5 + 0.5) * amplitude
    nostril_l.scale = Vector3(base_nostril_l_scale.x * flare, base_nostril_l_scale.y, base_nostril_l_scale.z * flare)
    nostril_r.scale = Vector3(base_nostril_r_scale.x * flare, base_nostril_r_scale.y, base_nostril_r_scale.z * flare)
