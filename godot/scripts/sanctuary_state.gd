extends RefCounted

const SAVE_VERSION = 6

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
    "text_scale": 1.0,
    "time_mode": "automatic",
    "onboarding_complete": false
}
var customization = {
    "interface": {
        "accent_hue": 0.39,
        "glass": 0.82,
        "scale": 1.0
    },
    "world": {
        "vegetation_density": 0.72,
        "water_clarity": 0.72,
        "mud_amount": 0.55,
        "light_warmth": 0.58,
        "weather_life": 0.65,
        "wind_life": 0.55,
        "world_motion": 0.62,
        "auto_living_world": true
    },
    "camera": {
        "bodycam_motion": 0.45
    },
    "animals": {
        "hippo_01": {"name": "Mochi"},
        "pig_01": {"name": "Truffle"},
        "sharpei_01": {"name": "Bao"}
    }
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

func set_customization(data):
    if typeof(data) == TYPE_DICTIONARY:
        customization = data.duplicate(true)

func customization_snapshot():
    return customization.duplicate(true)

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
        "customization": customization,
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
    if typeof(migrated.get("customization", {})) == TYPE_DICTIONARY:
        customization = migrated.get("customization", customization).duplicate(true)
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

    if version < 4:
        if not result.has("settings"):
            result["settings"] = settings.duplicate(true)
        else:
            var migrated_settings = result.get("settings", {})
            if typeof(migrated_settings) == TYPE_DICTIONARY:
                if not migrated_settings.has("text_scale"):
                    migrated_settings["text_scale"] = 1.0
                if not migrated_settings.has("onboarding_complete"):
                    migrated_settings["onboarding_complete"] = true
                result["settings"] = migrated_settings

    if version < 5:
        if not result.has("customization") or typeof(result.get("customization", {})) != TYPE_DICTIONARY:
            result["customization"] = customization.duplicate(true)

    if version < 6:
        var migrated_customization = result.get("customization", customization.duplicate(true))
        if typeof(migrated_customization) != TYPE_DICTIONARY:
            migrated_customization = customization.duplicate(true)
        var custom_animals = migrated_customization.get("animals", {})
        if typeof(custom_animals) != TYPE_DICTIONARY:
            custom_animals = {}
        var saved_animals = result.get("animals", {})
        if typeof(saved_animals) != TYPE_DICTIONARY:
            saved_animals = {}
        var default_names = {
            "hippo_01": "Mochi",
            "pig_01": "Truffle",
            "sharpei_01": "Bao"
        }
        for animal_id in default_names.keys():
            var entry = custom_animals.get(animal_id, {})
            if typeof(entry) != TYPE_DICTIONARY:
                entry = {}
            if not entry.has("name") or str(entry.get("name", "")).strip_edges().is_empty():
                var saved_state = saved_animals.get(animal_id, {})
                var fallback_name = str(default_names[animal_id])
                if typeof(saved_state) == TYPE_DICTIONARY:
                    entry["name"] = str(saved_state.get("animal_name", fallback_name))
                else:
                    entry["name"] = fallback_name
            custom_animals[animal_id] = entry
        migrated_customization["animals"] = custom_animals
        result["customization"] = migrated_customization

    result["save_version"] = SAVE_VERSION
    return result
