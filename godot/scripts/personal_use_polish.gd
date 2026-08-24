extends Node

# Personal-use Android polish: responsive safe-area UI, feeding preferences,
# startup/About UX, time-aware routines and camera smoothing.

const PREF_PATH: String = "user://hippo_personal_prefs.json"
const FOODS: Array[String] = ["Leafy greens", "Cucumber", "Pumpkin", "Melon"]
const FOOD_SATIETY: Dictionary = {
    "Leafy greens": 0.24,
    "Cucumber": 0.20,
    "Pumpkin": 0.29,
    "Melon": 0.26
}

var scene_root: Node = null
var hippo: CharacterBody3D = null
var camera: Camera3D = null
var stats_panel: Control = null
var settings_panel: Control = null
var settings_button: Button = null
var mute_button: Button = null
var original_feed_button: Button = null
var feed_button: Button = null
var food_selector: OptionButton = null
var zoom_in_button: Button = null
var zoom_out_button: Button = null
var help_label: Label = null
var about_button: Button = null
var about_dialog: AcceptDialog = null
var toast_label: Label = null
var startup_layer: CanvasLayer = null

var food_preferences: Dictionary = {}
var chosen_food: String = "Leafy greens"
var layout_timer: float = 0.0
var routine_timer: float = 8.0
var toast_timer: float = 0.0
var last_viewport_size: Vector2 = Vector2.ZERO
var smoothed_camera_position: Vector3 = Vector3.ZERO
var camera_initialized: bool = false
var startup_shown: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 100
    _load_preferences()
    _ensure_food_preferences()

func _process(delta: float) -> void:
    _ensure_scene_binding()
    if not is_instance_valid(scene_root):
        return
    layout_timer -= delta
    routine_timer -= delta
    toast_timer = maxf(0.0, toast_timer - delta)

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
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

func _ensure_scene_binding() -> void:
    var current_scene: Node = get_tree().current_scene
    if current_scene == null:
        return
    if scene_root == current_scene and is_instance_valid(hippo):
        if not is_instance_valid(mute_button):
            mute_button = current_scene.find_child("AudioMuteButton", true, false) as Button
        return

    scene_root = current_scene
    hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
    if hippo == null:
        return
    camera = _find_camera(scene_root)
    stats_panel = scene_root.get("stats_panel") as Control
    settings_panel = scene_root.get("settings_panel") as Control
    _discover_existing_ui()
    _build_personal_ui()
    camera_initialized = false
    call_deferred("_layout_ui")
    if not startup_shown:
        startup_shown = true
        call_deferred("_show_startup")

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child: Node in node.get_children():
        var found: Camera3D = _find_camera(child)
        if found != null:
            return found
    return null

func _discover_existing_ui() -> void:
    settings_button = null
    original_feed_button = null
    zoom_in_button = null
    zoom_out_button = null
    help_label = null
    var controls: Array[Node] = scene_root.find_children("*", "Control", true, false)
    for control: Node in controls:
        if control is Button:
            var button: Button = control as Button
            match button.text:
                "SETTINGS": settings_button = button
                "FEED": original_feed_button = button
                "+": zoom_in_button = button
                "-": zoom_out_button = button
        elif control is Label:
            var label: Label = control as Label
            if str(label.text).begins_with("Pet by dragging"):
                help_label = label
    if is_instance_valid(original_feed_button):
        original_feed_button.visible = false
    mute_button = scene_root.find_child("AudioMuteButton", true, false) as Button

func _build_personal_ui() -> void:
    var existing: Node = scene_root.find_child("PersonalUseUI", true, false)
    if is_instance_valid(existing):
        existing.queue_free()

    var layer: CanvasLayer = CanvasLayer.new()
    layer.name = "PersonalUseUI"
    layer.layer = 19
    scene_root.add_child(layer)

    food_selector = OptionButton.new()
    food_selector.name = "FoodSelector"
    for food: String in FOODS:
        food_selector.add_item(food)
    var selected_index: int = FOODS.find(chosen_food)
    food_selector.select(maxi(0, selected_index))
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

func _about_text() -> String:
    var version: String = str(ProjectSettings.get_setting("application/config/version", "0.2.1-personal"))
    return "Hippo OS  %s\n\nA personal offline-first pygmy hippo sanctuary.\n\nPrivacy\n• Companion state is stored locally on this device.\n• The personal Android build does not request Internet permission.\n• No account, analytics, advertising or cloud tracking is included.\n\nAudio\nImmersive cinematic 3D audio. No Dolby Atmos certification or Dolby branding is claimed.\n\nBuild target\nGodot 4.7.2 • Android 16 / API 36 • ARM64" % version

