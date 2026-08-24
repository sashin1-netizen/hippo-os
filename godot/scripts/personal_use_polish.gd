extends Node

# Personal-use launch polish for Hippo OS.
# Keeps the existing living-pet simulation intact while adding responsive safe-area UI,
# adaptive feeding, time-aware routine nudges, startup/about UX and camera smoothing.

const PREF_PATH := "user://hippo_personal_prefs.json"
const FOODS := ["Leafy greens", "Cucumber", "Pumpkin", "Melon"]
const FOOD_SATIETY := {
    "Leafy greens": 0.24,
    "Cucumber": 0.20,
    "Pumpkin": 0.29,
    "Melon": 0.26
}

var scene_root
var hippo
var camera
var stats_panel
var settings_panel
var settings_button
var mute_button
var original_feed_button
var feed_button
var food_selector
var zoom_in_button
var zoom_out_button
var help_label
var about_button
var about_dialog
var toast_label
var startup_layer

var food_preferences := {}
var chosen_food := "Leafy greens"
var layout_timer := 0.0
var routine_timer := 8.0
var toast_timer := 0.0
var last_viewport_size := Vector2.ZERO
var smoothed_camera_position := Vector3.ZERO
var camera_initialized := false
var startup_shown := false

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 100
    _load_preferences()
    _ensure_food_preferences()

func _process(delta):
    _ensure_scene_binding()
    if not is_instance_valid(scene_root):
        return

    layout_timer -= delta
    routine_timer -= delta
    toast_timer = max(0.0, toast_timer - delta)

    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size != last_viewport_size or layout_timer <= 0.0:
        last_viewport_size = viewport_size
        layout_timer = 0.5
        _layout_ui()

    if routine_timer <= 0.0:
        routine_timer = randf_range(18.0, 32.0)
        _apply_time_aware_routine()

    _smooth_camera(delta)
    if is_instance_valid(toast_label):
        toast_label.visible = toast_timer > 0.0

func _ensure_scene_binding():
    var current_scene = get_tree().current_scene
    if not current_scene:
        return
    if scene_root == current_scene and is_instance_valid(hippo):
        if not is_instance_valid(mute_button):
            mute_button = current_scene.find_child("AudioMuteButton", true, false)
        return

    scene_root = current_scene
    hippo = scene_root.find_child("BabyHippo", true, false)
    if not hippo:
        return

    camera = _find_camera(scene_root)
    stats_panel = scene_root.get("stats_panel")
    settings_panel = scene_root.get("settings_panel")
    _discover_existing_ui()
    _build_personal_ui()
    camera_initialized = false
    call_deferred("_layout_ui")
    if not startup_shown:
        startup_shown = true
        call_deferred("_show_startup")

func _find_camera(node):
    if node is Camera3D and node.current:
        return node
    for child in node.get_children():
        var found = _find_camera(child)
        if found:
            return found
    return null

func _discover_existing_ui():
    settings_button = null
    original_feed_button = null
    zoom_in_button = null
    zoom_out_button = null
    help_label = null

    var controls := scene_root.find_children("*", "Control", true, false)
    for control in controls:
        if control is Button:
            match control.text:
                "SETTINGS":
                    settings_button = control
                "FEED":
                    original_feed_button = control
                "+":
                    zoom_in_button = control
                "-":
                    zoom_out_button = control
        elif control is Label and str(control.text).begins_with("Pet by dragging"):
            help_label = control

    if is_instance_valid(original_feed_button):
        original_feed_button.visible = false
    mute_button = scene_root.find_child("AudioMuteButton", true, false)

