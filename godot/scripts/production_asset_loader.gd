extends Node

# Production animal model bridge.
# The simulation/collision bodies stay stable while final rigged GLBs replace only
# procedural visuals. Behaviour, saving, audio emitters and interaction logic remain
# authoritative, and this bridge translates live actions into authored animation clips.
#
# Source priority:
#   1. Final authored Hippo OS GLBs.
#   2. Pinned CC0 Gobkit authored model where an exact species is available.
#   3. Pinned MIT anyCreature generated quadrupeds.
# The public production gate still requires the final licensed 4K-PBR deliveries.

const MODEL_PATHS := {
    "hippo": "res://assets/animals/mochi.glb",
    "pig": "res://assets/animals/porky.glb",
    "dog": "res://assets/animals/bao.glb",
}

const GOBKIT_MODEL_PATHS := {
    "hippo": "res://assets/animals/community/gobkit_mochi.glb",
}

const COMMUNITY_MODEL_PATHS := {
    "hippo": "res://assets/animals/community/mochi.glb",
    "pig": "res://assets/animals/community/porky.glb",
    "dog": "res://assets/animals/community/bao.glb",
}

const COMMUNITY_VISUAL_SCALE := {
    "hippo": 0.92,
    "pig": 0.75,
    "dog": 0.70,
}

const COMMUNITY_VISUAL_Y_OFFSET := {
    "hippo": -0.78,
    "pig": -0.70,
    "dog": -0.73,
}

const GOBKIT_TARGET_HEIGHT := {
    "hippo": 1.28,
}

const GOBKIT_BOTTOM_Y := {
    "hippo": -0.79,
}

const GOBKIT_FPS := 24.0
const GOBKIT_SEGMENTS := {
    "idle": Vector2(0.0, 29.0),
    "attack": Vector2(30.0, 59.0),
    "dead": Vector2(60.0, 89.0),
    "walk": Vector2(90.0, 119.0),
}

const BODY_NAMES := {
    "hippo": "BabyHippo",
    "pig": "PorkyPig",
    "dog": "BaoSharPei",
}

const ANIMATION_ALIASES := {
    "idle": ["idle", "Idle", "idle_01", "Idle_01", "stand_idle", "Standing Idle", "standing_idle"],
    "walk": ["walk", "Walk", "walking", "Walking", "walk_cycle", "Walk Cycle", "move", "Move", "locomotion"],
    "run": ["run", "Run", "running", "Running", "run_cycle", "Run Cycle", "move", "Move", "locomotion"],
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
    "zoomies": ["zoomies", "Zoomies", "sprint", "Sprint", "run", "Run", "move", "Move"],
}

var scene_root: Node3D
var installed_models: Dictionary = {}
var installed_model_sources: Dictionary = {}
var animation_players: Dictionary = {}
var active_animation_keys: Dictionary = {}
var gobkit_segment_time: Dictionary = {}
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

    # Let fallback anatomy/material polish settle first. Authored/generated GLBs are
    # mounted afterwards so their own materials are never overwritten by primitive polish.
    for _frame in range(4):
        await get_tree().process_frame

    for species in BODY_NAMES.keys():
        _install_if_available(String(species))

    if not installed_models.is_empty():
        set_process(true)

func _process(delta: float) -> void:
    animation_sync_timer -= delta
    if animation_sync_timer <= 0.0:
        animation_sync_timer = 0.10
        for species_value in installed_models.keys():
            _sync_animation(String(species_value))

    # Gobkit ships one baked animation track split into documented 30-frame ranges.
    # Scrub only the active range every frame so idle/walk never spill into attack/dead.
    for species_value in installed_models.keys():
        var species := String(species_value)
        if String(installed_model_sources.get(species, "")) == "gobkit":
            _advance_gobkit_segment(species, delta)

func _all_bodies_present() -> bool:
    if scene_root == null:
        return false
    for species in BODY_NAMES.keys():
        if scene_root.find_child(String(BODY_NAMES[species]), true, false) == null:
            return false
    return true

