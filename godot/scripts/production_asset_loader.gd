extends Node

# Production animal model bridge.
# The simulation/collision bodies stay stable while final rigged GLBs replace only
# procedural visuals. Behaviour, saving, audio emitters and interaction logic remain
# authoritative, and this bridge translates live actions into authored animation clips.

const MODEL_PATHS := {
    "hippo": "res://assets/animals/mochi.glb",
    "pig": "res://assets/animals/porky.glb",
    "dog": "res://assets/animals/bao.glb",
}

const BODY_NAMES := {
    "hippo": "BabyHippo",
    "pig": "PorkyPig",
    "dog": "BaoSharPei",
}

const ANIMATION_ALIASES := {
    "idle": ["idle", "Idle", "idle_01", "Idle_01", "stand_idle", "Standing Idle", "standing_idle"],
    "walk": ["walk", "Walk", "walking", "Walking", "walk_cycle", "Walk Cycle"],
    "run": ["run", "Run", "running", "Running", "run_cycle", "Run Cycle"],
    "sleep": ["sleep", "Sleep", "sleeping", "Sleeping", "lay", "lying"],
    "wake": ["wake", "Wake", "wake_up", "Wake Up", "stand_up"],
    "eat": ["eat", "Eat", "eating", "Eating", "chew", "feeding"],
    "drink": ["drink", "Drink", "drinking", "Drinking"],
    "play": ["play", "Play", "playing", "Playing", "playful"],
    "pet_react": ["pet_react", "Pet React", "happy", "Happy", "affection", "reaction"],
    "call_react": ["call_react", "Call React", "alert", "Alert", "look", "watch"],
    "sniff": ["sniff", "Sniff", "sniffing", "root", "Root", "rooting"],
    "mud": ["mud", "Mud", "mud_play", "Mud Play", "roll"],
    "water_play": ["water_play", "Water Play", "swim", "Swimming", "splash"],
    "yawn": ["yawn", "Yawn"],
    "zoomies": ["zoomies", "Zoomies", "sprint", "Sprint", "run", "Run"],
}

var scene_root: Node3D
var installed_models: Dictionary = {}
var animation_players: Dictionary = {}
var active_animation_keys: Dictionary = {}
var animation_sync_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 165
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(300):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            if _all_bodies_present():
                break
        await get_tree().process_frame

    if scene_root == null or not _all_bodies_present():
        push_warning("ProductionAssetLoader could not bind to companion bodies")
        return

    for species in MODEL_PATHS.keys():
        _install_if_available(String(species))

    if not installed_models.is_empty():
        set_process(true)

func _process(delta: float) -> void:
    animation_sync_timer -= delta
    if animation_sync_timer > 0.0:
        return
    animation_sync_timer = 0.10

    for species_value in installed_models.keys():
        var species := String(species_value)
        _sync_animation(species)

func _all_bodies_present() -> bool:
    if scene_root == null:
        return false
    for species in BODY_NAMES.keys():
        if scene_root.find_child(String(BODY_NAMES[species]), true, false) == null:
            return false
    return true

func _install_if_available(species: String) -> void:
    var model_path := String(MODEL_PATHS.get(species, ""))
    if model_path.is_empty() or not ResourceLoader.exists(model_path):
        return

    var body_name := String(BODY_NAMES.get(species, ""))
    var body := scene_root.find_child(body_name, true, false) as Node3D
    if body == null:
        return

    var resource: Resource = load(model_path)
    if not resource is PackedScene:
        push_warning("Production model is not an importable PackedScene: %s" % model_path)
        return

    var packed := resource as PackedScene
    var visual := packed.instantiate() as Node3D
    if visual == null:
        push_warning("Production model could not instantiate: %s" % model_path)
        return

    visual.name = "ProductionVisual"
    visual.set_meta("hippo_os_production_visual", true)
    body.add_child(visual)
    _normalize_visual_transform(visual, species)
    _hide_procedural_visuals(body, visual)

    var player := _find_animation_player(visual)
    if player != null:
        animation_players[species] = player
        _play_animation_key(species, "idle", true)

    installed_models[species] = visual

