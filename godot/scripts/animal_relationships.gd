extends RefCounted

var relationships = {}

func ensure_pair(a_id, b_id):
    var key = _pair_key(a_id, b_id)
    if not relationships.has(key):
        relationships[key] = {
            "familiarity": 0.0,
            "trust": 0.0,
            "interest": 0.30,
            "avoidance": 0.25,
            "play_compatibility": 0.20,
            "resource_tension": 0.0,
            "preferred_distance": 3.0,
            "encounters": 0
        }
    return relationships[key]

func register_encounter(a_id, b_id, quality, distance, shared_resource):
    var key = _pair_key(a_id, b_id)
    var rel = ensure_pair(a_id, b_id)
    rel["encounters"] = int(rel.get("encounters", 0)) + 1
    rel["familiarity"] = clamp(float(rel.get("familiarity", 0.0)) + 0.018, 0.0, 1.0)

    if quality > 0.0:
        rel["trust"] = clamp(float(rel.get("trust", 0.0)) + quality * 0.025, 0.0, 1.0)
        rel["avoidance"] = clamp(float(rel.get("avoidance", 0.25)) - quality * 0.020, 0.0, 1.0)
        rel["interest"] = clamp(float(rel.get("interest", 0.30)) + quality * 0.018, 0.0, 1.0)
    elif quality < 0.0:
        rel["trust"] = clamp(float(rel.get("trust", 0.0)) + quality * 0.035, 0.0, 1.0)
        rel["avoidance"] = clamp(float(rel.get("avoidance", 0.25)) - quality * 0.040, 0.0, 1.0)
        rel["resource_tension"] = clamp(float(rel.get("resource_tension", 0.0)) - quality * 0.025, 0.0, 1.0)

    if shared_resource:
        rel["resource_tension"] = clamp(float(rel.get("resource_tension", 0.0)) + 0.03, 0.0, 1.0)

    rel["preferred_distance"] = clamp(lerp(float(rel.get("preferred_distance", 3.0)), float(distance), 0.10), 1.0, 8.0)
    relationships[key] = rel

func relationship(a_id, b_id):
    return ensure_pair(a_id, b_id)

func should_approach(a_id, b_id):
    var rel = ensure_pair(a_id, b_id)
    var score = float(rel.get("trust", 0.0)) * 0.55 + float(rel.get("interest", 0.3)) * 0.35 - float(rel.get("avoidance", 0.25)) * 0.65
    return score + randf_range(-0.10, 0.10) > 0.30

func should_avoid(a_id, b_id):
    var rel = ensure_pair(a_id, b_id)
    var score = float(rel.get("avoidance", 0.25)) * 0.70 + float(rel.get("resource_tension", 0.0)) * 0.40 - float(rel.get("trust", 0.0)) * 0.45
    return score + randf_range(-0.08, 0.08) > 0.38

func to_dict():
    return relationships

func from_dict(data):
    if typeof(data) == TYPE_DICTIONARY:
        relationships = data.duplicate(true)

func _pair_key(a_id, b_id):
    var ids = [str(a_id), str(b_id)]
    ids.sort()
    return str(ids[0]) + "::" + str(ids[1])
