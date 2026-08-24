extends Node

# Hippo OS gameplay director.
# Coordinates the existing autonomous creature brains into one low-cost sanctuary
# simulation without taking ownership away from main.gd or CompanionRoster.
# It provides world time/mood, ambient life beats, social encounters, interaction
# recognition and production-animation-friendly action changes at a mobile-safe cadence.

signal world_state_changed(state: Dictionary)
signal sanctuary_event(event: Dictionary)

const TICK_INTERVAL := 0.25
const AMBIENT_EVENT_MIN := 18.0
const AMBIENT_EVENT_MAX := 38.0
const SOCIAL_DISTANCE := 2.35
const HIPPO := "hippo"
const PIG := "pig"
const SHARPEI := "sharpei"

var scene_root: Node3D
var roster: Node
var tick_accumulator := 0.0
var session_seconds := 0.0
var ambient_event_timer := 24.0
var event_serial := 0
var last_snapshot: Dictionary = {}
var current_world_state: Dictionary = {}
var recent_events: Array[Dictionary] = []

func _ready() -> void:
    randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 210
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            var companions_variant: Variant = roster_candidate.get("companions")
            if typeof(companions_variant) == TYPE_DICTIONARY:
                var companions := companions_variant as Dictionary
                if companions.has(PIG) and companions.has(SHARPEI) and candidate.find_child("BabyHippo", true, false) != null:
                    scene_root = candidate as Node3D
                    roster = roster_candidate
                    break
        await get_tree().process_frame

    if scene_root == null or roster == null:
        push_warning("GameplayDirector could not bind to the live sanctuary")
        return

    last_snapshot = _collect_snapshot()
    current_world_state = _build_world_state()
    scene_root.set_meta("hippo_os_world_state", current_world_state.duplicate(true))
    ambient_event_timer = randf_range(AMBIENT_EVENT_MIN, AMBIENT_EVENT_MAX)
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null or not is_instance_valid(scene_root):
        return

    session_seconds += delta
    tick_accumulator += delta
    ambient_event_timer -= delta

    if tick_accumulator < TICK_INTERVAL:
        return

    var step := tick_accumulator
    tick_accumulator = 0.0
    _simulation_tick(step)

func _simulation_tick(_delta: float) -> void:
    var next_state := _build_world_state()
    if _world_state_changed(next_state):
        current_world_state = next_state
        scene_root.set_meta("hippo_os_world_state", current_world_state.duplicate(true))
        world_state_changed.emit(current_world_state.duplicate(true))
    else:
        current_world_state = next_state
        scene_root.set_meta("hippo_os_world_state", current_world_state.duplicate(true))

    var snapshot := _collect_snapshot()
    _recognize_player_interactions(snapshot)
    _recognize_action_changes(snapshot)
    _recognize_social_encounters(snapshot)
    _enforce_welfare_priorities(snapshot)

    if ambient_event_timer <= 0.0:
        ambient_event_timer = randf_range(AMBIENT_EVENT_MIN, AMBIENT_EVENT_MAX)
        _inject_ambient_life(snapshot)

    last_snapshot = snapshot

func _build_world_state() -> Dictionary:
    var clock := Time.get_datetime_dict_from_system()
    var hour := int(clock.get("hour", 12))
    var minute := int(clock.get("minute", 0))
    var phase := "day"
    var condition := "CLEAR DAY"
    if hour < 5 or hour >= 20:
        phase = "night"
        condition = "CLEAR NIGHT"
    elif hour < 7:
        phase = "dawn"
        condition = "DAWN"
    elif hour >= 17:
        phase = "golden_hour"
        condition = "GOLDEN HOUR"

    var temperature := 24.0
    if phase == "night":
        temperature = 19.0
    elif phase == "dawn":
        temperature = 20.5
    elif phase == "golden_hour":
        temperature = 23.0

    return {
        "hour": hour,
        "minute": minute,
        "phase": phase,
        "condition": condition,
        "temperature_c": temperature,
        "session_seconds": session_seconds,
        "event_count": event_serial,
    }

func _world_state_changed(next_state: Dictionary) -> bool:
    if current_world_state.is_empty():
        return true
    return (
        int(next_state.get("minute", -1)) != int(current_world_state.get("minute", -2))
        or str(next_state.get("phase", "")) != str(current_world_state.get("phase", ""))
        or int(next_state.get("event_count", -1)) != int(current_world_state.get("event_count", -2))
    )

