extends Node

# Hippo OS immersive audio director.
# The app deliberately does not claim Dolby Atmos certification. This system builds an
# Atmos-like spatial experience with Godot 3D emitters, layered ambience, dynamic
# range control, reverb, EQ and original procedural animal/foley sounds.

const POND_POS = Vector3(3.7, 0.8, 2.5)
const MUD_POS = Vector3(-3.7, 0.8, 2.8)
const SAMPLE_RATE = 48000
const FALLBACK_RATE = 24000

var scene_root
var hippo

var forest_player
var birds_player
var water_player
var voice_player
var mouth_player
var foley_player
var breath_player
var ui_player

var grunt_streams = []
var chuff_stream
var chew_stream
var splash_stream
var mud_stream
var step_streams = []
var breath_stream
var ui_tick_stream

var last_action = ""
var last_pet_count = 0
var last_feed_count = 0
var step_timer = 0.0
var action_fx_timer = 0.0
var vocal_timer = 5.0
var settings_timer = 0.0
var duck_timer = 0.0
var settings_signature = ""
var ui_tick_cooldown = 0.0

func _ready():
    randomize()
    _ensure_audio_buses()
    _build_procedural_library()
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
    _ensure_scene_binding()
    if not scene_root or not hippo:
        return

    settings_timer -= delta
    ui_tick_cooldown = max(0.0, ui_tick_cooldown - delta)
    duck_timer = max(0.0, duck_timer - delta)
    if settings_timer <= 0.0:
        settings_timer = 0.20
        _sync_mix_from_settings()

    _track_interactions()
    _track_action(delta)
    _track_movement(delta)
    _track_environmental_foley(delta)
    _track_vocalisations(delta)
    _update_emitter_positions()

func _ensure_scene_binding():
    var current_scene = get_tree().current_scene
    if not current_scene:
        return
    if scene_root == current_scene and is_instance_valid(hippo):
        return

    scene_root = current_scene
    hippo = scene_root.find_child("BabyHippo", true, false)
    if not hippo:
        return

    _build_scene_players()
    _prime_state_tracking()
    _start_ambience()
    _sync_mix_from_settings()

func _build_scene_players():
    forest_player = AudioStreamPlayer.new()
    forest_player.name = "ForestBed"
    forest_player.bus = &"Ambience"
    forest_player.volume_db = -13.0
    scene_root.add_child(forest_player)

    birds_player = AudioStreamPlayer.new()
    birds_player.name = "BirdCanopy"
    birds_player.bus = &"Ambience"
    birds_player.volume_db = -20.0
    scene_root.add_child(birds_player)

    water_player = _new_3d_player("PondWater", &"Ambience", 16.0, 3.8, 1.15)
    water_player.global_position = POND_POS

    voice_player = _new_3d_player("HippoVoice", &"Animal", 18.0, 2.6, 1.25)
    voice_player.max_polyphony = 2

    mouth_player = _new_3d_player("HippoMouth", &"Animal", 13.0, 2.2, 1.18)
    mouth_player.max_polyphony = 3

    foley_player = _new_3d_player("HippoFoley", &"Foley", 11.0, 1.8, 1.20)
    foley_player.max_polyphony = 4

    breath_player = _new_3d_player("HippoBreathing", &"Animal", 9.0, 1.5, 1.12)
    breath_player.volume_db = -18.0

    ui_player = AudioStreamPlayer.new()
    ui_player.name = "UISound"
    ui_player.bus = &"UI"
    ui_player.volume_db = -14.0
    scene_root.add_child(ui_player)

func _new_3d_player(node_name, bus_name, max_distance, unit_size, pan_strength):
    var player = AudioStreamPlayer3D.new()
    player.name = node_name
    player.bus = bus_name
    player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
    player.max_distance = max_distance
    player.unit_size = unit_size
    player.max_db = 0.0
    player.panning_strength = pan_strength
    player.attenuation_filter_cutoff_hz = 9000.0
    player.attenuation_filter_db = -18.0
    scene_root.add_child(player)
    return player

func _start_ambience():
    forest_player.stream = _load_loop_or_fallback(
        "res://assets/audio/forest_ambience.ogg",
        _make_forest_fallback(7.0, 7001)
    )
    birds_player.stream = _load_loop_or_fallback(
        "res://assets/audio/birds_garden.ogg",
        _make_birds_fallback(7.5, 7002)
    )
    water_player.stream = _load_loop_or_fallback(
        "res://assets/audio/water_stream.ogg",
        _make_water_fallback(6.0, 7003)
    )
    forest_player.play()
    birds_player.play(randf_range(0.0, 2.0))
    water_player.play(randf_range(0.0, 1.5))

