extends Node

# Persistent individual companion intelligence for Hippo OS.
# Each animal gets a lightweight blackboard with needs, personality, memories,
# learned preferences, utility-based behaviour selection, social context and
# high-priority voice-command overrides. It remains deterministic/offline-first
# and cooperates with the existing GameplayDirector and CompanionRoster.

signal mind_updated(species: String, blackboard: Dictionary)
signal decision_changed(species: String, decision: String, reason: String)

const SAVE_PATH := "user://animal_minds.json"
const SAVE_VERSION := 1
const THINK_INTERVAL := 0.55
const SAVE_INTERVAL := 20.0
const MEMORY_LIMIT := 28
const VOICE_PRIORITY_MSEC := 8000

const HIPPO := "hippo"
const PIG := "pig"
const SHARPEI := "sharpei"
const SPECIES := [HIPPO, PIG, SHARPEI]

const POND_POS := Vector3(3.7, 0.8, 2.5)
const MUD_POS := Vector3(-3.7, 0.8, 2.8)
const REST_POS := Vector3(-4.6, 0.8, -3.2)
const FEED_POS := Vector3(4.7, 0.8, -2.9)

var scene_root: Node3D
var roster: Node
var minds: Dictionary = {}
var think_timer := 0.0
var save_timer := 0.0
var loaded_state: Dictionary = {}

func _ready() -> void:
    randomize()
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 260
    _load_state()
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(420):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        if candidate is Node3D and roster_candidate != null:
            var companions_variant: Variant = roster_candidate.get("companions")
            if typeof(companions_variant) == TYPE_DICTIONARY:
                var companions := companions_variant as Dictionary
                if candidate.find_child("BabyHippo", true, false) != null and companions.has(PIG) and companions.has(SHARPEI):
                    scene_root = candidate as Node3D
                    roster = roster_candidate
                    break
        await get_tree().process_frame

    if scene_root == null or roster == null:
        push_warning("AnimalMindDirector could not bind to sanctuary companions")
        return

    for species in SPECIES:
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
        for species in SPECIES:
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
    var defaults := _defaults_for(species)
    var saved: Dictionary = {}
    if typeof(loaded_state.get(species, {})) == TYPE_DICTIONARY:
        saved = loaded_state.get(species, {}) as Dictionary
    var board := {
        "species": species,
        "name": defaults.name,
        "needs": {
            "hunger": 0.2,
            "thirst": float(saved.get("thirst", defaults.thirst)),
            "energy": 0.8,
            "cleanliness": 0.75,
            "social": float(saved.get("social", defaults.social_need)),
            "stimulation": float(saved.get("stimulation", defaults.stimulation)),
        },
        "personality": defaults.personality.duplicate(true),
        "preferences": defaults.preferences.duplicate(true),
        "memory": [],
        "decision": "idle",
        "reason": "settling into sanctuary",
        "decision_until_msec": 0,
        "last_voice_time_msec": 0,
        "last_voice_command": "",
        "social_target": "",
        "target_position": Vector3.ZERO,
        "mood": "content",
    }
    if typeof(saved.get("preferences", {})) == TYPE_DICTIONARY:
        for key in (saved.get("preferences", {}) as Dictionary):
            board.preferences[key] = clampf(float((saved.preferences as Dictionary)[key]), 0.0, 1.0)
    if typeof(saved.get("memory", [])) == TYPE_ARRAY:
        board.memory = (saved.get("memory", []) as Array).slice(maxi(0, (saved.get("memory", []) as Array).size() - MEMORY_LIMIT))
    return board

