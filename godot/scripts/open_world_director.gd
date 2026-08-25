extends Node

# Authoritative open-world presentation layer for the portrait sanctuary.
# It keeps the existing pet simulation, saves, audio, interactions and production GLB
# bridge intact while making the restored grasslands/premium habitat read as one large
# wildlife environment instead of a prototype arena. This layer owns only presentation:
# legacy primitive visibility, opening staging, camera composition and atmospheric depth.

const HIPPO_HOME := Vector3(0.0, 0.80, 0.0)
const PIG_HOME := Vector3(-4.2, 0.72, 3.25)
const DOG_HOME := Vector3(-4.4, 0.75, -3.10)
const WORLD_RADIUS := 12.0

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var open_world_root: Node3D

var bound := false
var staging_done := false
var scenery_timer := 0.0
var environment_timer := 0.0
var ui_timer := 0.0
var smoothed_focus := Vector3.ZERO
var focus_ready := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 5000
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(720):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            camera = _find_camera(scene_root)
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            if camera != null and hippo != null and pig != null and dog != null:
                break
        await get_tree().process_frame

    if scene_root == null or roster == null or camera == null or hippo == null or pig == null or dog == null:
        push_warning("OpenWorldDirector could not bind to the complete sanctuary")
        return

    # PremiumExperience and GrasslandsSanctuary are asynchronous autoload builders.
    # Let them finish, then make their output authoritative and remove only old base
    # prototype meshes that otherwise punch through the open-world composition.
    for _frame in range(40):
        await get_tree().process_frame

    _bind_environment()
    _build_open_world_finish()
    _hide_base_prototype_geometry()
    _expand_ground_finish()
    _stage_opening_companions()
    _set_opening_orbit()
    _apply_environment()
    _keep_world_layers_visible()
    bound = true
    set_process(true)

func _process(delta: float) -> void:
    if not bound or scene_root == null:
        return

    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return

    _correct_companion_orientation(delta)
    _update_camera(delta)
    _soft_world_bounds()

    scenery_timer -= delta
    environment_timer -= delta
    ui_timer -= delta

    if scenery_timer <= 0.0:
        scenery_timer = 0.45
        _hide_base_prototype_geometry()
        _keep_world_layers_visible()
        _clear_camera_lane()

    if environment_timer <= 0.0:
        environment_timer = 1.5
        _bind_environment()
        _apply_environment()

    if ui_timer <= 0.0:
        ui_timer = 0.7
        _hide_legacy_ui()

func _build_open_world_finish() -> void:
    var existing := scene_root.find_child("OpenWorldAuthority", true, false) as Node3D
    if existing != null:
        open_world_root = existing
        open_world_root.visible = true
        return

    open_world_root = Node3D.new()
    open_world_root.name = "OpenWorldAuthority"
    scene_root.add_child(open_world_root)

    _add_distant_escarpment()
    _add_signature_acacia(Vector3(-7.2, 0.0, -5.25), 1.45)
    _add_signature_acacia(Vector3(-10.4, 0.0, 5.8), 0.95)
    _add_distant_scrub()

func _add_distant_escarpment() -> void:
    var rocky := _rock_material()
    var positions: Array[Vector3] = [
        Vector3(-15.0, 1.8, -8.0),
        Vector3(-17.0, 2.4, -2.8),
        Vector3(-18.2, 2.2, 3.0),
        Vector3(-15.6, 1.7, 8.2)
    ]
    var scales: Array[Vector3] = [
        Vector3(4.8, 2.8, 4.2),
        Vector3(5.6, 3.7, 5.4),
        Vector3(5.2, 3.3, 5.0),
        Vector3(4.5, 2.6, 4.0)
    ]
    for i in range(positions.size()):
        var ridge := MeshInstance3D.new()
        ridge.name = "OpenWorldEscarpment%02d" % i
        var mesh := SphereMesh.new()
        mesh.radial_segments = 32
        mesh.rings = 16
        ridge.mesh = mesh
        ridge.position = positions[i]
        ridge.scale = scales[i]
        ridge.material_override = rocky
        ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        open_world_root.add_child(ridge)

