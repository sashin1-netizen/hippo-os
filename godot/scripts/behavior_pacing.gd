extends Node

var host
var rng := RandomNumberGenerator.new()
var last_actions := {}

func _ready():
    process_priority = 38
    rng.seed = 730194
    for i in range(9):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        if actor == null:
            continue
        var action = str(actor.get("current_action"))
        last_actions[str(animal_id)] = action
        _apply_duration(actor, action)

func _process(_delta):
    if host == null:
        return
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        if actor == null:
            continue
        var key = str(animal_id)
        var action = str(actor.get("current_action"))
        if action != str(last_actions.get(key, "")):
            last_actions[key] = action
            _apply_duration(actor, action)

func _apply_duration(actor, action: String):
    var species = str(actor.get("species_id"))
    var range = _duration_range(species, action)
    var minimum = float(range.x)
    var maximum = float(range.y)
    var duration = rng.randf_range(minimum, maximum)
    # Never shorten a deliberate user interaction that has already requested more time.
    actor.action_timer = max(float(actor.get("action_timer")), duration)

func _duration_range(species: String, action: String) -> Vector2:
    if action in ["sleep", "rest"]:
        return Vector2(20.0, 42.0)
    if action == "eat":
        return Vector2(6.0, 11.0)
    if action in ["approach_owner", "follow_owner"]:
        return Vector2(7.0, 15.0)
    if action in ["withdraw", "hide"]:
        return Vector2(8.0, 17.0)

    if species == "pygmy_hippo":
        match action:
            "enter_water": return Vector2(13.0, 25.0)
            "wallow": return Vector2(12.0, 24.0)
            "forage": return Vector2(12.0, 23.0)
            "investigate": return Vector2(8.0, 15.0)
            "play": return Vector2(5.0, 9.0)
            "mark_territory": return Vector2(6.0, 11.0)
            _: return Vector2(7.0, 14.0)

    if species == "pig":
        match action:
            "root": return Vector2(13.0, 26.0)
            "forage": return Vector2(11.0, 22.0)
            "investigate": return Vector2(8.0, 16.0)
            "push_object": return Vector2(8.0, 16.0)
            "wallow": return Vector2(11.0, 21.0)
            "social_contact": return Vector2(8.0, 16.0)
            "play": return Vector2(6.0, 11.0)
            _: return Vector2(7.0, 14.0)

    if species == "shar_pei":
        match action:
            "observe": return Vector2(13.0, 27.0)
            "rest_near_owner": return Vector2(16.0, 31.0)
            "patrol": return Vector2(12.0, 24.0)
            "investigate": return Vector2(8.0, 15.0)
            "play": return Vector2(5.0, 9.0)
            _: return Vector2(8.0, 16.0)

    return Vector2(7.0, 14.0)
