extends Node

# On-device acceptance helper. Automated checks remain separate from manual listening/visual checks.

const TEMP_PATH: String = "user://hippo_device_selftest.tmp"

var scene_root: Node = null
var settings_panel: Control = null
var diagnostics_button: Button = null
var diagnostics_dialog: AcceptDialog = null
var fps_samples: Array[float] = []
var sample_timer: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 110

func _process(delta: float) -> void:
    _ensure_binding()
    sample_timer -= delta
    if sample_timer <= 0.0:
        sample_timer = 0.5
        var fps: float = float(Performance.get_monitor(Performance.TIME_FPS))
        if fps > 0.0:
            fps_samples.append(fps)
            if fps_samples.size() > 20:
                fps_samples.pop_front()

func _ensure_binding() -> void:
    var current_scene: Node = get_tree().current_scene
    if current_scene == null:
        return
    if scene_root == current_scene and is_instance_valid(diagnostics_button):
        return
    scene_root = current_scene
    settings_panel = scene_root.get("settings_panel") as Control
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

func _show_diagnostics() -> void:
    if not is_instance_valid(diagnostics_dialog):
        return
    diagnostics_dialog.dialog_text = _build_report()
    diagnostics_dialog.popup_centered(Vector2i(720, 560))

func _build_report() -> String:
    var lines: PackedStringArray = PackedStringArray()
    var auto_passes: int = 0
    var auto_total: int = 0

    var storage_ok: bool = _storage_roundtrip()
    auto_total += 1
    auto_passes += 1 if storage_ok else 0
    lines.append(_result(storage_ok, "Local save storage is writable"))

    var package_ok: bool = str(ProjectSettings.get_setting("application/config/name", "")) == "Hippo OS"
    auto_total += 1
    auto_passes += 1 if package_ok else 0
    lines.append(_result(package_ok, "Hippo OS project identity loaded"))

    var audio_ok: bool = _audio_buses_ready()
    auto_total += 1
    auto_passes += 1 if audio_ok else 0
    lines.append(_result(audio_ok, "Master/Animal/Foley/Ambience/UI audio buses ready"))

    var systems_ok: bool = _required_systems_ready()
    auto_total += 1
    auto_passes += 1 if systems_ok else 0
    lines.append(_result(systems_ok, "Core launch autoload systems are active"))

    var hippo_ok: bool = is_instance_valid(scene_root.find_child("BabyHippo", true, false))
    auto_total += 1
    auto_passes += 1 if hippo_ok else 0
    lines.append(_result(hippo_ok, "Living-pet scene is present"))

    var safe_ok: bool = _safe_area_sane()
    auto_total += 1
    auto_passes += 1 if safe_ok else 0
    lines.append(_result(safe_ok, "Display safe area is valid"))

    var fps: float = _average_fps()
    var fps_ok: bool = fps <= 0.0 or fps >= 30.0
    auto_total += 1
    auto_passes += 1 if fps_ok else 0
    var fps_text: String = "Recent frame rate: %.1f FPS" % fps if fps > 0.0 else "Frame-rate sample warming up"
    lines.append(_result(fps_ok, fps_text))

    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var screen: Vector2i = DisplayServer.screen_get_size()
    var renderer: String = str(RenderingServer.get_current_rendering_method())
    var version: String = str(ProjectSettings.get_setting("application/config/version", "unknown"))
    var header: String = "AUTOMATED CHECKS  %d/%d PASS\nVersion %s\nOS %s • Renderer %s\nViewport %dx%d • Screen %dx%d\n\n" % [auto_passes, auto_total, version, OS.get_name(), renderer, int(viewport.x), int(viewport.y), screen.x, screen.y]
    var manual: String = "\n\nMANUAL PHONE CHECKS STILL REQUIRED\n[ ] Speaker audio is clear\n[ ] Bluetooth/headphone spatial mix is clear\n[ ] Icon looks correct on launcher\n[ ] No UI is hidden by camera cutout/system edges\n[ ] Petting and food interactions feel responsive\n[ ] Water/mud VFX look correct\n[ ] Background/resume preserves state\n[ ] Restart/offline progression behaves correctly\n[ ] Visual performance remains comfortable during normal use"
    return header + "\n".join(lines) + manual

func _storage_roundtrip() -> bool:
    var token: String = "%s-%d" % [str(Time.get_unix_time_from_system()), randi()]
    var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(token)
    file = null
    var read: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.READ)
    if read == null:
        return false
    var ok: bool = read.get_as_text() == token
    read = null
    if FileAccess.file_exists(TEMP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
    return ok

func _audio_buses_ready() -> bool:
    for bus_name: String in ["Master", "Animal", "Foley", "Ambience", "UI"]:
        if AudioServer.get_bus_index(bus_name) < 0:
            return false
    return true

func _required_systems_ready() -> bool:
    # Keep this list intentionally small and authoritative. Diagnostics used to require
    # retired visual hotfix autoloads, causing a false failure even when the consolidated
    # production runtime was healthy.
    var paths: Array[String] = [
        "/root/SaveMigrator",
        "/root/AudioDirector",
        "/root/CompanionRoster",
        "/root/GameplayDirector",
        "/root/ProductionAssetLoader",
        "/root/GrasslandsSanctuary",
        "/root/SanctuaryHUD",
        "/root/HeroCameraDirector",
        "/root/FinalPresentationDirector"
    ]
    for path: String in paths:
        if get_node_or_null(path) == null:
            return false
    return true

func _safe_area_sane() -> bool:
    var screen: Vector2i = DisplayServer.screen_get_size()
    var safe: Rect2i = DisplayServer.get_display_safe_area()
    if screen.x <= 0 or screen.y <= 0:
        return true
    if safe.size.x <= 0 or safe.size.y <= 0:
        return true
    return safe.position.x >= 0 and safe.position.y >= 0 and safe.end.x <= screen.x and safe.end.y <= screen.y

func _average_fps() -> float:
    if fps_samples.is_empty():
        return 0.0
    var total: float = 0.0
    for value: float in fps_samples:
        total += value
    return total / float(fps_samples.size())

func _result(ok: bool, text: String) -> String:
    return ("PASS  " if ok else "FAIL  ") + text
