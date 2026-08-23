extends SceneTree

func _initialize() -> void:
    var android_home := OS.get_environment("ANDROID_HOME")
    var java_home := OS.get_environment("JAVA_HOME")

    if not android_home.is_empty():
        EditorSettings.set_setting("export/android/android_sdk_path", android_home)
    if not java_home.is_empty():
        EditorSettings.set_setting("export/android/java_sdk_path", java_home)

    EditorSettings.save()
    quit()
