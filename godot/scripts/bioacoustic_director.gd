extends Node

# Species-aware vocal layer for Hippo OS.
# Pygmy hippos are generally quiet animals. Reliable husbandry/zoo references describe
# occasional grunts, snorts/huffs, hisses and higher squeaks rather than the constant loud
# calling associated with cinematic depictions of common hippos. This director therefore
# keeps spontaneous calls sparse and context-sensitive while leaving the main AudioDirector
# responsible for ambience, Foley, footsteps, water, mud and the core spatial mix.

const SAMPLE_RATE = 48000

var scene_root
var hippo
var voice_player
var audio_director

var huff_streams = []
var squeak_streams = []
var hiss_stream

var spontaneous_timer = 18.0
var last_pet_count = 0
var last_existing_voice_playing = false

func _ready():
    randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS
    audio_director = get_node_or_null("/root/AudioDirector")
    _build_library()

func _process(delta):
    _ensure_scene_binding()
    if not is_instance_valid(scene_root) or not is_instance_valid(hippo):
        return

    _update_position()
    _shape_core_vocal_cadence()
    _track_pet_reaction()

    spontaneous_timer -= delta
    if spontaneous_timer <= 0.0:
        _try_spontaneous_call()

func _ensure_scene_binding():
    var current_scene = get_tree().current_scene
    if not current_scene:
        return
    if scene_root == current_scene and is_instance_valid(hippo) and is_instance_valid(voice_player):
        return

    scene_root = current_scene
    hippo = scene_root.find_child("BabyHippo", true, false)
    if not hippo:
        return

    voice_player = AudioStreamPlayer3D.new()
    voice_player.name = "PygmyHippoBioVoice"
    voice_player.bus = &"Animal"
    voice_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
    voice_player.max_distance = 16.0
    voice_player.unit_size = 2.4
    voice_player.max_db = -1.0
    voice_player.panning_strength = 1.32
    voice_player.attenuation_filter_cutoff_hz = 10500.0
    voice_player.attenuation_filter_db = -16.0
    voice_player.max_polyphony = 2
    scene_root.add_child(voice_player)

    var counts = scene_root.get("interaction_counts")
    if typeof(counts) == TYPE_DICTIONARY:
        last_pet_count = int(counts.get("pet", 0))
    spontaneous_timer = randf_range(14.0, 26.0)

func _update_position():
    if not is_instance_valid(voice_player):
        return
    voice_player.global_position = hippo.global_position + Vector3(0.82, 0.72, 0.0)

func _shape_core_vocal_cadence():
    if not is_instance_valid(audio_director):
        audio_director = get_node_or_null("/root/AudioDirector")
    if not is_instance_valid(audio_director):
        return

    var core_voice = audio_director.get("voice_player")
    var playing = is_instance_valid(core_voice) and bool(core_voice.playing)
    if playing and not last_existing_voice_playing:
        # After any core grunt/chuff, enforce a quiet interval. Interaction sounds still
        # occur immediately when appropriate, but random calling no longer becomes noisy.
        audio_director.set("vocal_timer", randf_range(18.0, 38.0))
    last_existing_voice_playing = playing

func _track_pet_reaction():
    var counts = scene_root.get("interaction_counts")
    if typeof(counts) != TYPE_DICTIONARY:
        return
    var pet_count = int(counts.get("pet", 0))
    if pet_count <= last_pet_count:
        return

    var bond = float(scene_root.get("bond"))
    var affection = float(scene_root.get("affection"))
    # Keep touch vocal reactions special: most pets stay tactile/haptic only.
    if bond > 0.55 and affection > 0.62 and randf() < 0.16:
        _play_stream(squeak_streams[randi() % squeak_streams.size()], -13.0, 0.96, 1.05)
        spontaneous_timer = randf_range(24.0, 44.0)
    elif randf() < 0.10:
        _play_stream(huff_streams[randi() % huff_streams.size()], -12.0, 0.94, 1.04)
        spontaneous_timer = randf_range(22.0, 40.0)

    last_pet_count = pet_count

