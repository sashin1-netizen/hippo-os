extends Node

# Lightweight Android-safe open-world runtime for Hippo OS.
# Keeps logical sanctuary regions persistent while reducing expensive processing
# and visibility as regions move away from the active animal/camera focus.

signal region_state_changed(region_id: String, state: String)

const SAVE_PATH: String = "user://open_world_state.json"
const UPDATE_INTERVAL: float = 0.45
const NEAR_DISTANCE: float = 14.0
const MID_DISTANCE: float = 28.0
const FAR_DISTANCE: float = 48.0

var scene_root: Node3D = null
var camera: Camera3D = null
var update_timer: float = 0.0
var regions: Dictionary = {}
var persisted: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 245
    _load_state()
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt: int in range(420):
        var candidate: Node = get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            camera = _find_camera(scene_root)
            if camera != null:
                break
        await get_tree().process_frame

    if scene_root == null or camera == null:
        push_warning("OpenWorldRuntime could not bind to sanctuary camera")
        return

    _register_default_regions()
    _discover_scene_regions()
    _update_regions(true)
    set_process(true)
    print("HippoOS open-world runtime online")

func _process(delta: float) -> void:
    if scene_root == null or not is_instance_valid(scene_root):
        return
    update_timer -= delta
    if update_timer <= 0.0:
        update_timer = UPDATE_INTERVAL
        _update_regions(false)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_state()

func _exit_tree() -> void:
    _save_state()

func _register_default_regions() -> void:
    _ensure_region("home", Vector3(0.0, 0.0, 0.0), "Home Sanctuary")
    _ensure_region("pond", Vector3(3.7, 0.0, 2.5), "Pond and Wetland")
    _ensure_region("mud", Vector3(-3.7, 0.0, 2.8), "Mud Wallow")
    _ensure_region("feeding", Vector3(4.7, 0.0, -2.9), "Feeding Grounds")
    _ensure_region("rest", Vector3(-4.6, 0.0, -3.2), "Shaded Rest Area")
    _ensure_region("trail", Vector3(-10.0, 0.0, 0.0), "Forest Trail")
    _ensure_region("grassland", Vector3(10.0, 0.0, 0.0), "Grasslands")

func _ensure_region(region_id: String, center: Vector3, label: String) -> void:
    if regions.has(region_id):
        return
    var saved_variant: Variant = persisted.get(region_id, {})
    var saved: Dictionary = {}
    if typeof(saved_variant) == TYPE_DICTIONARY:
        saved = saved_variant as Dictionary
    regions[region_id] = {
        "id": region_id,
        "label": label,
        "center": center,
        "state": str(saved.get("state", "near")),
        "visited": bool(saved.get("visited", false)),
        "last_seen_unix": int(saved.get("last_seen_unix", 0)),
        "nodes": []
    }

func _discover_scene_regions() -> void:
    if scene_root == null:
        return
    var candidates: Dictionary = {
        "home": ["OpenWorldAuthority", "GrasslandsProductionLayer"],
        "pond": ["ForegroundWatercourse", "CompatibilityWatercourse"],
        "mud": ["WetBank", "CompatibilityWetBank"],
        "trail": ["DryAnimalTrail"],
        "grassland": ["CompatibilityOpenWorld", "GrasslandsProductionLayer"]
    }
    for region_variant: Variant in candidates.keys():
        var region_id: String = str(region_variant)
        var names_variant: Variant = candidates.get(region_id, [])
        if typeof(names_variant) != TYPE_ARRAY:
            continue
        var names: Array = names_variant as Array
        var region: Dictionary = regions.get(region_id, {}) as Dictionary
        var nodes: Array = region.get("nodes", []) as Array
        for name_variant: Variant in names:
            var node_name: String = str(name_variant)
            var found: Node3D = scene_root.find_child(node_name, true, false) as Node3D
            if found != null and not nodes.has(found):
                nodes.append(found)
        region["nodes"] = nodes
        regions[region_id] = region

