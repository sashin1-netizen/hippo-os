extends Node

var host
var day_creatures = []
var fireflies = []
var ripples = []
var elapsed = 0.0
var next_ripple = 3.0
var rng = RandomNumberGenerator.new()

func _ready():
    rng.seed = 910247
    for i in range(8):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _build_day_creatures()
    _build_fireflies()
    _build_ripples()

func _process(delta):
    if host == null:
        return
    elapsed += delta
    var hour = _local_hour()
    var night = hour >= 19 or hour < 6
    _animate_day_creatures(delta, night)
    _animate_fireflies(delta, night)
    _animate_ripples(delta)
    next_ripple -= delta
    if next_ripple <= 0.0:
        _trigger_random_ripple()
        next_ripple = rng.randf_range(4.5, 11.0)

func _local_hour():
    if host.has_method("_effective_local_hour"):
        return int(host.call("_effective_local_hour"))
    return int(Time.get_time_dict_from_system().get("hour", 12))

func _build_day_creatures():
    for i in range(9):
        var root = Node3D.new()
        root.name = "AmbientDayCreature%02d" % i
        var body = MeshInstance3D.new()
        var body_mesh = CapsuleMesh.new()
        body_mesh.radius = 0.018
        body_mesh.height = 0.105
        body.mesh = body_mesh
        body.rotation_degrees.z = 90.0
        body.material_override = _mat(Color(0.08, 0.055, 0.03), 0.72)
        root.add_child(body)

        for side in [-1.0, 1.0]:
            var wing = MeshInstance3D.new()
            wing.name = "WingL" if side < 0.0 else "WingR"
            var wing_mesh = QuadMesh.new()
            wing_mesh.size = Vector2(0.12, 0.065)
            wing.mesh = wing_mesh
            wing.position = Vector3(0.0, 0.025, side * 0.055)
            wing.rotation_degrees = Vector3(90.0, 0.0, 0.0)
            var tint = Color(0.68, 0.46, 0.18, 0.72) if i % 3 == 0 else Color(0.36, 0.52, 0.38, 0.68)
            wing.material_override = _transparent_mat(tint, 0.62)
            root.add_child(wing)

        var angle = TAU * float(i) / 9.0
        var radius = 2.9 + rng.randf_range(0.0, 3.8)
        root.position = Vector3(2.0 + cos(angle) * radius, rng.randf_range(0.75, 1.75), 2.1 + sin(angle) * radius)
        root.set_meta("phase", rng.randf_range(0.0, TAU))
        root.set_meta("radius", radius)
        root.set_meta("speed", rng.randf_range(0.20, 0.42))
        root.set_meta("height", root.position.y)
        day_creatures.append(root)
        host.add_child(root)

func _build_fireflies():
    for i in range(18):
        var light = MeshInstance3D.new()
        light.name = "Firefly%02d" % i
        var mesh = SphereMesh.new()
        mesh.radius = 0.020
        mesh.height = 0.040
        light.mesh = mesh
        var material = StandardMaterial3D.new()
        material.albedo_color = Color(0.68, 0.92, 0.42)
        material.emission_enabled = true
        material.emission = Color(0.60, 1.0, 0.28)
        material.emission_energy_multiplier = 1.8
        material.roughness = 0.18
        light.material_override = material
        light.position = Vector3(rng.randf_range(-11.5, 11.5), rng.randf_range(0.45, 2.15), rng.randf_range(-6.8, 6.8))
        light.set_meta("base", light.position)
        light.set_meta("phase", rng.randf_range(0.0, TAU))
        light.visible = false
        fireflies.append(light)
        host.add_child(light)

func _build_ripples():
    for i in range(5):
        var ripple = MeshInstance3D.new()
        ripple.name = "AmbientWaterRipple%02d" % i
        var mesh = CylinderMesh.new()
        mesh.top_radius = 0.42
        mesh.bottom_radius = 0.42
        mesh.height = 0.008
        ripple.mesh = mesh
        ripple.position = Vector3(2.0, 0.145, 2.1)
        ripple.scale = Vector3(0.1, 1.0, 0.1)
        ripple.material_override = _transparent_mat(Color(0.58, 0.86, 0.90, 0.0), 0.12)
        ripple.visible = false
        ripple.set_meta("life", 0.0)
        ripples.append(ripple)
        host.add_child(ripple)

func _animate_day_creatures(_delta, night):
    for i in range(day_creatures.size()):
        var creature = day_creatures[i]
        creature.visible = not night
        if night:
            continue
        var phase = float(creature.get_meta("phase", 0.0))
        var radius = float(creature.get_meta("radius", 3.5))
        var speed = float(creature.get_meta("speed", 0.3))
        var base_height = float(creature.get_meta("height", 1.1))
        var t = elapsed * speed + phase
        var x = 2.0 + cos(t) * radius + sin(t * 2.31) * 0.65
        var z = 2.1 + sin(t * 0.91) * radius + cos(t * 1.73) * 0.45
        var y = base_height + sin(t * 3.4) * 0.18
        var previous = creature.position
        creature.position = Vector3(x, y, z)
        var travel = creature.position - previous
        if travel.length_squared() > 0.00001:
            creature.look_at(creature.global_position + travel.normalized(), Vector3.UP)
        var flap = sin(elapsed * 18.0 + phase) * 38.0
        var left = creature.get_node_or_null("WingL")
        var right = creature.get_node_or_null("WingR")
        if left != null:
            left.rotation_degrees.x = 90.0 + flap
        if right != null:
            right.rotation_degrees.x = 90.0 - flap

func _animate_fireflies(_delta, night):
    for i in range(fireflies.size()):
        var firefly = fireflies[i]
        firefly.visible = night
        if not night:
            continue
        var base = firefly.get_meta("base", firefly.position)
        var phase = float(firefly.get_meta("phase", 0.0))
        if base is Vector3:
            firefly.position = base + Vector3(
                sin(elapsed * 0.54 + phase) * 0.55,
                sin(elapsed * 1.08 + phase * 1.7) * 0.24,
                cos(elapsed * 0.47 + phase) * 0.55
            )
        var pulse = 0.62 + 0.38 * sin(elapsed * 2.2 + phase)
        firefly.scale = Vector3.ONE * lerp(0.72, 1.25, pulse)

func _animate_ripples(delta):
    for ripple in ripples:
        var life = float(ripple.get_meta("life", 0.0))
        if life <= 0.0:
            continue
        life -= delta
        ripple.set_meta("life", life)
        var progress = clamp(1.0 - life / 1.8, 0.0, 1.0)
        var spread = lerp(0.18, 2.3, progress)
        ripple.scale = Vector3(spread, 1.0, spread * 0.78)
        var material = ripple.material_override
        if material is StandardMaterial3D:
            var alpha = (1.0 - progress) * 0.34
            material.albedo_color = Color(0.62, 0.90, 0.94, alpha)
        if life <= 0.0:
            ripple.visible = false

func _trigger_random_ripple():
    for ripple in ripples:
        if float(ripple.get_meta("life", 0.0)) <= 0.0:
            var angle = rng.randf_range(0.0, TAU)
            var radius = sqrt(rng.randf()) * 1.8
            ripple.position = Vector3(2.0 + cos(angle) * radius, 0.145, 2.1 + sin(angle) * radius * 0.72)
            ripple.scale = Vector3(0.12, 1.0, 0.12)
            ripple.set_meta("life", 1.8)
            ripple.visible = true
            return

func _mat(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _transparent_mat(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material
