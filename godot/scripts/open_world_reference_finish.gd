extends Node

# Final reference-driven runtime authority for the portrait sanctuary.
# This pass intentionally keeps gameplay, saves, audio, minimap and interaction systems
# untouched. It only resolves visual conflicts left by older procedural presentation
# layers so the live Android scene reads as one coherent South African open world.

const HERO_HOME := Vector3(1.15, 0.80, 1.55)
const PIG_HOME := Vector3(-3.90, 0.72, 3.55)
const DOG_HOME := Vector3(-4.15, 0.75, -2.65)
const LAUNCH_HOLD_SECONDS := 24.0

var scene_root: Node3D
var camera: Camera3D
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var roster: Node
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var initialized := false
var launch_hold_until := 0.0
var maintenance_timer := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 9500
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
        push_warning("OpenWorldReferenceFinish could not bind to complete sanctuary")
        return

    # Let habitat, PBR, animal-art and HUD builders finish before taking final visual
    # authority. No blocking asset loads happen here, which keeps emulator/phone startup
    # responsive while physical ARM64 devices still receive the existing 4K PBR path.
    for _frame in range(54):
        await get_tree().process_frame

    _bind_environment()
    _stage_reference_opening()
    _enforce_world_visibility()
    _enforce_daylight()
    _fix_hud_brand()
    launch_hold_until = Time.get_ticks_msec() / 1000.0 + LAUNCH_HOLD_SECONDS
    initialized = true
    set_process(true)

func _process(delta: float) -> void:
    if not initialized or scene_root == null:
        return

    _maintain_opening_pose(delta)

    maintenance_timer -= delta
    if maintenance_timer <= 0.0:
        maintenance_timer = 0.30
        _bind_environment()
        _enforce_world_visibility()
        _enforce_daylight()
        _fix_hud_brand()

func _stage_reference_opening() -> void:
    hippo.position = HERO_HOME
    pig.position = PIG_HOME
    dog.position = DOG_HOME
    hippo.velocity = Vector3.ZERO
    pig.velocity = Vector3.ZERO
    dog.velocity = Vector3.ZERO

    scene_root.set("current_action", "idle")
    scene_root.set("action_timer", LAUNCH_HOLD_SECONDS)
    scene_root.set("orbit_yaw", 1.53)
    scene_root.set("orbit_pitch", -0.045)
    scene_root.set("orbit_distance", 9.0)

    _set_secondary_action("pig", "watch", LAUNCH_HOLD_SECONDS)
    _set_secondary_action("sharpei", "watch", LAUNCH_HOLD_SECONDS)
    _face_body_toward(hippo, camera.global_position, 1.0)
    _face_body_toward(pig, hippo.global_position, 1.0)
    _face_body_toward(dog, hippo.global_position, 1.0)

func _maintain_opening_pose(delta: float) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if now < launch_hold_until:
        hippo.velocity = Vector3.ZERO
        pig.velocity = Vector3.ZERO
        dog.velocity = Vector3.ZERO
        hippo.position = hippo.position.lerp(HERO_HOME, clampf(delta * 6.0, 0.0, 1.0))
        pig.position = pig.position.lerp(PIG_HOME, clampf(delta * 4.0, 0.0, 1.0))
        dog.position = dog.position.lerp(DOG_HOME, clampf(delta * 4.0, 0.0, 1.0))
        scene_root.set("current_action", "idle")
        scene_root.set("action_timer", 1.5)
        _set_secondary_action("pig", "watch", 1.5)
        _set_secondary_action("sharpei", "watch", 1.5)
        _face_body_toward(hippo, camera.global_position, clampf(delta * 9.0, 0.0, 1.0))
        _face_body_toward(pig, hippo.global_position, clampf(delta * 5.0, 0.0, 1.0))
        _face_body_toward(dog, hippo.global_position, clampf(delta * 5.0, 0.0, 1.0))
        return

    # After the cinematic opening, normal autonomous behaviour resumes. Only keep the
    # selected hero from drifting completely out of the useful open-world camera area.
    var hero_offset := Vector2(hippo.position.x - HERO_HOME.x, hippo.position.z - HERO_HOME.z)
    if hero_offset.length() > 5.6:
        scene_root.set("wander_target", HERO_HOME)
    if hippo.velocity.length_squared() < 0.020:
        _face_body_toward(hippo, camera.global_position, clampf(delta * 4.5, 0.0, 1.0))

