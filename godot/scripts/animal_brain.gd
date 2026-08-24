extends RefCounted

var species_id = "pygmy_hippo"
var profile = {}
var temperament = {}
var memory = {}

func _init(new_species_id, species_profile, new_temperament):
    species_id = new_species_id
    profile = species_profile.duplicate(true)
    temperament = new_temperament.duplicate(true)
    memory = {
        "owner_trust": 0.35,
        "owner_familiarity": 0.30,
        "recent_annoyance": 0.0,
        "recent_reward": 0.0,
        "preferred_zone": "",
        "last_action": "idle"
    }

func choose_action(state, context):
    var candidates = {}

    if species_id == "pygmy_hippo":
        _score_hippo(candidates, state, context)
    elif species_id == "pig":
        _score_pig(candidates, state, context)
    elif species_id == "shar_pei":
        _score_shar_pei(candidates, state, context)
    else:
        candidates["idle"] = 1.0

    var best_action = "idle"
    var best_score = -999.0
    for action in candidates.keys():
        var score = float(candidates[action]) + randf_range(-0.04, 0.04)
        if action == str(memory.get("last_action", "")):
            score += 0.03
        if score > best_score:
            best_score = score
            best_action = str(action)

    memory["last_action"] = best_action
    return best_action

func register_owner_interaction(kind, positive):
    memory["owner_familiarity"] = clamp(float(memory.get("owner_familiarity", 0.3)) + 0.004, 0.0, 1.0)
    if positive:
        memory["owner_trust"] = clamp(float(memory.get("owner_trust", 0.35)) + 0.008, 0.0, 1.0)
        memory["recent_reward"] = 1.0
        memory["recent_annoyance"] = max(0.0, float(memory.get("recent_annoyance", 0.0)) - 0.25)
    else:
        memory["recent_annoyance"] = clamp(float(memory.get("recent_annoyance", 0.0)) + 0.18, 0.0, 1.0)

func tick_memory(delta):
    memory["recent_annoyance"] = max(0.0, float(memory.get("recent_annoyance", 0.0)) - delta * 0.025)
    memory["recent_reward"] = max(0.0, float(memory.get("recent_reward", 0.0)) - delta * 0.06)

func _score_hippo(scores, state, context):
    var energy = float(state.get("energy", 0.7))
    var hunger = float(state.get("hunger", 0.2))
    var security = float(state.get("security", 0.7))
    var curiosity = float(state.get("curiosity", 0.5))
    var social_tolerance = float(temperament.get("social_tolerance", 0.48))
    var trust = float(memory.get("owner_trust", 0.35))
    var owner_near = bool(context.get("owner_near", false))
    var is_dusk_or_night = bool(context.get("is_dusk_or_night", false))
    var water_available = bool(context.get("water_available", true))
    var cover_available = bool(context.get("cover_available", true))

    scores["rest"] = (1.0 - energy) * 1.15 + (0.22 if not is_dusk_or_night else 0.0)
    scores["hide"] = (1.0 - security) * 0.90 + (0.18 if cover_available else -0.3)
    scores["enter_water"] = 0.44 + (0.32 if water_available else -0.8)
    scores["forage"] = hunger * 0.95 + (0.18 if is_dusk_or_night else 0.02)
    scores["investigate"] = curiosity * 0.62 + float(temperament.get("boldness", 0.42)) * 0.25
    scores["approach_owner"] = trust * 0.48 + social_tolerance * 0.24 + (0.12 if owner_near else -0.05)
    scores["wallow"] = 0.34 + float(profile.get("behaviour_weights", {}).get("wallow", 0.6)) * 0.30
    scores["play"] = energy * float(temperament.get("playfulness", 0.5)) * 0.55
    scores["mark_territory"] = 0.12 + float(profile.get("behaviour_weights", {}).get("mark_territory", 0.3)) * 0.25
    scores["idle"] = 0.22

    if float(memory.get("recent_annoyance", 0.0)) > 0.45:
        scores["approach_owner"] -= 0.55
        scores["hide"] += 0.42
        scores["enter_water"] += 0.24

func _score_pig(scores, state, context):
    var energy = float(state.get("energy", 0.75))
    var hunger = float(state.get("hunger", 0.25))
    var curiosity = float(state.get("curiosity", 0.72))
    var owner_near = bool(context.get("owner_near", false))
    var enrichment_available = bool(context.get("enrichment_available", true))
    var mud_available = bool(context.get("mud_available", true))

    scores["root"] = 0.55 + curiosity * 0.52
    scores["forage"] = hunger * 1.05 + float(temperament.get("food_motivation", 0.9)) * 0.30
    scores["investigate"] = curiosity * 0.88
    scores["push_object"] = (0.55 if enrichment_available else 0.0) + curiosity * 0.36
    scores["wallow"] = 0.26 + (0.40 if mud_available else -0.25)
    scores["approach_owner"] = float(memory.get("owner_trust", 0.35)) * 0.55 + (0.18 if owner_near else 0.0)
    scores["social_contact"] = float(temperament.get("social_tolerance", 0.82)) * 0.64
    scores["play"] = energy * float(temperament.get("playfulness", 0.7)) * 0.65
    scores["rest"] = (1.0 - energy) * 0.95
    scores["idle"] = 0.12

func _score_shar_pei(scores, state, context):
    var energy = float(state.get("energy", 0.72))
    var security = float(state.get("security", 0.75))
    var owner_near = bool(context.get("owner_near", false))
    var unfamiliar_stimulus = bool(context.get("unfamiliar_stimulus", false))
    var trust = float(memory.get("owner_trust", 0.35))
    var independence = float(temperament.get("independence", 0.78))
    var watchfulness = float(temperament.get("watchfulness", 0.80))

    scores["observe"] = 0.38 + watchfulness * 0.55
    scores["rest_near_owner"] = trust * 0.55 + (0.28 if owner_near else -0.08)
    scores["follow_owner"] = trust * 0.48 + (0.16 if owner_near else 0.0) - independence * 0.10
    scores["patrol"] = energy * watchfulness * 0.46
    scores["investigate"] = float(temperament.get("curiosity", 0.44)) * 0.55
    scores["play"] = energy * float(temperament.get("playfulness", 0.48)) * 0.52
    scores["approach_owner"] = trust * 0.58
    scores["withdraw"] = (1.0 - security) * 0.62 + (0.42 if unfamiliar_stimulus else 0.0)
    scores["rest"] = (1.0 - energy) * 1.02 + independence * 0.14
    scores["idle"] = 0.20

    if float(memory.get("recent_annoyance", 0.0)) > 0.40:
        scores["withdraw"] += 0.48
        scores["approach_owner"] -= 0.32
        scores["follow_owner"] -= 0.22
