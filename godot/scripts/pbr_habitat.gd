extends Node

# Applies real CC0 photographed PBR texture sets when build-fetched assets exist.
# The procedural materials remain a source-tree fallback, while Android release builds
# package the 1K maps into the APK before Godot import.

const FOREST_DIFF := "res://assets/habitat/pbr/forrest_ground_01_diff_1k.jpg"
const FOREST_NORM := "res://assets/habitat/pbr/forrest_ground_01_nor_gl_1k.jpg"
const FOREST_ROUGH := "res://assets/habitat/pbr/forrest_ground_01_rough_1k.jpg"
const ROCK_DIFF := "res://assets/habitat/pbr/rocks_ground_08_diff_1k.jpg"
const ROCK_NORM := "res://assets/habitat/pbr/rocks_ground_08_nor_gl_1k.jpg"
const ROCK_ROUGH := "res://assets/habitat/pbr/rocks_ground_08_rough_1k.jpg"

var scene_root: Node3D
var applied := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 330
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var current := get_tree().current_scene
        if current is Node3D:
            scene_root = current as Node3D
            if scene_root.find_child("SanctuaryGroundFinish", true, false) != null:
                break
        await get_tree().process_frame

    if scene_root == null:
        return
    for _frame in range(6):
        await get_tree().process_frame
    _apply_pbr()

func _apply_pbr() -> void:
    if not _all_textures_exist():
        push_warning("PBRHabitat: build-fetched CC0 maps unavailable; keeping procedural fallback")
        return

    var forest := _material(FOREST_DIFF, FOREST_NORM, FOREST_ROUGH, Vector3(5.6, 5.6, 5.6), 0.96)
    var rocky := _material(ROCK_DIFF, ROCK_NORM, ROCK_ROUGH, Vector3(2.4, 2.4, 2.4), 0.91)

    var ground := scene_root.find_child("SanctuaryGroundFinish", true, false) as MeshInstance3D
    if ground != null:
        ground.material_override = forest
        ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

    var mud := scene_root.find_child("PremiumMudSurface", true, false) as MeshInstance3D
    if mud != null:
        var mud_material := rocky.duplicate() as StandardMaterial3D
        mud_material.albedo_color = Color(0.67, 0.49, 0.34, 1.0)
        mud_material.roughness = 0.80
        mud.material_override = mud_material

    var premium_world := scene_root.find_child("PremiumExperienceWorld", true, false)
    if premium_world != null:
        _style_named_rocks(premium_world, rocky)
    var grasslands_world := scene_root.find_child("GrasslandsProductionLayer", true, false)
    if grasslands_world != null:
        _style_named_rocks(grasslands_world, rocky)

    applied = true

func _style_named_rocks(root: Node, rocky: StandardMaterial3D) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var mesh := child as MeshInstance3D
            var lower := String(mesh.name).to_lower()
            if "rock" in lower or "stone" in lower:
                mesh.material_override = rocky
                mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        _style_named_rocks(child, rocky)

func _material(diff_path: String, norm_path: String, rough_path: String, uv_scale: Vector3, roughness_value: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture = load(diff_path) as Texture2D
    material.normal_enabled = true
    material.normal_texture = load(norm_path) as Texture2D
    material.roughness_texture = load(rough_path) as Texture2D
    material.roughness = roughness_value
    material.uv1_scale = uv_scale
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return material

func _all_textures_exist() -> bool:
    for path in [FOREST_DIFF, FOREST_NORM, FOREST_ROUGH, ROCK_DIFF, ROCK_NORM, ROCK_ROUGH]:
        if not ResourceLoader.exists(path):
            return false
    return true