func _defaults_for(species: String) -> Dictionary:
    match species:
        HIPPO:
            return {
                "name": "Mochi", "thirst": 0.24, "social_need": 0.28, "stimulation": 0.34,
                "personality": {"curiosity": 0.78, "sociability": 0.68, "playfulness": 0.64, "calmness": 0.72, "food_drive": 0.62, "water_affinity": 0.96, "obedience": 0.80},
                "preferences": {"food": 0.64, "water": 0.96, "mud": 0.88, "rest": 0.62, "social": 0.70, "explore": 0.78, "play": 0.66}
            }
        PIG:
            return {
                "name": "Porky", "thirst": 0.20, "social_need": 0.32, "stimulation": 0.44,
                "personality": {"curiosity": 0.86, "sociability": 0.74, "playfulness": 0.82, "calmness": 0.48, "food_drive": 0.94, "water_affinity": 0.48, "obedience": 0.68},
                "preferences": {"food": 0.95, "water": 0.52, "mud": 0.76, "rest": 0.48, "social": 0.73, "explore": 0.86, "play": 0.82}
            }
        _:
            return {
                "name": "Bao", "thirst": 0.18, "social_need": 0.25, "stimulation": 0.30,
                "personality": {"curiosity": 0.62, "sociability": 0.84, "playfulness": 0.58, "calmness": 0.80, "food_drive": 0.68, "water_affinity": 0.36, "obedience": 0.92},
                "preferences": {"food": 0.70, "water": 0.40, "mud": 0.18, "rest": 0.74, "social": 0.90, "explore": 0.58, "play": 0.60}
            }

func _advance_private_needs(delta: float) -> void:
    for species in SPECIES:
        if not minds.has(species):
            continue
        var board := minds[species] as Dictionary
        var needs := board.needs as Dictionary
        needs.thirst = clampf(float(needs.thirst) + delta * 0.000070, 0.0, 1.0)
        needs.social = clampf(float(needs.social) + delta * 0.000035, 0.0, 1.0)
        needs.stimulation = clampf(float(needs.stimulation) + delta * 0.000045, 0.0, 1.0)

func _think(species: String) -> void:
    if not minds.has(species):
        return
    var board := minds[species] as Dictionary
    _sync_public_needs(species, board)
    _consume_voice_command(species, board)
    var now := Time.get_ticks_msec()
    if now < int(board.decision_until_msec):
        _publish_blackboard(species)
        return

    var choice := _select_decision(species, board)
    _apply_decision(species, board, str(choice.action), str(choice.reason), float(choice.hold))
    _publish_blackboard(species)

func _sync_public_needs(species: String, board: Dictionary) -> void:
    var needs := board.needs as Dictionary
    if species == HIPPO:
        needs.hunger = _number(scene_root.get("hunger"), needs.hunger)
        needs.energy = _number(scene_root.get("energy"), needs.energy)
        needs.cleanliness = _number(scene_root.get("cleanliness"), needs.cleanliness)
        var personality_variant := scene_root.get("personality")
        if typeof(personality_variant) == TYPE_DICTIONARY:
            var main_personality := personality_variant as Dictionary
            if main_personality.has("curiosity"):
                board.personality.curiosity = clampf(float(main_personality.curiosity), 0.0, 1.0)
        return
    var data := _roster_data(species)
    if data.is_empty():
        return
    needs.hunger = _number(data.get("hunger", needs.hunger), needs.hunger)
    needs.energy = _number(data.get("energy", needs.energy), needs.energy)
    needs.cleanliness = 0.78

func _consume_voice_command(species: String, board: Dictionary) -> void:
    var body := _body_for(species)
    if body == null:
        return
    var stamp := int(body.get_meta("voice_command_time_msec", 0))
    if stamp <= int(board.last_voice_time_msec) or Time.get_ticks_msec() - stamp > VOICE_PRIORITY_MSEC:
        return
    var command := str(body.get_meta("voice_command", ""))
    if command.is_empty():
        return
    board.last_voice_time_msec = stamp
    board.last_voice_command = command
    var action := _voice_to_decision(command)
    _remember(board, "voice", "Heard '%s'" % command, 0.82)
    _learn(board, _preference_for_action(action), 0.018 * float(board.personality.obedience))
    _apply_decision(species, board, action, "voice command: %s" % command, 6.5)