func _update_regions(force: bool) -> void:
    var focus: Vector3 = _focus_position()
    for region_variant: Variant in regions.keys():
        var region_id: String = str(region_variant)
        var region_variant_value: Variant = regions.get(region_id, {})
        if typeof(region_variant_value) != TYPE_DICTIONARY:
            continue
        var region: Dictionary = region_variant_value as Dictionary
        var center_variant: Variant = region.get("center", Vector3.ZERO)
        var center: Vector3 = center_variant as Vector3 if center_variant is Vector3 else Vector3.ZERO
        var distance: float = focus.distance_to(center)
        var next_state: String = _state_for_distance(distance)
        var previous_state: String = str(region.get("state", "near"))
        if distance <= MID_DISTANCE:
            region["visited"] = true
            region["last_seen_unix"] = int(Time.get_unix_time_from_system())
        if force or next_state != previous_state:
            region["state"] = next_state
            _apply_region_state(region, next_state)
            region_state_changed.emit(region_id, next_state)
        regions[region_id] = region
    _snapshot_persisted()

func _state_for_distance(distance: float) -> String:
    if distance <= NEAR_DISTANCE:
        return "near"
    if distance <= MID_DISTANCE:
        return "mid"
    if distance <= FAR_DISTANCE:
        return "far"
    return "sleep"

func _apply_region_state(region: Dictionary, state: String) -> void:
    var nodes_variant: Variant = region.get("nodes", [])
    if typeof(nodes_variant) != TYPE_ARRAY:
        return
    var nodes: Array = nodes_variant as Array
    for node_variant: Variant in nodes:
        if not (node_variant is Node3D):
            continue
        var node: Node3D = node_variant as Node3D
        if not is_instance_valid(node):
            continue
        match state:
            "near":
                node.visible = true
                node.process_mode = Node.PROCESS_MODE_INHERIT
            "mid":
                node.visible = true
                node.process_mode = Node.PROCESS_MODE_DISABLED
            "far":
                node.visible = true
                node.process_mode = Node.PROCESS_MODE_DISABLED
            _:
                # Keep authoritative terrain roots visible if hiding them would create
                # a blank horizon, but stop their processing while sleeping.
                node.process_mode = Node.PROCESS_MODE_DISABLED

func get_region_center(region_id: String) -> Vector3:
    var region_variant: Variant = regions.get(region_id, {})
    if typeof(region_variant) != TYPE_DICTIONARY:
        return Vector3.ZERO
    var region: Dictionary = region_variant as Dictionary
    var center_variant: Variant = region.get("center", Vector3.ZERO)
    if center_variant is Vector3:
        return center_variant as Vector3
    return Vector3.ZERO

func get_region_state(region_id: String) -> String:
    var region_variant: Variant = regions.get(region_id, {})
    if typeof(region_variant) != TYPE_DICTIONARY:
        return "unknown"
    return str((region_variant as Dictionary).get("state", "unknown"))

func _snapshot_persisted() -> void:
    for region_variant: Variant in regions.keys():
        var region_id: String = str(region_variant)
        var region_value: Variant = regions.get(region_id, {})
        if typeof(region_value) != TYPE_DICTIONARY:
            continue
        var region: Dictionary = region_value as Dictionary
        persisted[region_id] = {
            "state": str(region.get("state", "near")),
            "visited": bool(region.get("visited", false)),
            "last_seen_unix": int(region.get("last_seen_unix", 0))
        }

func _focus_position() -> Vector3:
    if scene_root != null:
        var hippo: Node3D = scene_root.find_child("BabyHippo", true, false) as Node3D
        if hippo != null:
            return hippo.global_position
    if camera != null:
        return camera.global_position
    return Vector3.ZERO

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child: Node in node.get_children():
        var found: Camera3D = _find_camera(child)
        if found != null:
            return found
    return null

func _load_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        persisted = parsed as Dictionary

func _save_state() -> void:
    _snapshot_persisted()
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(persisted))