func _show_about() -> void:
    if is_instance_valid(about_dialog):
        about_dialog.dialog_text = _about_text()
        about_dialog.popup_centered(Vector2i(610, 430))

func _show_startup() -> void:
    if not is_instance_valid(scene_root):
        return
    startup_layer = CanvasLayer.new()
    startup_layer.name = "StartupExperience"
    startup_layer.layer = 100
    scene_root.add_child(startup_layer)
    var backdrop: ColorRect = ColorRect.new()
    backdrop.color = Color(0.008, 0.018, 0.022, 1.0)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    startup_layer.add_child(backdrop)

    var title: Label = Label.new()
    title.text = "HIPPO OS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 44)
    title.set_anchors_preset(Control.PRESET_CENTER_TOP)
    title.position = Vector2(-260, 265)
    title.size = Vector2(520, 60)
    backdrop.add_child(title)

    var status: Label = Label.new()
    status.text = "SANCTUARY ONLINE  •  COMPANION SAFE"
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 16)
    status.set_anchors_preset(Control.PRESET_CENTER_TOP)
    status.position = Vector2(-260, 330)
    status.size = Vector2(520, 40)
    backdrop.add_child(status)

    var tween: Tween = create_tween()
    tween.tween_interval(0.75)
    tween.tween_property(backdrop, "modulate:a", 0.0, 0.45)
    tween.tween_callback(startup_layer.queue_free)

func _layout_ui() -> void:
    if not is_instance_valid(scene_root):
        return
    var visible: Rect2 = get_viewport().get_visible_rect()
    var safe: Rect2 = _viewport_safe_rect(visible)
    var margin: float = 20.0
    var right: float = safe.position.x + safe.size.x
    var bottom: float = safe.position.y + safe.size.y

    if is_instance_valid(stats_panel):
        stats_panel.position = safe.position + Vector2(margin, margin)
        stats_panel.size.x = minf(560.0, safe.size.x * 0.54)
    if is_instance_valid(settings_button):
        settings_button.position = Vector2(right - settings_button.size.x - margin, safe.position.y + margin)
    mute_button = scene_root.find_child("AudioMuteButton", true, false) as Button
    if is_instance_valid(mute_button) and is_instance_valid(settings_button):
        mute_button.position = Vector2(settings_button.position.x - mute_button.size.x - 12.0, settings_button.position.y)
    if is_instance_valid(food_selector):
        food_selector.position = Vector2(safe.position.x + margin, bottom - 116.0)
        food_selector.size = Vector2(190, 40)
    if is_instance_valid(feed_button):
        feed_button.position = Vector2(safe.position.x + margin, bottom - 90.0)
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
        settings_panel.position = Vector2(right - settings_panel.size.x - margin, safe.position.y + maxf(88.0, (safe.size.y - settings_panel.size.y) * 0.5))
        if is_instance_valid(about_button):
            about_button.position = Vector2(settings_panel.size.x - 127.0, 13.0)
    if is_instance_valid(toast_label):
        toast_label.position = Vector2(safe.position.x + safe.size.x * 0.5 - 310.0, bottom - 120.0)
        toast_label.size = Vector2(620, 48)

func _viewport_safe_rect(visible: Rect2) -> Rect2:
    var screen_size: Vector2i = DisplayServer.screen_get_size()
    var system_safe: Rect2i = DisplayServer.get_display_safe_area()
    if screen_size.x <= 0 or screen_size.y <= 0 or system_safe.size.x <= 0 or system_safe.size.y <= 0:
        return visible
    var scale: Vector2 = Vector2(visible.size.x / float(screen_size.x), visible.size.y / float(screen_size.y))
    var safe_position: Vector2 = Vector2(system_safe.position) * scale
    var safe_size: Vector2 = Vector2(system_safe.size) * scale
    return Rect2(safe_position, safe_size)

func _on_food_selected(index: int) -> void:
    chosen_food = FOODS[clampi(index, 0, FOODS.size() - 1)]
    _save_preferences()

