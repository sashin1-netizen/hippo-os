extends SceneTree

var failures = []

func _initialize():
    print("HIPPO OS PERSONAL RELEASE SELF-TEST")
    _check_project_files()
    _check_runtime_modules()
    _check_production_models()
    _check_production_audio()
    _check_4k_visual_assets()
    _check_export_presets()
    if failures.is_empty():
        print("SELF-TEST PASS")
        quit(0)
    else:
        print("SELF-TEST FAIL")
        for failure in failures:
            push_error(str(failure))
        quit(1)

func _check_project_files():
    var required = [
        "res://project.godot",
        "res://sanctuary_v3.tscn",
        "res://scripts/flutter_runtime_overlay.gd",
        "res://scripts/launch_shell.gd",
        "res://scripts/sanctuary_v3.gd",
        "res://scripts/sanctuary_runtime_v4.gd",
        "res://scripts/animal_actor.gd",
        "res://scripts/animal_brain.gd",
        "res://scripts/animal_state.gd",
        "res://scripts/species_profiles.gd",
        "res://scripts/sanctuary_state.gd",
        "res://scripts/animal_relationships.gd",
        "res://scripts/living_world.gd",
        "res://scripts/environment_v2.gd",
        "res://scripts/environment_pbr.gd",
        "res://scripts/animal_render_v2.gd",
        "res://scripts/animal_motion_v3.gd",
        "res://scripts/ambient_life.gd",
        "res://assets/models/mochi_pygmy_hippo.glb",
        "res://assets/models/truffle_pig.glb",
        "res://assets/models/bao_shar_pei.glb",
        "res://assets/icon.svg",
        "res://export_presets.cfg"
    ]
    for path in required:
        if not FileAccess.file_exists(path):
            failures.append("Missing required file: " + path)

    if FileAccess.file_exists("res://sanctuary_v3.tscn"):
        var packed = load("res://sanctuary_v3.tscn")
        if packed == null:
            failures.append("sanctuary_v3.tscn failed to load")
        else:
            var instance = packed.instantiate()
            if instance == null:
                failures.append("sanctuary_v3.tscn failed to instantiate")
            else:
                instance.queue_free()

func _check_runtime_modules():
    var scripts = [
        "res://scripts/flutter_runtime_overlay.gd",
        "res://scripts/launch_shell.gd",
        "res://scripts/sanctuary_v3.gd",
        "res://scripts/sanctuary_runtime_v4.gd",
        "res://scripts/animal_actor.gd",
        "res://scripts/animal_brain.gd",
        "res://scripts/animal_state.gd",
        "res://scripts/species_profiles.gd",
        "res://scripts/sanctuary_state.gd",
        "res://scripts/animal_relationships.gd",
        "res://scripts/living_world.gd",
        "res://scripts/environment_v2.gd",
        "res://scripts/environment_pbr.gd",
        "res://scripts/animal_render_v2.gd",
        "res://scripts/animal_motion_v3.gd",
        "res://scripts/ambient_life.gd"
    ]
    for script_path in scripts:
        var script_resource = load(script_path)
        if script_resource == null:
            failures.append("Runtime module failed to load: " + script_path)

func _check_production_models():
    var models = {
        "res://assets/models/mochi_pygmy_hippo.glb": ["idle", "move", "eat", "rest", "sniff", "wallow"],
        "res://assets/models/truffle_pig.glb": ["idle", "move", "eat", "rest", "root", "sniff"],
        "res://assets/models/bao_shar_pei.glb": ["idle", "move", "eat", "rest", "observe", "sniff"]
    }
    for model_path in models.keys():
        if not FileAccess.file_exists(model_path):
            failures.append("Production model missing: " + model_path)
            continue
        var packed = load(model_path)
        if packed == null or not packed is PackedScene:
            failures.append("Production model failed to import: " + model_path)
            continue
        var instance = packed.instantiate()
        if instance == null:
            failures.append("Production model failed to instantiate: " + model_path)
            continue
        var player = _find_animation_player(instance)
        if player == null:
            failures.append("Production model has no AnimationPlayer: " + model_path)
        else:
            for clip_name in models[model_path]:
                if not player.has_animation(clip_name):
                    failures.append("Production model missing animation %s: %s" % [clip_name, model_path])
        instance.free()

func _check_production_audio():
    var audio = [
        "res://assets/audio/hippo_grunts.mp3",
        "res://assets/audio/pig_grunt.ogg",
        "res://assets/audio/dog_bark.ogg",
        "res://assets/audio/hippo_step.wav",
        "res://assets/audio/pig_step.wav",
        "res://assets/audio/dog_step.wav",
        "res://assets/audio/water_splash.wav",
        "res://assets/audio/mud_squelch.wav",
        "res://assets/audio/eat_crunch.wav",
        "res://assets/audio/drink_lap.wav",
        "res://assets/audio/ui_click.wav",
        "res://assets/audio/sanctuary_ambience.wav"
    ]
    for path in audio:
        if not FileAccess.file_exists(path):
            failures.append("Production audio missing: " + path)
        elif load(path) == null:
            failures.append("Production audio failed to import: " + path)

func _check_4k_visual_assets():
    var textures = [
        "res://assets/textures/leafy_grass_diff_4k.jpg",
        "res://assets/textures/leafy_grass_nor_gl_4k.jpg",
        "res://assets/textures/leafy_grass_rough_4k.jpg",
        "res://assets/textures/brown_mud_03_diff_4k.jpg",
        "res://assets/textures/brown_mud_03_nor_gl_4k.jpg",
        "res://assets/textures/brown_mud_03_rough_4k.jpg"
    ]
    for path in textures:
        if not FileAccess.file_exists(path):
            failures.append("4K habitat texture missing: " + path)
            continue
        var texture = load(path)
        if texture == null or not texture is Texture2D:
            failures.append("4K habitat texture failed to import: " + path)
            continue
        if texture.get_width() < 3840 or texture.get_height() < 3840:
            failures.append("Habitat texture is below 4K source resolution: " + path)

func _find_animation_player(node):
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found = _find_animation_player(child)
        if found != null:
            return found
    return null

func _check_export_presets():
    var config = ConfigFile.new()
    var error = config.load("res://export_presets.cfg")
    if error != OK:
        failures.append("export_presets.cfg failed to load")
        return

    var apk_name = str(config.get_value("preset.0", "name", ""))
    var apk_platform = str(config.get_value("preset.0", "platform", ""))
    var apk_package = str(config.get_value("preset.0.options", "package/unique_name", ""))
    var apk_version = str(config.get_value("preset.0.options", "version/name", ""))

    if apk_name != "Android APK":
        failures.append("Android APK export preset missing")
    if apk_platform != "Android":
        failures.append("APK export platform is not Android")
    if apk_package != "com.sashin.hippoos":
        failures.append("Unexpected Android package name")
    if apk_version.is_empty():
        failures.append("Android version name missing")
