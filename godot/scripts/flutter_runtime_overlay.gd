extends "res://scripts/launch_shell.gd"

const PRIMARY_SAVE := "user://sanctuary_save.json"
const BACKUP_SAVE := "user://sanctuary_save.bak.json"
const TEMP_SAVE := "user://sanctuary_save.tmp.json"

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

func _save_sanctuary():
    if sanctuary == null:
        return
    for id_key in animals.keys():
        sanctuary.update_animal(id_key, animals[id_key].to_dict())

    var payload = sanctuary.to_dict()
    if not _is_valid_save(payload):
        push_error("Refusing to write invalid sanctuary state")
        return
    var serialized = JSON.stringify(payload)
    var round_trip = JSON.parse_string(serialized)
    if not _is_valid_save(round_trip):
        push_error("Sanctuary save failed round-trip validation")
        return

    var temp_file = FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
    if temp_file == null:
        push_error("Unable to open sanctuary temporary save")
        return
    temp_file.store_string(serialized)
    temp_file.flush()
    temp_file.close()

    if FileAccess.file_exists(PRIMARY_SAVE) and _load_valid_save(PRIMARY_SAVE) != null:
        _copy_user_file(PRIMARY_SAVE, BACKUP_SAVE)

    var primary_abs = ProjectSettings.globalize_path(PRIMARY_SAVE)
    var temp_abs = ProjectSettings.globalize_path(TEMP_SAVE)
    if FileAccess.file_exists(PRIMARY_SAVE):
        DirAccess.remove_absolute(primary_abs)
    var rename_error = DirAccess.rename_absolute(temp_abs, primary_abs)
    if rename_error != OK:
        push_error("Atomic sanctuary save replace failed: %s" % rename_error)
        if not FileAccess.file_exists(PRIMARY_SAVE) and FileAccess.file_exists(BACKUP_SAVE):
            _copy_user_file(BACKUP_SAVE, PRIMARY_SAVE)

func _load_sanctuary():
    var primary = _load_valid_save(PRIMARY_SAVE)
    if primary != null:
        sanctuary.from_dict(primary)
        return

    if FileAccess.file_exists(PRIMARY_SAVE):
        _archive_corrupt_primary()

    var backup = _load_valid_save(BACKUP_SAVE)
    if backup != null:
        sanctuary.from_dict(backup)
        sanctuary.add_journal_event("recovery", "sanctuary", "The sanctuary recovered safely from its backup save.", 0.85)
        _save_sanctuary()

func _load_valid_save(path: String):
    if not FileAccess.file_exists(path):
        return null
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var raw = file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(raw)
    if not _is_valid_save(parsed):
        return null
    return parsed

func _is_valid_save(data) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    var version = int(data.get("save_version", 1))
    if version < 1 or version > 100:
        return false
    var has_legacy = data.has("hippo_name")
    var animals_value = data.get("animals", {})
    if not has_legacy and typeof(animals_value) != TYPE_DICTIONARY:
        return false
    if data.has("settings") and typeof(data.get("settings")) != TYPE_DICTIONARY:
        return false
    if data.has("journal") and typeof(data.get("journal")) != TYPE_ARRAY:
        return false
    return true

func _copy_user_file(from_path: String, to_path: String) -> bool:
    if not FileAccess.file_exists(from_path):
        return false
    var source = FileAccess.open(from_path, FileAccess.READ)
    if source == null:
        return false
    var bytes = source.get_buffer(source.get_length())
    source.close()
    var target = FileAccess.open(to_path, FileAccess.WRITE)
    if target == null:
        return false
    target.store_buffer(bytes)
    target.flush()
    target.close()
    return true

func _archive_corrupt_primary():
    if not FileAccess.file_exists(PRIMARY_SAVE):
        return
    var corrupt_path = "user://sanctuary_save_corrupt_%d.json" % int(Time.get_unix_time_from_system())
    DirAccess.rename_absolute(
        ProjectSettings.globalize_path(PRIMARY_SAVE),
        ProjectSettings.globalize_path(corrupt_path)
    )