func _set_secondary_action(species: String, action: String, duration: float) -> void:
    if roster == null:
        return
    var companions_value: Variant = roster.get("companions")
    if typeof(companions_value) != TYPE_DICTIONARY:
        return
    var companions := companions_value as Dictionary
    var value: Variant = companions.get(species, {})
    if typeof(value) != TYPE_DICTIONARY:
        return
    var data := value as Dictionary
    data["action"] = action
    data["action_timer"] = duration
    data["call_until"] = 0.0
    companions[species] = data
    roster.set("companions", companions)

func _face_body_toward(body: CharacterBody3D, target: Vector3, weight: float) -> void:
    if body == null:
        return
    var direction := target - body.global_position
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        return
    direction = direction.normalized()
    # Current procedural anatomy is authored along local +X.
    var target_yaw := atan2(-direction.z, direction.x)
    body.rotation.y = lerp_angle(body.rotation.y, target_yaw, clampf(weight, 0.0, 1.0))
    body.rotation.x = 0.0
    body.rotation.z = 0.0

func _enforce_world_visibility() -> void:
    # Older decorative prototype layer is intentionally retired in the open-world build.
    var old_polish := scene_root.find_child("SanctuaryVisualPolish", true, false) as Node3D
    if old_polish != null:
        old_polish.visible = false

    var premium := scene_root.find_child("PremiumExperienceWorld", true, false) as Node3D
    if premium != null:
        premium.visible = true
        _suppress_topiary_recursive(premium, false)

    var grasslands := scene_root.find_child("GrasslandsProductionLayer", true, false) as Node3D
    if grasslands != null:
        grasslands.visible = true
        _suppress_topiary_recursive(grasslands, true)

    var open_world := scene_root.find_child("OpenWorldAuthority", true, false) as Node3D
    if open_world != null:
        open_world.visible = true
        _suppress_topiary_recursive(open_world, true)

    # Keep the useful ground and water layers visible even when older cleanup scripts
    # try to simplify the scene.
    for node_name in ["SanctuaryGroundFinish", "ForegroundWatercourse", "WetBank", "DryAnimalTrail"]:
        var visual := scene_root.find_child(node_name, true, false) as GeometryInstance3D
        if visual != null:
            visual.visible = true

func _suppress_topiary_recursive(node: Node, aggressive: bool) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var visual := child as MeshInstance3D
            var lower := String(visual.name).to_lower()

            if "acaciacanopy" in lower or "signatureacaciacanopy" in lower or "distanttreecanopy" in lower:
                visual.visible = false
            elif "signatureacaciabranch" in lower or "signatureacaciatrunk" in lower:
                visual.visible = false
            elif visual.mesh is CylinderMesh:
                var cylinder := visual.mesh as CylinderMesh
                var upright := absf(visual.rotation_degrees.z) < 35.0 and absf(visual.rotation_degrees.x) < 35.0
                if upright and cylinder.height * absf(visual.scale.y) > 0.58 and visual.global_position.y > 0.24:
                    visual.visible = false
            elif aggressive and visual.mesh is SphereMesh:
                # Procedural shrubs/canopies close to the camera read as floating balls.
                # Keep named escarpments/rocks as distant terrain and retain low stones.
                var keep_terrain := "escarpment" in lower or "ridge" in lower or "rock" in lower or "stone" in lower
                if not keep_terrain and visual.global_position.x > -7.2 and visual.global_position.y > 0.34 and visual.scale.length() > 0.68:
                    visual.visible = false
        _suppress_topiary_recursive(child, aggressive)

func _bind_environment() -> void:
    world_environment = scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    sun_light = _find_sun(scene_root)

