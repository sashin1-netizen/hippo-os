extends Node

var host

func _ready():
    for i in range(12):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _scan(host)

func _scan(node):
    if node is Node3D:
        if node.name == "OpenWorldTree":
            _tree_collision(node)
        elif node.name == "OpenWorldRock" and node is MeshInstance3D:
            _rock_collision(node)
        elif node.name == "HabitatShelter":
            _shelter_collision(node)
    for child in node.get_children():
        _scan(child)

func _tree_collision(tree: Node3D):
    if tree.has_node("CollisionBody"):
        return
    var body := StaticBody3D.new()
    body.name = "CollisionBody"
    body.collision_layer = 1
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.38
    shape.height = 3.2
    collision.shape = shape
    collision.position.y = 1.6
    body.add_child(collision)
    tree.add_child(body)

func _rock_collision(rock: MeshInstance3D):
    if rock.has_node("CollisionBody"):
        return
    var body := StaticBody3D.new()
    body.name = "CollisionBody"
    body.collision_layer = 1
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = max(0.22, max(float(rock.scale.x), float(rock.scale.z)) * 0.40)
    collision.shape = shape
    body.add_child(collision)
    rock.add_child(body)

func _shelter_collision(shelter: Node3D):
    if shelter.has_node("CollisionBody"):
        return
    var body := StaticBody3D.new()
    body.name = "CollisionBody"
    body.collision_layer = 1
    for x in [-1.0, 1.0]:
        for z in [-0.7, 0.7]:
            var collision := CollisionShape3D.new()
            var shape := CylinderShape3D.new()
            shape.radius = 0.12
            shape.height = 1.5
            collision.shape = shape
            collision.position = Vector3(x, 0.75, z)
            body.add_child(collision)
    shelter.add_child(body)
