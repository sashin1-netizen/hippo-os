extends Node3D

const SAVE_PATH := "user://hippo_save.json"

var hippo: CharacterBody3D
var hippo_visual: Node3D
var head: MeshInstance3D
var ear_l: MeshInstance3D
var ear_r: MeshInstance3D
var camera: Camera3D
var orbit_pivot := Vector3.ZERO
var orbit_yaw := 0.0
var orbit_pitch := -0.12
var orbit_distance := 9.2

var hunger := 0.18
var energy := 0.88
var affection := 0.52
var curiosity := 0.68
var cleanliness := 0.82
var bond := 0.35
var personality := {
    "mischief": 0.55,
    "affection": 0.75,
    "energy": 0.72,
    "curiosity": 0.70,
    "stubbornness": 0.40,
    "boldness": 0.65
}
var hippo_name := "Mochi"
var session_count := 0
var last_save_unix := 0
var interaction_counts := {"pet": 0, "feed": 0}

var current_action := "idle"
var action_timer := 0.0
var wander_target := Vector3.ZERO
var pet_pulse := 0.0
var touch_on_hippo := false
var last_touch := Vector2.ZERO
var pet_distance := 0.0
var autosave_timer := 0.0

var title_label: Label
var stats_label: Label
var action_label: Label

func _ready() -> void:
    randomize()
    _build_environment()
    _build_hippo()
    _build_camera()
    _build_ui()
    _load_state()
    _choose_action()
    _update_camera()

func _process(delta: float) -> void:
    _simulate_needs(delta)
    _update_brain(delta)
    _update_hippo(delta)
    _update_ui()
    _update_camera()
    autosave_timer += delta
    if autosave_timer >= 30.0:
        autosave_timer = 0.0
        _save_state()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_state()

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("16241e")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("a8cbb0")
    env.ambient_light_energy = 0.75
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_env.environment = env
    add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    add_child(sun)
    var fill := OmniLight3D.new()
    fill.position = Vector3(0.0, 4.0, 2.0)
    fill.omni_range = 12.0
    fill.light_energy = 1.2
    fill.light_color = Color("bfe4d1")
    add_child(fill)
    _make_ground()
    _make_pond()
    _make_mud()
    _make_rocks_and_plants()

func _make_ground() -> void:
    var body := StaticBody3D.new()
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(18.0, 0.5, 14.0)
    mesh_instance.mesh = box
    mesh_instance.position.y = -0.25
    mesh_instance.material_override = _material(Color("466b45"), 0.88, 0.0)
    body.add_child(mesh_instance)
    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(18.0, 0.5, 14.0)
    shape.shape = box_shape
    shape.position.y = -0.25
    body.add_child(shape)
    add_child(body)

func _make_pond() -> void:
    var pond := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 3.1
    cylinder.bottom_radius = 3.1
    cylinder.height = 0.08
    pond.mesh = cylinder
    pond.scale = Vector3(1.0, 1.0, 0.72)
    pond.position = Vector3(3.7, 0.03, 2.6)
    var water_mat := _material(Color("2b7d90"), 0.15, 0.28)
    water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    water_mat.albedo_color.a = 0.82
    pond.material_override = water_mat
    add_child(pond)

func _make_mud() -> void:
    var mud := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 2.0
    cylinder.bottom_radius = 2.0
    cylinder.height = 0.05
    mud.mesh = cylinder
    mud.scale = Vector3(1.0, 1.0, 0.72)
    mud.position = Vector3(-3.8, 0.02, 2.8)
    mud.material_override = _material(Color("5e4632"), 0.95, 0.0)
    add_child(mud)

func _make_rocks_and_plants() -> void:
    var rock_positions := [Vector3(-5.8, 0.45, -3.8), Vector3(5.7, 0.35, -4.2), Vector3(-6.6, 0.32, 4.7), Vector3(6.2, 0.42, 4.8)]
    for p in rock_positions:
        var rock := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.7
        sphere.height = 1.15
        rock.mesh = sphere
        rock.position = p
        rock.scale = Vector3(randf_range(0.8, 1.3), randf_range(0.55, 0.9), randf_range(0.8, 1.25))
        rock.material_override = _material(Color("6d7668"), 0.92, 0.0)
        add_child(rock)
    for i in 18:
        var plant := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.05
        cyl.bottom_radius = 0.10
        cyl.height = randf_range(0.8, 1.8)
        plant.mesh = cyl
        var angle := TAU * float(i) / 18.0
        plant.position = Vector3(cos(angle) * randf_range(6.5, 8.2), cyl.height * 0.5, sin(angle) * randf_range(5.0, 6.5))
        plant.material_override = _material(Color("294c32"), 0.9, 0.0)
        add_child(plant)