func _build_personal_ui():
    var layer := CanvasLayer.new()
    layer.name = "PersonalUseUI"
    layer.layer = 19
    scene_root.add_child(layer)

    food_selector = OptionButton.new()
    food_selector.name = "FoodSelector"
    for food in FOODS:
        food_selector.add_item(food)
    var selected_index := FOODS.find(chosen_food)
    food_selector.select(max(0, selected_index))
    food_selector.item_selected.connect(_on_food_selected)
    layer.add_child(food_selector)

    feed_button = Button.new()
    feed_button.name = "OfferFoodButton"
    feed_button.text = "OFFER FOOD"
    feed_button.add_theme_font_size_override("font_size", 20)
    feed_button.pressed.connect(_offer_food)
    layer.add_child(feed_button)

    toast_label = Label.new()
    toast_label.name = "PetToast"
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 17)
    toast_label.visible = false
    layer.add_child(toast_label)

    if is_instance_valid(settings_panel):
        about_button = Button.new()
        about_button.name = "AboutButton"
        about_button.text = "ABOUT"
        about_button.size = Vector2(105, 34)
        about_button.pressed.connect(_show_about)
        settings_panel.add_child(about_button)

    about_dialog = AcceptDialog.new()
    about_dialog.name = "AboutDialog"
    about_dialog.title = "About Hippo OS"
    about_dialog.dialog_text = _about_text()
    about_dialog.ok_button_text = "CLOSE"
    scene_root.add_child(about_dialog)

func _about_text():
    var version := str(ProjectSettings.get_setting("application/config/version", "0.2.0-personal"))
    return "Hippo OS  %s\n\nA personal offline-first pygmy hippo sanctuary.\n\nPrivacy\n• Companion state is stored locally on this device.\n• The personal Android build does not request Internet permission.\n• No account, analytics, advertising or cloud tracking is included.\n\nAudio\nImmersive cinematic 3D audio. No Dolby Atmos certification or Dolby branding is claimed.\n\nBuild target\nGodot 4.7.2 • Android 16 / API 36 • ARM64" % version

func _show_about():
    if is_instance_valid(about_dialog):
        about_dialog.dialog_text = _about_text()
        about_dialog.popup_centered(Vector2i(610, 430))

func _show_startup():
    if not is_instance_valid(scene_root):
        return
    startup_layer = CanvasLayer.new()
    startup_layer.name = "StartupExperience"
    startup_layer.layer = 100
    scene_root.add_child(startup_layer)

    var backdrop := ColorRect.new()
    backdrop.color = Color(0.008, 0.018, 0.022, 1.0)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    startup_layer.add_child(backdrop)

    var title := Label.new()
    title.text = "HIPPO OS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 44)
    title.set_anchors_preset(Control.PRESET_CENTER_TOP)
    title.position = Vector2(-260, 265)
    title.size = Vector2(520, 60)
    backdrop.add_child(title)

    var status := Label.new()
    status.text = "SANCTUARY ONLINE  •  COMPANION SAFE"
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 16)
    status.set_anchors_preset(Control.PRESET_CENTER_TOP)
    status.position = Vector2(-260, 330)
    status.size = Vector2(520, 40)
    backdrop.add_child(status)

    var tween := create_tween()
    tween.tween_interval(0.75)
    tween.tween_property(backdrop, "modulate:a", 0.0, 0.45)
    tween.tween_callback(startup_layer.queue_free)