func _normalize_visual_transform(visual: Node3D, _species: String) -> void:
    visual.position = Vector3.ZERO
    visual.rotation = Vector3.ZERO
    visual.scale = Vector3.ONE

func _hide_procedural_visuals(body: Node3D, production_visual: Node3D) -> void:
    for child in body.get_children():
        if child == production_visual or child is CollisionShape3D:
            continue
        if child is Node3D:
            (child as Node3D).visible = false

func _sync_animation(species: String) -> void:
    if not animation_players.has(species):
        return
    var desired := _desired_animation_key(species)
    if desired.is_empty():
        desired = "idle"
    if String(active_animation_keys.get(species, "")) == desired:
        return
    _play_animation_key(species, desired, false)

func _desired_animation_key(species: String) -> String:
    var body_name := String(BODY_NAMES.get(species, ""))
    var body := scene_root.find_child(body_name, true, false) as CharacterBody3D
    var moving_fast := body != null and body.velocity.length() > 1.25
    var moving := body != null and body.velocity.length() > 0.16

    if species == "hippo":
        var action := String(scene_root.get("current_action"))
        match action:
            "sleep":
                return "sleep"
            "drink":
                return "drink"
            "mud":
                return "mud"
            "play":
                return "zoomies" if moving_fast else "play"
            "approach", "wander", "explore":
                return "run" if moving_fast else "walk"
            "feed", "eat":
                return "eat"
            _:
                return "walk" if moving else "idle"

    var roster := get_node_or_null("/root/CompanionRoster")
    if roster == null:
        return "run" if moving_fast else ("walk" if moving else "idle")
    var companions_value: Variant = roster.get("companions")
    if typeof(companions_value) != TYPE_DICTIONARY:
        return "run" if moving_fast else ("walk" if moving else "idle")

    var companions := companions_value as Dictionary
    var roster_key := "pig" if species == "pig" else "sharpei"
    if not companions.has(roster_key):
        return "run" if moving_fast else ("walk" if moving else "idle")

    var data_value: Variant = companions[roster_key]
    if typeof(data_value) != TYPE_DICTIONARY:
        return "idle"
    var data := data_value as Dictionary
    var action := String(data.get("action", "watch"))

    match action:
        "rest":
            return "sleep"
        "play":
            return "run" if moving_fast else "play"
        "wander", "coming":
            return "run" if moving_fast else "walk"
        "sniff":
            return "sniff"
        "happy":
            return "pet_react"
        "watch":
            return "call_react" if species == "dog" else "idle"
        _:
            return "walk" if moving else "idle"

func _play_animation_key(species: String, animation_key: String, force: bool) -> void:
    var player := animation_players.get(species) as AnimationPlayer
    if player == null:
        return

    var clip_name := _resolve_clip(player, animation_key)
    if clip_name == StringName():
        if animation_key != "idle":
            clip_name = _resolve_clip(player, "idle")
        if clip_name == StringName():
            var available := player.get_animation_list()
            if available.is_empty():
                return
            clip_name = available[0]

    if not force and player.current_animation == String(clip_name) and player.is_playing():
        active_animation_keys[species] = animation_key
        return

    player.play(clip_name, 0.18)
    active_animation_keys[species] = animation_key

func _resolve_clip(player: AnimationPlayer, animation_key: String) -> StringName:
    var aliases_value: Variant = ANIMATION_ALIASES.get(animation_key, [])
    if typeof(aliases_value) != TYPE_ARRAY:
        return StringName()
    for alias_value in aliases_value as Array:
        var alias_name := StringName(String(alias_value))
        if player.has_animation(alias_name):
            return alias_name
    return StringName()

func _find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func has_production_model(species: String) -> bool:
    return installed_models.has(species) and is_instance_valid(installed_models[species])
