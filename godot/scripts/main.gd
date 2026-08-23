extends Node3D

const SAVE_PATH = "user://hippo_save.json"

var hippo
var hippo_visual
var camera
var head
var ear_l
var ear_r

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
var touch_on_hippo = false
var pet_distance = 0.0
var orbit_yaw = 0.0
var orbit_pitch = -0.12
var orbit_distance = 9.0
var interaction_counts = {"pet": 0, "feed": 0}

var stats_label
var action_label

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
    _update_ui()
    autosave_timer += delta
    if autosave_timer >= 30.0:
        autosave_timer = 0.0
        _save_state()

func _build_world():
    var world_environment = WorldEnvironment.new()
    var environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.07, 0.12, 0.09)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.72, 0.60)
    environment.ambient_light_energy = 0.8
    world_environment.environment = environment
    add_child(world_environment)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    add_child(sun)

    var ground_body = StaticBody3D.new()
    var ground_mesh = MeshInstance3D.new()
    var ground_box = BoxMesh.new()
    ground_box.size = Vector3(18.0, 0.4, 14.0)
    ground_mesh.mesh = ground_box
    ground_mesh.position.y = -0.2
    ground_mesh.material_override = _make_material(Color(0.22, 0.40, 0.22), 0.9)
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
    pond_mesh.height = 0.06
    pond.mesh = pond_mesh
    pond.scale = Vector3(1.0, 1.0, 0.7)
    pond.position = Vector3(3.7, 0.03, 2.5)
    pond.material_override = _make_material(Color(0.10, 0.42, 0.56), 0.2)
    add_child(pond)

    var mud = MeshInstance3D.new()
    var mud_mesh = CylinderMesh.new()
    mud_mesh.top_radius = 2.0
    mud_mesh.bottom_radius = 2.0
    mud_mesh.height = 0.05
    mud.mesh = mud_mesh
    mud.scale = Vector3(1.0, 1.0, 0.75)
    mud.position = Vector3(-3.7, 0.03, 2.8)
    mud.material_override = _make_material(Color(0.30, 0.20, 0.12), 1.0)
    add_child(mud)

    for i in range(16):
        var plant = MeshInstance3D.new()
        var stem = CylinderMesh.new()
        stem.top_radius = 0.04
        stem.bottom_radius = 0.10
        stem.height = randf_range(0.8, 1.8)
        plant.mesh = stem
        var angle = TAU * float(i) / 16.0
        plant.position = Vector3(cos(angle) * 7.2, stem.height * 0.5, sin(angle) * 5.6)
        plant.material_override = _make_material(Color(0.08, 0.28, 0.12), 0.9)
        add_child(plant)

func _build_hippo():
    hippo = CharacterBody3D.new()
    hippo.name = "BabyHippo"
    hippo.position = Vector3(0.0, 0.8, 0.0)
    hippo.collision_layer = 2
    hippo.collision_mask = 1
    add_child(hippo)

    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.7
    capsule.height = 1.8
    collision.shape = capsule
    collision.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    hippo.add_child(collision)

    hippo_visual = Node3D.new()
    hippo.add_child(hippo_visual)

    var skin = _make_material(Color(0.45, 0.34, 0.42), 0.35)
    var pink = _make_material(Color(0.68, 0.43, 0.52), 0.4)
    var eye = _make_material(Color(0.03, 0.02, 0.03), 0.15)

    _sphere_part("Body", Vector3(-0.2, 0.35, 0.0), Vector3(1.55, 0.9, 0.9), skin)
    head = _sphere_part("Head", Vector3(1.1, 0.5, 0.0), Vector3(0.85, 0.78, 0.78), skin)
    _sphere_part("Snout", Vector3(1.72, 0.30, 0.0), Vector3(0.70, 0.48, 0.65), pink)
    ear_l = _sphere_part("EarL", Vector3(0.98, 1.02, -0.54), Vector3(0.20, 0.24, 0.16), skin)
    ear_r = _sphere_part("EarR", Vector3(0.98, 1.02, 0.54), Vector3(0.20, 0.24, 0.16), skin)
    _sphere_part("EyeL", Vector3(1.52, 0.78, -0.48), Vector3(0.10, 0.10, 0.08), eye)
    _sphere_part("EyeR", Vector3(1.52, 0.78, 0.48), Vector3(0.10, 0.10, 0.08), eye)
    _sphere_part("LegFL", Vector3(0.7, -0.22, -0.5), Vector3(0.28, 0.55, 0.28), skin)
    _sphere_part("LegFR", Vector3(0.7, -0.22, 0.5), Vector3(0.28, 0.55, 0.28), skin)
    _sphere_part("LegRL", Vector3(-0.9, -0.22, -0.5), Vector3(0.30, 0.58, 0.30), skin)
    _sphere_part("LegRR", Vector3(-0.9, -0.22, 0.5), Vector3(0.30, 0.58, 0.30), skin)

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
    camera.fov = 52.0
    add_child(camera)