func _layout_ui():
    if not is_instance_valid(scene_root):
        return
    var visible := get_viewport().get_visible_rect()
    var safe := _viewport_safe_rect(visible)
    var margin := 20.0
    var right := safe.position.x + safe.size.x
    var bottom := safe.position.y + safe.size.y

    if is_instance_valid(stats_panel):
        stats_panel.position = safe.position + Vector2(margin, margin)
        stats_panel.size.x = min(560.0, safe.size.x * 0.54)

    if is_instance_valid(settings_button):
        settings_button.position = Vector2(right - settings_button.size.x - margin, safe.position.y + margin)

    mute_button = scene_root.find_child("AudioMuteButton", true, false)
    if is_instance_valid(mute_button) and is_instance_valid(settings_button):
        mute_button.position = Vector2(settings_button.position.x - mute_button.size.x - 12.0, settings_button.position.y)

    if is_instance_valid(food_selector):
        food_selector.position = Vector2(safe.position.x + margin, bottom - 116.0)
        food_selector.size = Vector2(190, 40)
    if is_instance_valid(feed_button):
        feed_button.position = Vector2(safe.position.x + margin, bottom - 70.0 - margin)
        feed_button.size = Vector2(190, 70)

    if is_instance_valid(zoom_out_button):
        zoom_out_button.position = Vector2(right - zoom_out_button.size.x - margin, bottom - zoom_out_button.size.y - margin)
    if is_instance_valid(zoom_in_button) and is_instance_valid(zoom_out_button):
        zoom_in_button.position = Vector2(zoom_out_button.position.x - zoom_in_button.size.x - 12.0, zoom_out_button.position.y)

    if is_instance_valid(help_label):
        help_label.position = Vector2(safe.position.x + safe.size.x * 0.5 - 260.0, bottom - 46.0)
        help_label.size = Vector2(520, 32)
        help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    if is_instance_valid(settings_panel):
        settings_panel.position = Vector2(
            right - settings_panel.size.x - margin,
            safe.position.y + max(88.0, (safe.size.y - settings_panel.size.y) * 0.5)
        )
        if is_instance_valid(about_button):
            about_button.position = Vector2(settings_panel.size.x - 127.0, 13.0)

    if is_instance_valid(toast_label):
        toast_label.position = Vector2(safe.position.x + safe.size.x * 0.5 - 310.0, bottom - 120.0)
        toast_label.size = Vector2(620, 48)

func _viewport_safe_rect(visible: Rect2):
    var screen_size := Vector2(DisplayServer.screen_get_size())
    var system_safe := DisplayServer.get_display_safe_area()
    if screen_size.x <= 0.0 or screen_size.y <= 0.0 or system_safe.size.x <= 0:
        return visible

    var scale := Vector2(visible.size.x / screen_size.x, visible.size.y / screen_size.y)
    var safe_position := Vector2(system_safe.position) * scale
    var safe_size := Vector2(system_safe.size) * scale
    return Rect2(safe_position, safe_size)

func _on_food_selected(index):
    chosen_food = FOODS[clamp(int(index), 0, FOODS.size() - 1)]
    _save_preferences()

func _offer_food():
    if not is_instance_valid(scene_root):
        return
    _ensure_food_preferences()

    var hunger := float(scene_root.get("hunger"))
    var affection := float(scene_root.get("affection"))
    var bond := float(scene_root.get("bond"))
    var preference := float(food_preferences.get(chosen_food, 0.65))
    var willingness := clamp(hunger * 0.60 + preference * 0.28 + affection * 0.12, 0.0, 1.0)

    if hunger < 0.20:
        willingness *= 0.45
    if randf() > willingness:
        _show_toast("%s sniffs the %s and decides not to eat right now." % [str(scene_root.get("hippo_name")), chosen_food.to_lower()])
        _haptic(12)
        return

    scene_root.set("hunger", clamp(hunger - float(FOOD_SATIETY.get(chosen_food, 0.24)), 0.0, 1.0))
    scene_root.set("affection", clamp(affection + 0.012 + preference * 0.012, 0.0, 1.0))
    scene_root.set("bond", clamp(bond + 0.004 + preference * 0.004, 0.0, 1.0))

    var counts = scene_root.get("interaction_counts")
    if typeof(counts) == TYPE_DICTIONARY:
        counts["feed"] = int(counts.get("feed", 0)) + 1
        scene_root.set("interaction_counts", counts)

    scene_root.set("current_action", "approach")
    scene_root.set("action_timer", 3.0)
    if scene_root.has_method("_save_state"):
        scene_root.call("_save_state")
    _show_toast("%s happily eats the %s." % [str(scene_root.get("hippo_name")), chosen_food.to_lower()])
    _haptic(28)

func _show_toast(message: String):
    if not is_instance_valid(toast_label):
        return
    toast_label.text = message
    toast_label.visible = true
    toast_timer = 2.8