func _load_loop_or_fallback(path, fallback):
    if ResourceLoader.exists(path):
        var resource = load(path)
        if resource is AudioStreamOggVorbis:
            resource.loop = true
        return resource
    return fallback

func _prime_state_tracking():
    last_action = str(scene_root.get("current_action"))
    var counts = scene_root.get("interaction_counts")
    if typeof(counts) == TYPE_DICTIONARY:
        last_pet_count = int(counts.get("pet", 0))
        last_feed_count = int(counts.get("feed", 0))
    settings_signature = _settings_signature()
    step_timer = 0.1
    vocal_timer = randf_range(4.5, 9.0)

func _track_interactions():
    var counts = scene_root.get("interaction_counts")
    if typeof(counts) != TYPE_DICTIONARY:
        return

    var pet_count = int(counts.get("pet", 0))
    var feed_count = int(counts.get("feed", 0))

    if pet_count > last_pet_count:
        _play_3d(voice_player, chuff_stream, -7.0, 0.94, 1.08)
        _duck_ambience(0.65)
    if feed_count > last_feed_count:
        _play_3d(mouth_player, chew_stream, -5.5, 0.94, 1.05)
        if randf() < 0.58:
            _play_grunt(-8.5, 0.93, 1.05)

    last_pet_count = pet_count
    last_feed_count = feed_count

func _track_action(delta):
    action_fx_timer = max(0.0, action_fx_timer - delta)
    var action = str(scene_root.get("current_action"))
    if action == last_action:
        if action == "sleep" and breath_player and not breath_player.playing:
            breath_player.stream = breath_stream
            breath_player.pitch_scale = randf_range(0.96, 1.03)
            breath_player.play()
        return

    if breath_player and breath_player.playing:
        breath_player.stop()

    match action:
        "approach":
            if randf() < 0.62:
                _play_grunt(-8.0, 0.95, 1.07)
        "play":
            _play_grunt(-5.5, 1.04, 1.14)
        "drink":
            action_fx_timer = 0.5
        "mud":
            action_fx_timer = 0.4
        "sleep":
            breath_player.stream = breath_stream
            breath_player.pitch_scale = randf_range(0.96, 1.03)
            breath_player.play()
        _:
            pass

    last_action = action

func _track_movement(delta):
    if not (hippo is CharacterBody3D):
        return
    var speed = hippo.velocity.length()
    if speed < 0.18:
        step_timer = min(step_timer, 0.08)
        return

    step_timer -= delta
    if step_timer > 0.0:
        return

    var action = str(scene_root.get("current_action"))
    var interval = 0.30 if action == "play" else 0.47
    step_timer = interval * randf_range(0.86, 1.12)
    var stream = step_streams[randi() % step_streams.size()]
    var wetness = float(scene_root.get("wetness"))
    var mud_coat = float(scene_root.get("mud_coat"))
    var base_db = -12.5 + min(wetness + mud_coat, 1.0) * 2.0
    _play_3d(foley_player, stream, base_db, 0.92, 1.08)

func _track_environmental_foley(delta):
    action_fx_timer -= delta
    if action_fx_timer > 0.0:
        return

    var action = str(scene_root.get("current_action"))
    if action == "drink" and hippo.global_position.distance_to(POND_POS) < 1.15:
        action_fx_timer = randf_range(0.75, 1.35)
        _play_3d(foley_player, splash_stream, -7.0, 0.90, 1.10)
    elif action == "mud" and hippo.global_position.distance_to(MUD_POS) < 1.15:
        action_fx_timer = randf_range(0.55, 1.05)
        _play_3d(foley_player, mud_stream, -7.5, 0.88, 1.08)

func _track_vocalisations(delta):
    vocal_timer -= delta
    if vocal_timer > 0.0:
        return

    vocal_timer = randf_range(7.0, 15.0)
    var action = str(scene_root.get("current_action"))
    if action == "sleep":
        return
    if action == "idle" or action == "approach" or action == "play":
        var chance = 0.72 if action == "play" else 0.42
        if randf() < chance:
            _play_grunt(-9.5 if action != "play" else -7.0, 0.91, 1.08)