func _add_signature_acacia(origin: Vector3, scale_value: float) -> void:
    var trunk_mat := _material(Color(0.22, 0.135, 0.060), 0.94)
    var leaf_dark := _material(Color(0.075, 0.185, 0.040), 0.91)
    var leaf_light := _material(Color(0.14, 0.255, 0.065), 0.89)

    var trunk := MeshInstance3D.new()
    trunk.name = "SignatureAcaciaTrunk"
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.11 * scale_value
    trunk_mesh.bottom_radius = 0.24 * scale_value
    trunk_mesh.height = 3.6 * scale_value
    trunk_mesh.radial_segments = 14
    trunk.mesh = trunk_mesh
    trunk.position = origin + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
    trunk.rotation_degrees.z = -4.5
    trunk.material_override = trunk_mat
    open_world_root.add_child(trunk)

    var branch_data: Array[Dictionary] = [
        {"p": Vector3(0.22, 2.55, 0.0), "r": Vector3(0.0, 0.0, 55.0), "l": 1.45},
        {"p": Vector3(-0.18, 2.78, 0.02), "r": Vector3(0.0, 0.0, -53.0), "l": 1.25},
        {"p": Vector3(0.05, 3.12, 0.0), "r": Vector3(16.0, 0.0, 20.0), "l": 1.15}
    ]
    for item in branch_data:
        var branch := MeshInstance3D.new()
        branch.name = "SignatureAcaciaBranch"
        var branch_mesh := CylinderMesh.new()
        branch_mesh.top_radius = 0.045 * scale_value
        branch_mesh.bottom_radius = 0.075 * scale_value
        branch_mesh.height = float(item["l"]) * scale_value
        branch_mesh.radial_segments = 10
        branch.mesh = branch_mesh
        branch.position = origin + (item["p"] as Vector3) * scale_value
        branch.rotation_degrees = item["r"] as Vector3
        branch.material_override = trunk_mat
        open_world_root.add_child(branch)

    var canopy_offsets: Array[Vector3] = [
        Vector3(0.0, 3.70, 0.0),
        Vector3(0.75, 3.55, 0.05),
        Vector3(-0.72, 3.58, -0.04),
        Vector3(0.30, 3.63, 0.58),
        Vector3(-0.22, 3.62, -0.60),
        Vector3(1.18, 3.40, -0.22),
        Vector3(-1.08, 3.42, 0.20)
    ]
    for i in range(canopy_offsets.size()):
        var canopy := MeshInstance3D.new()
        canopy.name = "SignatureAcaciaCanopy"
        var canopy_mesh := SphereMesh.new()
        canopy_mesh.radial_segments = 20
        canopy_mesh.rings = 10
        canopy.mesh = canopy_mesh
        canopy.position = origin + canopy_offsets[i] * scale_value
        canopy.scale = Vector3(1.08, 0.29, 0.74) * scale_value * (0.90 + float(i % 3) * 0.07)
        canopy.material_override = leaf_light if i % 3 == 0 else leaf_dark
        canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        open_world_root.add_child(canopy)

func _add_distant_scrub() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 25082619
    var mats: Array[StandardMaterial3D] = [
        _material(Color(0.085, 0.205, 0.045), 0.94),
        _material(Color(0.145, 0.255, 0.065), 0.94),
        _material(Color(0.205, 0.285, 0.080), 0.95)
    ]
    for i in range(34):
        var shrub := MeshInstance3D.new()
        shrub.name = "OpenWorldScrub"
        var mesh := SphereMesh.new()
        mesh.radial_segments = 12
        mesh.rings = 7
        shrub.mesh = mesh
        var x := rng.randf_range(-13.5, -5.0)
        var z := rng.randf_range(-9.5, 9.5)
        var s := rng.randf_range(0.28, 0.72)
        shrub.position = Vector3(x, s * 0.30, z)
        shrub.scale = Vector3(s * rng.randf_range(1.0, 1.55), s * 0.44, s)
        shrub.material_override = mats[i % mats.size()]
        shrub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        open_world_root.add_child(shrub)

