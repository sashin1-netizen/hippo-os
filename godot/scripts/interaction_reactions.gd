extends Node

const REACTION_BONES := ["NeckB", "Neck2", "HeadRoot", "Skull", "Spine", "Chest"]

var host
var last_event_fingerprint := ""
var reactions := {}
var poll_timer := 0.0
var skeletons := {}
var bone_bases := {}

func _ready():
    process_priority = 95
    for i in range(10):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _prepare_models()

func _process(delta):
    if host == null:
        return
    poll_timer -= delta
    if poll_timer <= 0.0:
        poll_timer = 0.12
        _poll_latest_touch_event()
    _animate_reactions(delta)

func _prepare_models():
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        if actor == null:
            continue
        var model = actor.get("production_model")
        if not model is Node3D:
            continue
        model.set_meta("touch_base_rx", float(model.rotation_degrees.x))
        model.set_meta("touch_base_rz", float(model.rotation_degrees.z))
        var skeleton = _find_skeleton(model)
        if skeleton != null:
            var key = str(animal_id)
            skeletons[key] = skeleton
            bone_bases[key] = _capture_bone_bases(skeleton)

func _capture_bone_bases(skeleton: Skeleton3D) -> Dictionary:
    var bases := {}
    for bone_name in REACTION_BONES:
        var index = skeleton.find_bone(bone_name)
        if index >= 0:
            bases[bone_name] = skeleton.get_bone_pose_rotation(index)
    return bases

func _find_skeleton(node):
    if node is Skeleton3D:
        return node
    for child in node.get_children():
        var found = _find_skeleton(child)
        if found != null:
            return found
    return null

func _poll_latest_touch_event():
    var sanctuary = host.get("sanctuary")
    if sanctuary == null:
        return
    var recent = sanctuary.recent_journal(1)
    if recent.is_empty():
        return
    var event = recent[0]
    if typeof(event) != TYPE_DICTIONARY:
        return
    var kind = str(event.get("kind", ""))
    if kind not in ["interaction", "boundary"]:
        return
    var text = str(event.get("text", ""))
    if not "touch on the " in text:
        return
    var fingerprint = "%s|%s|%s" % [str(event.get("unix", 0)), kind, text]
    if fingerprint == last_event_fingerprint:
        return
    last_event_fingerprint = fingerprint
    var animal_id = str(event.get("animal_id", ""))
    if animal_id.is_empty():
        return
    var region = text.get_slice("touch on the ", 1).get_slice(".", 0).strip_edges()
    if region not in ["forehead", "cheek", "snout", "back", "belly", "ears"]:
        region = "forehead"
    reactions[animal_id] = {
        "remaining": 1.35 if kind == "interaction" else 1.0,
        "duration": 1.35 if kind == "interaction" else 1.0,
        "region": region,
        "accepted": kind == "interaction"
    }

func _animate_reactions(delta):
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        if actor == null:
            continue
        var model = actor.get("production_model")
        if not model is Node3D:
            continue
        var key = str(animal_id)
        var base_rx = float(model.get_meta("touch_base_rx", 0.0))
        var base_rz = float(model.get_meta("touch_base_rz", 0.0))
        var skeleton = skeletons.get(key, null)

        if not reactions.has(animal_id):
            model.rotation_degrees.x = lerp(float(model.rotation_degrees.x), base_rx, min(delta * 6.0, 1.0))
            model.rotation_degrees.z = lerp(float(model.rotation_degrees.z), base_rz, min(delta * 6.0, 1.0))
            if skeleton is Skeleton3D:
                _reset_reaction_bones(key, skeleton, min(delta * 12.0, 1.0))
            continue

        var reaction = reactions[animal_id]
        var remaining = max(0.0, float(reaction.get("remaining", 0.0)) - delta)
        reaction["remaining"] = remaining
        reactions[animal_id] = reaction
        var duration = max(0.1, float(reaction.get("duration", 1.0)))
        var progress = 1.0 - remaining / duration
        var pulse = sin(clamp(progress, 0.0, 1.0) * PI)
        var accepted = bool(reaction.get("accepted", true))
        var region = str(reaction.get("region", "forehead"))

        var skeletal_applied = false
        if skeleton is Skeleton3D:
            # Start every reaction frame from the captured neutral pose. This keeps
            # touch offsets temporary and prevents cumulative neck/head deformation.
            _reset_reaction_bones(key, skeleton, 1.0)
            skeletal_applied = _apply_skeletal_reaction(key, skeleton, region, accepted, pulse)

        # Whole-model movement remains a deliberately tiny secondary weight shift.
        # It is also the fallback for any future rig that lacks the named production bones.
        var target_rx = base_rx
        var target_rz = base_rz
        if accepted:
            if region in ["forehead", "snout"]:
                target_rx += (0.9 if skeletal_applied else 3.6) * pulse
            elif region in ["cheek", "ears"]:
                target_rz += (0.8 if skeletal_applied else 3.2) * pulse
                target_rx += (0.4 if skeletal_applied else 1.2) * pulse
            elif region == "back":
                target_rx += (0.5 if skeletal_applied else 1.8) * pulse
            elif region == "belly":
                target_rx += (0.8 if skeletal_applied else 4.2) * pulse
        else:
            target_rx -= (1.4 if skeletal_applied else 5.2) * pulse
            target_rz += (0.8 if skeletal_applied else 2.4) * pulse
        model.rotation_degrees.x = lerp(float(model.rotation_degrees.x), target_rx, min(delta * 14.0, 1.0))
        model.rotation_degrees.z = lerp(float(model.rotation_degrees.z), target_rz, min(delta * 14.0, 1.0))
        if remaining <= 0.0:
            reactions.erase(animal_id)
            if skeleton is Skeleton3D:
                _reset_reaction_bones(key, skeleton, 1.0)