func _build_ui():
    var ui = CanvasLayer.new()
    add_child(ui)

    var panel = ColorRect.new()
    panel.color = Color(0.01, 0.02, 0.03, 0.75)
    panel.position = Vector2(18, 18)
    panel.size = Vector2(500, 130)
    ui.add_child(panel)

    var title = Label.new()
    title.text = "HIPPO OS"
    title.position = Vector2(18, 12)
    title.add_theme_font_size_override("font_size", 30)
    panel.add_child(title)

    stats_label = Label.new()
    stats_label.position = Vector2(18, 54)
    stats_label.add_theme_font_size_override("font_size", 18)
    panel.add_child(stats_label)

    action_label = Label.new()
    action_label.position = Vector2(18, 88)
    action_label.add_theme_font_size_override("font_size", 16)
    panel.add_child(action_label)

    var feed_button = Button.new()
    feed_button.text = "FEED"
    feed_button.position = Vector2(25, 620)
    feed_button.size = Vector2(190, 70)
    feed_button.add_theme_font_size_override("font_size", 24)
    feed_button.pressed.connect(_feed_hippo)
    ui.add_child(feed_button)

    var help = Label.new()
    help.text = "Drag hippo to pet - drag habitat to look around"
    help.position = Vector2(330, 650)
    help.add_theme_font_size_override("font_size", 18)
    ui.add_child(help)

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
    action_timer = randf_range(2.0, 4.5)
    var choices = ["idle", "wander", "approach", "explore", "play"]
    if energy < 0.25:
        current_action = "sleep"
    elif hunger > 0.75:
        current_action = "approach"
    else:
        current_action = choices[randi() % choices.size()]
    if current_action == "wander" or current_action == "explore" or current_action == "play":
        _new_wander_target()

func _new_wander_target():
    wander_target = Vector3(randf_range(-5.5, 5.5), hippo.position.y, randf_range(-4.3, 4.3))

func _update_hippo(delta):
    var direction = Vector3.ZERO
    var speed = 0.0

    if current_action == "approach":
        var target = camera.global_position
        target.y = hippo.global_position.y
        if hippo.global_position.distance_to(target) > 3.0:
            direction = (target - hippo.global_position).normalized()
            speed = 1.2
    elif current_action == "wander" or current_action == "explore" or current_action == "play":
        if hippo.global_position.distance_to(wander_target) < 0.5:
            _new_wander_target()
        direction = (wander_target - hippo.global_position).normalized()
        speed = 1.5 if current_action == "play" else 0.9
    elif current_action == "sleep":
        energy = clamp(energy + delta * 0.01, 0.0, 1.0)

    hippo.velocity = Vector3(direction.x * speed, -0.2, direction.z * speed)
    hippo.move_and_slide()

    if direction.length_squared() > 0.01:
        var target_point = hippo.global_position + direction
        hippo.look_at(target_point, Vector3.UP)
        hippo.rotation.x = 0.0
        hippo.rotation.z = 0.0

    var now = Time.get_ticks_msec() / 1000.0
    var breathe = sin(now * 2.2) * 0.025
    hippo_visual.scale = Vector3(1.0 + breathe, 1.0 + breathe * 0.5, 1.0 + breathe)
    ear_l.rotation.z = sin(now * 5.0) * 0.18
    ear_r.rotation.z = -sin(now * 5.0) * 0.18

    if pet_pulse > 0.0:
        pet_pulse = max(0.0, pet_pulse - delta)
        head.rotation.z = sin(now * 10.0) * 0.12 * pet_pulse
    else:
        head.rotation.z = 0.0

func _update_camera():
    var pivot = Vector3(0.0, 1.0, 0.0)
    var horizontal = cos(orbit_pitch) * orbit_distance
    camera.position = pivot + Vector3(sin(orbit_yaw) * horizontal, -sin(orbit_pitch) * orbit_distance + 1.0, cos(orbit_yaw) * horizontal)
    camera.look_at(pivot, Vector3.UP)

func _update_ui():
    stats_label.text = "%s  Bond %d%%  Hunger %d%%  Energy %d%%" % [hippo_name, int(bond * 100.0), int(hunger * 100.0), int(energy * 100.0)]
    action_label.text = "Mood: %s" % current_action.capitalize()

func _feed_hippo():
    hunger = clamp(hunger - 0.30, 0.0, 1.0)
    affection = clamp(affection + 0.03, 0.0, 1.0)
    bond = clamp(bond + 0.008, 0.0, 1.0)
    interaction_counts["feed"] = int(interaction_counts.get("feed", 0)) + 1
    current_action = "approach"
    action_timer = 3.0
    _save_state()

func _pet(strength):
    affection = clamp(affection + 0.02 * strength, 0.0, 1.0)
    curiosity = clamp(curiosity + 0.006 * strength, 0.0, 1.0)
    bond = clamp(bond + 0.006 * strength, 0.0, 1.0)
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
            orbit_pitch = clamp(orbit_pitch - drag_delta.y * 0.004, -0.55, 0.20)
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
            orbit_pitch = clamp(orbit_pitch - mouse_delta.y * 0.004, -0.55, 0.20)

func _screen_hits_hippo(screen_pos):
    var origin = camera.project_ray_origin(screen_pos)
    var direction = camera.project_ray_normal(screen_pos)
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
        "last_save": int(Time.get_unix_time_from_system())
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
    var last_save = int(parsed.get("last_save", 0))
    if last_save > 0:
        var elapsed_minutes = min(float(int(Time.get_unix_time_from_system()) - last_save) / 60.0, 4320.0)
        hunger = clamp(hunger + elapsed_minutes * 0.003, 0.0, 1.0)
        energy = clamp(energy + elapsed_minutes * 0.0015, 0.0, 1.0)

func _make_material(color, roughness):
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