func _build_hippo() -> void:
    hippo = CharacterBody3D.new()
    hippo.name = "BabyHippo"
    hippo.position = Vector3(0.0, 0.72, 0.0)
    hippo.collision_layer = 2
    hippo.collision_mask = 1
    add_child(hippo)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.72
    capsule.height = 1.8
    collision.shape = capsule
    collision.rotation_degrees.z = 90.0
    collision.position.y = 0.18
    hippo.add_child(collision)
    hippo_visual = Node3D.new()
    hippo_visual.name = "Visual"
    hippo.add_child(hippo_visual)
    var skin := _material(Color("7a6575"), 0.32, 0.12)
    var pink := _material(Color("ad7687"), 0.38, 0.08)
    var eye_mat := _material(Color("151216"), 0.12, 0.08)
    _hippo_sphere("Body", Vector3(-0.20, 0.42, 0.0), Vector3(1.52, 0.92, 0.88), skin)
    head = _hippo_sphere("Head", Vector3(1.12, 0.52, 0.0), Vector3(0.84, 0.78, 0.76), skin)
    _hippo_sphere("Snout", Vector3(1.72, 0.34, 0.0), Vector3(0.68, 0.47, 0.64), pink)
    ear_l = _hippo_sphere("EarL", Vector3(0.98, 1.04, -0.54), Vector3(0.19, 0.24, 0.15), skin)
    ear_r = _hippo_sphere("EarR", Vector3(0.98, 1.04, 0.54), Vector3(0.19, 0.24, 0.15), skin)
    _hippo_sphere("EyeL", Vector3(1.54, 0.78, -0.48), Vector3(0.09, 0.10, 0.08), eye_mat)
    _hippo_sphere("EyeR", Vector3(1.54, 0.78, 0.48), Vector3(0.09, 0.10, 0.08), eye_mat)
    _hippo_sphere("LegFL", Vector3(0.72, -0.20, -0.52), Vector3(0.27, 0.55, 0.27), skin)
    _hippo_sphere("LegFR", Vector3(0.72, -0.20, 0.52), Vector3(0.27, 0.55, 0.27), skin)
    _hippo_sphere("LegRL", Vector3(-0.92, -0.20, -0.52), Vector3(0.29, 0.58, 0.29), skin)
    _hippo_sphere("LegRR", Vector3(-0.92, -0.20, 0.52), Vector3(0.29, 0.58, 0.29), skin)