func _apply_skeletal_reaction(animal_id: String, skeleton: Skeleton3D, region: String, accepted: bool, pulse: float) -> bool:
    var applied = false
    if accepted:
        match region:
            "forehead", "snout":
                applied = _offset_bone(animal_id, skeleton, "NeckB", Vector3(1, 0, 0), deg_to_rad(4.0) * pulse) or applied
                applied = _offset_bone(animal_id, skeleton, "Neck2", Vector3(1, 0, 0), deg_to_rad(4.5) * pulse) or applied
                applied = _offset_bone(animal_id, skeleton, "HeadRoot", Vector3(1, 0, 0), deg_to_rad(5.0) * pulse) or applied
                applied = _offset_bone(animal_id, skeleton, "Skull", Vector3(1, 0, 0), deg_to_rad(-2.4) * pulse) or applied
            "cheek":
                applied = _offset_bone(animal_id, skeleton, "Neck2", Vector3(0, 0, 1), deg_to_rad(4.8) * pulse) or applied
                applied = _offset_bone(animal_id, skeleton, "HeadRoot", Vector3(0, 1, 0), deg_to_rad(4.0) * pulse) or applied
            "ears":
                applied = _offset_bone(animal_id, skeleton, "Neck2", Vector3(0, 0, 1), deg_to_rad(5.5) * pulse) or applied
                applied = _offset_bone(animal_id, skeleton, "Skull", Vector3(0, 1, 0), deg_to_rad(-3.8) * pulse) or applied
            "back":
                applied = _offset_bone(animal_id, skeleton, "Spine", Vector3(1, 0, 0), deg_to_rad(-2.4) * pulse) or applied
                applied = _offset_bone(animal_id, skeleton, "Chest", Vector3(1, 0, 0), deg_to_rad(2.8) * pulse) or applied
            "belly":
                applied = _offset_bone(animal_id, skeleton, "Spine", Vector3(0, 0, 1), deg_to_rad(2.5) * pulse) or applied
                applied = _offset_bone(animal_id, skeleton, "Chest", Vector3(1, 0, 0), deg_to_rad(3.2) * pulse) or applied
    else:
        applied = _offset_bone(animal_id, skeleton, "NeckB", Vector3(1, 0, 0), deg_to_rad(-7.0) * pulse) or applied
        applied = _offset_bone(animal_id, skeleton, "Neck2", Vector3(0, 1, 0), deg_to_rad(6.0) * pulse) or applied
        applied = _offset_bone(animal_id, skeleton, "HeadRoot", Vector3(0, 0, 1), deg_to_rad(4.5) * pulse) or applied
    return applied

func _offset_bone(animal_id: String, skeleton: Skeleton3D, bone_name: String, axis: Vector3, radians: float) -> bool:
    var index = skeleton.find_bone(bone_name)
    if index < 0:
        return false
    var bases = bone_bases.get(animal_id, {})
    if typeof(bases) != TYPE_DICTIONARY or not bases.has(bone_name):
        return false
    var base: Quaternion = bases[bone_name]
    var offset = Quaternion(axis.normalized(), radians)
    skeleton.set_bone_pose_rotation(index, base * offset)
    return true

func _reset_reaction_bones(animal_id: String, skeleton: Skeleton3D, weight: float):
    var bases = bone_bases.get(animal_id, {})
    if typeof(bases) != TYPE_DICTIONARY:
        return
    for bone_name in bases.keys():
        var index = skeleton.find_bone(str(bone_name))
        if index < 0:
            continue
        var base: Quaternion = bases[bone_name]
        var current = skeleton.get_bone_pose_rotation(index)
        skeleton.set_bone_pose_rotation(index, current.slerp(base, clamp(weight, 0.0, 1.0)))
