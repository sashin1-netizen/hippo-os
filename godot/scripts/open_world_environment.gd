extends Node

const HALF_X := 48.0
const HALF_Z := 32.0
const GRID_X := 96
const GRID_Z := 64
const GRASS_DIFF := "res://assets/textures/leafy_grass_diff_4k.jpg"
const GRASS_NORMAL := "res://assets/textures/leafy_grass_nor_gl_4k.jpg"
const GRASS_ROUGH := "res://assets/textures/leafy_grass_rough_4k.jpg"
const MUD_DIFF := "res://assets/textures/brown_mud_03_diff_4k.jpg"
const MUD_NORMAL := "res://assets/textures/brown_mud_03_nor_gl_4k.jpg"
const MUD_ROUGH := "res://assets/textures/brown_mud_03_rough_4k.jpg"

var host
var terrain_mesh: MeshInstance3D
var terrain_body: StaticBody3D
var rng := RandomNumberGenerator.new()

func _ready():
    rng.seed = 912884
    for i in range(3):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _build_outer_terrain()
    _build_height_collision()
    _build_meandering_paths()
    _build_tree_groves()
    _build_outer_rocks()
    _build_stream_extension()
    _relocate_animals_for_open_world()

func terrain_height(x: float, z: float) -> float:
    # Keep the original habitat core nearly level so existing pond/mud props sit cleanly,
    # then open into rolling grassland and rocky rises outside the central sanctuary.
    var core_x = abs(x) / 17.0
    var core_z = abs(z) / 11.0
    var outside = smoothstep(0.72, 1.75, max(core_x, core_z))
    var broad = sin(x * 0.105) * cos(z * 0.13) * 0.78
    broad += sin((x + z) * 0.067 + 0.9) * 0.42
    broad += cos((x - z) * 0.049 - 0.4) * 0.30
    var ridge = pow(abs(sin(x * 0.054 + z * 0.031)), 2.4) * 0.85
    var h = 0.015 + outside * (broad + ridge - 0.42)

    # A shallow natural drainage line extends the pygmy-hippo wetland into the world.
    var stream_x = 3.3 + sin(z * 0.16) * 2.2
    var stream_distance = abs(x - stream_x)
    if z > 4.0 and stream_distance < 2.4:
        h -= smoothstep(2.4, 0.0, stream_distance) * 0.34

    # Give the far edges stronger relief so the sanctuary feels geographically bounded
    # without using visible game-like walls.
    var edge = max(abs(x) / HALF_X, abs(z) / HALF_Z)
    if edge > 0.78:
        h += smoothstep(0.78, 1.0, edge) * 1.25
    return h

func _build_outer_terrain():
    terrain_mesh = MeshInstance3D.new()
    terrain_mesh.name = "OpenWorldTerrain"
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ix in range(GRID_X):
        for iz in range(GRID_Z):
            var x0 = lerp(-HALF_X, HALF_X, float(ix) / float(GRID_X))
            var x1 = lerp(-HALF_X, HALF_X, float(ix + 1) / float(GRID_X))
            var z0 = lerp(-HALF_Z, HALF_Z, float(iz) / float(GRID_Z))
            var z1 = lerp(-HALF_Z, HALF_Z, float(iz + 1) / float(GRID_Z))
            var p00 = Vector3(x0, terrain_height(x0, z0), z0)
            var p10 = Vector3(x1, terrain_height(x1, z0), z0)
            var p01 = Vector3(x0, terrain_height(x0, z1), z1)
            var p11 = Vector3(x1, terrain_height(x1, z1), z1)
            _triangle(surface, p00, p10, p11)
            _triangle(surface, p00, p11, p01)
    surface.generate_normals()
    terrain_mesh.mesh = surface.commit()
    terrain_mesh.material_override = _grass_material()
    host.add_child(terrain_mesh)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3):
    for p in [a, b, c]:
        surface.set_uv(Vector2((p.x + HALF_X) / 8.0, (p.z + HALF_Z) / 8.0))
        surface.add_vertex(p)

func _grass_material():
    var material := StandardMaterial3D.new()
    if ResourceLoader.exists(GRASS_DIFF):
        material.albedo_texture = load(GRASS_DIFF)
    if ResourceLoader.exists(GRASS_NORMAL):
        material.normal_enabled = true
        material.normal_texture = load(GRASS_NORMAL)
        material.normal_scale = 0.72
    if ResourceLoader.exists(GRASS_ROUGH):
        material.roughness_texture = load(GRASS_ROUGH)
    material.roughness = 0.94
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.uv1_scale = Vector3(0.115, 0.115, 0.115)
    return material

