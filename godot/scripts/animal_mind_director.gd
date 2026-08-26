extends Node

signal mind_updated(species: String, blackboard: Dictionary)
signal decision_changed(species: String, decision: String, reason: String)

const SAVE_PATH: String = "user://animal_minds.json"
const THINK_INTERVAL: float = 0.55
const SAVE_INTERVAL: float = 20.0
const MEMORY_LIMIT: int = 28
const VOICE_PRIORITY_MSEC: int = 8000

const HIPPO: String = "hippo"
const PIG: String = "pig"
const SHARPEI: String = "sharpei"
const SPECIES: Array[String] = [HIPPO, PIG, SHARPEI]

const POND_POS: Vector3 = Vector3(3.7, 0.8, 2.5)
const MUD_POS: Vector3 = Vector3(-3.7, 0.8, 2.8)
const REST_POS: Vector3 = Vector3(-4.6, 0.8, -3.2)
const FEED_POS: Vector3 = Vector3(4.7, 0.8, -2.9)

var scene_root: Node3D = null
var roster: Node = null
var minds: Dictionary = {}
var loaded_state: Dictionary = {}
var think_timer: float = 0.0
var save_timer: float = 0.0

func _ready() -> void:
    randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 260
    _load_state()
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt: int in range(420):
        var candidate: Node = get_tree().current_scene
        var roster_candidate: Node = get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            var companions_variant: Variant = roster_candidate.get("companions")
            if typeof(companions_variant) == TYPE_DICTIONARY:
                var companions: Dictionary = companions_variant as Dictionary
                if candidate.find_child("BabyHippo", true, false) != null and companions.has(PIG) and companions.has(SHARPEI):
                    scene_root = candidate as Node3D
                    roster = roster_candidate
                    break
        await get_tree().process_frame

    if scene_root == null or roster == null:
        push_warning("AnimalMindDirector could not bind to sanctuary companions")
        return

    for species: String in SPECIES:
        minds[species] = _make_blackboard(species)
        _publish_blackboard(species)
    set_process(true)
    print("HippoOS persistent animal minds online")

func _process(delta: float) -> void:
    if scene_root == null or not is_instance_valid(scene_root):
        return
    think_timer -= delta
    save_timer += delta
    _advance_private_needs(delta)
    if think_timer <= 0.0:
        think_timer = THINK_INTERVAL
        for species: String in SPECIES:
            _think(species)
    if save_timer >= SAVE_INTERVAL:
        save_timer = 0.0
        _save_state()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_state()

func _exit_tree() -> void:
    _save_state()

func _make_blackboard(species: String) -> Dictionary:
    var defaults: Dictionary = _defaults_for(species)
    var saved: Dictionary = {}
    var saved_variant: Variant = loaded_state.get(species, {})
    if typeof(saved_variant) == TYPE_DICTIONARY:
        saved = saved_variant as Dictionary
    var board: Dictionary = {
        "species": species,
        "name": str(defaults.get("name", species)),
        "needs": {
            "hunger": 0.2,
            "thirst": float(saved.get("thirst", defaults.get("thirst", 0.2))),
            "energy": 0.8,
            "cleanliness": 0.75,
            "social": float(saved.get("social", defaults.get("social_need", 0.3))),
            "stimulation": float(saved.get("stimulation", defaults.get("stimulation", 0.3)))
        },
        "personality": (defaults.get("personality", {}) as Dictionary).duplicate(true),
        "preferences": (defaults.get("preferences", {}) as Dictionary).duplicate(true),
        "memory": [],
        "decision": "idle",
        "reason": "settling into sanctuary",
        "decision_until_msec": 0,
        "last_voice_time_msec": 0,
        "last_voice_command": "",
        "target_position": Vector3.ZERO,
        "mood": "content"
    }
    var saved_preferences_variant: Variant = saved.get("preferences", {})
    if typeof(saved_preferences_variant) == TYPE_DICTIONARY:
        var saved_preferences: Dictionary = saved_preferences_variant as Dictionary
        var preferences: Dictionary = board.get("preferences", {}) as Dictionary
        for key: Variant in saved_preferences.keys():
            preferences[key] = clampf(float(saved_preferences.get(key, 0.5)), 0.0, 1.0)
    var saved_memory_variant: Variant = saved.get("memory", [])
    if typeof(saved_memory_variant) == TYPE_ARRAY:
        var saved_memory: Array = saved_memory_variant as Array
        board["memory"] = saved_memory.slice(maxi(0, saved_memory.size() - MEMORY_LIMIT))
    return board

