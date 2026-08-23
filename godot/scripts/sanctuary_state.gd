extends RefCounted

const SAVE_VERSION = 3

var animals = {}
var relationships = {}
var settings = {
    "master_volume": 1.0,
    "animal_volume": 1.0,
    "ambience_volume": 0.85,
    "ui_volume": 0.85,
    "haptics": true,
    "show_stats": true,
    "reduced_motion": false,
    "camera_sensitivity": 1.0,
    "time_mode": "automatic"
}
var journal = []
var last_save_unix = 0

func register_animal(animal_id, state_dict):
    animals[str(animal_id)] = state_dict.duplicate(true)

func update_animal(animal_id, state_dict):
    animals[str(animal_id)] = state_dict.duplicate(true)

func animal(animal_id):
    return animals.get(str(animal_id), {})

func set_relationships(data):
    if typeof(data) == TYPE_DICTIONARY:
        relationships = data.duplicate(true)

func add_journal_event(kind, animal_id, text, importance):
    var event = {
        "kind": str(kind),
        "animal_id": str(animal_id),
        "text": str(text),
        "importance": clamp(float(importance), 0.0, 1.0),
        "unix": int(Time.get_unix_time_from_system())
    }
    journal.append(event)
    if journal.size() > 250:
        journal.pop_front()

func recent_journal(limit):
    var count = min(int(limit), journal.size())
    var output = []
    for i in range(count):
        output.append(journal[journal.size() - 1 - i])
    return output

func to_dict():
    return {
        "save_version": SAVE_VERSION,
        "animals": animals,
        "relationships": relationships,
        "settings": settings,
        "journal": journal,
        "last_save_unix": int(Time.get_unix_time_from_system())
    }

func from_dict(data):
    if typeof(data) != TYPE_DICTIONARY:
        return false

    var version = int(data.get("save_version", 1))
    var migrated = _migrate(data, version)

    if typeof(migrated.get("animals", {})) == TYPE_DICTIONARY:
        animals = migrated.get("animals", {}).duplicate(true)
    if typeof(migrated.get("relationships", {})) == TYPE_DICTIONARY:
        relationships = migrated.get("relationships", {}).duplicate(true)
    if typeof(migrated.get("settings", {})) == TYPE_DICTIONARY:
        var incoming_settings = migrated.get("settings", {})
        for key in incoming_settings.keys():
            settings[key] = incoming_settings[key]
    if typeof(migrated.get("journal", [])) == TYPE_ARRAY:
        journal = migrated.get("journal", []).duplicate(true)

    last_save_unix = int(migrated.get("last_save_unix", int(Time.get_unix_time_from_system())))
    return true

func offline_minutes():
    if last_save_unix <= 0:
        return 0.0
    var elapsed = max(0, int(Time.get_unix_time_from_system()) - last_save_unix)
    return clamp(float(elapsed) / 60.0, 0.0, 4320.0)

func _migrate(data, version):
    var result = data.duplicate(true)

    if version < 2:
        if not result.has("settings"):
            result["settings"] = settings.duplicate(true)

    if version < 3:
        if not result.has("relationships"):
            result["relationships"] = {}
        if not result.has("journal"):
            result["journal"] = []
        if result.has("hippo_name") and not result.has("animals"):
            result["animals"] = {
                "hippo_01": {
                    "species_id": "pygmy_hippo",
                    "animal_name": str(result.get("hippo_name", "Mochi")),
                    "bond": float(result.get("bond", 0.30)),
                    "needs": {
                        "hunger": float(result.get("hunger", 0.20)),
                        "energy": float(result.get("energy", 0.85)),
                        "curiosity": float(result.get("curiosity", 0.60)),
                        "thirst": 0.20,
                        "cleanliness": 0.80,
                        "security": 0.75
                    },
                    "interaction_counts": result.get("interaction_counts", {})
                }
            }

    result["save_version"] = SAVE_VERSION
    return result