func _expand_ground_finish() -> void:
    var ground := scene_root.find_child("SanctuaryGroundFinish", true, false) as MeshInstance3D
    if ground != null and ground.mesh is PlaneMesh:
        var plane := ground.mesh as PlaneMesh
        if plane.size.x < 30.0 or plane.size.y < 24.0:
            var expanded := plane.duplicate() as PlaneMesh
            expanded.size = Vector2(34.0, 26.0)
            expanded.subdivide_width = maxi(expanded.subdivide_width, 28)
            expanded.subdivide_depth = maxi(expanded.subdivide_depth, 22)
            ground.mesh = expanded
        ground.position = Vector3(-4.0, 0.016, 0.0)
        ground.visible = true

func _stage_opening_companions() -> void:
    if staging_done:
        return
    hippo.position = HIPPO_HOME
    pig.position = PIG_HOME
    dog.position = DOG_HOME
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    hippo.rotation = Vector3.ZERO
    pig.rotation = Vector3.ZERO
    dog.rotation = Vector3.ZERO
    staging_done = true

func _set_opening_orbit() -> void:
    scene_root.set("orbit_yaw", 1.53)
    scene_root.set("orbit_pitch", -0.035)
    scene_root.set("orbit_distance", 8.4)

func _update_camera(delta: float) -> void:
    var sanctuary_hud := get_node_or_null("/root/SanctuaryHUD")
    if sanctuary_hud != null and bool(sanctuary_hud.get("bodycam_mode")):
        return

    var selected := _selected_body()
    if selected == null:
        selected = hippo
    if selected == null:
        return

    var viewport := get_viewport().get_visible_rect().size
    var portrait := viewport.y >= viewport.x
    var focus := selected.global_position + Vector3(0.0, 0.48, 0.0)
    if not focus_ready:
        smoothed_focus = focus
        focus_ready = true
    else:
        smoothed_focus = smoothed_focus.lerp(focus, clampf(delta * 4.8, 0.0, 1.0))

    var yaw := float(scene_root.get("orbit_yaw"))
    var pitch := clampf(float(scene_root.get("orbit_pitch")), -0.22, 0.12)
    var requested_distance := float(scene_root.get("orbit_distance"))
    var min_distance := 6.8 if portrait else 5.8
    var max_distance := 10.8 if portrait else 9.4
    var distance := clampf(requested_distance, min_distance, max_distance)

    var horizontal := cos(pitch) * distance
    var camera_height := 0.92 if portrait else 0.72
    var desired := smoothed_focus + Vector3(
        sin(yaw) * horizontal,
        -sin(pitch) * distance + camera_height,
        cos(yaw) * horizontal
    )

    camera.global_position = camera.global_position.lerp(desired, clampf(delta * 5.6, 0.0, 1.0))
    camera.look_at(smoothed_focus + Vector3(0.0, -0.04 if portrait else 0.02, 0.0), Vector3.UP)
    var target_fov := 48.0 if portrait else 46.0
    camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 4.4, 0.0, 1.0))

func _selected_body() -> Node3D:
    if roster == null:
        return hippo
    var companions_value: Variant = roster.get("companions")
    if typeof(companions_value) != TYPE_DICTIONARY:
        return hippo
    var companions := companions_value as Dictionary
    var species := str(roster.get("selected_species"))
    var data_value: Variant = companions.get(species, {})
    if typeof(data_value) != TYPE_DICTIONARY:
        return hippo
    var body := (data_value as Dictionary).get("node") as Node3D
    return body if body != null and is_instance_valid(body) else hippo

func _correct_companion_orientation(delta: float) -> void:
    _orient_body(hippo, camera.global_position - hippo.global_position, delta, 8.0, true)
    _orient_body(pig, _attention_direction(pig), delta, 5.2, false)
    _orient_body(dog, _attention_direction(dog), delta, 5.5, false)

