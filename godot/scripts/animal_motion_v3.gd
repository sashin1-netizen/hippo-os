extends Node

var host
var last_actions = {}

func _ready():
    for i in range(6):
        await get_tree().process_frame
    host = get_parent()

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
        var action = str(actor.get("current_action"))
        if str(last_actions.get(animal_id, "")) == action:
            continue
        last_actions[animal_id] = action
        _apply_action_clip(actor, action)

func _apply_action_clip(actor, action):
    var player = actor.get("animation_player")
    if player == null or not player is AnimationPlayer:
        return
    var species = str(actor.get("species_id"))
    var clip = ""
    if species == "pygmy_hippo":
        if action == "wallow":
            clip = "wallow"
        elif action in ["investigate", "hide", "enter_water"]:
            clip = "sniff"
    elif species == "pig":
        if action in ["root", "forage"]:
            clip = "root"
        elif action in ["investigate", "push_object"]:
            clip = "sniff"
    elif species == "shar_pei":
        if action in ["observe", "patrol"]:
            clip = "observe"
        elif action == "investigate":
            clip = "sniff"
    if not clip.is_empty() and player.has_animation(clip):
        player.play(clip, 0.22)
