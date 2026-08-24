extends Node

# Secondary procedural motion layer for the current original hippo placeholder.
# It adds mouth/nostril/head/body nuance after the core simulation updates each frame.
# This is visual polish, not a claim that the placeholder has become the final studio rig.

var scene_root
var hippo
var visual
var head
var snout
var chin
var nostril_l
var nostril_r
var mouth
var mouth_material

var base_snout_position := Vector3.ZERO
var base_chin_position := Vector3.ZERO
var base_nostril_l_scale := Vector3.ONE
var base_nostril_r_scale := Vector3.ONE
var base_visual_rotation := Vector3.ZERO

var last_feed_count := 0
var last_action := ""
var chew_timer := 0.0
var yawn_timer := 0.0
var wake_timer := 0.0
var blink_reaction_timer := 0.0

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 90

func _process(delta):
    _ensure_binding()
    if not is_instance_valid(scene_root) or not is_instance_valid(hippo):
        return

    chew_timer = max(0.0, chew_timer - delta)
    yawn_timer = max(0.0, yawn_timer - delta)
    wake_timer = max(0.0, wake_timer - delta)
    blink_reaction_timer = max(0.0, blink_reaction_timer - delta)

    _track_interactions_and_actions()
    _animate_head_and_body(delta)
    _animate_mouth()
    _animate_nostrils()

func _ensure_binding():
    var current_scene := get_tree().current_scene
    if not current_scene:
        return
    if scene_root == current_scene and is_instance_valid(hippo):
        return

    scene_root = current_scene
    hippo = scene_root.find_child("BabyHippo", true, false)
    if not hippo:
        return

    visual = hippo.get_child(1) if hippo.get_child_count() > 1 else hippo
    head = hippo.find_child("Head", true, false)
    snout = hippo.find_child("Snout", true, false)
    chin = hippo.find_child("Chin", true, false)
    nostril_l = hippo.find_child("NostrilL", true, false)
    nostril_r = hippo.find_child("NostrilR", true, false)

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
    var counts = scene_root.get("interaction_counts")
    if typeof(counts) == TYPE_DICTIONARY:
        last_feed_count = int(counts.get("feed", 0))
    last_action = str(scene_root.get("current_action"))

func _build_mouth():
    if not is_instance_valid(visual) or is_instance_valid(mouth):
        return
    mouth = MeshInstance3D.new()
    mouth.name = "MouthInterior"
    var mesh := SphereMesh.new()
    mouth.mesh = mesh
    mouth.position = Vector3(1.88, 0.18, 0.0)
    mouth.scale = Vector3(0.42, 0.045, 0.42)
    mouth_material = StandardMaterial3D.new()
    mouth_material.albedo_color = Color(0.16, 0.035, 0.055)
    mouth_material.roughness = 0.62
    mouth.material_override = mouth_material
    visual.add_child(mouth)

func _track_interactions_and_actions():
    var counts = scene_root.get("interaction_counts")
    if typeof(counts) == TYPE_DICTIONARY:
        var feed_count := int(counts.get("feed", 0))
        if feed_count > last_feed_count:
            chew_timer = 1.65
            blink_reaction_timer = 0.55
        last_feed_count = feed_count

    var action := str(scene_root.get("current_action"))
    if action != last_action:
        if action == "sleep" and randf() < 0.42:
            yawn_timer = 1.35
        elif last_action == "sleep":
            wake_timer = 1.0
        last_action = action

func _animate_head_and_body(delta):
    var now := Time.get_ticks_msec() / 1000.0
    var action := str(scene_root.get("current_action"))
    var loaded_settings = scene_root.get("settings")
    var reduced_motion := typeof(loaded_settings) == TYPE_DICTIONARY and bool(loaded_settings.get("reduced_motion", false))
    var motion_scale := 0.35 if reduced_motion else 1.0

    if is_instance_valid(head):
        var target_yaw := 0.0
        match action:
            "approach":
                target_yaw = sin(now * 0.85) * 0.09
            "explore":
                target_yaw = sin(now * 0.62) * 0.13
            "play":
                target_yaw = sin(now * 1.8) * 0.11
            "sleep":
                target_yaw = -0.12 + sin(now * 0.28) * 0.025
            _:
                target_yaw = sin(now * 0.42) * 0.045
        head.rotation.y = lerp(head.rotation.y, target_yaw * motion_scale, 1.0 - exp(-6.0 * delta))

    if is_instance_valid(visual):
        var speed := hippo.velocity.length() if hippo is CharacterBody3D else 0.0
        var target_lean := 0.0
        if speed > 1.25:
            target_lean = -0.035
        elif speed > 0.2:
            target_lean = -0.015
        if action == "sleep":
            target_lean = 0.025
        visual.rotation.z = lerp(visual.rotation.z, base_visual_rotation.z + target_lean * motion_scale, 1.0 - exp(-7.0 * delta))

func _animate_mouth():
    if not is_instance_valid(chin) or not is_instance_valid(snout) or not is_instance_valid(mouth):
        return
    var now := Time.get_ticks_msec() / 1000.0
    var open_amount := 0.0

    if chew_timer > 0.0:
        open_amount = (sin(now * 15.0) * 0.5 + 0.5) * 0.12
    elif yawn_timer > 0.0:
        var phase := 1.0 - yawn_timer / 1.35
        open_amount = sin(phase * PI) * 0.24
    elif wake_timer > 0.0:
        open_amount = sin((1.0 - wake_timer) * PI) * 0.05

    chin.position = base_chin_position + Vector3(0.0, -open_amount, 0.0)
    snout.position = base_snout_position + Vector3(0.0, open_amount * 0.10, 0.0)
    mouth.scale.y = 0.045 + open_amount * 0.62
    mouth.visible = open_amount > 0.012

func _animate_nostrils():
    if not is_instance_valid(nostril_l) or not is_instance_valid(nostril_r):
        return
    var now := Time.get_ticks_msec() / 1000.0
    var action := str(scene_root.get("current_action"))
    var sniff_speed := 3.2
    var amplitude := 0.08
    if action == "explore":
        sniff_speed = 5.4
        amplitude = 0.18
    elif action == "approach":
        sniff_speed = 4.3
        amplitude = 0.13
    elif action == "sleep":
        sniff_speed = 1.45
        amplitude = 0.045

    var flare := 1.0 + (sin(now * sniff_speed) * 0.5 + 0.5) * amplitude
    nostril_l.scale = Vector3(base_nostril_l_scale.x * flare, base_nostril_l_scale.y, base_nostril_l_scale.z * flare)
    nostril_r.scale = Vector3(base_nostril_r_scale.x * flare, base_nostril_r_scale.y, base_nostril_r_scale.z * flare)
