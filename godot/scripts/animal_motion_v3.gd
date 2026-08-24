extends Node

var host

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
        var clip = _desired_action_clip(actor, action)
        if clip.is_empty():
            continue
        var player = actor.get("animation_player")
        if player == null or not player is AnimationPlayer or not player.has_animation(clip):
            continue
        # animal_actor.gd maintains its own default locomotion/eat/rest animation loop.
        # Reassert species-specific behaviour clips after the physics tick so actions such
        # as rooting, wallowing, sniffing and observing remain visible for their full state.
        if str(actor.get("active_animation")) != clip or player.current_animation != clip:
            player.play(clip, 0.22)
            actor.set("active_animation", clip)

func _desired_action_clip(actor, action):
    var species = str(actor.get("species_id"))
    if species == "pygmy_hippo":
        if action == "wallow":
            return "wallow"
        if action in ["investigate", "hide", "enter_water"]:
            return "sniff"
    elif species == "pig":
        if action in ["root", "forage"]:
            return "root"
        if action in ["investigate", "push_object"]:
            return "sniff"
    elif species == "shar_pei":
        if action in ["observe", "patrol"]:
            return "observe"
        if action == "investigate":
            return "sniff"
    return ""
