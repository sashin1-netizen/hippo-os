extends SceneTree

const CAPTURE_SIZE := Vector2i(3840, 2160)
const OUTPUT_DIR := "res://artifacts"

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
    # enough frames to initialise before the quality frames are captured.
    for i in range(140):
        await process_frame

    var ui_layer = sanctuary.get("ui_layer")
    if ui_layer is CanvasLayer:
        ui_layer.visible = false

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

    if sanctuary.has_method("set_camera_mode"):
        sanctuary.call("set_camera_mode", "cinematic")
    for i in range(60):
        await process_frame
    if not _save_frame("%s/sanctuary-cinematic-4k.png" % OUTPUT_DIR, "cinematic"):
        quit(3)
        return

    var controller = sanctuary.get_node_or_null("OpenWorldController")
    if controller == null:
        push_error("VISUAL QA: OpenWorldController missing")
        quit(4)
        return

    var ids = ["hippo_01", "pig_01", "sharpei_01"]
    var filenames = {
        "hippo_01": "mochi-bodycam-4k.png",
        "pig_01": "truffle-bodycam-4k.png",
        "sharpei_01": "bao-bodycam-4k.png"
    }

    for animal_id in ids:
        if sanctuary.has_method("_select_animal"):
            sanctuary.call("_select_animal", animal_id)
        var actor = sanctuary.call("_selected_actor") if sanctuary.has_method("_selected_actor") else null
        if actor == null:
            push_error("VISUAL QA: selected animal missing: %s" % animal_id)
            quit(5)
            return

        # Position the caretaker a natural close-interaction distance in front of
        # each animal. Bodycam collision remains active, so this also exercises the
        # close-range camera clearance logic used on-device.
        var actor_pos: Vector3 = actor.global_position
        controller.set("roam_position", Vector3(actor_pos.x, actor_pos.y + 1.45, actor_pos.z + 2.65))
        controller.set("roam_yaw", 0.0)
        controller.set("roam_pitch", -0.10)
        if controller.has_method("stop_move"):
            controller.call("stop_move")
        if sanctuary.has_method("set_camera_mode"):
            sanctuary.call("set_camera_mode", "bodycam")

        for i in range(48):
            await process_frame

        var output = "%s/%s" % [OUTPUT_DIR, filenames[animal_id]]
        if not _save_frame(output, animal_id):
            quit(6)
            return

    print("VISUAL QA CAPTURE PASS: 3840 x 2160 · cinematic + 3 bodycam frames")
    quit(0)

func _save_frame(path: String, label: String) -> bool:
    var image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("VISUAL QA: viewport image is empty for %s" % label)
        return false
    if image.get_width() != CAPTURE_SIZE.x or image.get_height() != CAPTURE_SIZE.y:
        push_error("VISUAL QA: %s expected 3840x2160, got %sx%s" % [label, image.get_width(), image.get_height()])
        return false
    var error = image.save_png(path)
    if error != OK:
        push_error("VISUAL QA: screenshot save failed for %s: %s" % [label, error])
        return false
    return true