func _offer_food() -> void:
    if not is_instance_valid(scene_root):
        return
    _ensure_food_preferences()
    var hunger: float = float(scene_root.get("hunger"))
    var affection: float = float(scene_root.get("affection"))
    var bond: float = float(scene_root.get("bond"))
    var preference: float = float(food_preferences.get(chosen_food, 0.65))
    var willingness: float = clampf(hunger * 0.60 + preference * 0.28 + affection * 0.12, 0.0, 1.0)
    if hunger < 0.20:
        willingness *= 0.45
    if randf() > willingness:
        _show_toast("%s sniffs the %s and decides not to eat right now." % [str(scene_root.get("hippo_name")), chosen_food.to_lower()])
        _haptic(12)
        return

    scene_root.set("hunger", clampf(hunger - float(FOOD_SATIETY.get(chosen_food, 0.24)), 0.0, 1.0))
    scene_root.set("affection", clampf(affection + 0.012 + preference * 0.012, 0.0, 1.0))
    scene_root.set("bond", clampf(bond + 0.004 + preference * 0.004, 0.0, 1.0))
    var counts_variant: Variant = scene_root.get("interaction_counts")
    if typeof(counts_variant) == TYPE_DICTIONARY:
        var counts: Dictionary = counts_variant as Dictionary
        counts["feed"] = int(counts.get("feed", 0)) + 1
        scene_root.set("interaction_counts", counts)
    scene_root.set("current_action", "approach")
    scene_root.set("action_timer", 3.0)
    if scene_root.has_method("_save_state"):
        scene_root.call("_save_state")
    _show_toast("%s happily eats the %s." % [str(scene_root.get("hippo_name")), chosen_food.to_lower()])
    _haptic(28)

func _show_toast(message: String) -> void:
    if not is_instance_valid(toast_label):
        return
    toast_label.text = message
    toast_label.visible = true
    toast_timer = 2.8

func _apply_time_aware_routine() -> void:
    if not is_instance_valid(scene_root):
        return
    var period: String = _routine_period()
    var action: String = str(scene_root.get("current_action"))
    var energy: float = float(scene_root.get("energy"))
    var hunger: float = float(scene_root.get("hunger"))
    if period == "day":
        if (action == "idle" or action == "wander") and energy < 0.72 and hunger < 0.78 and randf() < 0.32:
            scene_root.set("current_action", "sleep")
            scene_root.set("wander_target", Vector3(-4.6, 0.8, -3.2))
            scene_root.set("action_timer", randf_range(7.0, 13.0))
    else:
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

func _routine_period() -> String:
    var loaded_settings: Variant = scene_root.get("settings")
    if typeof(loaded_settings) == TYPE_DICTIONARY:
        var mode: String = str((loaded_settings as Dictionary).get("day_night_mode", "auto"))
        if mode == "day" or mode == "night":
            return mode
    var hour: int = int(Time.get_time_dict_from_system().get("hour", 12))
    return "night" if hour >= 18 or hour < 6 else "day"

func _smooth_camera(delta: float) -> void:
    if not is_instance_valid(camera):
        camera = _find_camera(scene_root)
    if not is_instance_valid(camera):
        return
    var desired: Vector3 = camera.position
    var pivot: Vector3 = Vector3(0.0, 1.0, 0.0)
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pivot, desired)
    query.collision_mask = 1
    if is_instance_valid(hippo):
        query.exclude = [hippo.get_rid()]
    var hit: Dictionary = scene_root.get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        desired = Vector3(hit.get("position", desired)) + Vector3(hit.get("normal", Vector3.ZERO)) * 0.28

    if not camera_initialized:
        smoothed_camera_position = desired
        camera_initialized = true
    else:
        var loaded_settings: Variant = scene_root.get("settings")
        var reduced_motion: bool = false
        if typeof(loaded_settings) == TYPE_DICTIONARY:
            reduced_motion = bool((loaded_settings as Dictionary).get("reduced_motion", false))
        var speed: float = 20.0 if reduced_motion else 10.0
        var alpha: float = 1.0 - exp(-speed * delta)
        smoothed_camera_position = smoothed_camera_position.lerp(desired, alpha)
    camera.position = smoothed_camera_position
    camera.look_at(pivot, Vector3.UP)

func _ensure_food_preferences() -> void:
    if not food_preferences.is_empty():
        return
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 4815162342
    for food: String in FOODS:
        food_preferences[food] = rng.randf_range(0.42, 0.96)
    food_preferences[FOODS[0]] = maxf(float(food_preferences[FOODS[0]]), 0.78)
    food_preferences[FOODS[3]] = minf(float(food_preferences[FOODS[3]]), 0.64)
    _save_preferences()

func _save_preferences() -> void:
    var file: FileAccess = FileAccess.open(PREF_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"chosen_food": chosen_food, "food_preferences": food_preferences}))

func _load_preferences() -> void:
    if not FileAccess.file_exists(PREF_PATH):
        return
    var file: FileAccess = FileAccess.open(PREF_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed as Dictionary
    chosen_food = str(data.get("chosen_food", chosen_food))
    var loaded: Variant = data.get("food_preferences", {})
    if typeof(loaded) == TYPE_DICTIONARY:
        food_preferences = loaded as Dictionary

func _haptic(duration_ms: int) -> void:
    var loaded_settings: Variant = scene_root.get("settings") if is_instance_valid(scene_root) else {}
    if typeof(loaded_settings) == TYPE_DICTIONARY and bool((loaded_settings as Dictionary).get("haptics", true)):
        Input.vibrate_handheld(duration_ms)
