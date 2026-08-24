extends Node

# Android boot fail-safe. PersonalUsePolish owns the cinematic startup overlay, but
# this independent always-processing watchdog guarantees that a stalled Tween can
# never trap the user behind StartupExperience while the sanctuary is already alive.

const MAX_STARTUP_SECONDS := 2.0

var elapsed := 0.0
var dismissed := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 1000
    set_process(true)
    set_process_unhandled_input(true)

func _process(delta: float) -> void:
    if dismissed:
        return
    elapsed += delta
    if elapsed >= MAX_STARTUP_SECONDS:
        _dismiss_startup()

func _unhandled_input(event: InputEvent) -> void:
    if dismissed:
        return
    if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
        _dismiss_startup()
    elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
        _dismiss_startup()

func _dismiss_startup() -> void:
    var current := get_tree().current_scene
    if current == null:
        return

    var overlay := current.find_child("StartupExperience", true, false)
    if is_instance_valid(overlay):
        overlay.queue_free()

    dismissed = true
    set_process(false)
    set_process_unhandled_input(false)