func _update_emitter_positions():
    if not is_instance_valid(hippo):
        return
    var mouth_position = hippo.global_position + Vector3(0.75, 0.72, 0.0)
    voice_player.global_position = mouth_position
    mouth_player.global_position = mouth_position + Vector3(0.35, -0.12, 0.0)
    breath_player.global_position = mouth_position
    foley_player.global_position = hippo.global_position + Vector3(0.0, -0.45, 0.0)
    water_player.global_position = POND_POS

func _play_grunt(volume_db, pitch_min, pitch_max):
    if grunt_streams.is_empty():
        return
    var stream = grunt_streams[randi() % grunt_streams.size()]
    _play_3d(voice_player, stream, volume_db, pitch_min, pitch_max)
    _duck_ambience(0.9)

func _play_3d(player, stream, volume_db, pitch_min, pitch_max):
    if not player or not stream:
        return
    player.stream = stream
    player.volume_db = volume_db
    player.pitch_scale = randf_range(pitch_min, pitch_max)
    player.play()

func _duck_ambience(duration):
    duck_timer = max(duck_timer, duration)

func _sync_mix_from_settings():
    var settings = scene_root.get("settings")
    if typeof(settings) != TYPE_DICTIONARY:
        return

    _set_bus_linear("Master", float(settings.get("master_volume", 1.0)))
    _set_bus_linear("Animal", float(settings.get("animal_volume", 1.0)))
    _set_bus_linear("Foley", float(settings.get("animal_volume", 1.0)) * 0.94)
    var ambience_gain = float(settings.get("ambience_volume", 0.75))
    if duck_timer > 0.0:
        ambience_gain *= 0.70
    _set_bus_linear("Ambience", ambience_gain)
    _set_bus_linear("UI", float(settings.get("ui_volume", 0.85)))

    var new_signature = _settings_signature()
    if settings_signature != "" and new_signature != settings_signature and ui_tick_cooldown <= 0.0:
        ui_player.stream = ui_tick_stream
        ui_player.pitch_scale = randf_range(0.98, 1.04)
        ui_player.play()
        ui_tick_cooldown = 0.10
    settings_signature = new_signature

func _settings_signature():
    if not scene_root:
        return ""
    var settings = scene_root.get("settings")
    if typeof(settings) != TYPE_DICTIONARY:
        return ""
    return "%0.2f|%0.2f|%0.2f|%0.2f|%s|%s|%0.2f|%s" % [
        float(settings.get("master_volume", 1.0)),
        float(settings.get("animal_volume", 1.0)),
        float(settings.get("ambience_volume", 0.75)),
        float(settings.get("ui_volume", 0.85)),
        str(settings.get("haptics", true)),
        str(settings.get("show_stats", true)),
        float(settings.get("camera_sensitivity", 1.0)),
        str(settings.get("day_night_mode", "auto"))
    ]

func _set_bus_linear(bus_name, value):
    var index = AudioServer.get_bus_index(bus_name)
    if index >= 0:
        AudioServer.set_bus_volume_linear(index, clamp(float(value), 0.0, 1.0))

func _ensure_audio_buses():
    _ensure_bus("Animal")
    _ensure_bus("Foley")
    _ensure_bus("Ambience")
    _ensure_bus("UI")
    _configure_master_fx()
    _configure_animal_fx()
    _configure_foley_fx()
    _configure_ambience_fx()

func _ensure_bus(bus_name):
    if AudioServer.get_bus_index(bus_name) >= 0:
        return
    AudioServer.add_bus()
    var index = AudioServer.get_bus_count() - 1
    AudioServer.set_bus_name(index, bus_name)
    AudioServer.set_bus_send(index, &"Master")

func _configure_master_fx():
    var index = AudioServer.get_bus_index("Master")
    if index < 0 or AudioServer.get_bus_effect_count(index) > 0:
        return

    var eq = AudioEffectEQ6.new()
    eq.set_band_gain_db(0, -4.0)
    eq.set_band_gain_db(1, -1.5)
    eq.set_band_gain_db(2, 0.6)
    eq.set_band_gain_db(3, 0.0)
    eq.set_band_gain_db(4, 0.8)
    eq.set_band_gain_db(5, 0.4)
    AudioServer.add_bus_effect(index, eq)

    var compressor = AudioEffectCompressor.new()
    compressor.threshold = -9.0
    compressor.ratio = 2.2
    compressor.attack_us = 120.0
    compressor.release_ms = 180.0
    compressor.gain = 0.8
    AudioServer.add_bus_effect(index, compressor)

    var limiter = AudioEffectHardLimiter.new()
    limiter.ceiling_db = -0.8
    limiter.pre_gain_db = 0.0
    limiter.release = 0.12
    AudioServer.add_bus_effect(index, limiter)

