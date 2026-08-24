extends RefCounted

const SAVE_VERSION = 6
const MAX_OFFLINE_MINUTES = 4320.0
const MAX_JOURNAL_EVENTS = 250

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
    if typeof(state_dict) == TYPE_DICTIONARY:
        animals[str(animal_id)] = state_dict.duplicate(true)

func update_animal(animal_id, state_dict):
    if typeof(state_dict) == TYPE_DICTIONARY:
        animals[str(animal_id)] = state_dict.duplicate(true)

func animal(animal_id):
    return animals.get(str(animal_id), {})

func set_relationships(data):
    if typeof(data) == TYPE_DICTIONARY:
        relationships = data.duplicate(true)

func set_customization(data):
    if typeof(data) != TYPE_DICTIONARY:
        return
    var merged = customization.duplicate(true)
    _deep_merge(merged, data)
    customization = merged
    _sanitize_customization()

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
    while journal.size() > MAX_JOURNAL_EVENTS:
        journal.pop_front()

func recent_journal(limit):
    var count = min(max(int(limit), 0), journal.size())
    var output = []
    for i in range(count):
        output.append(journal[journal.size() - 1 - i])
    return output

func to_dict():
    return {
        "save_version": SAVE_VERSION,
        "animals": animals.duplicate(true),
        "relationships": relationships.duplicate(true),
        "settings": settings.duplicate(true),
        "customization": customization.duplicate(true),
        "journal": journal.duplicate(true),
        "last_save_unix": int(Time.get_unix_time_from_system())
    }

func from_dict(data):
    if typeof(data) != TYPE_DICTIONARY:
        return false

    var version = int(data.get("save_version", 1))
    if version < 1 or version > SAVE_VERSION:
        return false

    var migrated = _migrate(data, version)
    if typeof(migrated) != TYPE_DICTIONARY:
        return false
    if typeof(migrated.get("animals", {})) != TYPE_DICTIONARY:
        return false
    if typeof(migrated.get("relationships", {})) != TYPE_DICTIONARY:
        return false
    if typeof(migrated.get("settings", {})) != TYPE_DICTIONARY:
        return false
    if typeof(migrated.get("customization", {})) != TYPE_DICTIONARY:
        return false
    if typeof(migrated.get("journal", [])) != TYPE_ARRAY:
        return false

    animals = migrated.get("animals", {}).duplicate(true)
    relationships = migrated.get("relationships", {}).duplicate(true)

    var incoming_settings = migrated.get("settings", {})
    for key in incoming_settings.keys():
        if settings.has(key):
            settings[key] = incoming_settings[key]
    _sanitize_settings()

    var merged_customization = customization.duplicate(true)
    _deep_merge(merged_customization, migrated.get("customization", {}))
    customization = merged_customization
    _sanitize_customization()

    journal = []
    for entry in migrated.get("journal", []):
        if typeof(entry) == TYPE_DICTIONARY:
            journal.append(entry.duplicate(true))
    while journal.size() > MAX_JOURNAL_EVENTS:
        journal.pop_front()

    var now = int(Time.get_unix_time_from_system())
    last_save_unix = int(migrated.get("last_save_unix", now))
    # A device clock can move backwards/forwards. A save timestamp far in the future
    # must never create negative or impossible offline simulation later.
    last_save_unix = clamp(last_save_unix, 0, now + 300)
    return true

func offline_minutes():
    if last_save_unix <= 0:
        return 0.0
    var elapsed = max(0, int(Time.get_unix_time_from_system()) - last_save_unix)
    return clamp(float(elapsed) / 60.0, 0.0, MAX_OFFLINE_MINUTES)

func _sanitize_settings():
    settings["master_volume"] = clamp(float(settings.get("master_volume", 1.0)), 0.0, 1.0)
    settings["animal_volume"] = clamp(float(settings.get("animal_volume", 1.0)), 0.0, 1.0)
    settings["ambience_volume"] = clamp(float(settings.get("ambience_volume", 0.85)), 0.0, 1.0)
    settings["ui_volume"] = clamp(float(settings.get("ui_volume", 0.85)), 0.0, 1.0)
    settings["camera_sensitivity"] = clamp(float(settings.get("camera_sensitivity", 1.0)), 0.4, 2.0)
    settings["text_scale"] = clamp(float(settings.get("text_scale", 1.0)), 0.85, 1.35)
    settings["haptics"] = bool(settings.get("haptics", true))
    settings["show_stats"] = bool(settings.get("show_stats", true))
    settings["reduced_motion"] = bool(settings.get("reduced_motion", false))
    settings["onboarding_complete"] = bool(settings.get("onboarding_complete", false))
    if str(settings.get("time_mode", "automatic")) != "automatic":
        settings["time_mode"] = "automatic"