func _mud_material():
    var material := StandardMaterial3D.new()
    if ResourceLoader.exists(MUD_DIFF):
        material.albedo_texture = load(MUD_DIFF)
    if ResourceLoader.exists(MUD_NORMAL):
        material.normal_enabled = true
        material.normal_texture = load(MUD_NORMAL)
        material.normal_scale = 0.82
    if ResourceLoader.exists(MUD_ROUGH):
        material.roughness_texture = load(MUD_ROUGH)
    material.roughness = 0.78
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.uv1_scale = Vector3(0.20, 0.20, 0.20)
    return material

func _build_height_collision():
    terrain_body = StaticBody3D.new()
    terrain_body.name = "OpenWorldTerrainCollision"
    terrain_body.collision_layer = 1
    var collision := CollisionShape3D.new()
    var shape := HeightMapShape3D.new()
    shape.map_width = GRID_X + 1
    shape.map_depth = GRID_Z + 1
    var heights := PackedFloat32Array()
    heights.resize((GRID_X + 1) * (GRID_Z + 1))
    var cursor = 0
    for iz in range(GRID_Z + 1):
        var z = lerp(-HALF_Z, HALF_Z, float(iz) / float(GRID_Z))
        for ix in range(GRID_X + 1):
            var x = lerp(-HALF_X, HALF_X, float(ix) / float(GRID_X))
            heights[cursor] = terrain_height(x, z)
            cursor += 1
    shape.map_data = heights
    collision.shape = shape
    terrain_body.add_child(collision)
    host.add_child(terrain_body)

func _build_meandering_paths():
    _path_ribbon([Vector2(-2, -1), Vector2(-7, -6), Vector2(-15, -8), Vector2(-23, -5), Vector2(-31, 1)], 1.15)
    _path_ribbon([Vector2(3, -1), Vector2(9, -6), Vector2(18, -7), Vector2(26, -2), Vector2(34, 6)], 1.05)
    _path_ribbon([Vector2(0, 4), Vector2(-1, 10), Vector2(3, 17), Vector2(1, 25)], 0.92)

func _path_ribbon(points: Array, width: float):
    if points.size() < 2:
        return
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "SanctuaryTrail"
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(points.size() - 1):
        var a: Vector2 = points[i]
        var b: Vector2 = points[i + 1]
        var direction = (b - a).normalized()
        var side = Vector2(-direction.y, direction.x) * width * 0.5
        var p0 = Vector3(a.x + side.x, terrain_height(a.x + side.x, a.y + side.y) + 0.022, a.y + side.y)
        var p1 = Vector3(a.x - side.x, terrain_height(a.x - side.x, a.y - side.y) + 0.022, a.y - side.y)
        var p2 = Vector3(b.x - side.x, terrain_height(b.x - side.x, b.y - side.y) + 0.022, b.y - side.y)
        var p3 = Vector3(b.x + side.x, terrain_height(b.x + side.x, b.y + side.y) + 0.022, b.y + side.y)
        for p in [p0, p1, p2, p0, p2, p3]:
            surface.set_uv(Vector2(p.x * 0.25, p.z * 0.25))
            surface.add_vertex(p)
    surface.generate_normals()
    mesh_instance.mesh = surface.commit()
    mesh_instance.material_override = _mud_material()
    host.add_child(mesh_instance)

func _build_tree_groves():
    var centers = [
        Vector2(-34, -16), Vector2(-28, 14), Vector2(-18, 23),
        Vector2(28, 18), Vector2(36, -13), Vector2(22, -22), Vector2(41, 7)
    ]
    for center in centers:
        for i in range(10):
            var angle = rng.randf_range(0.0, TAU)
            var radius = rng.randf_range(1.4, 8.2)
            var x = center.x + cos(angle) * radius
            var z = center.y + sin(angle) * radius
            if abs(x) > HALF_X - 2.0 or abs(z) > HALF_Z - 2.0:
                continue
            _tree(Vector3(x, terrain_height(x, z), z), rng.randf_range(2.4, 5.0))

