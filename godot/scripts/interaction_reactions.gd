extends Node

var host
var last_event_fingerprint := ""
var reactions := {}
var poll_timer := 0.0

func _ready():
    process_priority = 62
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
        "remaining": 1.25 if kind == "interaction" else 0.95,
        "duration": 1.25 if kind == "interaction" else 0.95,
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
        var base_rx = float(model.get_meta("touch_base_rx", 0.0))
        var base_rz = float(model.get_meta("touch_base_rz", 0.0))
        if not reactions.has(animal_id):
            model.rotation_degrees.x = lerp(float(model.rotation_degrees.x), base_rx, min(delta * 6.0, 1.0))
            model.rotation_degrees.z = lerp(float(model.rotation_degrees.z), base_rz, min(delta * 6.0, 1.0))
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
        var target_rx = base_rx
        var target_rz = base_rz
        if accepted:
            if region in ["forehead", "snout"]:
                target_rx += 3.6 * pulse
            elif region in ["cheek", "ears"]:
                target_rz += 3.2 * pulse
                target_rx += 1.2 * pulse
            elif region == "back":
                target_rx += 1.8 * pulse
            elif region == "belly":
                target_rx += 4.2 * pulse
        else:
            target_rx -= 5.2 * pulse
            target_rz += 2.4 * pulse
        model.rotation_degrees.x = lerp(float(model.rotation_degrees.x), target_rx, min(delta * 14.0, 1.0))
        model.rotation_degrees.z = lerp(float(model.rotation_degrees.z), target_rz, min(delta * 14.0, 1.0))
        if remaining <= 0.0:
            reactions.erase(animal_id)
