extends Node

# Small always-available audio safety control. The main settings keep the detailed
# Master / Animal / Ambience / UI mix, while this provides a one-tap global mute.

const PREF_PATH = "user://hippo_audio_prefs.json"

var muted := false
var bound_scene
var mute_button: Button

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_preferences()
    _apply_mute_state()

func _process(_delta):
    var scene = get_tree().current_scene
    if not scene or scene == bound_scene:
        return
    bound_scene = scene
    call_deferred("_attach_control")

func _attach_control():
    if not is_instance_valid(bound_scene):
        return

    var existing = bound_scene.find_child("AudioMuteButton", true, false)
    if existing is Button:
        mute_button = existing
        _refresh_button()
        return

    var layer = CanvasLayer.new()
    layer.name = "AudioQuickControl"
    layer.layer = 20
    bound_scene.add_child(layer)

    mute_button = Button.new()
    mute_button.name = "AudioMuteButton"
    mute_button.text = "MUTED" if muted else "SOUND"
    mute_button.position = Vector2(968, 20)
    mute_button.size = Vector2(96, 58)
    mute_button.toggle_mode = true
    mute_button.add_theme_font_size_override("font_size", 16)
    mute_button.tooltip_text = "Mute or restore all Hippo OS audio"
    mute_button.pressed.connect(_toggle_mute)
    layer.add_child(mute_button)
    _refresh_button()

func _toggle_mute():
    muted = not muted
    _apply_mute_state()
    _save_preferences()
    _refresh_button()
    _haptic_feedback()

func _apply_mute_state():
    var master_index = AudioServer.get_bus_index("Master")
    if master_index >= 0:
        AudioServer.set_bus_mute(master_index, muted)

func _refresh_button():
    if not is_instance_valid(mute_button):
        return
    mute_button.text = "MUTED" if muted else "SOUND"
    mute_button.button_pressed = muted

func _haptic_feedback():
    if not is_instance_valid(bound_scene):
        return
    var settings = bound_scene.get("settings")
    if typeof(settings) == TYPE_DICTIONARY and bool(settings.get("haptics", true)):
        Input.vibrate_handheld(18)

func _save_preferences():
    var file = FileAccess.open(PREF_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({"muted": muted}))

func _load_preferences():
    if not FileAccess.file_exists(PREF_PATH):
        return
    var file = FileAccess.open(PREF_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        muted = bool(parsed.get("muted", false))