func _hippo_sphere(node_name: String, local_pos: Vector3, local_scale: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = node_name
    var sphere := SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    part.mesh = sphere
    part.position = local_pos
    part.scale = local_scale
    part.material_override = mat
    hippo_visual.add_child(part)
    return part

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 52.0
    add_child(camera)
    orbit_pivot = Vector3(0.0, 0.9, 0.0)

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var top_panel := ColorRect.new()
    top_panel.color = Color(0.02, 0.03, 0.04, 0.72)
    top_panel.position = Vector2(20, 18)
    top_panel.size = Vector2(440, 120)
    ui.add_child(top_panel)
    title_label = Label.new()
    title_label.text = "HIPPO OS"
    title_label.position = Vector2(20, 12)
    title_label.add_theme_font_size_override("font_size", 28)
    top_panel.add_child(title_label)
    stats_label = Label.new()
    stats_label.position = Vector2(20, 52)
    stats_label.add_theme_font_size_override("font_size", 20)
    top_panel.add_child(stats_label)
    action_label = Label.new()
    action_label.position = Vector2(20, 82)
    action_label.add_theme_font_size_override("font_size", 16)
    top_panel.add_child(action_label)
    var feed := Button.new()
    feed.text = "FEED"
    feed.position = Vector2(24, 620)
    feed.size = Vector2(180, 72)
    feed.add_theme_font_size_override("font_size", 24)
    feed.pressed.connect(_feed_hippo)
    ui.add_child(feed)
    var help := Label.new()
    help.text = "Drag the hippo to pet - Drag the habitat to look around"
    help.position = Vector2(360, 655)
    help.add_theme_font_size_override("font_size", 18)
    ui.add_child(help)

func _simulate_needs(delta: float) -> void:
    var minutes := delta / 60.0
    hunger = clamp(hunger + 0.006 * minutes, 0.0, 1.0)
    energy = clamp(energy - 0.004 * minutes, 0.0, 1.0)
    curiosity = clamp(curiosity - 0.003 * minutes, 0.0, 1.0)

func _update_brain(delta: float) -> void:
    action_timer -= delta
    if action_timer <= 0.0:
        _choose_action()

func _choose_action() -> void:
    action_timer = randf_range(2.0, 4.5)
    var scores := {
        "idle": 0.18 + (1.0 - curiosity) * 0.10,
        "wander": 0.25 + energy * 0.25 + (1.0 - curiosity) * 0.18,
        "approach": (0.18 + bond * 0.48 + affection * 0.18) * lerp(0.72, 1.45, float(personality["affection"])),
        "sleep": (1.0 - energy) * 1.08,
        "explore": ((1.0 - curiosity) * 0.66 + energy * 0.20) * lerp(0.75, 1.42, float(personality["curiosity"])),
        "play": (energy * 0.34 + curiosity * 0.25 + bond * 0.16) * lerp(0.74, 1.50, float(personality["energy"]))
    }
    var best := "idle"
    var best_score := -1.0
    for key in scores.keys():
        var score: float = float(scores[key]) + randf_range(-0.035, 0.035)
        if score > best_score:
            best_score = score
            best = str(key)
    current_action = best
    if current_action in ["wander", "explore", "play"]:
        _new_wander_target()

func _new_wander_target() -> void:
    wander_target = Vector3(randf_range(-5.5, 5.5), hippo.position.y, randf_range(-4.3, 4.3))

func _update_hippo(delta: float) -> void:
    if not is_instance_valid(hippo):
        return
    var desired := Vector3.ZERO
    var speed := 0.0
    if current_action == "approach":
        var target := camera.global_position
        target.y = hippo.position.y
        var dist := hippo.position.distance_to(target)
        if dist > 3.0:
            desired = (target - hippo.position).normalized()
            speed = 1.35
    elif current_action in ["wander", "explore", "play"]:
        if hippo.position.distance_to(wander_target) < 0.5:
            _new_wander_target()
        desired = (wander_target - hippo.position).normalized()
        speed = 1.55 if current_action == "play" else 0.95
    elif current_action == "sleep":
        energy = clamp(energy + delta * 0.012, 0.0, 1.0)
    hippo.velocity.x = desired.x * speed
    hippo.velocity.z = desired.z * speed
    hippo.velocity.y = -0.2
    hippo.move_and_slide()
    if desired.length_squared() > 0.01:
        var look_target := hippo.global_position + desired
        hippo.look_at(look_target, Vector3.UP)
        hippo.rotation.x = 0.0
        hippo.rotation.z = 0.0
    var t := Time.get_ticks_msec() * 0.001
    var breathing := 1.0 + sin(t * 2.2) * 0.012
    hippo_visual.scale = Vector3(breathing, breathing, breathing)
    var ear_motion := sin(t * 8.5) * 0.12 if fmod(t, 5.5) < 0.55 else 0.0
    ear_l.rotation.x = ear_motion
    ear_r.rotation.x = -ear_motion
    if pet_pulse > 0.0:
        pet_pulse = max(0.0, pet_pulse - delta * 2.8)
        head.rotation.z = sin(t * 18.0) * 0.045 * pet_pulse
    else:
        head.rotation.z = 0.0

func _update_camera() -> void:
    if not is_instance_valid(camera):
        return
    orbit_pivot = lerp(orbit_pivot, hippo.global_position + Vector3(0.0, 0.65, 0.0), 0.06)
    var offset := Vector3(cos(orbit_pitch) * cos(orbit_yaw), sin(orbit_pitch), cos(orbit_pitch) * sin(orbit_yaw)) * orbit_distance
    camera.global_position = orbit_pivot + offset
    camera.look_at(orbit_pivot, Vector3.UP)

func _update_ui() -> void:
    if stats_label:
        stats_label.text = "%s | Bond %d%% | Hunger %d%% | Energy %d%%" % [hippo_name, int(bond * 100.0), int(hunger * 100.0), int(energy * 100.0)]
    if action_label:
        action_label.text = "Mood: %s | Session %d" % [current_action.capitalize(), session_count]

func _feed_hippo() -> void:
    hunger = clamp(hunger - 0.28, 0.0, 1.0)
    affection = clamp(affection + 0.025, 0.0, 1.0)
    bond = clamp(bond + 0.012, 0.0, 1.0)
    interaction_counts["feed"] = int(interaction_counts.get("feed", 0)) + 1
    current_action = "approach"
    action_timer = 2.5
    _save_state()

func _pet(strength: float) -> void:
    affection = clamp(affection + 0.02 * strength, 0.0, 1.0)
    curiosity = clamp(curiosity + 0.006 * strength, 0.0, 1.0)
    bond = clamp(bond + 0.006 * strength, 0.0, 1.0)
    interaction_counts["pet"] = int(interaction_counts.get("pet", 0)) + 1
    pet_pulse = 1.0

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            last_touch = event.position
            pet_distance = 0.0
            touch_on_hippo = _screen_hits_hippo(event.position)
        else:
            if touch_on_hippo and pet_distance < 16.0:
                _pet(0.35)
            touch_on_hippo = false
            pet_distance = 0.0
    elif event is InputEventScreenDrag:
        var drag_delta: Vector2 = event.relative
        if touch_on_hippo:
            if _screen_hits_hippo(event.position):
                pet_distance += drag_delta.length()
                if pet_distance >= 42.0:
                    _pet(clamp(pet_distance / 120.0, 0.4, 1.5))
                    pet_distance = 0.0
        else:
            orbit_yaw -= drag_delta.x * 0.006
            orbit_pitch = clamp(orbit_pitch - drag_delta.y * 0.004, -0.55, 0.20)
        last_touch = event.position
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            last_touch = event.position
            pet_distance = 0.0
            touch_on_hippo = _screen_hits_hippo(event.position)
        else:
            if touch_on_hippo and pet_distance < 16.0:
                _pet(0.35)
            touch_on_hippo = false
            pet_distance = 0.0
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var mouse_drag: Vector2 = event.relative
        if touch_on_hippo:
            pet_distance += mouse_drag.length()
            if pet_distance >= 42.0:
                _pet(clamp(pet_distance / 120.0, 0.4, 1.5))
                pet_distance = 0.0
        else:
            orbit_yaw -= mouse_drag.x * 0.006
            orbit_pitch = clamp(orbit_pitch - mouse_drag.y * 0.004, -0.55, 0.20)

func _screen_hits_hippo(screen_pos: Vector2) -> bool:
    if not is_instance_valid(camera):
        return false
    var origin := camera.project_ray_origin(screen_pos)
    var direction := camera.project_ray_normal(screen_pos)
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
    query.collision_mask = 2
    var result := get_world_3d().direct_space_state.intersect_ray(query)
    return not result.is_empty() and result.get("collider") == hippo

func _save_state() -> void:
    var data := {
        "hippo_name": hippo_name,
        "hunger": hunger,
        "energy": energy,
        "affection": affection,
        "curiosity": curiosity,
        "cleanliness": cleanliness,
        "bond": bond,
        "personality": personality,
        "session_count": session_count,
        "interaction_counts": interaction_counts,
        "last_save_unix": int(Time.get_unix_time_from_system())
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        personality["mischief"] = randf_range(0.30, 0.90)
        personality["affection"] = randf_range(0.45, 0.95)
        personality["energy"] = randf_range(0.40, 0.95)
        personality["curiosity"] = randf_range(0.45, 0.95)
        personality["stubbornness"] = randf_range(0.20, 0.80)
        personality["boldness"] = randf_range(0.35, 0.90)
        session_count = 1
        _save_state()
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    hippo_name = str(parsed.get("hippo_name", hippo_name))
    hunger = float(parsed.get("hunger", hunger))
    energy = float(parsed.get("energy", energy))
    affection = float(parsed.get("affection", affection))
    curiosity = float(parsed.get("curiosity", curiosity))
    cleanliness = float(parsed.get("cleanliness", cleanliness))
    bond = float(parsed.get("bond", bond))
    personality = parsed.get("personality", personality)
    session_count = int(parsed.get("session_count", 0)) + 1
    interaction_counts = parsed.get("interaction_counts", interaction_counts)
    last_save_unix = int(parsed.get("last_save_unix", int(Time.get_unix_time_from_system())))
    var elapsed_minutes := clamp((Time.get_unix_time_from_system() - last_save_unix) / 60.0, 0.0, 4320.0)
    hunger = clamp(hunger + 0.0033 * elapsed_minutes, 0.0, 1.0)
    energy = clamp(energy + 0.0015 * elapsed_minutes, 0.0, 1.0)
    curiosity = clamp(curiosity - 0.0018 * elapsed_minutes, 0.0, 1.0)
    _save_state()

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    mat.metallic = metallic
    return mat
