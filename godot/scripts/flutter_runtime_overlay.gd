extends "res://scripts/launch_shell.gd"

func flutter_action(action_name):
    var action = str(action_name)
    if action.begins_with("select:"):
        var animal_id = action.trim_prefix("select:")
        if animal_id not in ["hippo_01", "pig_01", "sharpei_01"]:
            return false
        _select_animal(animal_id)
        _push_flutter_status()
        return true

    if action.begins_with("pet:"):
        var region = action.trim_prefix("pet:")
        if region not in ["forehead", "cheek", "snout", "back", "belly", "ears"]:
            return false
        var actor = _selected_actor()
        if actor == null:
            return false
        actor.pet(region)
        _save_sanctuary()
        _push_flutter_status()
        return true

    return super(action)