func _select_decision(species: String, board: Dictionary) -> Dictionary:
    var needs := board.needs as Dictionary
    var personality := board.personality as Dictionary
    var preferences := board.preferences as Dictionary
    var scores := {
        "sleep": (1.0 - float(needs.energy)) * 1.35 + float(preferences.rest) * 0.12,
        "eat": float(needs.hunger) * (0.86 + float(personality.food_drive) * 0.54) + float(preferences.food) * 0.12,
        "drink": float(needs.thirst) * (1.02 + float(personality.water_affinity) * 0.30) + float(preferences.water) * 0.10,
        "clean": (1.0 - float(needs.cleanliness)) * (0.72 + float(personality.water_affinity) * 0.42),
        "social": float(needs.social) * (0.58 + float(personality.sociability) * 0.72) + float(preferences.social) * 0.12,
        "play": float(needs.stimulation) * (0.52 + float(personality.playfulness) * 0.76) + float(preferences.play) * 0.11,
        "explore": float(needs.stimulation) * (0.48 + float(personality.curiosity) * 0.74) + float(preferences.explore) * 0.12,
        "idle": 0.28 + float(personality.calmness) * 0.22,
    }

    # Hard welfare priorities beat personality utility.
    if float(needs.energy) < 0.14:
        return {"action": "sleep", "reason": "very low energy", "hold": 8.0}
    if float(needs.thirst) > 0.88:
        return {"action": "drink", "reason": "very thirsty", "hold": 7.0}
    if float(needs.hunger) > 0.88:
        return {"action": "eat", "reason": "very hungry", "hold": 7.0}

    var best := "idle"
    var best_score := -1.0
    for action in scores:
        var score := float(scores[action]) + randf_range(-0.035, 0.035)
        if score > best_score:
            best_score = score
            best = str(action)
    var reason := "utility %.2f" % best_score
    return {"action": best, "reason": reason, "hold": _hold_for(best)}

func _apply_decision(species: String, board: Dictionary, action: String, reason: String, hold: float) -> void:
    var previous := str(board.decision)
    board.decision = action
    board.reason = reason
    board.decision_until_msec = Time.get_ticks_msec() + int(hold * 1000.0)
    board.target_position = _target_for(species, action)
    board.mood = _mood_for(board)
    _apply_to_existing_brain(species, action, board.target_position)
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
    var companions := companions_variant as Dictionary
    if not companions.has(species) or typeof(companions[species]) != TYPE_DICTIONARY:
        return
    var data := companions[species] as Dictionary
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
            var hippo := _body_for(HIPPO)
            if hippo != null:
                return hippo.global_position + _species_offset(species)
        "explore", "play":
            return Vector3(randf_range(-5.0, 5.0), 0.8, randf_range(-3.8, 3.8))
    return Vector3.ZERO

func _species_offset(species: String) -> Vector3:
    if species == PIG:
        return Vector3(-0.8, -0.08, 0.7)
    if species == SHARPEI:
        return Vector3(-0.7, -0.05, -0.8)
    return Vector3.ZERO

func _apply_need_relief(board: Dictionary, action: String) -> void:
    var needs := board.needs as Dictionary
    match action:
        "drink", "swim": needs.thirst = maxf(0.0, float(needs.thirst) - 0.16)
        "social", "come": needs.social = maxf(0.0, float(needs.social) - 0.12)
        "play", "explore": needs.stimulation = maxf(0.0, float(needs.stimulation) - 0.10)
        "clean": needs.cleanliness = minf(1.0, float(needs.cleanliness) + 0.10)
    _learn(board, _preference_for_action(action), 0.0025)

func _mood_for(board: Dictionary) -> String:
    var needs := board.needs as Dictionary
    if float(needs.energy) < 0.22:
        return "tired"
    if float(needs.hunger) > 0.78 or float(needs.thirst) > 0.78:
        return "needy"
    if float(needs.social) > 0.72:
        return "seeking company"
    if float(needs.stimulation) > 0.72:
        return "curious"
    return "content"

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