func _defaults_for(species: String) -> Dictionary:
    if species == HIPPO:
        return {
            "name": "Mochi", "thirst": 0.24, "social_need": 0.28, "stimulation": 0.34,
            "personality": {"curiosity": 0.78, "sociability": 0.68, "playfulness": 0.64, "calmness": 0.72, "food_drive": 0.62, "water_affinity": 0.96, "obedience": 0.80},
            "preferences": {"food": 0.64, "water": 0.96, "mud": 0.88, "rest": 0.62, "social": 0.70, "explore": 0.78, "play": 0.66}
        }
    if species == PIG:
        return {
            "name": "Porky", "thirst": 0.20, "social_need": 0.32, "stimulation": 0.44,
            "personality": {"curiosity": 0.86, "sociability": 0.74, "playfulness": 0.82, "calmness": 0.48, "food_drive": 0.94, "water_affinity": 0.48, "obedience": 0.68},
            "preferences": {"food": 0.95, "water": 0.52, "mud": 0.76, "rest": 0.48, "social": 0.73, "explore": 0.86, "play": 0.82}
        }
    return {
        "name": "Bao", "thirst": 0.18, "social_need": 0.25, "stimulation": 0.30,
        "personality": {"curiosity": 0.62, "sociability": 0.84, "playfulness": 0.58, "calmness": 0.80, "food_drive": 0.68, "water_affinity": 0.36, "obedience": 0.92},
        "preferences": {"food": 0.70, "water": 0.40, "mud": 0.18, "rest": 0.74, "social": 0.90, "explore": 0.58, "play": 0.60}
    }

func _advance_private_needs(delta: float) -> void:
    for species: String in SPECIES:
        var board_variant: Variant = minds.get(species, null)
        if typeof(board_variant) != TYPE_DICTIONARY:
            continue
        var board: Dictionary = board_variant as Dictionary
        var needs: Dictionary = board.get("needs", {}) as Dictionary
        needs["thirst"] = clampf(float(needs.get("thirst", 0.2)) + delta * 0.000070, 0.0, 1.0)
        needs["social"] = clampf(float(needs.get("social", 0.3)) + delta * 0.000035, 0.0, 1.0)
        needs["stimulation"] = clampf(float(needs.get("stimulation", 0.3)) + delta * 0.000045, 0.0, 1.0)

func _think(species: String) -> void:
    var board_variant: Variant = minds.get(species, null)
    if typeof(board_variant) != TYPE_DICTIONARY:
        return
    var board: Dictionary = board_variant as Dictionary
    _sync_public_needs(species, board)
    _consume_voice_command(species, board)
    var now_msec: int = Time.get_ticks_msec()
    if now_msec < int(board.get("decision_until_msec", 0)):
        _publish_blackboard(species)
        return
    var choice: Dictionary = _select_decision(board)
    _apply_decision(species, board, str(choice.get("action", "idle")), str(choice.get("reason", "utility")), float(choice.get("hold", 4.0)))
    _publish_blackboard(species)

func _sync_public_needs(species: String, board: Dictionary) -> void:
    var needs: Dictionary = board.get("needs", {}) as Dictionary
    if species == HIPPO:
        needs["hunger"] = _number(scene_root.get("hunger"), float(needs.get("hunger", 0.2)))
        needs["energy"] = _number(scene_root.get("energy"), float(needs.get("energy", 0.8)))
        needs["cleanliness"] = _number(scene_root.get("cleanliness"), float(needs.get("cleanliness", 0.75)))
        var personality_variant: Variant = scene_root.get("personality")
        if typeof(personality_variant) == TYPE_DICTIONARY:
            var main_personality: Dictionary = personality_variant as Dictionary
            if main_personality.has("curiosity"):
                var personality: Dictionary = board.get("personality", {}) as Dictionary
                personality["curiosity"] = clampf(float(main_personality.get("curiosity", 0.78)), 0.0, 1.0)
        return
    var data: Dictionary = _roster_data(species)
    if data.is_empty():
        return
    needs["hunger"] = _number(data.get("hunger"), float(needs.get("hunger", 0.2)))
    needs["energy"] = _number(data.get("energy"), float(needs.get("energy", 0.8)))
    needs["cleanliness"] = 0.78

func _consume_voice_command(species: String, board: Dictionary) -> void:
    var body: Node3D = _body_for(species)
    if body == null:
        return
    var stamp: int = int(body.get_meta("voice_command_time_msec", 0))
    if stamp <= int(board.get("last_voice_time_msec", 0)) or Time.get_ticks_msec() - stamp > VOICE_PRIORITY_MSEC:
        return
    var command: String = str(body.get_meta("voice_command", ""))
    if command.is_empty():
        return
    board["last_voice_time_msec"] = stamp
    board["last_voice_command"] = command
    var action: String = _voice_to_decision(command)
    var personality: Dictionary = board.get("personality", {}) as Dictionary
    _remember(board, "voice", "Heard '%s'" % command, 0.82)
    _learn(board, _preference_for_action(action), 0.018 * float(personality.get("obedience", 0.7)))
    _apply_decision(species, board, action, "voice command: %s" % command, 6.5)

