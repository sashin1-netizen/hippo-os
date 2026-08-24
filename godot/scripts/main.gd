extends Node3D

const SAVE_PATH = "user://hippo_save.json"

var hippo
var hippo_visual
var body_mesh
var head
var snout
var ear_l
var ear_r
var eye_l
var eye_r
var camera

var hunger = 0.18
var energy = 0.88
var affection = 0.52
var curiosity = 0.68
var bond = 0.35
var hippo_name = "Mochi"
var current_action = "idle"
var action_timer = 0.0
var wander_target = Vector3.ZERO
var autosave_timer = 0.0
var pet_pulse = 0.0
var happy_pulse = 0.0
var touch_on_hippo = false
var pet_distance = 0.0
var orbit_yaw = -0.25
var orbit_pitch = -0.10
var orbit_distance = 8.2
var zoomies_time = 0.0
var feed_flash = 0.0
var interaction_counts = {"pet": 0, "feed": 0}

var stats_label
var action_label
var hint_label
var feed_button
var panel

func _ready():
    randomize()
    _build_world()
    _build_hippo()
    _build_camera()
    _build_ui()
    _load_state()
    _choose_action()
    _update_camera()

func _process(delta):
    _update_needs(delta)
    _update_brain(delta)
    _update_hippo(delta)
    _update_camera()
    _update_ui(delta)
    autosave_timer += delta
    if autosave_timer >= 30.0:
        autosave_timer = 0.0
        _save_state()

func _build_world():
    var world_environment = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.025, 0.055, 0.045)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.42, 0.58, 0.48)
    environment.ambient_light_energy = 0.82
    world_environment.environment = environment
    add_child(world_environment)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-46.0, -28.0, 0.0)
    sun.light_energy = 1.45
    sun.light_color = Color(1.0, 0.90, 0.74)
    sun.shadow_enabled = true
    add_child(sun)

    var rim = OmniLight3D.new()
    rim.position = Vector3(-2.0, 3.5, -1.5)
    rim.omni_range = 10.0
    rim.light_energy = 1.05
    rim.light_color = Color(0.46, 0.72, 0.62)
    add_child(rim)

    var ground_body = StaticBody3D.new()
    var ground_mesh = MeshInstance3D.new()
    var ground_box = BoxMesh.new()
    ground_box.size = Vector3(18.0, 0.4, 14.0)
    ground_mesh.mesh = ground_box
    ground_mesh.position.y = -0.2
    ground_mesh.material_override = _make_material(Color(0.14, 0.30, 0.15), 0.96)
    ground_body.add_child(ground_mesh)

    var ground_collision = CollisionShape3D.new()
    var ground_shape = BoxShape3D.new()
    ground_shape.size = Vector3(18.0, 0.4, 14.0)
    ground_collision.shape = ground_shape
    ground_collision.position.y = -0.2
    ground_body.add_child(ground_collision)
    add_child(ground_body)

    var pond = MeshInstance3D.new()
    var pond_mesh = CylinderMesh.new()
    pond_mesh.top_radius = 3.0
    pond_mesh.bottom_radius = 3.0
    pond_mesh.height = 0.07
    pond.mesh = pond_mesh
    pond.scale = Vector3(1.1, 1.0, 0.72)
    pond.position = Vector3(3.5, 0.03, 2.6)
    var water = _make_material(Color(0.05, 0.36, 0.48), 0.16)
    water.metallic = 0.08
    pond.material_override = water
    add_child(pond)

    var mud = MeshInstance3D.new()
    var mud_mesh = CylinderMesh.new()
    mud_mesh.top_radius = 2.0
    mud_mesh.bottom_radius = 2.0
    mud_mesh.height = 0.05
    mud.mesh = mud_mesh
    mud.scale = Vector3(1.0, 1.0, 0.75)
    mud.position = Vector3(-3.6, 0.03, 2.8)
    mud.material_override = _make_material(Color(0.25, 0.15, 0.09), 1.0)
    add_child(mud)

    for i in range(24):
        var plant = MeshInstance3D.new()
        var stem = CylinderMesh.new()
        stem.top_radius = 0.035
        stem.bottom_radius = 0.12
        stem.height = randf_range(0.9, 2.2)
        plant.mesh = stem
        var angle = TAU * float(i) / 24.0
        var radius_x = randf_range(6.7, 8.5)
        var radius_z = randf_range(5.0, 6.5)
        plant.position = Vector3(cos(angle) * radius_x, stem.height * 0.5, sin(angle) * radius_z)
        plant.material_override = _make_material(Color(0.04, randf_range(0.20, 0.32), 0.10), 0.94)
        add_child(plant)

    for i in range(6):
        var rock = MeshInstance3D.new()
        var sphere = SphereMesh.new()
        sphere.radius = 0.5
        sphere.height = 0.9
        rock.mesh = sphere
        rock.position = Vector3(randf_range(-6.0, 6.0), 0.25, randf_range(-5.0, 5.0))
        rock.scale = Vector3(randf_range(0.6, 1.3), randf_range(0.45, 0.8), randf_range(0.7, 1.5))
        rock.material_override = _make_material(Color(0.27, 0.30, 0.27), 0.98)
        add_child(rock)

