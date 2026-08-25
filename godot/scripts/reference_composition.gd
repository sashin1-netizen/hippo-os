extends Node

# Keeps the live companions staged like a wildlife composition instead of clustered
# around the origin: Mochi owns the foreground, Porky reads left-midground and Bao
# reads right-midground. The companions still run their autonomous behaviour logic.

const PIG_HOME := Vector3(-3.65, 0.72, -3.75)
const DOG_HOME := Vector3(3.55, 0.75, -3.55)
const HIPPO_HOME := Vector3(0.0, 0.80, 0.70)
const MIDGROUND_FRONT_Z := -2.35

var scene_root: Node3D
var roster: Node
var initialized := false
var timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 255
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            var companions_variant: Variant = roster_candidate.get("companions")
            if typeof(companions_variant) == TYPE_DICTIONARY and (companions_variant as Dictionary).size() >= 3:
                scene_root = candidate as Node3D
                roster = roster_candidate
                break
        await get_tree().process_frame

    if scene_root == null or roster == null:
        push_warning("ReferenceComposition could not bind to the sanctuary roster")
        return
    _initial_stage()

func _process(delta: float) -> void:
    if scene_root == null or roster == null:
        return
    timer -= delta
    if timer <= 0.0:
        timer = 0.45
        _maintain_depth_composition()

func _initial_stage() -> void:
    if initialized:
        return
    var companions := _companions()
    var hippo := _node_for(companions, "hippo")
    var pig := _node_for(companions, "pig")
    var dog := _node_for(companions, "sharpei")
    if hippo != null:
        hippo.position = HIPPO_HOME
    if pig != null:
        pig.position = PIG_HOME
        _set_target(companions, "pig", PIG_HOME + Vector3(0.45, 0.0, 0.25))
    if dog != null:
        dog.position = DOG_HOME
        _set_target(companions, "sharpei", DOG_HOME + Vector3(-0.40, 0.0, 0.20))

    # Three-quarter wildlife framing: enough distance to show habitat and the two
    # supporting companions, while Mochi remains the foreground emotional anchor.
    scene_root.set("orbit_yaw", 0.34)
    scene_root.set("orbit_pitch", -0.055)
    scene_root.set("orbit_distance", 9.8)
    initialized = true

func _maintain_depth_composition() -> void:
    var companions := _companions()
    if companions.is_empty():
        return

    var hippo := _node_for(companions, "hippo")
    var pig := _node_for(companions, "pig")
    var dog := _node_for(companions, "sharpei")

    # Supporting animals live in the midground, not on top of Mochi. Clamp only the
    # compositional boundary; their AI still chooses actions and wanders within it.
    if pig != null:
        if pig.position.z > MIDGROUND_FRONT_Z:
            pig.position.z = MIDGROUND_FRONT_Z
        if pig.position.x > -1.35:
            pig.position.x = -1.35
        if pig.position.distance_to(PIG_HOME) > 2.35:
            pig.position = pig.position.lerp(PIG_HOME, 0.18)
        if pig.position.z > -2.65 or pig.position.distance_to(PIG_HOME) > 1.85:
            _set_target(companions, "pig", PIG_HOME + Vector3(randf_range(-0.55, 0.55), 0.0, randf_range(-0.40, 0.40)))

    if dog != null:
        if dog.position.z > MIDGROUND_FRONT_Z:
            dog.position.z = MIDGROUND_FRONT_Z
        if dog.position.x < 1.35:
            dog.position.x = 1.35
        if dog.position.distance_to(DOG_HOME) > 2.35:
            dog.position = dog.position.lerp(DOG_HOME, 0.18)
        if dog.position.z > -2.65 or dog.position.distance_to(DOG_HOME) > 1.85:
            _set_target(companions, "sharpei", DOG_HOME + Vector3(randf_range(-0.50, 0.50), 0.0, randf_range(-0.40, 0.40)))

    # Avoid all three animals visually stacking even if the autonomous pathfinder
    # briefly chooses a converging target.
    if hippo != null and pig != null and hippo.position.distance_to(pig.position) < 2.35:
        _set_target(companions, "pig", PIG_HOME)
    if hippo != null and dog != null and hippo.position.distance_to(dog.position) < 2.35:
        _set_target(companions, "sharpei", DOG_HOME)

func _companions() -> Dictionary:
    var value: Variant = roster.get("companions") if roster != null else {}
    return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _node_for(companions: Dictionary, species: String) -> Node3D:
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return null
    var node := (data_variant as Dictionary).get("node") as Node3D
    return node if node != null and is_instance_valid(node) else null

func _set_target(companions: Dictionary, species: String, target: Vector3) -> void:
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return
    var data := data_variant as Dictionary
    data["target"] = target
    data["action"] = "wander" if species == "pig" else "watch"
    data["action_timer"] = randf_range(4.0, 7.0)
