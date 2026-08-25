extends Node

# Adaptive mix layer for the Hippo OS immersive soundscape.
# It changes ambience with day/night, activity and proximity while shaping the
# animal's high-frequency content around water. This remains standards-based Godot
# spatial audio and does not claim proprietary Dolby Atmos certification.

const POND_POS = Vector3(3.7, 0.8, 2.5)

var audio_director
var scene_root
var hippo
var camera
var update_timer = 0.0

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    audio_director = get_node_or_null("/root/AudioDirector")

func _process(delta):
    update_timer -= delta
    if update_timer > 0.0:
        return
    update_timer = 0.20

    _ensure_binding()
    if not is_instance_valid(audio_director) or not is_instance_valid(scene_root) or not is_instance_valid(hippo):
        return

    _shape_day_night_mix()
    _shape_activity_mix()
    _shape_water_timbre()

func _ensure_binding():
    if not is_instance_valid(audio_director):
        audio_director = get_node_or_null("/root/AudioDirector")
    var current_scene = get_tree().current_scene
    if not current_scene:
        return
    if scene_root != current_scene or not is_instance_valid(hippo):
        scene_root = current_scene
        hippo = scene_root.find_child("BabyHippo", true, false)
        camera = _find_camera(scene_root)
    elif not is_instance_valid(camera):
        camera = _find_camera(scene_root)

func _shape_day_night_mix():
    var daylight = _daylight_factor()
    var forest = audio_director.get("forest_player")
    var birds = audio_director.get("birds_player")
    var water = audio_director.get("water_player")

    if is_instance_valid(forest):
        # Give night more insect/forest bed; daylight opens space for birds and water.
        forest.volume_db = lerp(-9.5, -13.2, daylight)
    if is_instance_valid(birds):
        birds.volume_db = lerp(-34.0, -18.5, daylight)
    if is_instance_valid(water):
        water.volume_db = lerp(-3.3, -4.4, daylight)

func _shape_activity_mix():
    var action = str(scene_root.get("current_action"))
    var forest = audio_director.get("forest_player")
    var birds = audio_director.get("birds_player")
    var water = audio_director.get("water_player")

    var interactive = action in ["approach", "play", "feed", "eat"]
    var resting = action in ["sleep", "rest"]
    var near_water = hippo.global_position.distance_to(POND_POS) < 2.4

    # Create acoustic focus when the animal is doing something meaningful instead of
    # leaving every ambience layer equally loud at all times.
    if is_instance_valid(forest):
        forest.volume_db += -2.0 if interactive else (1.0 if resting else 0.0)
    if is_instance_valid(birds):
        birds.volume_db += -2.5 if interactive else (-1.0 if resting else 0.0)
    if is_instance_valid(water):
        water.volume_db += 2.0 if near_water else -1.0

    # Keep 3D animal emitters intimate in camera mode without making them unnaturally
    # loud from across the sanctuary.
    if is_instance_valid(camera):
        var camera_distance = camera.global_position.distance_to(hippo.global_position)
        var proximity = 1.0 - clamp((camera_distance - 2.5) / 8.0, 0.0, 1.0)
        var breath = audio_director.get("breath_player")
        var mouth = audio_director.get("mouth_player")
        if is_instance_valid(breath) and action not in ["sleep", "rest"]:
            breath.volume_db = lerp(-23.0, -17.0, proximity)
        if is_instance_valid(mouth):
            mouth.max_distance = lerp(10.0, 14.0, proximity)

func _daylight_factor():
    var settings = scene_root.get("settings")
    if typeof(settings) != TYPE_DICTIONARY:
        return 1.0

    var mode = str(settings.get("day_night_mode", "auto"))
    if mode == "night":
        return 0.0
    if mode == "day":
        return 1.0

    var time = Time.get_time_dict_from_system()
    var hour = float(time.get("hour", 12)) + float(time.get("minute", 0)) / 60.0
    var daylight_angle = (hour - 6.0) / 12.0 * PI
    return clamp(sin(daylight_angle), 0.0, 1.0)

func _shape_water_timbre():
    var action = str(scene_root.get("current_action"))
    var wetness = clamp(float(scene_root.get("wetness")), 0.0, 1.0)
    var at_pond = hippo.global_position.distance_to(POND_POS) < 1.25
    var water_factor = wetness if action == "drink" and at_pond else wetness * 0.25 if at_pond else 0.0

    var cutoff = lerp(9000.0, 3600.0, water_factor)
    var filter_db = lerp(-18.0, -11.0, water_factor)

    var core_voice = audio_director.get("voice_player")
    var mouth = audio_director.get("mouth_player")
    var breath = audio_director.get("breath_player")

    for player in [core_voice, mouth, breath]:
        if is_instance_valid(player):
            player.attenuation_filter_cutoff_hz = cutoff
            player.attenuation_filter_db = filter_db

    var bio = get_node_or_null("/root/BioAcoustics")
    if is_instance_valid(bio):
        var bio_voice = bio.get("voice_player")
        if is_instance_valid(bio_voice):
            bio_voice.attenuation_filter_cutoff_hz = lerp(10500.0, 4100.0, water_factor)
            bio_voice.attenuation_filter_db = filter_db

func _find_camera(node):
    if node is Camera3D and node.current:
        return node
    for child in node.get_children():
        var found = _find_camera(child)
        if found != null:
            return found
    return null