func _build_hippo():
    hippo = CharacterBody3D.new()
    hippo.name = "BabyHippo"
    hippo.position = Vector3(0.0, 0.78, 0.0)
    hippo.collision_layer = 2
    hippo.collision_mask = 1
    add_child(hippo)

    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.67
    capsule.height = 1.7
    collision.shape = capsule
    collision.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    hippo.add_child(collision)

    hippo_visual = Node3D.new()
    hippo.add_child(hippo_visual)

    var skin = _make_material(Color(0.34, 0.25, 0.31), 0.26)
    var muzzle = _make_material(Color(0.60, 0.34, 0.42), 0.30)
    var inner_ear = _make_material(Color(0.72, 0.42, 0.49), 0.38)
    var eye = _make_material(Color(0.012, 0.009, 0.012), 0.08)

    body_mesh = _sphere_part("Body", Vector3(-0.22, 0.35, 0.0), Vector3(1.47, 0.91, 0.88), skin)
    _sphere_part("Chest", Vector3(0.52, 0.44, 0.0), Vector3(0.85, 0.82, 0.78), skin)
    head = _sphere_part("Head", Vector3(1.08, 0.58, 0.0), Vector3(0.82, 0.77, 0.76), skin)
    snout = _sphere_part("Snout", Vector3(1.62, 0.33, 0.0), Vector3(0.67, 0.45, 0.63), muzzle)

    ear_l = _sphere_part("EarL", Vector3(0.91, 1.05, -0.50), Vector3(0.18, 0.23, 0.14), inner_ear)
    ear_r = _sphere_part("EarR", Vector3(0.91, 1.05, 0.50), Vector3(0.18, 0.23, 0.14), inner_ear)

    eye_l = _sphere_part("EyeL", Vector3(1.47, 0.80, -0.43), Vector3(0.115, 0.12, 0.09), eye)
    eye_r = _sphere_part("EyeR", Vector3(1.47, 0.80, 0.43), Vector3(0.115, 0.12, 0.09), eye)

    _sphere_part("NostrilL", Vector3(1.94, 0.43, -0.24), Vector3(0.075, 0.045, 0.07), eye)
    _sphere_part("NostrilR", Vector3(1.94, 0.43, 0.24), Vector3(0.075, 0.045, 0.07), eye)

    _sphere_part("LegFL", Vector3(0.62, -0.18, -0.48), Vector3(0.26, 0.52, 0.26), skin)
    _sphere_part("LegFR", Vector3(0.62, -0.18, 0.48), Vector3(0.26, 0.52, 0.26), skin)
    _sphere_part("LegRL", Vector3(-0.84, -0.18, -0.48), Vector3(0.28, 0.55, 0.28), skin)
    _sphere_part("LegRR", Vector3(-0.84, -0.18, 0.48), Vector3(0.28, 0.55, 0.28), skin)

    _sphere_part("Tail", Vector3(-1.48, 0.38, 0.0), Vector3(0.16, 0.16, 0.24), skin)

func _sphere_part(part_name, local_position, local_scale, material):
    var part = MeshInstance3D.new()
    part.name = part_name
    var sphere = SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    part.mesh = sphere
    part.position = local_position
    part.scale = local_scale
    part.material_override = material
    hippo_visual.add_child(part)
    return part

func _build_camera():
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 48.0
    add_child(camera)

func _build_ui():
    var ui = CanvasLayer.new()
    add_child(ui)

    panel = ColorRect.new()
    panel.color = Color(0.01, 0.015, 0.018, 0.82)
    panel.position = Vector2(18, 18)
    panel.size = Vector2(520, 135)
    ui.add_child(panel)

    var title = Label.new()
    title.text = "HIPPO OS"
    title.position = Vector2(20, 12)
    title.add_theme_font_size_override("font_size", 30)
    panel.add_child(title)

    stats_label = Label.new()
    stats_label.position = Vector2(20, 56)
    stats_label.add_theme_font_size_override("font_size", 18)
    panel.add_child(stats_label)

    action_label = Label.new()
    action_label.position = Vector2(20, 91)
    action_label.add_theme_font_size_override("font_size", 17)
    panel.add_child(action_label)

    feed_button = Button.new()
    feed_button.text = "FEED"
    feed_button.position = Vector2(25, 620)
    feed_button.size = Vector2(200, 72)
    feed_button.add_theme_font_size_override("font_size", 24)
    feed_button.pressed.connect(_feed_hippo)
    ui.add_child(feed_button)

    hint_label = Label.new()
    hint_label.text = "Pet Mochi by dragging over her - drag the habitat to look around"
    hint_label.position = Vector2(300, 650)
    hint_label.add_theme_font_size_override("font_size", 18)
    ui.add_child(hint_label)

