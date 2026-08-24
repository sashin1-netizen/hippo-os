extends Node

const SAMPLE_SECONDS := 3.0
const LOW_FPS := 38.0
const RECOVER_FPS := 53.0

var host
var sample_timer := 0.0
var low_samples := 0
var recovery_samples := 0
var reduced := false
var grass_nodes: Array[GeometryInstance3D] = []
var tree_nodes: Array[GeometryInstance3D] = []
var rock_nodes: Array[GeometryInstance3D] = []
var effect_nodes: Array[CPUParticles3D] = []

func _ready():
    process_priority = 95
    for i in range(14):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _scan(host, false)
    _apply_quality(false)

func _process(delta):
    if host == null:
        return
    sample_timer += delta
    if sample_timer < SAMPLE_SECONDS:
        return
    sample_timer = 0.0
    var fps = float(Engine.get_frames_per_second())
    if fps > 0.0 and fps < LOW_FPS:
        low_samples += 1
        recovery_samples = 0
    elif fps >= RECOVER_FPS:
        recovery_samples += 1
        low_samples = 0
    else:
        low_samples = max(0, low_samples - 1)
        recovery_samples = max(0, recovery_samples - 1)

    if not reduced and low_samples >= 2:
        reduced = true
        _apply_quality(true)
    elif reduced and recovery_samples >= 3:
        reduced = false
        _apply_quality(false)

func _scan(node: Node, inside_tree: bool):
    var now_inside_tree = inside_tree or node.name == "OpenWorldTree"
    if node is MultiMeshInstance3D and node.name == "LivingGrass":
        grass_nodes.append(node)
    elif node is MeshInstance3D:
        if now_inside_tree:
            tree_nodes.append(node)
        elif node.name == "OpenWorldRock":
            rock_nodes.append(node)
        elif node.name in ["MudTrack", "Footprint", "TrackMark"]:
            grass_nodes.append(node)
    elif node is CPUParticles3D:
        effect_nodes.append(node)
        if not node.has_meta("hippo_full_amount"):
            node.set_meta("hippo_full_amount", node.amount)
    for child in node.get_children():
        _scan(child, now_inside_tree)

func _apply_quality(use_reduced: bool):
    var grass_end = 26.0 if use_reduced else 38.0
    var tree_end = 68.0 if use_reduced else 92.0
    var rock_end = 50.0 if use_reduced else 74.0
    for node in grass_nodes:
        if is_instance_valid(node):
            node.visibility_range_end = grass_end
            node.visibility_range_end_margin = 6.0
    for node in tree_nodes:
        if is_instance_valid(node):
            node.visibility_range_end = tree_end
            node.visibility_range_end_margin = 10.0
    for node in rock_nodes:
        if is_instance_valid(node):
            node.visibility_range_end = rock_end
            node.visibility_range_end_margin = 8.0
    for particles in effect_nodes:
        if not is_instance_valid(particles):
            continue
        var full_amount = int(particles.get_meta("hippo_full_amount", particles.amount))
        particles.amount = max(4, int(round(full_amount * (0.55 if use_reduced else 1.0))))
