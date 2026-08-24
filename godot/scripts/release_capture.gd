extends SceneTree

const OUTPUT_PATH = "res://artifacts/sanctuary-cinematic-1080p.png"

func _initialize():
    call_deferred("_capture")

func _capture():
    var packed = load("res://sanctuary_v3.tscn")
    if packed == null or not packed is PackedScene:
        push_error("VISUAL QA: sanctuary scene failed to load")
        quit(2)
        return

    var sanctuary = packed.instantiate()
    root.add_child(sanctuary)
    root.size = Vector2i(1920, 1080)

    # Give generated models, terrain, PBR layers and ambient life enough frames to initialise.
    for i in range(90):
        await process_frame

    var ui_layer = sanctuary.get("ui_layer")
    if ui_layer is CanvasLayer:
        ui_layer.visible = false

    if sanctuary.has_method("set_camera_mode"):
        sanctuary.call("set_camera_mode", "cinematic")

    for i in range(45):
        await process_frame

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    var image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("VISUAL QA: viewport image is empty")
        quit(3)
        return

    var error = image.save_png(OUTPUT_PATH)
    if error != OK:
        push_error("VISUAL QA: screenshot save failed: %s" % error)
        quit(4)
        return

    print("VISUAL QA CAPTURE PASS: %s x %s" % [image.get_width(), image.get_height()])
    quit(0)
