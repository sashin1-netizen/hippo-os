extends Node

var host

func _ready():
    process_priority = 32
    for i in range(8):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    for animal_id in animals.keys():
        var actor = animals[animal_id]
        if actor is CharacterBody3D:
            # Layer 1 is world/terrain, layer 2 is animals. Each animal remains on
            # layer 2 and now masks both so bodies cannot occupy the same space.
            actor.collision_layer = 2
            actor.collision_mask = 3
            actor.safe_margin = 0.035
            actor.floor_stop_on_slope = true
            actor.floor_snap_length = 0.18
