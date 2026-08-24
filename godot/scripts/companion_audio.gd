extends Node

# Spatial audio layer for Porky and Bao. Real licensed recordings are preferred
# when present; original synthesized fallbacks keep development checkouts offline.

const SAMPLE_RATE := 48000
const PIG := "pig"
const SHARPEI := "sharpei"

var scene_root: Node3D
var roster: Node
var pig_player: AudioStreamPlayer3D
var dog_player: AudioStreamPlayer3D
var pig_foley: AudioStreamPlayer3D
var dog_foley: AudioStreamPlayer3D
var pig_voice: AudioStream
var dog_bark: AudioStream
var pig_fallback: AudioStreamWAV
var dog_fallback: AudioStreamWAV
var pig_step: AudioStreamWAV
var dog_step: AudioStreamWAV
var last_actions: Dictionary = {PIG: "", SHARPEI: ""}
var voice_cooldowns: Dictionary = {PIG: 0.0, SHARPEI: 0.0}
var step_cooldowns: Dictionary = {PIG: 0.0, SHARPEI: 0.0}
var random_voice_timers: Dictionary = {PIG: 8.0, SHARPEI: 12.0}

func _ready() -> void:
    randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 70
    _build_fallbacks()
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(240):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            var companions_variant: Variant = roster.get("companions")
            if typeof(companions_variant) == TYPE_DICTIONARY:
                var companions: Dictionary = companions_variant
                if companions.has(PIG) and companions.has(SHARPEI):
                    break
        await get_tree().process_frame

    if scene_root == null or roster == null:
        push_warning("CompanionAudio could not bind to the sanctuary roster")
        return

    _build_players()
    _load_library()
    _prime_actions()
    set_process(true)

func _process(delta: float) -> void:
    if roster == null or not is_instance_valid(roster):
        return

    for species in [PIG, SHARPEI]:
        voice_cooldowns[species] = maxf(0.0, float(voice_cooldowns.get(species, 0.0)) - delta)
        step_cooldowns[species] = maxf(0.0, float(step_cooldowns.get(species, 0.0)) - delta)
        random_voice_timers[species] = float(random_voice_timers.get(species, 10.0)) - delta
        _track_species(species)

func _build_players() -> void:
    pig_player = _new_player("PorkyVoice", &"Animal", 15.0, 2.0, 1.18)
    dog_player = _new_player("BaoVoice", &"Animal", 17.0, 2.1, 1.22)
    pig_foley = _new_player("PorkyFoley", &"Foley", 10.0, 1.6, 1.12)
    dog_foley = _new_player("BaoFoley", &"Foley", 11.0, 1.7, 1.15)
    pig_player.max_polyphony = 2
    dog_player.max_polyphony = 2
    pig_foley.max_polyphony = 3
    dog_foley.max_polyphony = 3

func _new_player(node_name: String, bus_name: StringName, max_distance: float, unit_size: float, pan_strength: float) -> AudioStreamPlayer3D:
    var player := AudioStreamPlayer3D.new()
    player.name = node_name
    player.bus = bus_name if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"
    player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
    player.max_distance = max_distance
    player.unit_size = unit_size
    player.panning_strength = pan_strength
    player.attenuation_filter_cutoff_hz = 9200.0
    player.attenuation_filter_db = -16.0
    scene_root.add_child(player)
    return player

func _load_library() -> void:
    pig_voice = _load_audio("res://assets/audio/pig_grunt.ogg", pig_fallback)
    dog_bark = _load_audio("res://assets/audio/dog_bark.ogg", dog_fallback)

func _load_audio(path: String, fallback: AudioStream) -> AudioStream:
    if ResourceLoader.exists(path):
        var resource: Resource = load(path)
        if resource is AudioStream:
            return resource as AudioStream
    return fallback

func _prime_actions() -> void:
    for species in [PIG, SHARPEI]:
        var data := _data_for(species)
        last_actions[species] = str(data.get("action", "watch"))
    random_voice_timers[PIG] = randf_range(7.0, 14.0)
    random_voice_timers[SHARPEI] = randf_range(12.0, 24.0)

func _track_species(species: String) -> void:
    var data := _data_for(species)
    if data.is_empty():
        return
    var body := data.get("node") as CharacterBody3D
    if body == null or not is_instance_valid(body):
        return

    var voice_player := pig_player if species == PIG else dog_player
    var foley_player := pig_foley if species == PIG else dog_foley
    voice_player.global_position = body.global_position + Vector3(0.62, 0.62, 0.0)
    foley_player.global_position = body.global_position + Vector3(0.0, -0.34, 0.0)

    var action := str(data.get("action", "watch"))
    var previous := str(last_actions.get(species, ""))
    if action != previous:
        _react_to_action(species, action)
        last_actions[species] = action

    _track_steps(species, body, action)
    _track_ambient_voice(species, action)