func _select_decision(board: Dictionary) -> Dictionary:
    var needs: Dictionary = board.get("needs", {}) as Dictionary
    var personality: Dictionary = board.get("personality", {}) as Dictionary
    var preferences: Dictionary = board.get("preferences", {}) as Dictionary
    var energy: float = float(needs.get("energy", 0.8))
    var hunger: float = float(needs.get("hunger", 0.2))
    var thirst: float = float(needs.get("thirst", 0.2))
    if energy < 0.14:
        return {"action": "sleep", "reason": "very low energy", "hold": 8.0}
    if thirst > 0.88:
        return {"action": "drink", "reason": "very thirsty", "hold": 7.0}
    if hunger > 0.88:
        return {"action": "eat", "reason": "very hungry", "hold": 7.0}
    var scores: Dictionary = {
        "sleep": (1.0 - energy) * 1.35 + float(preferences.get("rest", 0.5)) * 0.12,
        "eat": hunger * (0.86 + float(personality.get("food_drive", 0.6)) * 0.54),
        "drink": thirst * (1.02 + float(personality.get("water_affinity", 0.5)) * 0.30),
        "social": float(needs.get("social", 0.3)) * (0.58 + float(personality.get("sociability", 0.6)) * 0.72),
        "play": float(needs.get("stimulation", 0.3)) * (0.52 + float(personality.get("playfulness", 0.6)) * 0.76),
        "explore": float(needs.get("stimulation", 0.3)) * (0.48 + float(personality.get("curiosity", 0.6)) * 0.74),
        "idle": 0.28 + float(personality.get("calmness", 0.6)) * 0.22
    }
    var best: String = "idle"
    var best_score: float = -1.0
    for action_variant: Variant in scores.keys():
        var action: String = str(action_variant)
        var score: float = float(scores.get(action, 0.0)) + randf_range(-0.035, 0.035)
        if score > best_score:
            best_score = score
            best = action
    return {"action": best, "reason": "utility %.2f" % best_score, "hold": _hold_for(best)}

func _apply_decision(species: String, board: Dictionary, action: String, reason: String, hold: float) -> void:
    var previous: String = str(board.get("decision", "idle"))
    var target: Vector3 = _target_for(species, action)
    board["decision"] = action
    board["reason"] = reason
    board["decision_until_msec"] = Time.get_ticks_msec() + int(hold * 1000.0)
    board["target_position"] = target
    board["mood"] = _mood_for(board)
    _apply_to_existing_brain(species, action, target)
    _apply_need_relief(board, action)
    if previous != action:
        _remember(board, "decision", "%s -> %s (%s)" % [previous, action, reason], 0.40)
        decision_changed.emit(species, action, reason)

func _apply_to_existing_brain(species: String, action: String, target: Vector3) -> void:
    if species == HIPPO:
        scene_root.set("current_action", _hippo_action(action))
        if scene_root.get("action_timer") != null:
            scene_root.set("action_timer", maxf(3.0, _hold_for(action)))
        if scene_root.get("wander_target") != null and target != Vector3.ZERO:
            scene_root.set("wander_target", target)
        return
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return
    var companions: Dictionary = companions_variant as Dictionary
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return
    var data: Dictionary = data_variant as Dictionary
    data["action"] = _roster_action(action)
    data["action_timer"] = maxf(3.0, _hold_for(action))
    if target != Vector3.ZERO:
        data["target"] = target
    companions[species] = data
    roster.set("companions", companions)

func _target_for(species: String, action: String) -> Vector3:
    match action:
        "eat": return FEED_POS + _species_offset(species)
        "drink", "clean", "swim": return POND_POS + _species_offset(species)
        "mud": return MUD_POS + _species_offset(species)
        "sleep": return REST_POS + _species_offset(species)
        "social", "come":
            var hippo: Node3D = _body_for(HIPPO)
            if hippo != null:
                return hippo.global_position + _species_offset(species)
        "explore", "play": return Vector3(randf_range(-5.0, 5.0), 0.8, randf_range(-3.8, 3.8))
    return Vector3.ZERO

func _species_offset(species: String) -> Vector3:
    if species == PIG:
        return Vector3(-0.8, -0.08, 0.7)
    if species == SHARPEI:
        return Vector3(-0.7, -0.05, -0.8)
    return Vector3.ZERO

