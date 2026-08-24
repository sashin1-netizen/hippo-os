extends Node

# Runs before the main scene and upgrades older Hippo OS save payloads in place.
# Migration is deliberately additive: unknown keys are preserved so future versions
# can safely carry forward data written by newer feature modules.

const SAVE_PATH := "user://hippo_save.json"
const BACKUP_PATH := "user://hippo_save.backup.json"
const CURRENT_VERSION := 2

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    _migrate_if_needed()

func _migrate_if_needed():
    if not FileAccess.file_exists(SAVE_PATH):
        return

    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var raw := file.get_as_text()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        _write_backup(raw)
        return

    var data: Dictionary = parsed
    var source_version := int(data.get("save_version", 0))
    if source_version >= CURRENT_VERSION:
        return

    _write_backup(raw)

    if source_version < 1:
        if not data.has("interaction_counts"):
            data["interaction_counts"] = {"pet": 0, "feed": 0, "water": 0, "mud": 0}
        if not data.has("settings"):
            data["settings"] = {}

    if source_version < 2:
        data["cleanliness"] = clamp(float(data.get("cleanliness", 0.76)), 0.0, 1.0)
        data["wetness"] = clamp(float(data.get("wetness", 0.0)), 0.0, 1.0)
        data["mud_coat"] = clamp(float(data.get("mud_coat", 0.0)), 0.0, 1.0)
        if typeof(data.get("personality", {})) != TYPE_DICTIONARY:
            data["personality"] = {}

        var loaded_settings = data.get("settings", {})
        if typeof(loaded_settings) != TYPE_DICTIONARY:
            loaded_settings = {}
        var defaults := {
            "master_volume": 1.0,
            "animal_volume": 1.0,
            "ambience_volume": 0.75,
            "ui_volume": 0.85,
            "haptics": true,
            "show_stats": true,
            "reduced_motion": false,
            "camera_sensitivity": 1.0,
            "text_scale": 1.0,
            "day_night_mode": "auto"
        }
        for key in defaults:
            if not loaded_settings.has(key):
                loaded_settings[key] = defaults[key]
        data["settings"] = loaded_settings

    data["save_version"] = CURRENT_VERSION
    var out := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if out:
        out.store_string(JSON.stringify(data))

func _write_backup(raw: String):
    var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
    if backup:
        backup.store_string(raw)