func _update_needs(delta):
    var minutes = delta / 60.0
    hunger = clamp(hunger + 0.006 * minutes, 0.0, 1.0)
    energy = clamp(energy - 0.004 * minutes, 0.0, 1.0)
    curiosity = clamp(curiosity - 0.003 * minutes, 0.0, 1.0)

func _update_brain(delta):
    action_timer -= delta
    if action_timer <= 0.0:
        _choose_action()

func _choose_action():
    if energy < 0.22:
        current_action = "sleep"
        action_timer = randf_range(5.0, 8.0)
        return

    if hunger > 0.72:
        current_action = "approach"
        action_timer = randf_range(3.0, 5.0)
        return

    var roll = randf()
    if roll < 0.12 and energy > 0.60:
        current_action = "zoomies"
        zoomies_time = randf_range(3.5, 5.5)
        action_timer = zoomies_time
        _new_wander_target()
    elif roll < 0.33:
        current_action = "approach"
        action_timer = randf_range(2.5, 4.5)
    elif roll < 0.52:
        current_action = "play"
        action_timer = randf_range(3.0, 5.0)
        _new_wander_target()
    elif roll < 0.77:
        current_action = "wander"
        action_timer = randf_range(3.0, 5.5)
        _new_wander_target()
    else:
        current_action = "idle"
        action_timer = randf_range(2.0, 4.0)

func _new_wander_target():
    wander_target = Vector3(randf_range(-5.3, 5.3), hippo.position.y, randf_range(-4.1, 4.1))

func _update_hippo(delta):
    if hippo == null:
        return

    var direction = Vector3.ZERO
    var speed = 0.0

    if current_action == "approach":
        var target = camera.global_position
        target.y = hippo.global_position.y
        if hippo.global_position.distance_to(target) > 2.8:
            direction = (target - hippo.global_position).normalized()
            speed = 1.15
    elif current_action == "wander" or current_action == "play" or current_action == "zoomies":
        if hippo.global_position.distance_to(wander_target) < 0.55:
            _new_wander_target()
        direction = (wander_target - hippo.global_position).normalized()
        if current_action == "zoomies":
            speed = 3.2
        elif current_action == "play":
            speed = 1.55
        else:
            speed = 0.90
    elif current_action == "sleep":
        energy = clamp(energy + delta * 0.018, 0.0, 1.0)

    hippo.velocity = Vector3(direction.x * speed, -0.2, direction.z * speed)
    hippo.move_and_slide()

    if direction.length_squared() > 0.01:
        var target_point = hippo.global_position + direction
        hippo.look_at(target_point, Vector3.UP)
        hippo.rotation.x = 0.0
        hippo.rotation.z = 0.0

    var now = Time.get_ticks_msec() / 1000.0
    var breathe = sin(now * 2.2) * 0.018
    hippo_visual.scale = Vector3(1.0 + breathe, 1.0 + breathe * 0.55, 1.0 + breathe)

    var ear_speed = 7.5 if current_action == "zoomies" else 4.5
    ear_l.rotation.z = sin(now * ear_speed) * 0.16
    ear_r.rotation.z = -sin(now * ear_speed) * 0.16

    if current_action == "sleep":
        hippo_visual.rotation.z = lerp(hippo_visual.rotation.z, -0.16, delta * 2.0)
        head.rotation.z = -0.08
    else:
        hippo_visual.rotation.z = lerp(hippo_visual.rotation.z, 0.0, delta * 3.0)

    if current_action == "zoomies":
        hippo_visual.position.y = abs(sin(now * 8.0)) * 0.07
        head.rotation.z = sin(now * 9.0) * 0.08
    else:
        hippo_visual.position.y = 0.0

    if pet_pulse > 0.0:
        pet_pulse = max(0.0, pet_pulse - delta)
        head.rotation.z = sin(now * 11.0) * 0.10 * pet_pulse
        snout.scale.y = 0.45 + 0.04 * pet_pulse
    elif current_action != "sleep" and current_action != "zoomies":
        head.rotation.z = lerp(head.rotation.z, 0.0, delta * 5.0)
        snout.scale.y = 0.45