func _enforce_daylight() -> void:
    if world_environment == null:
        return
    if world_environment.environment == null:
        world_environment.environment = Environment.new()

    var env := world_environment.environment
    var daylight := _daylight_factor()
    var architecture := Engine.get_architecture_name().to_lower()
    var sky_color := Color(0.055, 0.145, 0.30).lerp(Color(0.075, 0.43, 0.78), daylight)
    RenderingServer.set_default_clear_color(sky_color)

    # Android CI uses a software x86 renderer where procedural skies can present black.
    # Keep the proof path deterministic without downgrading the physical ARM64 renderer.
    if "x86" in architecture:
        env.background_mode = Environment.BG_COLOR
        env.background_color = sky_color
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.39, 0.48, 0.60).lerp(Color(0.72, 0.78, 0.70), daylight)
        env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    else:
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

        sky_material.sky_top_color = sky_color
        sky_material.sky_horizon_color = Color(0.32, 0.38, 0.48).lerp(Color(0.70, 0.86, 0.97), daylight)
        sky_material.ground_horizon_color = Color(0.18, 0.23, 0.16).lerp(Color(0.48, 0.55, 0.30), daylight)
        sky_material.ground_bottom_color = Color(0.045, 0.060, 0.040)
        sky_material.sun_angle_max = 18.0
        sky_material.sun_curve = 0.05
        sky_material.use_debanding = true
        env.background_mode = Environment.BG_SKY
        env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

    env.ambient_light_energy = lerpf(0.80, 1.08, daylight)
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.39, 0.45, 0.55).lerp(Color(0.76, 0.82, 0.78), daylight)
    env.fog_light_energy = lerpf(0.36, 0.56, daylight)
    env.fog_density = lerpf(0.009, 0.0026, daylight)
    env.fog_height = -0.65
    env.fog_height_density = 0.025
    env.fog_sky_affect = 0.16
    env.adjustment_enabled = true
    env.adjustment_brightness = lerpf(1.05, 1.12, daylight)
    env.adjustment_contrast = 1.025
    env.adjustment_saturation = lerpf(0.92, 1.00, daylight)

    if sun_light != null:
        sun_light.light_color = Color(0.66, 0.74, 0.96).lerp(Color(1.0, 0.95, 0.84), daylight)
        sun_light.light_energy = lerpf(0.58, 1.38, daylight)
        sun_light.shadow_enabled = true
        sun_light.directional_shadow_max_distance = 52.0

func _daylight_factor() -> float:
    var mode := "auto"
    var settings_value: Variant = scene_root.get("settings")
    if typeof(settings_value) == TYPE_DICTIONARY:
        mode = str((settings_value as Dictionary).get("day_night_mode", "auto"))
    if mode == "day":
        return 1.0
    if mode == "night":
        return 0.0

    # South African daylight stays visually bright through late afternoon. This avoids
    # the old sine curve turning a 17:00 sanctuary almost black.
    var now := Time.get_time_dict_from_system()
    var hour := float(now.get("hour", 12)) + float(now.get("minute", 0)) / 60.0
    if hour >= 6.75 and hour <= 18.0:
        return 1.0
    if hour > 18.0 and hour <= 19.25:
        return lerpf(1.0, 0.14, (hour - 18.0) / 1.25)
    if hour >= 5.35 and hour < 6.75:
        return lerpf(0.14, 1.0, (hour - 5.35) / 1.40)
    return 0.08

func _fix_hud_brand() -> void:
    var hud := get_node_or_null("/root/SanctuaryHUD")
    if hud == null:
        return
    var brand_value: Variant = hud.get("brand_label")
    if brand_value is Label:
        var brand := brand_value as Label
        brand.text = "HIPPO OS"
        brand.add_theme_font_size_override("font_size", 22)
        var size := get_viewport().get_visible_rect().size
        if size.y >= size.x:
            brand.position.x = size.x * 0.5 - 78.0
            brand.size.x = 156.0
    var subtitle_value: Variant = hud.get("brand_subtitle")
    if subtitle_value is Label:
        var subtitle := subtitle_value as Label
        subtitle.text = "Sanctuary"
        subtitle.add_theme_font_size_override("font_size", 13)
        var size2 := get_viewport().get_visible_rect().size
        if size2.y >= size2.x:
            subtitle.position.x = size2.x * 0.5 - 78.0
            subtitle.size.x = 156.0

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