func _install_if_available(species: String) -> void:
    var model_path := String(MODEL_PATHS.get(species, ""))
    var source := "production"

    if model_path.is_empty() or not ResourceLoader.exists(model_path):
        model_path = String(GOBKIT_MODEL_PATHS.get(species, ""))
        source = "gobkit"

    if model_path.is_empty() or not ResourceLoader.exists(model_path):
        model_path = String(COMMUNITY_MODEL_PATHS.get(species, ""))
        source = "anycreature"

    if model_path.is_empty() or not ResourceLoader.exists(model_path):
        return

    var body_name := String(BODY_NAMES.get(species, ""))
    var body := scene_root.find_child(body_name, true, false) as Node3D
    if body == null:
        return

    var resource: Resource = load(model_path)
    if not resource is PackedScene:
        push_warning("Animal model is not an importable PackedScene: %s" % model_path)
        return

    var packed := resource as PackedScene
    var visual := packed.instantiate() as Node3D
    if visual == null:
        push_warning("Animal model could not instantiate: %s" % model_path)
        return

    match source:
        "production":
            visual.name = "ProductionVisual"
        "gobkit":
            visual.name = "GobkitCC0Visual"
        _:
            visual.name = "CommunityRiggedVisual"

    visual.set_meta("hippo_os_production_visual", source == "production")
    visual.set_meta("hippo_os_community_generated", source != "production")
    visual.set_meta("hippo_os_model_source", source)
    visual.set_meta("hippo_os_model_path", model_path)
    body.add_child(visual)
    _normalize_visual_transform(visual, species, source)
    _hide_procedural_visuals(body, visual)

    installed_models[species] = visual
    installed_model_sources[species] = source

    var player := _find_animation_player(visual)
    if player != null:
        animation_players[species] = player
        _play_animation_key(species, "idle", true)

    print("HippoOS animal visual installed: %s <- %s" % [species, source])

func _normalize_visual_transform(visual: Node3D, species: String, source: String) -> void:
    visual.position = Vector3.ZERO
    visual.rotation = Vector3.ZERO
    visual.scale = Vector3.ONE
    if source == "production":
        return

    # Both pinned community sources author quadrupeds facing +Z; Hippo OS simulation
    # bodies are authored along +X. Rotate only the replaceable visual, never physics.
    visual.rotation.y = deg_to_rad(90.0)

    if source == "gobkit":
        _normalize_gobkit_visual(visual, species)
        return

    var visual_scale := float(COMMUNITY_VISUAL_SCALE.get(species, 0.8))
    visual.scale = Vector3.ONE * visual_scale
    visual.position.y = float(COMMUNITY_VISUAL_Y_OFFSET.get(species, -0.72))

func _normalize_gobkit_visual(visual: Node3D, species: String) -> void:
    var bounds := _visual_bounds_in_root(visual)
    if bounds.size.y <= 0.001:
        visual.scale = Vector3.ONE
        visual.position.y = float(GOBKIT_BOTTOM_Y.get(species, -0.78))
        return

    var target_height := float(GOBKIT_TARGET_HEIGHT.get(species, 1.2))
    var scale_factor := clampf(target_height / bounds.size.y, 0.05, 8.0)
    var center := bounds.position + bounds.size * 0.5
    var rotated_center := Basis(Vector3.UP, visual.rotation.y) * Vector3(center.x, 0.0, center.z)
    visual.scale = Vector3.ONE * scale_factor
    visual.position.x = -rotated_center.x * scale_factor
    visual.position.z = -rotated_center.z * scale_factor
    visual.position.y = float(GOBKIT_BOTTOM_Y.get(species, -0.78)) - bounds.position.y * scale_factor

func _visual_bounds_in_root(root: Node3D) -> AABB:
    var found := false
    var merged := AABB()
    var root_inverse := root.global_transform.affine_inverse()
    var mesh_nodes := root.find_children("*", "MeshInstance3D", true, false)
    for node in mesh_nodes:
        var mesh_node := node as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            continue
        var to_root := root_inverse * mesh_node.global_transform
        var transformed := _transform_aabb(mesh_node.get_aabb(), to_root)
        if not found:
            merged = transformed
            found = true
        else:
            merged = merged.merge(transformed)
    return merged if found else AABB()