func _collect_snapshot() -> Dictionary:
    var snapshot: Dictionary = {}
    if scene_root != null:
        var hippo_body := scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
        snapshot[HIPPO] = {
            "body": hippo_body,
            "action": str(scene_root.get("current_action")),
            "hunger": _number(scene_root.get("hunger"), 0.2),
            "energy": _number(scene_root.get("energy"), 0.8),
            "bond": _number(scene_root.get("bond"), 0.35),
            "curiosity": _number(scene_root.get("curiosity"), 0.6),
            "cleanliness": _number(scene_root.get("cleanliness"), 0.75),
        }

    if roster != null:
        var companions_variant: Variant = roster.get("companions")
        if typeof(companions_variant) == TYPE_DICTIONARY:
            var companions := companions_variant as Dictionary
            for species in [PIG, SHARPEI]:
                var data_variant: Variant = companions.get(species, {})
                if typeof(data_variant) != TYPE_DICTIONARY:
                    continue
                var data := data_variant as Dictionary
                snapshot[species] = {
                    "body": data.get("node"),
                    "action": str(data.get("action", "watch")),
                    "hunger": _number(data.get("hunger", 0.2), 0.2),
                    "energy": _number(data.get("energy", 0.8), 0.8),
                    "bond": _number(data.get("bond", 0.3), 0.3),
                    "curiosity": _number(data.get("curiosity", 0.6), 0.6),
                    "playfulness": _number(data.get("playfulness", 0.6), 0.6),
                }
    return snapshot

func _recognize_player_interactions(snapshot: Dictionary) -> void:
    if last_snapshot.is_empty():
        return
    for species in [HIPPO, PIG, SHARPEI]:
        if not snapshot.has(species) or not last_snapshot.has(species):
            continue
        var now_data := snapshot[species] as Dictionary
        var old_data := last_snapshot[species] as Dictionary
        var hunger_drop := _number(old_data.get("hunger", 0.0), 0.0) - _number(now_data.get("hunger", 0.0), 0.0)
        var bond_gain := _number(now_data.get("bond", 0.0), 0.0) - _number(old_data.get("bond", 0.0), 0.0)
        if hunger_drop > 0.025:
            _record_event(species, "feed", "%s enjoyed being fed" % _display_name(species), 0.8)
        elif bond_gain > 0.006:
            _record_event(species, "bond", "%s is growing closer to you" % _display_name(species), 0.65)

func _recognize_action_changes(snapshot: Dictionary) -> void:
    if last_snapshot.is_empty():
        return
    for species in [HIPPO, PIG, SHARPEI]:
        if not snapshot.has(species) or not last_snapshot.has(species):
            continue
        var action := str((snapshot[species] as Dictionary).get("action", "idle"))
        var previous := str((last_snapshot[species] as Dictionary).get("action", "idle"))
        if action == previous:
            continue
        if action in ["play", "mud", "drink", "sleep", "coming", "happy"]:
            _record_event(species, action, "%s: %s" % [_display_name(species), _friendly_action(action)], 0.35, false)

func _recognize_social_encounters(snapshot: Dictionary) -> void:
    var pairs := [[HIPPO, PIG], [HIPPO, SHARPEI], [PIG, SHARPEI]]
    for pair in pairs:
        var a := str(pair[0])
        var b := str(pair[1])
        if not snapshot.has(a) or not snapshot.has(b):
            continue
        var body_a := (snapshot[a] as Dictionary).get("body") as Node3D
        var body_b := (snapshot[b] as Dictionary).get("body") as Node3D
        if body_a == null or body_b == null or not is_instance_valid(body_a) or not is_instance_valid(body_b):
            continue
        var key := "social_%s_%s" % [a, b]
        var near_now := body_a.global_position.distance_to(body_b.global_position) <= SOCIAL_DISTANCE
        var was_near := bool(scene_root.get_meta(key, false))
        scene_root.set_meta(key, near_now)
        if near_now and not was_near:
            _record_event(a, "social", "%s and %s crossed paths" % [_display_name(a), _display_name(b)], 0.25)

func _enforce_welfare_priorities(snapshot: Dictionary) -> void:
    if not snapshot.has(HIPPO):
        return
    var hippo_data := snapshot[HIPPO] as Dictionary
    var action := str(hippo_data.get("action", "idle"))
    var energy := _number(hippo_data.get("energy", 0.8), 0.8)
    var cleanliness := _number(hippo_data.get("cleanliness", 0.75), 0.75)
    if action in ["feed", "eat", "drink", "sleep", "mud"]:
        return

    # Only intervene at genuine welfare thresholds. Normal personality/utility AI
    # remains authoritative the rest of the time.
    if energy < 0.12:
        scene_root.set("current_action", "sleep")
        scene_root.set("action_timer", 8.0)
        _record_event(HIPPO, "welfare", "%s needs a rest" % _display_name(HIPPO), 0.7)
    elif cleanliness < 0.12:
        scene_root.set("current_action", "drink")
        scene_root.set("action_timer", 7.0)
        _record_event(HIPPO, "welfare", "%s heads for the water" % _display_name(HIPPO), 0.55)

