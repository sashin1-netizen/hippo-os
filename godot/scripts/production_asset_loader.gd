extends Node

# Production animal model bridge.
# The simulation/collision bodies stay stable while a final rigged GLB can replace
# the procedural visual for each companion. This keeps behaviour, save state,
# audio emitters, interaction logic and Android code independent from art delivery.

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

var scene_root: Node3D
var installed_models: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 165
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
    body.add_child(visual)
    _normalize_visual_transform(visual, species)
    _hide_procedural_visuals(body, visual)
    _start_idle_animation(visual)
    installed_models[species] = visual

func _normalize_visual_transform(visual: Node3D, species: String) -> void:
    visual.position = Vector3.ZERO
    visual.rotation = Vector3.ZERO
    match species:
        "hippo":
            visual.scale = Vector3.ONE
        "pig":
            visual.scale = Vector3.ONE
        "dog":
            visual.scale = Vector3.ONE
        _:
            visual.scale = Vector3.ONE

func _hide_procedural_visuals(body: Node3D, production_visual: Node3D) -> void:
    for child in body.get_children():
        if child == production_visual or child is CollisionShape3D:
            continue
        if child is Node3D:
            (child as Node3D).visible = false

func _start_idle_animation(root: Node) -> void:
    var player := _find_animation_player(root)
    if player == null:
        return

    var candidates: Array[StringName] = [&"idle", &"Idle", &"idle_01", &"Idle_01", &"stand_idle", &"Standing Idle"]
    for animation_name in candidates:
        if player.has_animation(animation_name):
            player.play(animation_name)
            return

    var animations := player.get_animation_list()
    if not animations.is_empty():
        player.play(animations[0])

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
