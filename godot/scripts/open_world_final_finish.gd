extends Node

# Final open-world art-direction pass. This deliberately leaves gameplay systems alive
# and only stabilizes the launch composition: bright South African daylight, a textured
# ground plane, restrained vegetation, one readable acacia silhouette and front-facing
# companion staging before autonomous behaviour resumes.

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var finish_root: Node3D
var low_grass: MultiMeshInstance3D
var initialized := false
var timer := 0.0
var launch_hold_until := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 6500
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(760):
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

    if scene_root == null or camera == null or hippo == null or pig == null or dog == null:
        push_warning("OpenWorldFinalFinish could not bind to sanctuary")
        return

    for _frame in range(52):
        await get_tree().process_frame

    _bind_environment()
    _build_finish_root()
    _apply_ground_pbr()
    _simplify_procedural_vegetation()
    _build_low_grass()
    _stage_launch_animals()
    _apply_bright_environment()
    _fix_brand_overlap()
    initialized = true
    set_process(true)

func _process(delta: float) -> void:
    if not initialized:
        return

    timer -= delta
    if timer <= 0.0:
        timer = 0.45
        _bind_environment()
        _apply_bright_environment()
        _simplify_procedural_vegetation()
        _apply_ground_pbr()
        _fix_brand_overlap()

    if Time.get_ticks_msec() / 1000.0 < launch_hold_until:
        _hold_launch_pose(delta)

func _build_finish_root() -> void:
    var existing := scene_root.find_child("OpenWorldFinalFinish", true, false) as Node3D
    if existing != null:
        finish_root = existing
        finish_root.visible = true
        return
    finish_root = Node3D.new()
    finish_root.name = "OpenWorldFinalFinish"
    scene_root.add_child(finish_root)

func _apply_ground_pbr() -> void:
    var ground := scene_root.find_child("SanctuaryGroundFinish", true, false) as MeshInstance3D
    if ground == null:
        return

    var diff_path := "res://assets/habitat/pbr/forrest_ground_01_diff_4k.jpg"
    var norm_path := "res://assets/habitat/pbr/forrest_ground_01_nor_gl_4k.jpg"
    var rough_path := "res://assets/habitat/pbr/forrest_ground_01_rough_4k.jpg"
    if not ResourceLoader.exists(diff_path):
        return

    var material := StandardMaterial3D.new()
    material.albedo_texture = load(diff_path) as Texture2D
    material.albedo_color = Color(0.78, 0.84, 0.70)
    material.roughness = 0.94
    material.uv1_scale = Vector3(4.6, 4.6, 4.6)
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

    var architecture := Engine.get_architecture_name().to_lower()
    if not ("x86" in architecture) and ResourceLoader.exists(norm_path) and ResourceLoader.exists(rough_path):
        material.normal_enabled = true
        material.normal_texture = load(norm_path) as Texture2D
        material.roughness_texture = load(rough_path) as Texture2D

    ground.material_override = material
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    ground.visible = true

func _simplify_procedural_vegetation() -> void:
    # The old grassland generator is useful for water, rocks and habitat depth, but its
    # tall procedural canopies and dense blade field dominate a portrait screen. Keep
    # the landscape and replace only those elements with a restrained foreground layer.
    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass != null:
        grass.visible = false

    var roots: Array[Node3D] = []
    var grasslands := scene_root.find_child("GrasslandsProductionLayer", true, false) as Node3D
    if grasslands != null:
        roots.append(grasslands)
    var open_world := scene_root.find_child("OpenWorldAuthority", true, false) as Node3D
    if open_world != null:
        roots.append(open_world)

    for root in roots:
        _simplify_recursive(root)

func _simplify_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var visual := child as MeshInstance3D
            var lower := String(visual.name).to_lower()

            # Hide the original repeated acacia canopy system. Keep only the signature
            # acacia on the camera-right side (negative Z from the +X launch camera).
            if "acaciacanopy" in lower or lower == "distanttreetrunk" or lower == "distanttreecanopy":
                visual.visible = false
            elif "signatureacacia" in lower:
                visual.visible = visual.global_position.z <= -1.0
            elif "distantridge" in lower:
                visual.visible = false
            elif "shrub" in lower and visual.global_position.x > -4.0:
                visual.visible = false
        _simplify_recursive(child)

func _build_low_grass() -> void:
    if finish_root == null:
        return
    var existing := finish_root.find_child("NaturalLowGrass", false, false) as MultiMeshInstance3D
    if existing != null:
        low_grass = existing
        low_grass.visible = true
        return

    var blade := QuadMesh.new()
    blade.size = Vector2(0.055, 0.30)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.26, 0.39, 0.105)
    material.roughness = 0.97
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    blade.material = material

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade
    multi.instance_count = 260

    var rng := RandomNumberGenerator.new()
    rng.seed = 2508261906
    for i in range(multi.instance_count):
        var x := rng.randf_range(-10.5, 2.5)
        var z := rng.randf_range(-8.5, 8.5)
        var hero_clear := x > -2.8 and x < 2.8 and absf(z) < 2.2
        var water_clear := x > -2.2 and x < 4.2 and z > 0.55 and z < 4.7
        if hero_clear or water_clear:
            x = rng.randf_range(-10.5, -4.0)
            z = rng.randf_range(-8.5, 8.5)
        var height := rng.randf_range(0.55, 1.05)
        var width := rng.randf_range(0.70, 1.15)
        var yaw := rng.randf_range(0.0, TAU)
        var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width, height, 1.0))
        multi.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.15 * height, z)))

    low_grass = MultiMeshInstance3D.new()
    low_grass.name = "NaturalLowGrass"
    low_grass.multimesh = multi
    low_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    finish_root.add_child(low_grass)