func _apply_need_relief(board: Dictionary, action: String) -> void:
    var needs: Dictionary = board.get("needs", {}) as Dictionary
    if action == "drink" or action == "swim":
        needs["thirst"] = maxf(0.0, float(needs.get("thirst", 0.2)) - 0.16)
    elif action == "social" or action == "come":
        needs["social"] = maxf(0.0, float(needs.get("social", 0.3)) - 0.12)
    elif action == "play" or action == "explore":
        needs["stimulation"] = maxf(0.0, float(needs.get("stimulation", 0.3)) - 0.10)

func _mood_for(board: Dictionary) -> String:
    var needs: Dictionary = board.get("needs", {}) as Dictionary
    if float(needs.get("energy", 0.8)) < 0.22:
        return "tired"
    if float(needs.get("hunger", 0.2)) > 0.75 or float(needs.get("thirst", 0.2)) > 0.75:
        return "needy"
    if float(needs.get("stimulation", 0.3)) > 0.72:
        return "restless"
    return "content"

func _hold_for(action: String) -> float:
    match action:
        "sleep": return 8.0
        "eat", "drink": return 7.0
        "social", "play", "explore": return 5.5
    return 4.0

func _voice_to_decision(command: String) -> String:
    match command:
        "come": return "come"
        "stay": return "idle"
        "eat": return "eat"
        "drink": return "drink"
        "sleep": return "sleep"
        "play": return "play"
        "explore": return "explore"
        "mud": return "mud"
        "swim": return "swim"
    return "idle"

func _preference_for_action(action: String) -> String:
    match action:
        "eat": return "food"
        "drink", "swim": return "water"
        "sleep": return "rest"
        "social", "come": return "social"
        "explore": return "explore"
        "play": return "play"
        "mud": return "mud"
    return ""

func _hippo_action(action: String) -> String:
    match action:
        "sleep": return "sleep"
        "eat": return "feed"
        "drink", "swim", "clean": return "drink"
        "mud": return "mud"
        "play": return "play"
        "explore", "come": return "wander"
    return "idle"

func _roster_action(action: String) -> String:
    match action:
        "sleep": return "rest"
        "eat": return "sniff"
        "drink", "swim": return "drink"
        "social", "come": return "coming"
        "play": return "play"
        "explore": return "wander"
    return "watch"

func _remember(board: Dictionary, kind: String, text: String, weight: float) -> void:
    var memory: Array = board.get("memory", []) as Array
    memory.append({"time": Time.get_unix_time_from_system(), "kind": kind, "text": text, "weight": weight})
    while memory.size() > MEMORY_LIMIT:
        memory.pop_front()
    board["memory"] = memory

func _learn(board: Dictionary, key: String, amount: float) -> void:
    if key.is_empty():
        return
    var preferences: Dictionary = board.get("preferences", {}) as Dictionary
    preferences[key] = clampf(float(preferences.get(key, 0.5)) + amount, 0.0, 1.0)

func _publish_blackboard(species: String) -> void:
    var board_variant: Variant = minds.get(species, null)
    if typeof(board_variant) != TYPE_DICTIONARY:
        return
    var board: Dictionary = board_variant as Dictionary
    var body: Node3D = _body_for(species)
    if body != null:
        body.set_meta("animal_blackboard", board.duplicate(true))
    mind_updated.emit(species, board.duplicate(true))

func _body_for(species: String) -> Node3D:
    if scene_root == null:
        return null
    if species == HIPPO:
        return scene_root.find_child("BabyHippo", true, false) as Node3D
    if species == PIG:
        return scene_root.find_child("PorkyPig", true, false) as Node3D
    return scene_root.find_child("BaoSharPei", true, false) as Node3D

func _roster_data(species: String) -> Dictionary:
    if roster == null:
        return {}
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return {}
    var companions: Dictionary = companions_variant as Dictionary
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) == TYPE_DICTIONARY:
        return data_variant as Dictionary
    return {}

func _number(value: Variant, fallback: float) -> float:
    if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
        return float(value)
    return fallback

func _load_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        loaded_state = parsed as Dictionary

func _save_state() -> void:
    if minds.is_empty():
        return
    var output: Dictionary = {}
    for species: String in SPECIES:
        var board_variant: Variant = minds.get(species, null)
        if typeof(board_variant) != TYPE_DICTIONARY:
            continue
        var board: Dictionary = board_variant as Dictionary
        var needs: Dictionary = board.get("needs", {}) as Dictionary
        output[species] = {
            "thirst": float(needs.get("thirst", 0.2)),
            "social": float(needs.get("social", 0.3)),
            "stimulation": float(needs.get("stimulation", 0.3)),
            "preferences": (board.get("preferences", {}) as Dictionary).duplicate(true),
            "memory": (board.get("memory", []) as Array).duplicate(true)
        }
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(output))