func _apply_time_aware_routine():
    if not is_instance_valid(scene_root):
        return
    var period := _routine_period()
    var action := str(scene_root.get("current_action"))
    var energy := float(scene_root.get("energy"))
    var hunger := float(scene_root.get("hunger"))

    if period == "day":
        # Pygmy hippos are generally more secretive/restful by day. Only nudge when the
        # core brain is already in a low-priority activity; never interrupt feeding/water.
        if (action == "idle" or action == "wander") and energy < 0.72 and hunger < 0.78 and randf() < 0.32:
            scene_root.set("current_action", "sleep")
            scene_root.set("wander_target", Vector3(-4.6, 0.8, -3.2))
            scene_root.set("action_timer", randf_range(7.0, 13.0))
    else:
        # Dusk/night is a better exploration window. A rested animal is gently encouraged
        # back into the sanctuary instead of sleeping indefinitely.
        if action == "sleep" and energy > 0.58 and randf() < 0.42:
            scene_root.set("current_action", "explore")
            scene_root.set("action_timer", randf_range(5.0, 9.0))
            if scene_root.has_method("_new_wander_target"):
                scene_root.call("_new_wander_target")
        elif action == "idle" and energy > 0.68 and randf() < 0.24:
            scene_root.set("current_action", "wander")
            scene_root.set("action_timer", randf_range(5.0, 9.0))
            if scene_root.has_method("_new_wander_target"):
                scene_root.call("_new_wander_target")

func _routine_period():
    var loaded_settings = scene_root.get("settings")
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        var mode := str(loaded_settings.get("day_night_mode", "auto"))
        if mode == "day" or mode == "night":
            return mode
    var hour := int(Time.get_time_dict_from_system().get("hour", 12))
    return "night" if hour >= 18 or hour < 6 else "day"

func _smooth_camera(delta):
    if not is_instance_valid(camera):
        camera = _find_camera(scene_root)
    if not is_instance_valid(camera):
        return

    var desired := camera.position
    var pivot := Vector3(0.0, 1.0, 0.0)
    var query := PhysicsRayQueryParameters3D.create(pivot, desired)
    query.collision_mask = 1
    if is_instance_valid(hippo):
        query.exclude = [hippo.get_rid()]
    var hit := scene_root.get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        desired = hit.position + hit.normal * 0.28

    if not camera_initialized:
        smoothed_camera_position = desired
        camera_initialized = true
    else:
        var loaded_settings = scene_root.get("settings")
        var reduced_motion := false
        if typeof(loaded_settings) == TYPE_DICTIONARY:
            reduced_motion = bool(loaded_settings.get("reduced_motion", false))
        var speed := 20.0 if reduced_motion else 10.0
        var alpha := 1.0 - exp(-speed * delta)
        smoothed_camera_position = smoothed_camera_position.lerp(desired, alpha)

    camera.position = smoothed_camera_position
    camera.look_at(pivot, Vector3.UP)

func _ensure_food_preferences():
    if not food_preferences.is_empty():
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = 4815162342
    for food in FOODS:
        food_preferences[food] = rng.randf_range(0.42, 0.96)
    # Ensure every companion has one clearly preferred option and one less exciting one.
    food_preferences[FOODS[0]] = max(float(food_preferences[FOODS[0]]), 0.78)
    food_preferences[FOODS[3]] = min(float(food_preferences[FOODS[3]]), 0.64)
    _save_preferences()

func _save_preferences():
    var file := FileAccess.open(PREF_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({
            "chosen_food": chosen_food,
            "food_preferences": food_preferences
        }))

func _load_preferences():
    if not FileAccess.file_exists(PREF_PATH):
        return
    var file := FileAccess.open(PREF_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    chosen_food = str(parsed.get("chosen_food", chosen_food))
    var loaded = parsed.get("food_preferences", {})
    if typeof(loaded) == TYPE_DICTIONARY:
        food_preferences = loaded

func _haptic(duration_ms: int):
    var loaded_settings = scene_root.get("settings") if is_instance_valid(scene_root) else {}
    if typeof(loaded_settings) == TYPE_DICTIONARY and bool(loaded_settings.get("haptics", true)):
        Input.vibrate_handheld(duration_ms)
