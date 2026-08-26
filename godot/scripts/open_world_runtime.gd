extends Node

# Mobile-first open-world runtime for Hippo OS.
# Regions remain authored Godot nodes; this director controls activation cost, visibility,
# processing and persistent region metadata without replacing gameplay or animal minds.

signal region_state_changed(region_id: String, state: String)
signal active_region_changed(region_id: String)

const SAVE_PATH := "user://open_world_runtime.json"
const TICK_INTERVAL := 0.35
const NEAR_RADIUS := 18.0
const MID_RADIUS := 34.0
const FAR_RADIUS := 60.0

var scene_root: Node3D
var camera: Camera3D
var regions: Dictionary = {}
var persisted: Dictionary = {}
var tick_accumulator := 0.0
var active_region := "sanctuary_core"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 260
    _load_state()
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var current := get_tree().current_scene
        if current is Node3D:
            scene_root = current as Node3D
            camera = _find_camera(scene_root)
            if camera != null:
                break
        await get_tree().process_frame
    if scene_root == null or camera == null:
        push_warning("OpenWorldRuntime could not bind")
        return
    _discover_regions()
    _ensure_default_regions()
    _update_regions(true)
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null or camera == null:
        return
    tick_accumulator += delta
    if tick_accumulator < TICK_INTERVAL:
        return
    tick_accumulator = 0.0
    _update_regions(false)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_state()

func _exit_tree() -> void:
    _save_state()

func register_region(region_id: String, root: Node3D, center: Vector3, radius: float = 14.0) -> void:
    if root == null:
        return
    regions[region_id] = {
        "root": root,
        "center": center,
        "radius": radius,
        "state": "near",
    }
    root.set_meta("hippo_os_region_id", region_id)

func _discover_regions() -> void:
    for node in scene_root.find_children("*", "Node3D", true, false):
        if not (node is Node3D):
            continue
        var n := node as Node3D
        if n.has_meta("hippo_os_region_id"):
            var region_id := str(n.get_meta("hippo_os_region_id"))
            register_region(region_id, n, n.global_position, float(n.get_meta("hippo_os_region_radius", 14.0)))

func _ensure_default_regions() -> void:
    # These logical regions can exist even before dedicated scene chunks are authored.
    # They give AI/navigation a stable world vocabulary now and can later map to streamed scenes.
    var defaults := {
        "sanctuary_core": Vector3(0, 0, 0),
        "pond_wetland": Vector3(3.7, 0, 2.5),
        "mud_wallow": Vector3(-3.7, 0, 2.8),
        "feeding_meadow": Vector3(4.7, 0, -2.9),
        "sleeping_grove": Vector3(-4.6, 0, -3.2),
        "forest_trail": Vector3(-14.0, 0, -2.0),
        "grassland_range": Vector3(14.0, 0, 3.0),
    }
    for region_id in defaults:
        if regions.has(region_id):
            continue
        regions[region_id] = {
            "root": null,
            "center": defaults[region_id],
            "radius": 12.0,
            "state": "logical",
        }

func _update_regions(force: bool) -> void:
    var focus := _focus_position()
    var nearest_id := active_region
    var nearest_distance := INF
    for region_id in regions:
        var data := regions[region_id] as Dictionary
        var center := data.get("center", Vector3.ZERO) as Vector3
        var distance := focus.distance_to(center)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_id = str(region_id)
        var next_state := _distance_state(distance)
        var previous := str(data.get("state", "unknown"))
        if force or next_state != previous:
            data["state"] = next_state
            regions[region_id] = data
            _apply_region_state(str(region_id), data, next_state)
            region_state_changed.emit(str(region_id), next_state)
    if nearest_id != active_region:
        active_region = nearest_id
        scene_root.set_meta("hippo_os_active_region", active_region)
        active_region_changed.emit(active_region)

func _distance_state(distance: float) -> String:
    if distance <= NEAR_RADIUS:
        return "near"
    if distance <= MID_RADIUS:
        return "mid"
    if distance <= FAR_RADIUS:
        return "far"
    return "sleep"

func _apply_region_state(region_id: String, data: Dictionary, state: String) -> void:
    var root := data.get("root") as Node3D
    persisted[region_id] = {
        "state": state,
        "last_seen_unix": Time.get_unix_time_from_system(),
    }
    if root == null or not is_instance_valid(root):
        return
    match state:
        "near":
            root.visible = true
            root.process_mode = Node.PROCESS_MODE_INHERIT
            _set_geometry_range(root, 0.0, 0.0)
        "mid":
            root.visible = true
            root.process_mode = Node.PROCESS_MODE_DISABLED
            _set_geometry_range(root, 0.0, FAR_RADIUS + 8.0)
        "far":
            root.visible = true
            root.process_mode = Node.PROCESS_MODE_DISABLED
            _set_geometry_range(root, MID_RADIUS * 0.65, FAR_RADIUS + 8.0)
        "sleep":
            root.process_mode = Node.PROCESS_MODE_DISABLED
            root.visible = false

func _set_geometry_range(root: Node, begin: float, end: float) -> void:
    if root is GeometryInstance3D:
        var geometry := root as GeometryInstance3D
        geometry.visibility_range_begin = begin
        geometry.visibility_range_end = end
        geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    for child in root.get_children():
        _set_geometry_range(child, begin, end)

func get_region_center(region_id: String) -> Vector3:
    if not regions.has(region_id):
        return Vector3.ZERO
    return (regions[region_id] as Dictionary).get("center", Vector3.ZERO) as Vector3

func get_region_state(region_id: String) -> String:
    if not regions.has(region_id):
        return "unknown"
    return str((regions[region_id] as Dictionary).get("state", "unknown"))

func _focus_position() -> Vector3:
    var hippo := scene_root.find_child("BabyHippo", true, false) as Node3D
    if hippo != null:
        return hippo.global_position
    return camera.global_position

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null

func _load_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed := JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        persisted = parsed as Dictionary

func _save_state() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(persisted))
