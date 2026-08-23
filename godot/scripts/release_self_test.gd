extends SceneTree

var failures = []

func _initialize():
    print("HIPPO OS 1.0 RELEASE SELF-TEST")
    _check_project_files()
    _check_runtime_modules()
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
        "res://scripts/launch_shell.gd",
        "res://scripts/sanctuary_v3.gd",
        "res://scripts/animal_actor.gd",
        "res://scripts/animal_brain.gd",
        "res://scripts/animal_state.gd",
        "res://scripts/species_profiles.gd",
        "res://scripts/sanctuary_state.gd",
        "res://scripts/animal_relationships.gd",
        "res://assets/icon.svg",
        "res://assets/splash.svg",
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
        "res://scripts/launch_shell.gd",
        "res://scripts/sanctuary_v3.gd",
        "res://scripts/animal_actor.gd",
        "res://scripts/animal_brain.gd",
        "res://scripts/animal_state.gd",
        "res://scripts/species_profiles.gd",
        "res://scripts/sanctuary_state.gd",
        "res://scripts/animal_relationships.gd"
    ]
    for script_path in scripts:
        var script_resource = load(script_path)
        if script_resource == null:
            failures.append("Runtime module failed to load: " + script_path)

func _check_export_presets():
    var config = ConfigFile.new()
    var error = config.load("res://export_presets.cfg")
    if error != OK:
        failures.append("export_presets.cfg failed to load")
        return

    var apk_name = str(config.get_value("preset.0", "name", ""))
    var apk_platform = str(config.get_value("preset.0", "platform", ""))
    var apk_package = str(config.get_value("preset.0.options", "package/unique_name", ""))
    var apk_target = int(config.get_value("preset.0.options", "gradle_build/target_sdk", "0"))
    var apk_version = str(config.get_value("preset.0.options", "version/name", ""))

    if apk_name != "Android APK":
        failures.append("Android APK export preset missing")
    if apk_platform != "Android":
        failures.append("APK export platform is not Android")
    if apk_package != "com.sashin.hippoos":
        failures.append("Unexpected Android package name")
    if apk_target < 36:
        failures.append("Android target SDK must be API 36 or newer")
    if apk_version.is_empty():
        failures.append("Android version name missing")

    var aab_name = str(config.get_value("preset.1", "name", ""))
    var aab_platform = str(config.get_value("preset.1", "platform", ""))
    var aab_format = int(config.get_value("preset.1.options", "gradle_build/export_format", -1))
    var aab_target = int(config.get_value("preset.1.options", "gradle_build/target_sdk", "0"))

    if aab_name != "Google Play AAB":
        failures.append("Google Play AAB export preset missing")
    if aab_platform != "Android":
        failures.append("AAB export platform is not Android")
    if aab_format != 1:
        failures.append("Google Play preset is not configured as AAB")
    if aab_target < 36:
        failures.append("Google Play target SDK must be API 36 or newer")
