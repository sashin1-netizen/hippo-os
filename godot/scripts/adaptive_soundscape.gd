extends Node

# Adaptive mix layer for the Hippo OS immersive soundscape.
# It changes ambience with day/night and shapes the animal's high-frequency content when
# Mochi is actually in the pond, adding environmental depth without requiring platform-
# specific proprietary spatial-audio middleware.

const POND_POS = Vector3(3.7, 0.8, 2.5)

var audio_director
var scene_root
var hippo
var update_timer = 0.0

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    audio_director = get_node_or_null("/root/AudioDirector")

func _process(delta):
    update_timer -= delta
    if update_timer > 0.0:
        return
    update_timer = 0.25

    _ensure_binding()
    if not is_instance_valid(audio_director) or not is_instance_valid(scene_root) or not is_instance_valid(hippo):
        return

    _shape_day_night_mix()
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

func _shape_day_night_mix():
    var daylight = _daylight_factor()
    var forest = audio_director.get("forest_player")
    var birds = audio_director.get("birds_player")
    var water = audio_director.get("water_player")

    if is_instance_valid(forest):
        forest.volume_db = lerp(-10.5, -13.0, daylight)
    if is_instance_valid(birds):
        birds.volume_db = lerp(-32.0, -20.0, daylight)
    if is_instance_valid(water):
        # Water stays present at night but recedes slightly during the denser daytime bed.
        water.volume_db = lerp(-3.0, -4.2, daylight)

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
    var hour = float(time.get("hour", 12))
    var daylight_angle = (hour - 6.0) / 12.0 * PI
    return clamp(sin(daylight_angle), 0.0, 1.0)

func _shape_water_timbre():
    var action = str(scene_root.get("current_action"))
    var wetness = clamp(float(scene_root.get("wetness")), 0.0, 1.0)
    var at_pond = hippo.global_position.distance_to(POND_POS) < 1.25
    var water_factor = wetness if action == "drink" and at_pond else 0.0

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
