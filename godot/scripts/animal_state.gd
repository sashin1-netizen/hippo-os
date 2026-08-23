extends RefCounted

var species_id = "pygmy_hippo"
var animal_name = "Mochi"

var needs = {
    "hunger": 0.20,
    "energy": 0.85,
    "thirst": 0.20,
    "cleanliness": 0.80,
    "security": 0.75,
    "curiosity": 0.60
}

var emotion = {
    "valence": 0.55,
    "arousal": 0.35,
    "security": 0.75,
    "social_motivation": 0.50,
    "curiosity": 0.60
}

var bond = 0.30
var temperament = {}
var interaction_counts = {}
var learned_preferences = {
    "foods": {},
    "touch_regions": {},
    "zones": {},
    "activities": {}
}

func setup(new_species_id, new_name, new_temperament):
    species_id = new_species_id
    animal_name = new_name
    temperament = new_temperament.duplicate(true)

func tick(delta, species_profile):
    var minutes = delta / 60.0
    needs["hunger"] = clamp(float(needs.get("hunger", 0.2)) + 0.005 * minutes, 0.0, 1.0)
    needs["energy"] = clamp(float(needs.get("energy", 0.85)) - 0.0035 * minutes, 0.0, 1.0)
    needs["thirst"] = clamp(float(needs.get("thirst", 0.2)) + 0.004 * minutes, 0.0, 1.0)
    needs["curiosity"] = clamp(float(needs.get("curiosity", 0.6)) - 0.002 * minutes, 0.0, 1.0)
    _update_emotion(species_profile)

func apply_rest(amount):
    needs["energy"] = clamp(float(needs.get("energy", 0.5)) + amount, 0.0, 1.0)
    emotion["arousal"] = max(0.0, float(emotion.get("arousal", 0.3)) - amount * 0.35)

func apply_food(food_id, nutrition, reward):
    needs["hunger"] = clamp(float(needs.get("hunger", 0.2)) - nutrition, 0.0, 1.0)
    emotion["valence"] = clamp(float(emotion.get("valence", 0.5)) + reward * 0.15, 0.0, 1.0)
    bond = clamp(bond + reward * 0.012, 0.0, 1.0)
    _learn_preference("foods", food_id, reward)
    _increment("feed")

func apply_water(amount):
    needs["thirst"] = clamp(float(needs.get("thirst", 0.2)) - amount, 0.0, 1.0)

func apply_pet(region, quality):
    emotion["valence"] = clamp(float(emotion.get("valence", 0.5)) + quality * 0.08, 0.0, 1.0)
    emotion["social_motivation"] = clamp(float(emotion.get("social_motivation", 0.5)) + quality * 0.04, 0.0, 1.0)
    bond = clamp(bond + quality * 0.008, 0.0, 1.0)
    _learn_preference("touch_regions", region, quality)
    _increment("pet")

func apply_unwanted_interaction(intensity):
    emotion["valence"] = clamp(float(emotion.get("valence", 0.5)) - intensity * 0.10, 0.0, 1.0)
    emotion["social_motivation"] = clamp(float(emotion.get("social_motivation", 0.5)) - intensity * 0.14, 0.0, 1.0)
    emotion["security"] = clamp(float(emotion.get("security", 0.75)) - intensity * 0.08, 0.0, 1.0)

func remember_zone(zone_id, reward):
    _learn_preference("zones", zone_id, reward)

func remember_activity(activity_id, reward):
    _learn_preference("activities", activity_id, reward)

func offline_simulate(minutes):
    var safe_minutes = clamp(float(minutes), 0.0, 4320.0)
    needs["hunger"] = clamp(float(needs.get("hunger", 0.2)) + safe_minutes * 0.0025, 0.0, 1.0)
    needs["thirst"] = clamp(float(needs.get("thirst", 0.2)) + safe_minutes * 0.0020, 0.0, 1.0)
    needs["energy"] = clamp(float(needs.get("energy", 0.85)) + safe_minutes * 0.0014, 0.0, 1.0)
    emotion["arousal"] = max(0.12, float(emotion.get("arousal", 0.35)) - safe_minutes * 0.0005)

func to_dict():
    return {
        "species_id": species_id,
        "animal_name": animal_name,
        "needs": needs,
        "emotion": emotion,
        "bond": bond,
        "temperament": temperament,
        "interaction_counts": interaction_counts,
        "learned_preferences": learned_preferences
    }

func from_dict(data):
    species_id = str(data.get("species_id", species_id))
    animal_name = str(data.get("animal_name", animal_name))
    if typeof(data.get("needs", {})) == TYPE_DICTIONARY:
        needs = data.get("needs", needs)
    if typeof(data.get("emotion", {})) == TYPE_DICTIONARY:
        emotion = data.get("emotion", emotion)
    bond = clamp(float(data.get("bond", bond)), 0.0, 1.0)
    if typeof(data.get("temperament", {})) == TYPE_DICTIONARY:
        temperament = data.get("temperament", temperament)
    if typeof(data.get("interaction_counts", {})) == TYPE_DICTIONARY:
        interaction_counts = data.get("interaction_counts", interaction_counts)
    if typeof(data.get("learned_preferences", {})) == TYPE_DICTIONARY:
        learned_preferences = data.get("learned_preferences", learned_preferences)

func _update_emotion(species_profile):
    var energy = float(needs.get("energy", 0.8))
    var hunger = float(needs.get("hunger", 0.2))
    var security = float(needs.get("security", 0.75))
    var curiosity = float(needs.get("curiosity", 0.6))
    emotion["security"] = security
    emotion["curiosity"] = curiosity
    emotion["arousal"] = clamp((1.0 - energy) * 0.25 + curiosity * 0.45 + hunger * 0.20, 0.0, 1.0)
    emotion["valence"] = clamp(0.55 + bond * 0.22 - hunger * 0.18 - (1.0 - security) * 0.26, 0.0, 1.0)

func _learn_preference(category, key, reward):
    if not learned_preferences.has(category):
        learned_preferences[category] = {}
    var bucket = learned_preferences[category]
    var previous = float(bucket.get(key, 0.0))
    bucket[key] = clamp(previous * 0.85 + reward * 0.15, -1.0, 1.0)
    learned_preferences[category] = bucket

func _increment(key):
    interaction_counts[key] = int(interaction_counts.get(key, 0)) + 1