func _try_spontaneous_call():
    var action = str(scene_root.get("current_action"))
    if action == "sleep":
        spontaneous_timer = randf_range(18.0, 34.0)
        return

    var chance = 0.16
    match action:
        "approach":
            chance = 0.30
        "play":
            chance = 0.38
        "idle":
            chance = 0.18
        "wander", "explore":
            chance = 0.10
        "drink", "mud":
            chance = 0.08
        _:
            chance = 0.12

    if randf() >= chance:
        spontaneous_timer = randf_range(12.0, 24.0)
        return

    var affection = float(scene_root.get("affection"))
    var curiosity = float(scene_root.get("curiosity"))
    var roll = randf()

    if action == "play" and roll < 0.34:
        _play_stream(squeak_streams[randi() % squeak_streams.size()], -12.5, 0.97, 1.08)
    elif curiosity < 0.24 and affection < 0.45 and roll < 0.30:
        # A restrained hiss is reserved for low-curiosity/low-affection moments rather
        # than being treated as a generic happy sound.
        _play_stream(hiss_stream, -14.0, 0.96, 1.03)
    else:
        _play_stream(huff_streams[randi() % huff_streams.size()], -11.5, 0.93, 1.05)

    spontaneous_timer = randf_range(24.0, 48.0)
    if is_instance_valid(audio_director):
        audio_director.set("vocal_timer", randf_range(20.0, 42.0))

func _play_stream(stream, volume_db, pitch_min, pitch_max):
    if not is_instance_valid(voice_player) or not stream:
        return
    voice_player.stream = stream
    voice_player.volume_db = float(volume_db)
    voice_player.pitch_scale = randf_range(float(pitch_min), float(pitch_max))
    voice_player.play()

func _build_library():
    huff_streams = [
        _make_huff(0.34, 2101),
        _make_huff(0.42, 2102),
        _make_huff(0.29, 2103)
    ]
    squeak_streams = [
        _make_squeak(0.24, 360.0, 510.0, 2201),
        _make_squeak(0.30, 325.0, 455.0, 2202)
    ]
    hiss_stream = _make_hiss(0.52, 2301)

func _new_wav(data):
    var stream = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = data
    return stream

func _make_huff(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = int(seed)
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var smooth_noise = 0.0
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var attack = min(t / 0.018, 1.0)
        var release = pow(max(0.0, 1.0 - t / duration), 2.0)
        var env = attack * release
        smooth_noise = lerp(smooth_noise, rng.randf_range(-1.0, 1.0), 0.13)
        var chest = sin(TAU * 86.0 * t) * 0.20 + sin(TAU * 132.0 * t) * 0.09
        var sample = clamp((smooth_noise * 0.58 + chest) * env * 0.72, -0.92, 0.92)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_squeak(duration, start_freq, end_freq, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = int(seed)
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var phase = 0.0
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var progress = clamp(t / duration, 0.0, 1.0)
        var freq = lerp(float(start_freq), float(end_freq), smoothstep(0.0, 1.0, progress))
        phase += TAU * freq / SAMPLE_RATE
        var env = sin(PI * progress)
        var body = sin(phase) * 0.55 + sin(phase * 2.01) * 0.12
        var noise = rng.randf_range(-1.0, 1.0) * 0.025
        var sample = clamp((body + noise) * env * 0.62, -0.86, 0.86)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _make_hiss(duration, seed):
    var rng = RandomNumberGenerator.new()
    rng.seed = int(seed)
    var frames = int(duration * SAMPLE_RATE)
    var data = PackedByteArray()
    data.resize(frames * 2)
    var previous = 0.0
    for i in range(frames):
        var t = float(i) / SAMPLE_RATE
        var progress = clamp(t / duration, 0.0, 1.0)
        var env = sin(PI * progress)
        var raw = rng.randf_range(-1.0, 1.0)
        var high = raw - previous * 0.76
        previous = raw
        var throat = sin(TAU * 145.0 * t) * 0.035
        var sample = clamp((high * 0.34 + throat) * env * 0.62, -0.82, 0.82)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)