func _orient_body(body: CharacterBody3D, fallback: Vector3, delta: float, speed: float, face_camera_when_idle: bool) -> void:
    if body == null or not is_instance_valid(body):
        return
    var direction := Vector3(body.velocity.x, 0.0, body.velocity.z)
    if direction.length_squared() < 0.018:
        if not face_camera_when_idle and body.global_position.distance_to(hippo.global_position) > 0.1:
            direction = hippo.global_position - body.global_position
        else:
            direction = fallback
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        return
    direction = direction.normalized()
    var target_yaw := atan2(-direction.z, direction.x)
    body.rotation.y = lerp_angle(body.rotation.y, target_yaw, 1.0 - exp(-speed * delta))
    body.rotation.x = 0.0
    body.rotation.z = 0.0

func _attention_direction(body: CharacterBody3D) -> Vector3:
    if body == null or hippo == null:
        return Vector3(1.0, 0.0, 0.0)
    var direction := hippo.global_position - body.global_position
    direction.y = 0.0
    return direction

func _soft_world_bounds() -> void:
    for body in [hippo, pig, dog]:
        if body == null:
            continue
        var flat := Vector2(body.position.x, body.position.z)
        if flat.length() > WORLD_RADIUS:
            body.position.x = lerpf(body.position.x, 0.0, 0.045)
            body.position.z = lerpf(body.position.z, 0.0, 0.045)

func _hide_base_prototype_geometry() -> void:
    if scene_root == null:
        return
    for child in scene_root.get_children():
        if child == hippo or child == pig or child == dog:
            continue
        if child == open_world_root:
            continue
        if child is MeshInstance3D:
            (child as MeshInstance3D).visible = false
        elif child is StaticBody3D:
            for grandchild in child.get_children():
                if grandchild is GeometryInstance3D:
                    (grandchild as GeometryInstance3D).visible = false

func _keep_world_layers_visible() -> void:
    for node_name in ["PremiumExperienceWorld", "GrasslandsProductionLayer", "SanctuaryVisualPolish", "OpenWorldAuthority"]:
        var root := scene_root.find_child(node_name, true, false) as Node3D
        if root != null:
            root.visible = true

func _clear_camera_lane() -> void:
    if camera == null or hippo == null:
        return
    var roots: Array[Node3D] = []
    for node_name in ["PremiumExperienceWorld", "GrasslandsProductionLayer"]:
        var root := scene_root.find_child(node_name, true, false) as Node3D
        if root != null:
            roots.append(root)

    var hero_vector := hippo.global_position + Vector3(0.0, 0.45, 0.0) - camera.global_position
    var hero_len_sq := hero_vector.length_squared()
    if hero_len_sq < 0.01:
        return

    for root in roots:
        _clear_lane_recursive(root, hero_vector, hero_len_sq)

func _clear_lane_recursive(node: Node, hero_vector: Vector3, hero_len_sq: float) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var visual := child as MeshInstance3D
            var to_object := visual.global_position - camera.global_position
            var along := to_object.dot(hero_vector) / hero_len_sq
            if along > 0.08 and along < 0.88:
                var perpendicular := (to_object - hero_vector * along).length()
                if perpendicular < 1.55 and _is_tall_blocker(visual):
                    visual.visible = false
        _clear_lane_recursive(child, hero_vector, hero_len_sq)

func _is_tall_blocker(visual: MeshInstance3D) -> bool:
    if visual.mesh is CylinderMesh:
        var cylinder := visual.mesh as CylinderMesh
        return cylinder.height * absf(visual.scale.y) > 0.75
    if visual.mesh is SphereMesh:
        return visual.global_position.y > 1.1 and visual.scale.length() > 1.2
    return false

func _hide_legacy_ui() -> void:
    var stats_value: Variant = scene_root.get("stats_panel")
    if stats_value is Control:
        (stats_value as Control).visible = false
    var personal_ui := scene_root.find_child("PersonalUseUI", true, false)
    if personal_ui is CanvasLayer:
        (personal_ui as CanvasLayer).visible = false
    var roster_ui := scene_root.find_child("CompanionRosterUI", true, false)
    if roster_ui is CanvasLayer:
        (roster_ui as CanvasLayer).visible = false