func _inject_ambient_life(snapshot: Dictionary) -> void:
    if _reduced_motion():
        return

    var choices: Array[String] = []
    for species in [HIPPO, PIG, SHARPEI]:
        if not snapshot.has(species):
            continue
        var data := snapshot[species] as Dictionary
        if _number(data.get("energy", 0.7), 0.7) > 0.45 and str(data.get("action", "idle")) not in ["sleep", "rest", "drink"]:
            choices.append(species)
    if choices.is_empty():
        return

    var species := choices[randi() % choices.size()]
    if species == HIPPO:
        var actions := ["explore", "wander", "play"]
        var action := str(actions[randi() % actions.size()])
        scene_root.set("current_action", action)
        scene_root.set("action_timer", randf_range(3.2, 5.8))
        if scene_root.has_method("_new_wander_target"):
            scene_root.call("_new_wander_target")
        _record_event(HIPPO, "ambient", "%s explores the sanctuary" % _display_name(HIPPO), 0.20)
        return

    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return
    var companions := companions_variant as Dictionary
    if not companions.has(species):
        return
    var data_variant: Variant = companions[species]
    if typeof(data_variant) != TYPE_DICTIONARY:
        return
    var data := data_variant as Dictionary
    var action_pool := ["sniff", "wander", "play"] if species == PIG else ["watch", "wander", "play"]
    var action := str(action_pool[randi() % action_pool.size()])
    data["action"] = action
    data["action_timer"] = randf_range(3.0, 5.5)
    companions[species] = data
    roster.set("companions", companions)
    _record_event(species, "ambient", "%s %s" % [_display_name(species), _friendly_action(action).to_lower()], 0.20)

func _record_event(species: String, kind: String, text: String, intensity: float, emit_signal := true) -> void:
    event_serial += 1
    var event := {
        "id": event_serial,
        "species": species,
        "kind": kind,
        "text": text,
        "intensity": clampf(intensity, 0.0, 1.0),
        "session_seconds": session_seconds,
    }
    recent_events.push_front(event)
    if recent_events.size() > 12:
        recent_events.resize(12)
    if scene_root != null:
        scene_root.set_meta("hippo_os_last_event", event.duplicate(true))
    if emit_signal:
        sanctuary_event.emit(event.duplicate(true))

func notify_interaction(species: String, kind: String) -> void:
    _record_event(species, kind, "%s interaction: %s" % [_display_name(species), kind], 0.8)

func get_world_state() -> Dictionary:
    return current_world_state.duplicate(true)

func get_recent_events() -> Array[Dictionary]:
    return recent_events.duplicate(true)

func get_companion_mood(species: String) -> String:
    var snapshot := _collect_snapshot()
    if not snapshot.has(species):
        return "settled"
    var data := snapshot[species] as Dictionary
    var energy := _number(data.get("energy", 0.7), 0.7)
    var hunger := _number(data.get("hunger", 0.2), 0.2)
    var bond := _number(data.get("bond", 0.3), 0.3)
    var action := str(data.get("action", "idle"))
    if action in ["sleep", "rest"] or energy < 0.25:
        return "sleepy"
    if hunger > 0.72:
        return "hungry"
    if action == "play" and energy > 0.55:
        return "playful"
    if bond > 0.65:
        return "trusting"
    if action in ["explore", "wander", "sniff"]:
        return "curious"
    return "settled"

func _display_name(species: String) -> String:
    if species == HIPPO and scene_root != null:
        var value: Variant = scene_root.get("hippo_name")
        var name := str(value)
        return name if not name.is_empty() and name != "<null>" else "Mochi"
    if species == PIG:
        return "Porky"
    if species == SHARPEI:
        return "Bao"
    return "Companion"

func _friendly_action(action: String) -> String:
    match action:
        "mud":
            return "playing in the mud"
        "drink":
            return "cooling off in the water"
        "sleep", "rest":
            return "settling down to rest"
        "coming":
            return "coming over"
        "happy":
            return "enjoying the attention"
        "play":
            return "playing"
        "sniff":
            return "sniffing around"
        "wander", "explore":
            return "exploring"
        _:
            return action.replace("_", " ")

func _reduced_motion() -> bool:
    if scene_root == null:
        return false
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) != TYPE_DICTIONARY:
        return false
    return bool((settings_variant as Dictionary).get("reduced_motion", false))

func _number(value: Variant, fallback: float) -> float:
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return fallback