func _stage_launch_animals() -> void:
    hippo.position = Vector3(0.0, 0.80, 0.0)
    pig.position = Vector3(-4.4, 0.72, 3.10)
    dog.position = Vector3(-4.7, 0.75, -3.00)
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO

    scene_root.set("current_action", "idle")
    scene_root.set("action_timer", 5.5)
    scene_root.set("orbit_yaw", 1.54)
    scene_root.set("orbit_pitch", -0.025)
    scene_root.set("orbit_distance", 9.1)

    var companions_value: Variant = roster.get("companions") if roster != null else {}
    if typeof(companions_value) == TYPE_DICTIONARY:
        var companions := companions_value as Dictionary
        for species in ["pig", "sharpei"]:
            var value: Variant = companions.get(species, {})
            if typeof(value) == TYPE_DICTIONARY:
                var data := value as Dictionary
                data["action"] = "watch"
                data["action_timer"] = 5.5
                data["call_until"] = 0.0

    launch_hold_until = Time.get_ticks_msec() / 1000.0 + 5.2

func _hold_launch_pose(delta: float) -> void:
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO
    scene_root.set("current_action", "idle")
    scene_root.set("action_timer", 1.0)

    # Procedural anatomy is authored along local +X. Face Mochi into the +X launch
    # camera while the two secondary companions look toward the hero.
    hippo.rotation.y = lerp_angle(hippo.rotation.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))
    pig.rotation.y = lerp_angle(pig.rotation.y, atan2(-(hippo.position.z - pig.position.z), hippo.position.x - pig.position.x), clampf(delta * 6.0, 0.0, 1.0))
    dog.rotation.y = lerp_angle(dog.rotation.y, atan2(-(hippo.position.z - dog.position.z), hippo.position.x - dog.position.x), clampf(delta * 6.0, 0.0, 1.0))

    var hippo_visual := _fallback_visual(hippo)
    if hippo_visual != null:
        hippo_visual.rotation.y = 0.0

func _fallback_visual(body: Node3D) -> Node3D:
    if body == null or body.find_child("ProductionVisual", false, false) != null:
        return null
    for child in body.get_children():
        if child is Node3D and not child is CollisionShape3D:
            return child as Node3D
    return null

func _apply_bright_environment() -> void:
    if world_environment == null or world_environment.environment == null:
        return

    var env := world_environment.environment
    var daylight := _display_daylight_factor()

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

    sky_material.sky_top_color = Color(0.045, 0.17, 0.34).lerp(Color(0.10, 0.46, 0.82), daylight)
    sky_material.sky_horizon_color = Color(0.38, 0.44, 0.50).lerp(Color(0.73, 0.88, 0.98), daylight)
    sky_material.ground_horizon_color = Color(0.31, 0.37, 0.23).lerp(Color(0.56, 0.61, 0.34), daylight)
    sky_material.ground_bottom_color = Color(0.07, 0.09, 0.055)
    sky_material.sun_angle_max = 20.0
    sky_material.sun_curve = 0.045
    sky_material.use_debanding = true

    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.ambient_light_energy = lerpf(0.92, 1.08, daylight)
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.48, 0.52, 0.54).lerp(Color(0.78, 0.84, 0.80), daylight)
    env.fog_light_energy = lerpf(0.42, 0.58, daylight)
    env.fog_density = lerpf(0.0075, 0.0025, daylight)
    env.fog_height = -0.8
    env.fog_height_density = 0.022
    env.fog_sky_affect = 0.14
    env.adjustment_enabled = true
    env.adjustment_brightness = lerpf(1.08, 1.14, daylight)
    env.adjustment_contrast = 1.025
    env.adjustment_saturation = lerpf(0.94, 1.01, daylight)

    if sun_light != null:
        sun_light.light_color = Color(0.72, 0.79, 0.94).lerp(Color(1.0, 0.94, 0.82), daylight)
        sun_light.light_energy = lerpf(0.72, 1.42, daylight)
        sun_light.shadow_enabled = true
        sun_light.directional_shadow_max_distance = 48.0

func _display_daylight_factor() -> float:
    var mode := "auto"
    var settings_value: Variant = scene_root.get("settings")
    if typeof(settings_value) == TYPE_DICTIONARY:
        mode = str((settings_value as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0

    # Keep normal daylight visually bright until early evening. The previous sine curve
    # made 17:00 look like midnight, which is both unrealistic and far from the target.
    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    if hour >= 7.0 and hour <= 17.8:
        return 1.0
    if hour > 17.8 and hour <= 19.2:
        return lerpf(1.0, 0.16, (hour - 17.8) / 1.4)
    if hour >= 5.5 and hour < 7.0:
        return lerpf(0.16, 1.0, (hour - 5.5) / 1.5)
    return 0.08

func _fix_brand_overlap() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null:
        return
    var brand_value: Variant = hud.get("brand_label")
    if brand_value is Label:
        var brand := brand_value as Label
        brand.text = "HIPPO OS"
        brand.add_theme_font_size_override("font_size", 24)
    var subtitle_value: Variant = hud.get("brand_subtitle")
    if subtitle_value is Label:
        (subtitle_value as Label).text = "Sanctuary"

func _bind_environment() -> void:
    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    sun_light = _find_sun(scene_root)

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