func _bind_environment() -> void:
    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    sun_light = _find_sun(scene_root)

func _apply_environment() -> void:
    if world_environment == null:
        return
    if world_environment.environment == null:
        world_environment.environment = Environment.new()
    var env := world_environment.environment
    var daylight := _daylight_factor()

    var sky := env.sky
    var sky_material: ProceduralSkyMaterial
    if sky == null or not (sky.sky_material is ProceduralSkyMaterial):
        sky = Sky.new()
        sky.radiance_size = Sky.RADIANCE_SIZE_128
        sky_material = ProceduralSkyMaterial.new()
        sky.sky_material = sky_material
        env.sky = sky
    else:
        sky_material = sky.sky_material as ProceduralSkyMaterial

    sky_material.sky_top_color = Color(0.045, 0.22, 0.48).lerp(Color(0.12, 0.47, 0.82), daylight)
    sky_material.sky_horizon_color = Color(0.44, 0.48, 0.54).lerp(Color(0.72, 0.86, 0.95), daylight)
    sky_material.ground_bottom_color = Color(0.035, 0.055, 0.040)
    sky_material.ground_horizon_color = Color(0.28, 0.34, 0.22).lerp(Color(0.48, 0.55, 0.34), daylight)
    sky_material.sun_angle_max = 18.0
    sky_material.sun_curve = 0.055
    sky_material.use_debanding = true

    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.ambient_light_energy = lerpf(0.78, 0.94, daylight)
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.38, 0.43, 0.48).lerp(Color(0.72, 0.79, 0.75), daylight)
    env.fog_light_energy = lerpf(0.38, 0.54, daylight)
    env.fog_density = lerpf(0.011, 0.0038, daylight)
    env.fog_height = -0.4
    env.fog_height_density = 0.035
    env.fog_sky_affect = 0.22
    env.adjustment_enabled = true
    env.adjustment_brightness = lerpf(1.04, 1.08, daylight)
    env.adjustment_contrast = 1.03
    env.adjustment_saturation = lerpf(0.91, 0.96, daylight)

    if sun_light != null:
        sun_light.light_color = Color(0.66, 0.73, 0.94).lerp(Color(1.0, 0.93, 0.80), daylight)
        sun_light.light_energy = lerpf(0.55, 1.32, daylight)
        sun_light.shadow_enabled = true
        sun_light.directional_shadow_max_distance = 48.0

func _daylight_factor() -> float:
    var mode := "auto"
    var settings_value: Variant = scene_root.get("settings")
    if typeof(settings_value) == TYPE_DICTIONARY:
        mode = str((settings_value as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0
    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    return clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)

func _rock_material() -> Material:
    var architecture := Engine.get_architecture_name().to_lower()
    var diff_path := "res://assets/habitat/pbr/rocks_ground_08_diff_4k.jpg"
    var norm_path := "res://assets/habitat/pbr/rocks_ground_08_nor_gl_4k.jpg"
    var rough_path := "res://assets/habitat/pbr/rocks_ground_08_rough_4k.jpg"
    if ResourceLoader.exists(diff_path):
        var mat := StandardMaterial3D.new()
        mat.albedo_texture = load(diff_path) as Texture2D
        mat.roughness = 0.90
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        if not "x86" in architecture and ResourceLoader.exists(norm_path) and ResourceLoader.exists(rough_path):
            mat.normal_enabled = true
            mat.normal_texture = load(norm_path) as Texture2D
            mat.roughness_texture = load(rough_path) as Texture2D
        return mat
    return _material(Color(0.29, 0.25, 0.19), 0.96)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null

func _find_sun(node: Node) -> DirectionalLight3D:
    if node is DirectionalLight3D:
        var light := node as DirectionalLight3D
        if light.name != "PhoneReadabilityFill" and light.name != "QualityRimLight":
            return light
    for child in node.get_children():
        var found := _find_sun(child)
        if found != null:
            return found
    return null
