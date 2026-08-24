extends "res://scripts/launch_shell.gd"

var interaction_hint := ""

func _open_world_controller():
    return get_node_or_null("OpenWorldController")

func flutter_action(action_name):
    var action = str(action_name)

    if action.begins_with("roam:"):
        var parts = action.split(":")
        if parts.size() != 3:
            return false
        var controller = _open_world_controller()
        if controller == null:
            return false
        controller.set_move_input(float(parts[1]), float(parts[2]))
        return true

    if action == "roam_stop":
        var controller = _open_world_controller()
        if controller != null:
            controller.stop_move()
        return true

    if action.begins_with("look:"):
        var parts = action.split(":")
        if parts.size() != 3:
            return false
        var controller = _open_world_controller()
        if controller == null:
            return false
        controller.add_look_delta(float(parts[1]), float(parts[2]))
        return true

    if action.begins_with("sprint:"):
        var controller = _open_world_controller()
        if controller == null:
            return false
        controller.set_sprinting(action.trim_prefix("sprint:") == "1")
        return true

    if action.begins_with("select:"):
        var animal_id = action.trim_prefix("select:")
        if animal_id not in ["hippo_01", "pig_01", "sharpei_01"]:
            return false
        _select_animal(animal_id)
        interaction_hint = ""
        _push_flutter_status()
        return true

    if action == "feed":
        if not _interaction_allowed():
            _set_too_far_hint()
            return true
        interaction_hint = ""
        return super(action)

    if action.begins_with("pet:"):
        var region = action.trim_prefix("pet:")
        if region not in ["forehead", "cheek", "snout", "back", "belly", "ears"]:
            return false
        if not _interaction_allowed():
            _set_too_far_hint()
            return true
        var actor = _selected_actor()
        if actor == null:
            return false
        var quality = actor.pet(region)
        if quality >= 0.22:
            sanctuary.add_journal_event("interaction", selected_id, "%s accepted touch on the %s." % [actor.display_name(), region], 0.42)
        else:
            sanctuary.add_journal_event("boundary", selected_id, "%s moved away from touch on the %s." % [actor.display_name(), region], 0.48)
        interaction_hint = ""
        _save_sanctuary()
        _push_flutter_status()
        return true

    return super(action)

func _interaction_allowed() -> bool:
    var controller = _open_world_controller()
    if controller == null or not controller.is_free_roam():
        return true
    return controller.can_interact()

func _set_too_far_hint():
    var actor = _selected_actor()
    var name = actor.display_name() if actor != null else "the animal"
    interaction_hint = "Move closer to %s to interact." % name
    _push_flutter_status()

func get_flutter_status():
    var payload = super()
    payload["selected_id"] = selected_id
    payload["journal_json"] = JSON.stringify(sanctuary.recent_journal(36))
    payload["interaction_hint"] = interaction_hint

    var controller = _open_world_controller()
    if controller != null:
        var roam = controller.snapshot()
        for key in roam.keys():
            payload[key] = roam[key]

    var hippo = animals.get("hippo_01", null)
    var pig = animals.get("pig_01", null)
    var dog = animals.get("sharpei_01", null)
    if hippo != null:
        payload["hippo_x"] = hippo.global_position.x
        payload["hippo_z"] = hippo.global_position.z
    if pig != null:
        payload["pig_x"] = pig.global_position.x
        payload["pig_z"] = pig.global_position.z
    if dog != null:
        payload["dog_x"] = dog.global_position.x
        payload["dog_z"] = dog.global_position.z
    return payload