func _sanitize_customization():
    var interface = customization.get("interface", {})
    if typeof(interface) != TYPE_DICTIONARY:
        interface = {}
    interface["accent_hue"] = clamp(float(interface.get("accent_hue", 0.39)), 0.0, 1.0)
    interface["glass"] = clamp(float(interface.get("glass", 0.82)), 0.25, 1.0)
    interface["scale"] = clamp(float(interface.get("scale", 1.0)), 0.85, 1.25)
    customization["interface"] = interface

    var world = customization.get("world", {})
    if typeof(world) != TYPE_DICTIONARY:
        world = {}
    var world_defaults = {
        "vegetation_density": 0.72,
        "water_clarity": 0.72,
        "mud_amount": 0.55,
        "light_warmth": 0.58,
        "weather_life": 0.65,
        "wind_life": 0.55,
        "world_motion": 0.62
    }
    for key in world_defaults.keys():
        world[key] = clamp(float(world.get(key, world_defaults[key])), 0.0, 1.0)
    world["auto_living_world"] = bool(world.get("auto_living_world", true))
    customization["world"] = world

    var camera = customization.get("camera", {})
    if typeof(camera) != TYPE_DICTIONARY:
        camera = {}
    camera["bodycam_motion"] = clamp(float(camera.get("bodycam_motion", 0.45)), 0.0, 1.0)
    customization["camera"] = camera

    var custom_animals = customization.get("animals", {})
    if typeof(custom_animals) != TYPE_DICTIONARY:
        custom_animals = {}
    var default_names = {
        "hippo_01": "Mochi",
        "pig_01": "Truffle",
        "sharpei_01": "Bao"
    }
    for animal_id in default_names.keys():
        var entry = custom_animals.get(animal_id, {})
        if typeof(entry) != TYPE_DICTIONARY:
            entry = {}
        var clean_name = str(entry.get("name", default_names[animal_id])).strip_edges()
        if clean_name.is_empty():
            clean_name = default_names[animal_id]
        entry["name"] = clean_name.substr(0, min(clean_name.length(), 24))
        entry["body_scale"] = clamp(float(entry.get("body_scale", 1.0)), 0.88, 1.12)
        entry["skin_warmth"] = clamp(float(entry.get("skin_warmth", 0.5)), 0.0, 1.0)
        entry["pattern_strength"] = clamp(float(entry.get("pattern_strength", 0.25)), 0.0, 1.0)
        entry["eye_brightness"] = clamp(float(entry.get("eye_brightness", 0.5)), 0.0, 1.0)
        entry["curiosity_bias"] = clamp(float(entry.get("curiosity_bias", 0.5)), 0.0, 1.0)
        entry["social_bias"] = clamp(float(entry.get("social_bias", 0.5)), 0.0, 1.0)
        entry["energy_bias"] = clamp(float(entry.get("energy_bias", 0.5)), 0.0, 1.0)
        custom_animals[animal_id] = entry
    customization["animals"] = custom_animals

func _deep_merge(target: Dictionary, source: Dictionary):
    for key in source.keys():
        var incoming = source[key]
        if typeof(incoming) == TYPE_DICTIONARY and typeof(target.get(key, null)) == TYPE_DICTIONARY:
            var nested = target[key]
            _deep_merge(nested, incoming)
            target[key] = nested
        else:
            target[key] = incoming

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

    if not result.has("animals"):
        result["animals"] = {}
    if not result.has("relationships"):
        result["relationships"] = {}
    if not result.has("settings"):
        result["settings"] = settings.duplicate(true)
    if not result.has("customization"):
        result["customization"] = customization.duplicate(true)
    if not result.has("journal"):
        result["journal"] = []

    result["save_version"] = SAVE_VERSION
    return result