func _tree(pos: Vector3, height: float):
    var root := Node3D.new()
    root.name = "OpenWorldTree"
    root.position = pos
    host.add_child(root)

    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = height * 0.045
    trunk_mesh.bottom_radius = height * 0.072
    trunk_mesh.height = height * 0.62
    trunk_mesh.radial_segments = 8
    trunk.mesh = trunk_mesh
    trunk.position.y = trunk_mesh.height * 0.5
    var bark := StandardMaterial3D.new()
    bark.albedo_color = Color(0.17, 0.105, 0.058)
    bark.roughness = 0.95
    trunk.material_override = bark
    root.add_child(trunk)

    var leaf_material := StandardMaterial3D.new()
    leaf_material.albedo_color = Color(0.055, rng.randf_range(0.19, 0.31), 0.07)
    leaf_material.roughness = 0.90
    for offset in [Vector3(0, 0.72, 0), Vector3(-0.42, 0.50, 0.10), Vector3(0.40, 0.47, -0.08)]:
        var crown := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = height * 0.31
        sphere.height = height * 0.50
        sphere.radial_segments = 10
        sphere.rings = 5
        crown.mesh = sphere
        crown.position = Vector3(offset.x * height, height * 0.60 + offset.y * height * 0.28, offset.z * height)
        crown.scale = Vector3(1.22, 0.72, 1.0)
        crown.material_override = leaf_material
        root.add_child(crown)

func _build_outer_rocks():
    for i in range(58):
        var x = rng.randf_range(-HALF_X + 3.0, HALF_X - 3.0)
        var z = rng.randf_range(-HALF_Z + 3.0, HALF_Z - 3.0)
        if abs(x) < 16.0 and abs(z) < 11.0:
            continue
        var rock := MeshInstance3D.new()
        rock.name = "OpenWorldRock"
        var sphere := SphereMesh.new()
        sphere.radius = 0.5
        sphere.height = 0.85
        sphere.radial_segments = 8
        sphere.rings = 5
        rock.mesh = sphere
        var scale = rng.randf_range(0.35, 1.5)
        rock.scale = Vector3(scale * rng.randf_range(0.85, 1.45), scale * rng.randf_range(0.45, 0.82), scale)
        rock.rotation_degrees = Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 180), rng.randf_range(-8, 8))
        rock.position = Vector3(x, terrain_height(x, z) + scale * 0.18, z)
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(rng.randf_range(0.22, 0.34), rng.randf_range(0.22, 0.32), rng.randf_range(0.20, 0.29))
        material.roughness = 0.98
        rock.material_override = material
        host.add_child(rock)

func _build_stream_extension():
    var water_material := ShaderMaterial.new()
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 water_color : source_color = vec4(0.035, 0.22, 0.25, 0.92);
void vertex(){ VERTEX.y += sin(VERTEX.x * 2.8 + TIME * 1.5) * 0.012 + cos(VERTEX.z * 2.1 - TIME) * 0.009; }
void fragment(){ float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0); ALBEDO = mix(water_color.rgb, vec3(0.18,0.42,0.46), f); ROUGHNESS = mix(0.15,0.04,f); SPECULAR = 0.78; ALPHA = 0.92; }
"""
    water_material.shader = shader
    for z in range(6, 30, 3):
        var center_x = 3.3 + sin(float(z) * 0.16) * 2.2
        var segment := MeshInstance3D.new()
        var plane := PlaneMesh.new()
        plane.size = Vector2(3.4, 3.8)
        segment.mesh = plane
        segment.position = Vector3(center_x, terrain_height(center_x, float(z)) + 0.16, float(z))
        segment.material_override = water_material
        host.add_child(segment)

func _relocate_animals_for_open_world():
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    var homes = {
        "hippo_01": [Vector3(1.0, 0.9, 6.0), Vector2(11.0, 9.0)],
        "pig_01": [Vector3(-17.0, 0.72, -5.0), Vector2(10.5, 9.0)],
        "sharpei_01": [Vector3(17.0, 0.78, -4.0), Vector2(12.0, 10.0)]
    }
    for animal_id in homes.keys():
        var actor = animals.get(animal_id, null)
        if actor == null:
            continue
        var entry = homes[animal_id]
        var home: Vector3 = entry[0]
        home.y = terrain_height(home.x, home.z) + home.y
        actor.home_center = home
        actor.zone_radius = entry[1]
        actor.global_position = home
        actor.move_target = home