func _hippo_action(action: String) -> String:
    match action:
        "sleep": return "sleep"
        "eat": return "feed"
        "drink", "swim", "clean": return "drink"
        "mud": return "mud"
        "play": return "play"
        "explore": return "explore"
        "social", "come": return "approach"
    return "idle"

func _roster_action(action: String) -> String:
    match action:
        "sleep": return "rest"
        "eat": return "sniff"
        "drink", "swim", "clean": return "wander"
        "mud": return "sniff"
        "play": return "play"
        "explore": return "wander"
        "social", "come": return "coming"
    return "watch"

func _hold_for(action: String) -> float:
    match action:
        "sleep": return 8.5
        "eat", "drink", "mud", "clean", "swim": return 6.5
        "social", "come": return 5.5
        "play", "explore": return 5.0
    return 3.5

func _preference_for_action(action: String) -> String:
    match action:
        "eat": return "food"
        "drink", "swim", "clean": return "water"
        "mud": return "mud"
        "sleep": return "rest"
        "social", "come": return "social"
        "play": return "play"
        "explore": return "explore"
    return "rest"

func _learn(board: Dictionary, key: String, amount: float) -> void:
    var preferences := board.preferences as Dictionary
    preferences[key] = clampf(float(preferences.get(key, 0.5)) + amount, 0.0, 1.0)

func _remember(board: Dictionary, kind: String, text: String, weight: float) -> void:
    var memory := board.memory as Array
    memory.append({"time": Time.get_unix_time_from_system(), "kind": kind, "text": text, "weight": weight})
    while memory.size() > MEMORY_LIMIT:
        memory.pop_front()

func _publish_blackboard(species: String) -> void:
    if not minds.has(species):
        return
    var board := minds[species] as Dictionary
    var published := board.duplicate(true)
    # Vector3 is useful live but JSON persistence is handled separately.
    var body := _body_for(species)
    if body != null:
        body.set_meta("hippo_os_blackboard", published)
    mind_updated.emit(species, published)

func get_blackboard(species: String) -> Dictionary:
    if not minds.has(species):
        return {}
    return (minds[species] as Dictionary).duplicate(true)

func reinforce_preference(species: String, preference: String, amount := 0.03) -> void:
    if not minds.has(species):
        return
    var board := minds[species] as Dictionary
    _learn(board, preference, amount)
    _remember(board, "learning", "Preference reinforced: %s" % preference, clampf(amount * 8.0, 0.1, 1.0))
    _publish_blackboard(species)

func _body_for(species: String) -> CharacterBody3D:
    if scene_root == null:
        return null
    if species == HIPPO:
        return scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
    var data := _roster_data(species)
    return data.get("node") as CharacterBody3D if not data.is_empty() else null

func _roster_data(species: String) -> Dictionary:
    if roster == null:
        return {}
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return {}
    var companions := companions_variant as Dictionary
    if typeof(companions.get(species, {})) != TYPE_DICTIONARY:
        return {}
    return companions.get(species, {}) as Dictionary

func _number(value: Variant, fallback: float) -> float:
    if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
        return float(value)
    return fallback

func _save_state() -> void:
    if minds.is_empty():
        return
    var output := {"version": SAVE_VERSION, "animals": {}}
    for species in SPECIES:
        if not minds.has(species):
            continue
        var board := minds[species] as Dictionary
        var needs := board.needs as Dictionary
        output.animals[species] = {
            "thirst": float(needs.thirst),
            "social": float(needs.social),
            "stimulation": float(needs.stimulation),
            "preferences": (board.preferences as Dictionary).duplicate(true),
            "memory": (board.memory as Array).duplicate(true),
        }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(output))

func _load_state() -> void:
    loaded_state = {}
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var root := parsed as Dictionary
    if int(root.get("version", 0)) != SAVE_VERSION:
        return
    if typeof(root.get("animals", {})) == TYPE_DICTIONARY:
        loaded_state = root.get("animals", {}) as Dictionary
