extends Node

# On-device acceptance helper. It verifies facts software can test automatically and
# clearly separates them from speaker/headphone/visual checks that still require a human.

const TEMP_PATH := "user://hippo_device_selftest.tmp"

var scene_root
var settings_panel
var diagnostics_button
var diagnostics_dialog
var fps_samples := []
var sample_timer := 0.0

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 110

func _process(delta):
    _ensure_binding()
    sample_timer -= delta
    if sample_timer <= 0.0:
        sample_timer = 0.5
        var fps := float(Performance.get_monitor(Performance.TIME_FPS))
        if fps > 0.0:
            fps_samples.append(fps)
            if fps_samples.size() > 20:
                fps_samples.pop_front()

func _ensure_binding():
    var current_scene := get_tree().current_scene
    if not current_scene:
        return
    if scene_root == current_scene and is_instance_valid(diagnostics_button):
        return

    scene_root = current_scene
    settings_panel = scene_root.get("settings_panel")
    if not is_instance_valid(settings_panel):
        return

    diagnostics_button = Button.new()
    diagnostics_button.name = "DeviceDiagnosticsButton"
    diagnostics_button.text = "DEVICE CHECK"
    diagnostics_button.position = Vector2(285, 13)
    diagnostics_button.size = Vector2(120, 34)
    diagnostics_button.pressed.connect(_show_diagnostics)
    settings_panel.add_child(diagnostics_button)

    diagnostics_dialog = AcceptDialog.new()
    diagnostics_dialog.name = "DeviceDiagnosticsDialog"
    diagnostics_dialog.title = "Hippo OS Device Check"
    diagnostics_dialog.ok_button_text = "CLOSE"
    scene_root.add_child(diagnostics_dialog)

func _show_diagnostics():
    if not is_instance_valid(diagnostics_dialog):
        return
    diagnostics_dialog.dialog_text = _build_report()
    diagnostics_dialog.popup_centered(Vector2i(720, 560))

func _build_report():
    var lines := PackedStringArray()
    var auto_passes := 0
    var auto_total := 0

    var storage_ok := _storage_roundtrip()
    auto_total += 1
    auto_passes += 1 if storage_ok else 0
    lines.append(_result(storage_ok, "Local save storage is writable"))

    var package_ok := str(ProjectSettings.get_setting("application/config/name", "")) == "Hippo OS"
    auto_total += 1
    auto_passes += 1 if package_ok else 0
    lines.append(_result(package_ok, "Hippo OS project identity loaded"))

    var audio_ok := _audio_buses_ready()
    auto_total += 1
    auto_passes += 1 if audio_ok else 0
    lines.append(_result(audio_ok, "Master/Animal/Foley/Ambience/UI audio buses ready"))

    var systems_ok := _required_systems_ready()
    auto_total += 1
    auto_passes += 1 if systems_ok else 0
    lines.append(_result(systems_ok, "Core launch autoload systems are active"))

    var hippo_ok := is_instance_valid(scene_root.find_child("BabyHippo", true, false))
    auto_total += 1
    auto_passes += 1 if hippo_ok else 0
    lines.append(_result(hippo_ok, "Living-pet scene is present"))

    var safe_ok := _safe_area_sane()
    auto_total += 1
    auto_passes += 1 if safe_ok else 0
    lines.append(_result(safe_ok, "Display safe area is valid"))

    var fps := _average_fps()
    var fps_ok := fps <= 0.0 or fps >= 30.0
    auto_total += 1
    auto_passes += 1 if fps_ok else 0
    lines.append(_result(fps_ok, "Recent frame rate: %.1f FPS" % fps if fps > 0.0 else "Frame-rate sample warming up"))

    var viewport := get_viewport().get_visible_rect().size
    var screen := DisplayServer.screen_get_size()
    var renderer := str(RenderingServer.get_current_rendering_method())
    var version := str(ProjectSettings.get_setting("application/config/version", "unknown"))

    var header := "AUTOMATED CHECKS  %d/%d PASS\nVersion %s\nOS %s • Renderer %s\nViewport %dx%d • Screen %dx%d\n\n" % [
        auto_passes,
        auto_total,
        version,
        OS.get_name(),
        renderer,
        int(viewport.x), int(viewport.y),
        int(screen.x), int(screen.y)
    ]

    var manual := "\n\nMANUAL PHONE CHECKS STILL REQUIRED\n[ ] Speaker audio is clear\n[ ] Bluetooth/headphone spatial mix is clear\n[ ] Icon looks correct on launcher\n[ ] No UI is hidden by camera cutout/system edges\n[ ] Petting and food interactions feel responsive\n[ ] Water/mud VFX look correct\n[ ] Background/resume preserves state\n[ ] Restart/offline progression behaves correctly\n[ ] Visual performance remains comfortable during normal use"

    return header + "\n".join(lines) + manual

func _storage_roundtrip():
    var token := "%s-%d" % [str(Time.get_unix_time_from_system()), randi()]
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if not file:
        return false
    file.store_string(token)
    file = null
    var read := FileAccess.open(TEMP_PATH, FileAccess.READ)
    if not read:
        return false
    var ok := read.get_as_text() == token
    read = null
    if FileAccess.file_exists(TEMP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
    return ok

func _audio_buses_ready():
    for bus_name in ["Master", "Animal", "Foley", "Ambience", "UI"]:
        if AudioServer.get_bus_index(bus_name) < 0:
            return false
    return true

func _required_systems_ready():
    for path in [
        "/root/SaveMigrator",
        "/root/AudioDirector",
        "/root/AudioControls",
        "/root/BioAcoustics",
        "/root/AdaptiveSoundscape",
        "/root/VisualSanctuaryPolish",
        "/root/CharacterMotionPolish",
        "/root/AtmospherePolish",
        "/root/PersonalUsePolish"
    ]:
        if not get_node_or_null(path):
            return false
    return true

func _safe_area_sane():
    var screen := DisplayServer.screen_get_size()
    var safe := DisplayServer.get_display_safe_area()
    if screen.x <= 0 or screen.y <= 0:
        return true
    if safe.size.x <= 0 or safe.size.y <= 0:
        return true
    return safe.position.x >= 0 and safe.position.y >= 0 and safe.end.x <= screen.x and safe.end.y <= screen.y

func _average_fps():
    if fps_samples.is_empty():
        return 0.0
    var total := 0.0
    for value in fps_samples:
        total += float(value)
    return total / float(fps_samples.size())

func _result(ok: bool, text: String):
    return ("PASS  " if ok else "FAIL  ") + text
