extends Node

const RelationshipGraph = preload("res://scripts/animal_relationships.gd")
const EVALUATE_SECONDS := 1.5
const ENCOUNTER_COOLDOWN := 24.0

var host
var graph
var timer := 0.0
var encounter_cooldowns := {}
var together_last_tick := {}
var journaled_session_pairs := {}

func _ready():
    process_priority = 35
    for i in range(7):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    graph = RelationshipGraph.new()
    var sanctuary = host.get("sanctuary")
    if sanctuary != null:
        graph.from_dict(sanctuary.relationships)
    _ensure_all_pairs()

func _process(delta):
    if host == null or graph == null:
        return
    for key in encounter_cooldowns.keys():
        encounter_cooldowns[key] = max(0.0, float(encounter_cooldowns[key]) - delta)
    timer -= delta
    if timer > 0.0:
        return
    timer = EVALUATE_SECONDS
    _evaluate_relationships()

func _ensure_all_pairs():
    for pair in [["hippo_01", "pig_01"], ["hippo_01", "sharpei_01"], ["pig_01", "sharpei_01"]]:
        graph.ensure_pair(pair[0], pair[1])

func _evaluate_relationships():
    var animals = host.get("animals")
    if typeof(animals) != TYPE_DICTIONARY:
        return
    for pair in [["hippo_01", "pig_01"], ["hippo_01", "sharpei_01"], ["pig_01", "sharpei_01"]]:
        var a = animals.get(pair[0], null)
        var b = animals.get(pair[1], null)
        if a == null or b == null:
            continue
        _evaluate_pair(pair[0], a, pair[1], b)
    _persist()

func _evaluate_pair(a_id: String, a, b_id: String, b):
    var key = _pair_key(a_id, b_id)
    var distance = Vector2(
        a.global_position.x - b.global_position.x,
        a.global_position.z - b.global_position.z
    ).length()
    var close_now = distance < 5.4
    var was_close = bool(together_last_tick.get(key, false))
    together_last_tick[key] = close_now

    if close_now and float(encounter_cooldowns.get(key, 0.0)) <= 0.0:
        var quality = _encounter_quality(a, b, distance)
        var shared_resource = _shared_resource_context(a, b)
        graph.register_encounter(a_id, b_id, quality, distance, shared_resource)
        encounter_cooldowns[key] = ENCOUNTER_COOLDOWN
        _maybe_journal_encounter(key, a, b, quality)

    var rel = graph.relationship(a_id, b_id)
    var preferred = float(rel.get("preferred_distance", 3.0))
    if distance < max(1.4, preferred * 0.66) and graph.should_avoid(a_id, b_id):
        _encourage_space(a, b)
        _encourage_space(b, a)
    elif distance > preferred + 1.8 and distance < 8.5 and graph.should_approach(a_id, b_id):
        _encourage_contact(a, b, rel)
    elif close_now and not was_close:
        # They notice each other even when neither chooses direct social contact.
        if str(a.current_action) in ["idle", "observe", "investigate"]:
            a.current_action = "observe"
            a.action_timer = randf_range(1.6, 3.1)
        if str(b.current_action) in ["idle", "observe", "investigate"]:
            b.current_action = "observe"
            b.action_timer = randf_range(1.6, 3.1)

func _encounter_quality(a, b, distance: float) -> float:
    var security_a = float(a.state.emotion.get("security", 0.5))
    var security_b = float(b.state.emotion.get("security", 0.5))
    var arousal_a = float(a.state.emotion.get("arousal", 0.4))
    var arousal_b = float(b.state.emotion.get("arousal", 0.4))
    var calm = ((security_a + security_b) * 0.5) - ((arousal_a + arousal_b) * 0.22)
    var distance_quality = 1.0 - clamp(abs(distance - 3.2) / 5.0, 0.0, 1.0)
    var quality = (calm - 0.34) * 0.55 + (distance_quality - 0.5) * 0.22
    if str(a.current_action) in ["withdraw", "hide"] or str(b.current_action) in ["withdraw", "hide"]:
        quality -= 0.30
    if str(a.current_action) in ["play", "social_contact"] or str(b.current_action) in ["play", "social_contact"]:
        quality += 0.18
    return clamp(quality, -0.65, 0.75)

func _shared_resource_context(a, b) -> bool:
    var resource_actions = ["eat", "forage", "root", "enter_water", "wallow"]
    return str(a.current_action) in resource_actions and str(b.current_action) in resource_actions

func _encourage_space(actor, other):
    if str(actor.current_action) in ["eat", "rest", "sleep"]:
        return
    var away = Vector3(
        actor.global_position.x - other.global_position.x,
        0.0,
        actor.global_position.z - other.global_position.z
    )
    if away.length_squared() < 0.02:
        away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
    away = away.normalized()
    actor.current_action = "withdraw"
    actor.move_target = actor.global_position + away * randf_range(2.4, 4.2)
    actor.action_timer = randf_range(2.2, 4.0)

func _encourage_contact(actor, other, relationship):
    if str(actor.current_action) not in ["idle", "investigate", "observe", "patrol", "social_contact"]:
        return
    var trust = float(relationship.get("trust", 0.0))
    if randf() > 0.20 + trust * 0.35:
        return
    var toward = Vector3(other.global_position.x, actor.global_position.y, other.global_position.z)
    var offset = (actor.global_position - toward).normalized() * float(relationship.get("preferred_distance", 3.0))
    actor.current_action = "social_contact"
    actor.move_target = toward + Vector3(offset.x, 0.0, offset.z)
    actor.action_timer = randf_range(2.6, 4.6)

func _maybe_journal_encounter(key: String, a, b, quality: float):
    if journaled_session_pairs.has(key):
        return
    var sanctuary = host.get("sanctuary")
    if sanctuary == null:
        return
    journaled_session_pairs[key] = true
    var text = "%s and %s noticed one another and kept their own space." % [a.display_name(), b.display_name()]
    if quality >= 0.18:
        text = "%s and %s shared a calm encounter in the sanctuary." % [a.display_name(), b.display_name()]
    elif quality <= -0.16:
        text = "%s and %s chose a little more distance from each other." % [a.display_name(), b.display_name()]
    sanctuary.add_journal_event("relationship", key, text, 0.48)

func _persist():
    var sanctuary = host.get("sanctuary")
    if sanctuary != null:
        sanctuary.set_relationships(graph.to_dict())

func _pair_key(a_id: String, b_id: String) -> String:
    return a_id + "::" + b_id if a_id < b_id else b_id + "::" + a_id
