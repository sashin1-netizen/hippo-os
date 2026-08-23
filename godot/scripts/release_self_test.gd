extends SceneTree

var failures = []

func _initialize():
    print("HIPPO OS RELEASE SELF-TEST")
    _check_project_files()
    _check_export_preset()
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
        "res://main.tscn",
        "res://scripts/main.gd",
        "res://export_presets.cfg"
    ]
    for path in required:
        if not FileAccess.file_exists(path):
            failures.append("Missing required file: " + path)

    if FileAccess.file_exists("res://main.tscn"):
        var packed = load("res://main.tscn")
        if packed == null:
            failures.append("main.tscn failed to load")
        else:
            var instance = packed.instantiate()
            if instance == null:
                failures.append("main.tscn failed to instantiate")
            else:
                instance.queue_free()

func _check_export_preset():
    var config = ConfigFile.new()
    var error = config.load("res://export_presets.cfg")
    if error != OK:
        failures.append("export_presets.cfg failed to load")
        return

    var preset_name = str(config.get_value("preset.0", "name", ""))
    var platform = str(config.get_value("preset.0", "platform", ""))
    var package_name = str(config.get_value("preset.0.options", "package/unique_name", ""))

    if preset_name != "Android":
        failures.append("Android export preset missing")
    if platform != "Android":
        failures.append("Export platform is not Android")
    if package_name.is_empty():
        failures.append("Android package name missing")
