extends SceneTree

const CAPTURE_SIZE := Vector2i(3840, 2160)
const OUTPUT_PATH := "res://artifacts/sanctuary-cinematic-4k.png"

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
    root.size = CAPTURE_SIZE

    # Give generated models, open-world terrain, PBR layers, sky and ambient life
    # enough frames to initialise before the quality frame is captured.
    for i in range(120):
        await process_frame

    var ui_layer = sanctuary.get("ui_layer")
    if ui_layer is CanvasLayer:
        ui_layer.visible = false

    if sanctuary.has_method("set_camera_mode"):
        sanctuary.call("set_camera_mode", "cinematic")

    for i in range(60):
        await process_frame

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
    var image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("VISUAL QA: viewport image is empty")
        quit(3)
        return

    if image.get_width() != CAPTURE_SIZE.x or image.get_height() != CAPTURE_SIZE.y:
        push_error("VISUAL QA: expected 3840x2160, got %sx%s" % [image.get_width(), image.get_height()])
        quit(4)
        return

    var error = image.save_png(OUTPUT_PATH)
    if error != OK:
        push_error("VISUAL QA: screenshot save failed: %s" % error)
        quit(5)
        return

    print("VISUAL QA CAPTURE PASS: %s x %s" % [image.get_width(), image.get_height()])
    quit(0)