func _update_camera():
    var pivot = Vector3(0.0, 1.0, 0.0)
    var horizontal = cos(orbit_pitch) * orbit_distance
    camera.position = pivot + Vector3(sin(orbit_yaw) * horizontal, -sin(orbit_pitch) * orbit_distance + 0.95, cos(orbit_yaw) * horizontal)
    camera.look_at(pivot, Vector3.UP)

func _update_ui(delta):
    stats_label.text = "%s   Bond %d%%   Hunger %d%%   Energy %d%%" % [hippo_name, int(bond * 100.0), int(hunger * 100.0), int(energy * 100.0)]
    action_label.text = "Mood: %s" % _friendly_action(current_action)

    if feed_flash > 0.0:
        feed_flash = max(0.0, feed_flash - delta)
        feed_button.text = "YUM!"
    else:
        feed_button.text = "FEED"

func _friendly_action(action):
    if action == "zoomies":
        return "ZOOMIES!"
    if action == "approach":
        return "Coming to see you"
    if action == "play":
        return "Playful"
    if action == "wander":
        return "Exploring"
    if action == "sleep":
        return "Sleepy"
    return "Relaxed"

func _feed_hippo():
    hunger = clamp(hunger - 0.30, 0.0, 1.0)
    affection = clamp(affection + 0.03, 0.0, 1.0)
    bond = clamp(bond + 0.010, 0.0, 1.0)
    interaction_counts["feed"] = int(interaction_counts.get("feed", 0)) + 1
    current_action = "approach"
    action_timer = 3.0
    happy_pulse = 1.0
    feed_flash = 1.2
    _save_state()

func _pet(strength):
    affection = clamp(affection + 0.02 * strength, 0.0, 1.0)
    curiosity = clamp(curiosity + 0.006 * strength, 0.0, 1.0)
    bond = clamp(bond + 0.007 * strength, 0.0, 1.0)
    interaction_counts["pet"] = int(interaction_counts.get("pet", 0)) + 1
    pet_pulse = 1.0

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            pet_distance = 0.0
            touch_on_hippo = _screen_hits_hippo(event.position)
        else:
            if touch_on_hippo and pet_distance < 16.0:
                _pet(0.35)
            touch_on_hippo = false
            pet_distance = 0.0
    elif event is InputEventScreenDrag:
        var drag_delta = event.relative
        if touch_on_hippo:
            if _screen_hits_hippo(event.position):
                pet_distance += drag_delta.length()
                if pet_distance >= 42.0:
                    _pet(clamp(pet_distance / 120.0, 0.4, 1.5))
                    pet_distance = 0.0
        else:
            orbit_yaw -= drag_delta.x * 0.006
            orbit_pitch = clamp(orbit_pitch - drag_delta.y * 0.004, -0.52, 0.18)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            pet_distance = 0.0
            touch_on_hippo = _screen_hits_hippo(event.position)
        else:
            if touch_on_hippo and pet_distance < 16.0:
                _pet(0.35)
            touch_on_hippo = false
            pet_distance = 0.0
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var mouse_delta = event.relative
        if touch_on_hippo:
            pet_distance += mouse_delta.length()
            if pet_distance >= 42.0:
                _pet(clamp(pet_distance / 120.0, 0.4, 1.5))
                pet_distance = 0.0
        else:
            orbit_yaw -= mouse_delta.x * 0.006
            orbit_pitch = clamp(orbit_pitch - mouse_delta.y * 0.004, -0.52, 0.18)

func _screen_hits_hippo(screen_position):
    if camera == null:
        return false
    var origin = camera.project_ray_origin(screen_position)
    var direction = camera.project_ray_normal(screen_position)
    var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
    query.collision_mask = 2
    var result = get_world_3d().direct_space_state.intersect_ray(query)
    return not result.is_empty() and result.get("collider") == hippo

func _save_state():
    var data = {
        "hippo_name": hippo_name,
        "hunger": hunger,
        "energy": energy,
        "affection": affection,
        "curiosity": curiosity,
        "bond": bond,
        "interaction_counts": interaction_counts,
        "last_save_unix": int(Time.get_unix_time_from_system())
    }
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_state():
    if not FileAccess.file_exists(SAVE_PATH):
        _save_state()
        return
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
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
    bond = float(parsed.get("bond", bond))
    interaction_counts = parsed.get("interaction_counts", interaction_counts)
    var then_time = int(parsed.get("last_save_unix", int(Time.get_unix_time_from_system())))
    var now_time = int(Time.get_unix_time_from_system())
    var away_minutes = clamp(float(now_time - then_time) / 60.0, 0.0, 4320.0)
    hunger = clamp(hunger + away_minutes * 0.003, 0.0, 1.0)
    energy = clamp(energy + away_minutes * 0.0015, 0.0, 1.0)

func _make_material(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