func _configure_animal_fx():
    var index = AudioServer.get_bus_index("Animal")
    if index < 0 or AudioServer.get_bus_effect_count(index) > 0:
        return

    var eq = AudioEffectEQ6.new()
    eq.set_band_gain_db(0, -6.0)
    eq.set_band_gain_db(1, 1.0)
    eq.set_band_gain_db(2, 1.4)
    eq.set_band_gain_db(3, 0.4)
    eq.set_band_gain_db(4, -0.3)
    eq.set_band_gain_db(5, -1.0)
    AudioServer.add_bus_effect(index, eq)

    var compressor = AudioEffectCompressor.new()
    compressor.threshold = -15.0
    compressor.ratio = 3.0
    compressor.attack_us = 180.0
    compressor.release_ms = 220.0
    compressor.gain = 1.2
    AudioServer.add_bus_effect(index, compressor)

func _configure_foley_fx():
    var index = AudioServer.get_bus_index("Foley")
    if index < 0 or AudioServer.get_bus_effect_count(index) > 0:
        return
    var reverb = AudioEffectReverb.new()
    reverb.room_size = 0.35
    reverb.damping = 0.72
    reverb.wet = 0.09
    reverb.dry = 1.0
    reverb.predelay_msec = 18.0
    reverb.predelay_feedback = 0.10
    AudioServer.add_bus_effect(index, reverb)

func _configure_ambience_fx():
    var index = AudioServer.get_bus_index("Ambience")
    if index < 0 or AudioServer.get_bus_effect_count(index) > 0:
        return

    var eq = AudioEffectEQ6.new()
    eq.set_band_gain_db(0, -8.0)
    eq.set_band_gain_db(1, -2.5)
    eq.set_band_gain_db(2, -0.8)
    eq.set_band_gain_db(3, 0.0)
    eq.set_band_gain_db(4, 0.7)
    eq.set_band_gain_db(5, 0.5)
    AudioServer.add_bus_effect(index, eq)

    var reverb = AudioEffectReverb.new()
    reverb.room_size = 0.62
    reverb.damping = 0.74
    reverb.wet = 0.13
    reverb.dry = 1.0
    reverb.predelay_msec = 22.0
    reverb.predelay_feedback = 0.12
    AudioServer.add_bus_effect(index, reverb)

func _build_procedural_library():
    grunt_streams = [
        _make_grunt(0.92, 64.0, 1101),
        _make_grunt(1.08, 58.0, 1102),
        _make_grunt(0.74, 72.0, 1103)
    ]
    chuff_stream = _make_chuff(0.42, 1201)
    chew_stream = _make_chew(0.85, 1301)
    splash_stream = _make_splash(0.72, 1401)
    mud_stream = _make_mud_squelch(0.68, 1501)
    step_streams = [
        _make_step(0.28, 1601),
        _make_step(0.30, 1602),
        _make_step(0.26, 1603)
    ]
    breath_stream = _make_breath_loop(3.6, 1701)
    ui_tick_stream = _make_ui_tick(0.075)

func _new_wav(data, sample_rate = SAMPLE_RATE, looped = false):
    var stream = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = data
    if looped:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = data.size() / 2
    return stream

