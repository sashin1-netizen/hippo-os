extends Node

# Lightweight secondary motion for the procedural pig and Shar-Pei fallbacks.
# CompanionRoster remains authoritative for locomotion, breathing, ears and tails.
# This layer only adds randomized blinks and subtle head-attention motion, and it
# automatically stays out of the way when a licensed ProductionVisual rig is present.

class MotionState:
    var body: Node3D
    var head: Node3D
    var eye_l: Node3D
    var eye_r: Node3D
    var eye_l_base: Vector3
    var eye_r_base: Vector3
    var head_base_rotation: Vector3
    var blink_timer := 2.0
    var blink_phase := 0.0
    var glance_timer := 2.5
    var target_yaw := 0.0
    var target_pitch := 0.0
    var phase := 0.0

var scene_root: Node3D
var states: Array[MotionState] = []
var bound := false

func _ready() -> void:
    randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 1160
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            var pig := scene_root.find_child("PorkyPig", true, false) as Node3D
            var dog := scene_root.find_child("BaoSharPei", true, false) as Node3D
            if pig != null and dog != null:
                _register_fallback(pig, 0.0)
                _register_fallback(dog, 2.1)
                break
        await get_tree().process_frame

    if states.is_empty():
        push_warning("CompanionLifeMotion found no procedural companion visuals")
        return
    bound = true
    set_process(true)

func _register_fallback(body: Node3D, phase: float) -> void:
    if body.find_child("ProductionVisual", false, false) != null:
        return
    var head := body.find_child("Head", true, false) as Node3D
    var eye_l := body.find_child("EyeL", true, false) as Node3D
    var eye_r := body.find_child("EyeR", true, false) as Node3D
    if head == null or eye_l == null or eye_r == null:
        return
    var state := MotionState.new()
    state.body = body
    state.head = head
    state.eye_l = eye_l
    state.eye_r = eye_r
    state.eye_l_base = eye_l.scale
    state.eye_r_base = eye_r.scale
    state.head_base_rotation = head.rotation
    state.blink_timer = randf_range(1.8, 4.8)
    state.glance_timer = randf_range(2.0, 5.0)
    state.phase = phase
    states.append(state)

func _process(delta: float) -> void:
    if not bound:
        return
    var reduced := _reduced_motion()
    var motion_scale := 0.32 if reduced else 1.0
    var now := float(Time.get_ticks_msec()) / 1000.0

    for state in states:
        if state.body == null or not is_instance_valid(state.body):
            continue
        if state.body.find_child("ProductionVisual", false, false) != null:
            continue

        _update_blink(state, delta)
        _update_attention(state, delta, now, motion_scale)

func _update_blink(state: MotionState, delta: float) -> void:
    state.blink_timer -= delta
    if state.blink_phase <= 0.0 and state.blink_timer <= 0.0:
        state.blink_phase = 0.18
        state.blink_timer = randf_range(2.2, 5.8)

    var eye_factor := 1.0
    if state.blink_phase > 0.0:
        state.blink_phase = maxf(0.0, state.blink_phase - delta)
        var progress := 1.0 - state.blink_phase / 0.18
        eye_factor = 1.0 - sin(progress * PI) * 0.90

    if is_instance_valid(state.eye_l):
        state.eye_l.scale = Vector3(state.eye_l_base.x, maxf(0.08, state.eye_l_base.y * eye_factor), state.eye_l_base.z)
    if is_instance_valid(state.eye_r):
        state.eye_r.scale = Vector3(state.eye_r_base.x, maxf(0.08, state.eye_r_base.y * eye_factor), state.eye_r_base.z)

func _update_attention(state: MotionState, delta: float, now: float, motion_scale: float) -> void:
    if not is_instance_valid(state.head):
        return
    state.glance_timer -= delta
    if state.glance_timer <= 0.0:
        state.glance_timer = randf_range(2.4, 5.8)
        state.target_yaw = randf_range(-0.14, 0.14) * motion_scale
        state.target_pitch = randf_range(-0.045, 0.055) * motion_scale

    var settle_yaw := sin(now * 0.31 + state.phase) * 0.024 * motion_scale
    var settle_pitch := sin(now * 0.23 + state.phase * 0.7) * 0.012 * motion_scale
    var desired_yaw := state.head_base_rotation.y + state.target_yaw + settle_yaw
    var desired_pitch := state.head_base_rotation.x + state.target_pitch + settle_pitch
    var response := 1.0 - exp(-2.8 * delta)
    state.head.rotation.y = lerpf(state.head.rotation.y, desired_yaw, response)
    state.head.rotation.x = lerpf(state.head.rotation.x, desired_pitch, response)

func _reduced_motion() -> bool:
    if scene_root == null:
        return false
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) == TYPE_DICTIONARY:
        return bool((settings_variant as Dictionary).get("reduced_motion", false))
    return false