func _transform_aabb(box: AABB, transform: Transform3D) -> AABB:
    var output := AABB(transform * box.position, Vector3.ZERO)
    for xi in range(2):
        for yi in range(2):
            for zi in range(2):
                var point := box.position + Vector3(
                    box.size.x * float(xi),
                    box.size.y * float(yi),
                    box.size.z * float(zi)
                )
                output = output.expand(transform * point)
    return output

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

    if String(installed_model_sources.get(species, "")) == "gobkit":
        if not force and String(active_animation_keys.get(species, "")) == animation_key:
            return
        active_animation_keys[species] = animation_key
        gobkit_segment_time[species] = 0.0
        var baked_clip := _first_animation_clip(player)
        if baked_clip != StringName():
            player.play(baked_clip)
            player.pause()
            _seek_gobkit_segment(species, 0.0)
        return

    var clip_name := _resolve_clip(player, animation_key)
    if clip_name == StringName():
        if animation_key != "idle":
            clip_name = _resolve_clip(player, "idle")
        if clip_name == StringName():
            clip_name = _first_animation_clip(player)
            if clip_name == StringName():
                return

    if not force and player.current_animation == String(clip_name) and player.is_playing():
        active_animation_keys[species] = animation_key
        return

    player.play(clip_name, 0.18)
    active_animation_keys[species] = animation_key

func _advance_gobkit_segment(species: String, delta: float) -> void:
    var player := animation_players.get(species) as AnimationPlayer
    if player == null:
        return
    var key := String(active_animation_keys.get(species, "idle"))
    var segment_name := _gobkit_segment_for_key(key)
    var segment := GOBKIT_SEGMENTS.get(segment_name, GOBKIT_SEGMENTS["idle"]) as Vector2
    var duration := maxf((segment.y - segment.x) / GOBKIT_FPS, 0.001)
    var local_time := float(gobkit_segment_time.get(species, 0.0)) + delta
    if segment_name == "dead":
        local_time = minf(local_time, duration)
    else:
        local_time = fmod(local_time, duration)
    gobkit_segment_time[species] = local_time
    _seek_gobkit_segment(species, local_time)

func _seek_gobkit_segment(species: String, local_time: float) -> void:
    var player := animation_players.get(species) as AnimationPlayer
    if player == null:
        return
    var key := String(active_animation_keys.get(species, "idle"))
    var segment_name := _gobkit_segment_for_key(key)
    var segment := GOBKIT_SEGMENTS.get(segment_name, GOBKIT_SEGMENTS["idle"]) as Vector2
    var sample_time := segment.x / GOBKIT_FPS + local_time
    player.seek(sample_time, true)

func _gobkit_segment_for_key(animation_key: String) -> String:
    if animation_key in ["walk", "run", "zoomies"]:
        return "walk"
    if animation_key in ["play", "pet_react", "call_react", "eat", "drink", "sniff", "mud", "water_play", "yawn", "wake"]:
        return "attack"
    return "idle"

func _resolve_clip(player: AnimationPlayer, animation_key: String) -> StringName:
    var aliases_value: Variant = ANIMATION_ALIASES.get(animation_key, [])
    if typeof(aliases_value) != TYPE_ARRAY:
        return StringName()
    for alias_value in (aliases_value as Array):
        var alias_name := StringName(String(alias_value))
        if player.has_animation(alias_name):
            return alias_name
    return StringName()

func _first_animation_clip(player: AnimationPlayer) -> StringName:
    for clip in player.get_animation_list():
        var name := String(clip)
        if name.to_lower() == "reset":
            continue
        return StringName(name)
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

func is_final_production_model(species: String) -> bool:
    return has_production_model(species) and String(installed_model_sources.get(species, "")) == "production"
