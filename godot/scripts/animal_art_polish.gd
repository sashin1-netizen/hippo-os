extends Node

# Adds lightweight anatomical detail to the procedural companions already created
# by main.gd and CompanionRoster. This improves readability on mobile without
# changing their simulation state or collision bodies.

var scene_root: Node3D
var applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 135
    call_deferred("_apply_when_ready")

func _apply_when_ready() -> void:
    for _attempt in range(240):
        var candidate := get_tree().current_scene
        if candidate is Node3D:
            scene_root = candidate as Node3D
            var hippo := scene_root.find_child("BabyHippo", true, false)
            var pig := scene_root.find_child("PorkyPig", true, false)
            var dog := scene_root.find_child("BaoSharPei", true, false)
            if hippo != null and pig != null and dog != null:
                _polish_hippo(hippo as Node3D)
                _polish_pig(pig as Node3D)
                _polish_sharpei(dog as Node3D)
                applied = true
                return
        await get_tree().process_frame

    push_warning("AnimalArtPolish could not find all three companions")

func _polish_hippo(hippo: Node3D) -> void:
    if hippo.find_child("AnatomyPolish", false, false) != null:
        return
    var visual := _find_visual(hippo)
    if visual == null:
        return

    var root := Node3D.new()
    root.name = "AnatomyPolish"
    visual.add_child(root)

    var skin := _material(Color(0.39, 0.29, 0.36), 0.46)
    var soft_skin := _material(Color(0.57, 0.36, 0.45), 0.50)
    var dark := _material(Color(0.055, 0.035, 0.045), 0.34)
    var nail := _material(Color(0.20, 0.15, 0.17), 0.62)

    _sphere(root, "CheekL", Vector3(1.35, 0.43, -0.46), Vector3(0.34, 0.30, 0.22), soft_skin)
    _sphere(root, "CheekR", Vector3(1.35, 0.43, 0.46), Vector3(0.34, 0.30, 0.22), soft_skin)
    _sphere(root, "BrowL", Vector3(1.28, 0.88, -0.38), Vector3(0.23, 0.12, 0.17), skin)
    _sphere(root, "BrowR", Vector3(1.28, 0.88, 0.38), Vector3(0.23, 0.12, 0.17), skin)
    _sphere(root, "LowerLip", Vector3(1.87, 0.17, 0.0), Vector3(0.42, 0.08, 0.36), dark)
    _sphere(root, "NeckFold", Vector3(0.62, 0.42, 0.0), Vector3(0.38, 0.14, 0.64), skin)

    var feet: Array[Vector3] = [
        Vector3(0.72, -0.48, -0.50), Vector3(0.72, -0.48, 0.50),
        Vector3(-0.92, -0.50, -0.50), Vector3(-0.92, -0.50, 0.50)
    ]
    for foot_index in range(feet.size()):
        for toe in range(3):
            var z_offset := (float(toe) - 1.0) * 0.10
            _sphere(root, "Toe%d_%d" % [foot_index, toe], feet[foot_index] + Vector3(0.16, 0.0, z_offset), Vector3(0.11, 0.07, 0.075), nail)

func _polish_pig(pig: Node3D) -> void:
    var visual := pig.get_node_or_null("Visual") as Node3D
    if visual == null or visual.find_child("AnatomyPolish", false, false) != null:
        return

    var root := Node3D.new()
    root.name = "AnatomyPolish"
    visual.add_child(root)

    var skin := _material(Color(0.73, 0.43, 0.42), 0.68)
    var blush := _material(Color(0.85, 0.54, 0.52), 0.60)
    var hoof := _material(Color(0.13, 0.095, 0.085), 0.72)
    var mouth := _material(Color(0.20, 0.085, 0.09), 0.52)

    _sphere(root, "CheekL", Vector3(1.22, 0.51, -0.36), Vector3(0.25, 0.23, 0.18), blush)
    _sphere(root, "CheekR", Vector3(1.22, 0.51, 0.36), Vector3(0.25, 0.23, 0.18), blush)
    _sphere(root, "Jaw", Vector3(1.30, 0.27, 0.0), Vector3(0.34, 0.16, 0.34), skin)
    _sphere(root, "MouthLine", Vector3(1.59, 0.31, 0.0), Vector3(0.18, 0.045, 0.24), mouth)

    var hoof_positions: Array[Vector3] = [
        Vector3(0.66, -0.46, -0.43), Vector3(0.66, -0.46, 0.43),
        Vector3(-0.76, -0.46, -0.43), Vector3(-0.76, -0.46, 0.43)
    ]
    for i in range(hoof_positions.size()):
        var hoof_part := _sphere(root, "Hoof%d" % i, hoof_positions[i], Vector3(0.20, 0.12, 0.19), hoof)
        hoof_part.rotation.z = 0.08 if i < 2 else -0.05

func _polish_sharpei(dog: Node3D) -> void:
    var visual := dog.get_node_or_null("Visual") as Node3D
    if visual == null or visual.find_child("AnatomyPolish", false, false) != null:
        return

    var root := Node3D.new()
    root.name = "AnatomyPolish"
    visual.add_child(root)

    var coat := _material(Color(0.64, 0.39, 0.21), 0.84)
    var fold := _material(Color(0.56, 0.32, 0.17), 0.88)
    var muzzle := _material(Color(0.46, 0.26, 0.16), 0.80)
    var paw := _material(Color(0.55, 0.32, 0.19), 0.86)
    var mouth := _material(Color(0.12, 0.075, 0.055), 0.62)

    _sphere(root, "FaceFoldA", Vector3(1.12, 1.00, 0.0), Vector3(0.48, 0.11, 0.54), fold)
    _sphere(root, "FaceFoldB", Vector3(1.20, 0.87, 0.0), Vector3(0.50, 0.10, 0.55), fold)
    _sphere(root, "CheekL", Vector3(1.34, 0.66, -0.34), Vector3(0.29, 0.27, 0.21), muzzle)
    _sphere(root, "CheekR", Vector3(1.34, 0.66, 0.34), Vector3(0.29, 0.27, 0.21), muzzle)
    _sphere(root, "Chin", Vector3(1.48, 0.39, 0.0), Vector3(0.31, 0.14, 0.31), muzzle)
    _sphere(root, "MouthLine", Vector3(1.68, 0.51, 0.0), Vector3(0.15, 0.045, 0.22), mouth)
    _sphere(root, "ShoulderFold", Vector3(0.47, 0.70, 0.0), Vector3(0.58, 0.12, 0.61), coat)
    _sphere(root, "RumpFold", Vector3(-0.73, 0.66, 0.0), Vector3(0.46, 0.11, 0.58), fold)

    var paw_positions: Array[Vector3] = [
        Vector3(0.62, -0.45, -0.43), Vector3(0.62, -0.45, 0.43),
        Vector3(-0.73, -0.47, -0.43), Vector3(-0.73, -0.47, 0.43)
    ]
    for i in range(paw_positions.size()):
        _sphere(root, "Paw%d" % i, paw_positions[i], Vector3(0.23, 0.14, 0.23), paw)

func _find_visual(parent: Node3D) -> Node3D:
    for child in parent.get_children():
        if child is Node3D and not child is CollisionShape3D:
            if child.name == "Visual" or child.get_child_count() > 4:
                return child as Node3D
    return null

func _sphere(parent: Node3D, part_name: String, local_position: Vector3, local_scale: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    part.mesh = mesh
    part.position = local_position
    part.scale = local_scale
    part.material_override = material
    parent.add_child(part)
    return part

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