func _react_to_action(species: String, action: String) -> void:
    if float(voice_cooldowns.get(species, 0.0)) > 0.0:
        return

    match action:
        "happy":
            _play_voice(species, -7.5 if species == PIG else -9.0, 0.96, 1.07)
            voice_cooldowns[species] = 2.8
        "coming":
            if species == SHARPEI:
                _play_voice(species, -8.0, 0.95, 1.04)
                voice_cooldowns[species] = 4.8
            elif randf() < 0.58:
                _play_voice(species, -10.0, 0.96, 1.05)
                voice_cooldowns[species] = 4.0
        "play":
            if randf() < (0.64 if species == PIG else 0.34):
                _play_voice(species, -9.0, 0.97, 1.09)
                voice_cooldowns[species] = 5.5
        _:
            pass

func _track_steps(species: String, body: CharacterBody3D, action: String) -> void:
    var speed := body.velocity.length()
    if speed < 0.22:
        return
    if float(step_cooldowns.get(species, 0.0)) > 0.0:
        return

    var base_interval := 0.34 if species == SHARPEI else 0.42
    if action == "play":
        base_interval *= 0.72
    step_cooldowns[species] = base_interval * randf_range(0.88, 1.12)

    var player := pig_foley if species == PIG else dog_foley
    player.stream = pig_step if species == PIG else dog_step
    player.volume_db = -15.0 if species == PIG else -16.0
    player.pitch_scale = randf_range(0.94, 1.08)
    player.play()

func _track_ambient_voice(species: String, action: String) -> void:
    if float(random_voice_timers.get(species, 10.0)) > 0.0:
        return

    if species == PIG:
        random_voice_timers[species] = randf_range(10.0, 21.0)
        if action in ["sniff", "wander", "watch"] and randf() < 0.45:
            _play_voice(PIG, -12.0, 0.94, 1.05)
            voice_cooldowns[PIG] = 4.0
    else:
        # Bao stays comparatively quiet. A bark is contextual/rare, not a loop.
        random_voice_timers[species] = randf_range(18.0, 34.0)
        if action == "play" and randf() < 0.28:
            _play_voice(SHARPEI, -11.0, 0.96, 1.03)
            voice_cooldowns[SHARPEI] = 7.0

func _play_voice(species: String, volume_db: float, pitch_min: float, pitch_max: float) -> void:
    var player := pig_player if species == PIG else dog_player
    player.stream = pig_voice if species == PIG else dog_bark
    player.volume_db = volume_db
    player.pitch_scale = randf_range(pitch_min, pitch_max)
    player.play()

func _data_for(species: String) -> Dictionary:
    if roster == null:
        return {}
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return {}
    var companions: Dictionary = companions_variant
    var data_variant: Variant = companions.get(species, {})
    return data_variant as Dictionary if typeof(data_variant) == TYPE_DICTIONARY else {}

func _build_fallbacks() -> void:
    pig_fallback = _synth_pig_grunt(0.52, 4101)
    dog_fallback = _synth_dog_huff(0.28, 4201)
    pig_step = _synth_step(0.20, 86.0, 4301)
    dog_step = _synth_step(0.17, 105.0, 4302)

func _new_wav(data: PackedByteArray) -> AudioStreamWAV:
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = data
    return stream

func _synth_pig_grunt(duration: float, seed: int) -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var frames := int(duration * SAMPLE_RATE)
    var data := PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t := float(i) / float(SAMPLE_RATE)
        var env := minf(t / 0.025, 1.0) * pow(maxf(0.0, 1.0 - t / duration), 1.8)
        var wobble := sin(TAU * 6.2 * t) * 11.0
        var body := sin(TAU * (92.0 + wobble) * t) * 0.48
        body += sin(TAU * (184.0 + wobble * 0.6) * t + 0.5) * 0.22
        var noise := rng.randf_range(-1.0, 1.0) * 0.11
        var sample := clampf((body + noise) * env * 0.78, -0.92, 0.92)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _synth_dog_huff(duration: float, seed: int) -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var frames := int(duration * SAMPLE_RATE)
    var data := PackedByteArray()
    data.resize(frames * 2)
    var smooth := 0.0
    for i in range(frames):
        var t := float(i) / float(SAMPLE_RATE)
        var env := minf(t / 0.012, 1.0) * exp(-t * 10.5)
        smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.16)
        var chest := sin(TAU * (150.0 - 35.0 * t) * t) * 0.30
        var sample := clampf((smooth * 0.44 + chest) * env, -0.85, 0.85)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)

func _synth_step(duration: float, base_freq: float, seed: int) -> AudioStreamWAV:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var frames := int(duration * SAMPLE_RATE)
    var data := PackedByteArray()
    data.resize(frames * 2)
    for i in range(frames):
        var t := float(i) / float(SAMPLE_RATE)
        var env := exp(-t * 24.0)
        var body := sin(TAU * (base_freq - t * 24.0) * t) * 0.56
        var texture := rng.randf_range(-1.0, 1.0) * 0.16
        var sample := clampf((body + texture) * env * 0.62, -0.90, 0.90)
        data.encode_s16(i * 2, int(sample * 32767.0))
    return _new_wav(data)