func _make_grunt(duration, base_freq, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var attack = min(t / 0.045, 1.0)
        var release = pow(max(0.0, 1.0 - t / duration), 1.65)
        var env = attack * release
        var wobble = sin(TAU * 2.7 * t) * 5.0 + sin(TAU * 6.1 * t) * 1.4
        var f = base_freq + wobble
        var throat = sin(TAU * f * t) * 0.54
        throat += sin(TAU * f * 2.0 * t + 0.3) * 0.25
        throat += sin(TAU * f * 3.0 * t + 0.9) * 0.10
        var breath_noise = rng.randf_range(-1.0, 1.0) * 0.085
        var pulse = 0.78 + sin(TAU * 7.0 * t) * 0.12
        var sample = clamp((throat * pulse + breath_noise) * env * 0.82, -0.95, 0.95)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_chuff(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var smooth_noise = 0.0
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var env = min(t / 0.02, 1.0) * pow(max(0.0, 1.0 - t / duration), 2.3)
        smooth_noise = lerp(smooth_noise, rng.randf_range(-1.0, 1.0), 0.18)
        var body = sin(TAU * 118.0 * t) * 0.23 + sin(TAU * 182.0 * t) * 0.08
        var sample = clamp((smooth_noise * 0.55 + body) * env, -0.9, 0.9)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_chew(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var local = fmod(t, 0.19)
        var burst = exp(-local * 24.0)
        var jaw = sin(TAU * (75.0 + 35.0 * exp(-local * 10.0)) * local)
        var noise = rng.randf_range(-1.0, 1.0)
        var sample = clamp((jaw * 0.42 + noise * 0.20) * burst * 0.72, -0.9, 0.9)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_step(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var env = exp(-t * 19.0)
        var body = sin(TAU * (62.0 - 18.0 * t) * t) * 0.74
        var texture = rng.randf_range(-1.0, 1.0) * 0.20
        var sample = clamp((body + texture) * env * 0.75, -0.95, 0.95)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_splash(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var smooth = 0.0
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var env = min(t / 0.012, 1.0) * exp(-t * 5.2)
        smooth = lerp(smooth, rng.randf_range(-1.0, 1.0), 0.42)
        var thump = sin(TAU * (78.0 - t * 35.0) * t) * exp(-t * 11.0) * 0.52
        var sample = clamp((smooth * 0.62 + thump) * env, -0.95, 0.95)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_mud_squelch(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var smooth = 0.0
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var progress = t / duration
        var env = sin(PI * clamp(progress, 0.0, 1.0))
        var freq = lerp(105.0, 34.0, progress)
        smooth = lerp(smooth, rng.randf_range(-1.0, 1.0), 0.09)
        var wet = sin(TAU * freq * t + sin(TAU * 7.0 * t) * 1.2) * 0.48
        var sample = clamp((wet + smooth * 0.34) * env * 0.70, -0.9, 0.9)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_breath_loop(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var smooth = 0.0
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var cycle = (sin(TAU * t / duration - PI * 0.5) + 1.0) * 0.5
        var env = pow(cycle, 1.6)
        smooth = lerp(smooth, rng.randf_range(-1.0, 1.0), 0.035)
        var body = sin(TAU * 54.0 * t) * 0.06
        var sample = clamp((smooth * 0.30 + body) * env * 0.55, -0.65, 0.65)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data, SAMPLE_RATE, true)

func _make_ui_tick(duration):
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var env = exp(-t * 42.0)
        var sample = (sin(TAU * 980.0 * t) * 0.26 + sin(TAU * 1470.0 * t) * 0.11) * env
        data.encode_s16(i * 2, int(clamp(sample, -0.8, 0.8) * 32767.0))
    return _new_wav(data)

func _make_forest_fallback(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * FALLBACK_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var slow = 0.0
    var fast = 0.0
    for i in range(frames):
        var t = float(i) / FALLBACK_RATE
        slow = lerp(slow, rng.randf_range(-1.0, 1.0), 0.0025)
        fast = lerp(fast, rng.randf_range(-1.0, 1.0), 0.022)
        var leaf = sin(TAU * 0.17 * t) * 0.04
        var sample = clamp(slow * 0.28 + fast * 0.08 + leaf, -0.45, 0.45)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data, FALLBACK_RATE, true)

func _make_birds_fallback(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * FALLBACK_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var chirp_starts = [0.8, 2.2, 3.05, 5.4, 6.2]
    for i in range(frames):
        var t = float(i) / FALLBACK_RATE
        var sample = rng.randf_range(-1.0, 1.0) * 0.012
        for start in chirp_starts:
            var local = t - float(start)
            if local >= 0.0 and local < 0.28:
                var env = sin(PI * local / 0.28)
                var freq = 2100.0 + local * 3200.0 + sin(TAU * 9.0 * local) * 280.0
                sample += sin(TAU * freq * local) * env * 0.16
        data.encode_s16(i * 2, int(clamp(sample, -0.5, 0.5) * 32767.0))
    return _new_wav(data, FALLBACK_RATE, true)

func _make_water_fallback(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed
    var frames = int(duration * FALLBACK_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var smooth = 0.0
    for i in range(frames):
        var t = float(i) / FALLBACK_RATE
        smooth = lerp(smooth, rng.randf_range(-1.0, 1.0), 0.10)
        var ripple = sin(TAU * 3.8 * t + sin(TAU * 0.21 * t)) * 0.035
        var sample = clamp(smooth * 0.18 + ripple, -0.35, 0.35)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data, FALLBACK_RATE, true)
