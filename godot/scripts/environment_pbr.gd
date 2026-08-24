extends Node

const GRASS_DIFF = "res://assets/textures/leafy_grass_diff_4k.jpg"
const GRASS_NORMAL = "res://assets/textures/leafy_grass_nor_gl_4k.jpg"
const GRASS_ROUGH = "res://assets/textures/leafy_grass_rough_4k.jpg"
const MUD_DIFF = "res://assets/textures/brown_mud_03_diff_4k.jpg"
const MUD_NORMAL = "res://assets/textures/brown_mud_03_nor_gl_4k.jpg"
const MUD_ROUGH = "res://assets/textures/brown_mud_03_rough_4k.jpg"

var host

func _ready():
    for i in range(4):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    _apply_terrain_material()
    _apply_mud_materials()
    _upgrade_rock_materials()

func _load_texture(path):
    if not ResourceLoader.exists(path):
        push_error("PBR sanctuary texture missing: %s" % path)
        return null
    return load(path)

func _apply_terrain_material():
    var terrain = host.get_node_or_null("NaturalTerrain")
    if terrain == null or not terrain is MeshInstance3D:
        push_error("NaturalTerrain missing for PBR pass")
        return
    var material = StandardMaterial3D.new()
    material.albedo_texture = _load_texture(GRASS_DIFF)
    material.normal_enabled = true
    material.normal_texture = _load_texture(GRASS_NORMAL)
    material.normal_scale = 0.72
    material.roughness = 0.92
    material.roughness_texture = _load_texture(GRASS_ROUGH)
    material.vertex_color_use_as_albedo = true
    material.uv1_scale = Vector3(6.5, 6.5, 6.5)
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    terrain.material_override = material

func _apply_mud_materials():
    for child in host.get_children():
        if not child is MeshInstance3D:
            continue
        var mesh = child.mesh
        if not mesh is CylinderMesh:
            continue
        var radius = float(mesh.top_radius)
        if radius < 1.3 or radius >= 2.0:
            continue
        var material = StandardMaterial3D.new()
        material.albedo_texture = _load_texture(MUD_DIFF)
        material.normal_enabled = true
        material.normal_texture = _load_texture(MUD_NORMAL)
        material.normal_scale = 0.92
        material.roughness = 0.56
        material.roughness_texture = _load_texture(MUD_ROUGH)
        material.uv1_scale = Vector3(1.35, 1.35, 1.35)
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        child.material_override = material
        child.set_meta("living_base_material", material.duplicate(true))

func _upgrade_rock_materials():
    for child in host.get_children():
        if not child is MeshInstance3D:
            continue
        if not child.mesh is SphereMesh:
            continue
        var material = child.material_override
        if material is StandardMaterial3D:
            var upgraded = material.duplicate(true)
            upgraded.roughness = 0.88
            upgraded.metallic = 0.0
            child.material_override = upgraded
