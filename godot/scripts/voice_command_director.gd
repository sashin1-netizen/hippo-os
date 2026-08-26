extends Node

# Voice-command bridge for Hippo OS.
# Recognition is intentionally provider-agnostic: Android/native STT or a future
# on-device recognizer can submit final transcript text here. Gameplay remains
# fully functional without network access or an AI service.

signal command_recognized(command: String, target: String, transcript: String)
signal command_rejected(transcript: String)

const TARGET_ALIASES := {
    "mochi": "BabyHippo",
    "hippo": "BabyHippo",
    "porky": "Pig",
    "pig": "Pig",
    "bao": "Dog",
    "dog": "Dog"
}

const COMMAND_ALIASES := {
    "come": ["come", "come here", "come to me", "follow me"],
    "stay": ["stay", "wait", "stop there"],
    "eat": ["eat", "food", "have some food", "feed"],
    "drink": ["drink", "water", "go drink"],
    "sleep": ["sleep", "rest", "go to sleep"],
    "play": ["play", "let's play", "lets play"],
    "explore": ["explore", "go explore", "wander"],
    "mud": ["mud", "go to the mud", "mud bath"],
    "swim": ["swim", "go swim", "water time"]
}

var enabled := true
var last_transcript := ""
var last_command := ""
var last_target := ""

func submit_transcript(transcript: String) -> bool:
    if not enabled:
        return false
    var clean := transcript.strip_edges().to_lower()
    if clean.is_empty():
        return false
    last_transcript = clean
    var target := _find_target(clean)
    var command := _find_command(clean)
    if command.is_empty():
        command_rejected.emit(clean)
        return false
    last_command = command
    last_target = target
    _dispatch(command, target)
    command_recognized.emit(command, target, clean)
    return true

func _find_target(text: String) -> String:
    for alias in TARGET_ALIASES:
        if _contains_phrase(text, alias):
            return str(TARGET_ALIASES[alias])
    return "BabyHippo"

func _find_command(text: String) -> String:
    for command in COMMAND_ALIASES:
        for phrase in COMMAND_ALIASES[command]:
            if _contains_phrase(text, str(phrase)):
                return str(command)
    return ""

func _contains_phrase(text: String, phrase: String) -> bool:
    if text == phrase:
        return true
    return (" " + text + " ").contains(" " + phrase + " ")

func _dispatch(command: String, target: String) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var animal := scene.find_child(target, true, false)
    if animal != null:
        animal.set_meta("voice_command", command)
        animal.set_meta("voice_command_time_msec", Time.get_ticks_msec())
    # Existing gameplay directors can consume this without a hard dependency.
    scene.set_meta("voice_command", command)
    scene.set_meta("voice_target", target)
    scene.set_meta("voice_command_time_msec", Time.get_ticks_msec())
    if scene.get("current_action") != null and target == "BabyHippo":
        var action := _legacy_action(command)
        if not action.is_empty():
            scene.set("current_action", action)
            if scene.get("action_timer") != null:
                scene.set("action_timer", 4.0)

func _legacy_action(command: String) -> String:
    match command:
        "eat": return "eat"
        "drink", "swim": return "water"
        "mud": return "mud"
        "sleep": return "rest"
        "play": return "play"
        "explore", "come": return "walk"
        "stay": return "idle"
    return ""
