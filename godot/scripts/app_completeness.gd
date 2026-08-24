extends Node

# Finished-feature layer for the Grasslands Sanctuary experience.
# Persists dated companion memories and upgrades Customize/Collection sheets
# without duplicating the core simulation owned by main.gd and CompanionRoster.

const SAVE_PATH := "user://hippo_app_features.json"
const SAVE_VERSION := 1
const SPECIES := ["hippo", "pig", "sharpei"]
const MAX_MEMORIES_PER_COMPANION := 80

var scene_root: Node3D
var roster: Node
var hud: Node
var grasslands: Node
var state: Dictionary = {}
var previous_hippo_counts: Dictionary = {}
var previous_companion_state: Dictionary = {}
var selected_species_last := ""
var tick := 0.0
var save_dirty := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 320
    _load_state()
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(360):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        var hud_candidate := get_node_or_null("/root/SanctuaryHUD")
        if candidate is Node3D and roster_candidate != null and hud_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            hud = hud_candidate
            grasslands = get_node_or_null("/root/GrasslandsSanctuary")
            break
        await get_tree().process_frame

    if scene_root == null or roster == null or hud == null:
        push_warning("AppCompleteness could not bind to the sanctuary UI")
        return

    _ensure_state_shape()
    _snapshot_interactions()
    _seed_first_memories()
    _apply_customization()
    set_process(true)

func _process(delta: float) -> void:
    if scene_root == null or roster == null or hud == null:
        return
    tick -= delta
    if tick > 0.0:
        return
    tick = 0.35
    _track_memories()
    _sync_active_sheet()
    if save_dirty:
        _save_state()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        if save_dirty:
            _save_state()

func _load_state() -> void:
    state = {
        "version": SAVE_VERSION,
        "memories": {"hippo": [], "pig": [], "sharpei": []},
        "customization": {
            "grass_density": "lush",
            "atmosphere": "cinematic",
            "camera_style": "hero"
        }
    }
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var loaded := parsed as Dictionary
    if typeof(loaded.get("memories", null)) == TYPE_DICTIONARY:
        state["memories"] = loaded["memories"]
    if typeof(loaded.get("customization", null)) == TYPE_DICTIONARY:
        state["customization"] = loaded["customization"]
    _ensure_state_shape()

func _ensure_state_shape() -> void:
    if typeof(state.get("memories", null)) != TYPE_DICTIONARY:
        state["memories"] = {}
    var memories := state["memories"] as Dictionary
    for species in SPECIES:
        if typeof(memories.get(species, null)) != TYPE_ARRAY:
            memories[species] = []
    state["memories"] = memories

    if typeof(state.get("customization", null)) != TYPE_DICTIONARY:
        state["customization"] = {}
    var customization := state["customization"] as Dictionary
    if not customization.has("grass_density"):
        customization["grass_density"] = "lush"
    if not customization.has("atmosphere"):
        customization["atmosphere"] = "cinematic"
    if not customization.has("camera_style"):
        customization["camera_style"] = "hero"
    state["customization"] = customization
    state["version"] = SAVE_VERSION

func _save_state() -> void:
    _ensure_state_shape()
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("AppCompleteness could not save companion memories")
        return
    file.store_string(JSON.stringify(state, "  "))
    save_dirty = false

func _seed_first_memories() -> void:
    var memories := state["memories"] as Dictionary
    var seeded := false
    if (memories["hippo"] as Array).is_empty():
        _record_memory("hippo", "Sanctuary life began — a safe place to explore, rest, play and bond.", "milestone", true)
        seeded = true
    if (memories["pig"] as Array).is_empty():
        _record_memory("pig", "Porky joined the sanctuary and started exploring the grasslands.", "milestone", true)
        seeded = true
    if (memories["sharpei"] as Array).is_empty():
        _record_memory("sharpei", "Bao joined the sanctuary and began quietly watching the world.", "milestone", true)
        seeded = true
    if seeded:
        _save_state()

func _snapshot_interactions() -> void:
    var counts_variant: Variant = scene_root.get("interaction_counts")
    previous_hippo_counts = (counts_variant as Dictionary).duplicate(true) if typeof(counts_variant) == TYPE_DICTIONARY else {}
    previous_companion_state.clear()
    var companions := _companions()
    for species in ["pig", "sharpei"]:
        var data_variant: Variant = companions.get(species, {})
        if typeof(data_variant) != TYPE_DICTIONARY:
            continue
        var data := data_variant as Dictionary
        previous_companion_state[species] = {
            "bond": float(data.get("bond", 0.0)),
            "hunger": float(data.get("hunger", 0.0)),
            "action": str(data.get("action", "idle")),
            "call_until": float(data.get("call_until", 0.0))
        }
    selected_species_last = str(roster.get("selected_species"))

func _track_memories() -> void:
    _track_hippo_interactions()
    _track_companion_interactions("pig")
    _track_companion_interactions("sharpei")
    var selected := str(roster.get("selected_species"))
    if selected != selected_species_last and selected in SPECIES:
        _record_memory(selected, "%s became the focus of today's sanctuary visit." % _display_name(selected), "focus")
        selected_species_last = selected

func _track_hippo_interactions() -> void:
    var counts_variant: Variant = scene_root.get("interaction_counts")
    if typeof(counts_variant) != TYPE_DICTIONARY:
        return
    var counts := counts_variant as Dictionary
    var event_copy := {
        "pet": "Shared a calm petting moment and strengthened your bond.",
        "feed": "Accepted a meal in the sanctuary.",
        "water": "Spent time splashing and cooling off in the pond.",
        "mud": "Enjoyed another muddy sanctuary session."
    }
    for key in event_copy.keys():
        var before := int(previous_hippo_counts.get(key, 0))
        var now := int(counts.get(key, 0))
        if now > before:
            _record_memory("hippo", str(event_copy[key]), str(key))
    previous_hippo_counts = counts.duplicate(true)

func _track_companion_interactions(species: String) -> void:
    var companions := _companions()
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return
    var data := data_variant as Dictionary
    var previous_variant: Variant = previous_companion_state.get(species, {})
    var previous := previous_variant as Dictionary if typeof(previous_variant) == TYPE_DICTIONARY else {}

    var bond_now := float(data.get("bond", 0.0))
    var hunger_now := float(data.get("hunger", 0.0))
    var action_now := str(data.get("action", "idle"))
    var call_now := float(data.get("call_until", 0.0))
    var bond_before := float(previous.get("bond", bond_now))
    var hunger_before := float(previous.get("hunger", hunger_now))
    var action_before := str(previous.get("action", action_now))
    var call_before := float(previous.get("call_until", call_now))

    if hunger_before - hunger_now > 0.10:
        _record_memory(species, "%s happily accepted a treat." % _display_name(species), "feed")
    elif bond_now - bond_before >= 0.012:
        _record_memory(species, "%s shared an affectionate petting moment with you." % _display_name(species), "pet")
    if call_now > call_before + 1.0:
        _record_memory(species, "%s heard your call and came closer." % _display_name(species), "call")
    if action_now != action_before and action_now in ["play", "rest", "happy"]:
        var action_text := {
            "play": "%s had a playful burst of energy in the grasslands.",
            "rest": "%s settled down for a peaceful rest.",
            "happy": "%s looked especially content after your interaction."
        }
        _record_memory(species, str(action_text[action_now]) % _display_name(species), action_now, false, 45)

    previous_companion_state[species] = {
        "bond": bond_now,
        "hunger": hunger_now,
        "action": action_now,
        "call_until": call_now
    }

func _record_memory(species: String, text: String, kind := "moment", force := false, dedupe_seconds := 12) -> void:
    if not species in SPECIES:
        return
    _ensure_state_shape()
    var memories := state["memories"] as Dictionary
    var list := memories[species] as Array
    var now_unix := int(Time.get_unix_time_from_system())
    if not force and not list.is_empty():
        var last_variant: Variant = list[0]
        if typeof(last_variant) == TYPE_DICTIONARY:
            var last := last_variant as Dictionary
            if str(last.get("text", "")) == text and now_unix - int(last.get("unix", 0)) < dedupe_seconds:
                return
    list.push_front({
        "unix": now_unix,
        "stamp": _timestamp(),
        "text": text,
        "kind": kind
    })
    while list.size() > MAX_MEMORIES_PER_COMPANION:
        list.pop_back()
    memories[species] = list
    state["memories"] = memories
    save_dirty = true

func _timestamp() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d  %02d:%02d" % [
        int(dt.get("year", 2026)), int(dt.get("month", 1)), int(dt.get("day", 1)),
        int(dt.get("hour", 0)), int(dt.get("minute", 0))
    ]

func _sync_active_sheet() -> void:
    var panel_variant: Variant = hud.get("sheet_panel")
    var title_variant: Variant = hud.get("sheet_title")
    var body_variant: Variant = hud.get("sheet_body")
    if not (panel_variant is Control) or not (title_variant is Label) or not (body_variant is Label):
        return
    var panel := panel_variant as Control
    if not panel.visible:
        return
    var title := title_variant as Label
    var body := body_variant as Label
    match title.text:
        "JOURNAL":
            body.text = journal_text(str(roster.get("selected_species")))
        "CUSTOMIZE SANCTUARY":
            _upgrade_customize_sheet(body)
        "YOUR COLLECTION":
            body.text = _collection_text()
        "COMPANIONS":
            body.text = _companions_text()

func journal_text(species: String) -> String:
    if not species in SPECIES:
        species = "hippo"
    var snapshot := _snapshot_text(species)
    var result := "%s'S JOURNAL\n\n%s\n\nRECENT MEMORIES\n" % [_display_name(species).to_upper(), snapshot]
    var memories := state["memories"] as Dictionary
    var list := memories.get(species, []) as Array
    if list.is_empty():
        return result + "No memories recorded yet. Spend time together in the sanctuary."
    var shown := mini(8, list.size())
    for i in range(shown):
        var entry_variant: Variant = list[i]
        if typeof(entry_variant) != TYPE_DICTIONARY:
            continue
        var entry := entry_variant as Dictionary
        result += "\n• %s\n  %s\n" % [str(entry.get("stamp", "")), str(entry.get("text", ""))]
    return result

func _snapshot_text(species: String) -> String:
    if species == "hippo":
        return "Bond %d%%  •  Energy %d%%  •  Hunger %d%%\nNow: %s" % [
            int(float(scene_root.get("bond")) * 100.0),
            int(float(scene_root.get("energy")) * 100.0),
            int(float(scene_root.get("hunger")) * 100.0),
            str(scene_root.get("current_action")).capitalize()
        ]
    var data := _companion_data(species)
    return "Bond %d%%  •  Energy %d%%  •  Hunger %d%%\nNow: %s" % [
        int(float(data.get("bond", 0.0)) * 100.0),
        int(float(data.get("energy", 0.0)) * 100.0),
        int(float(data.get("hunger", 0.0)) * 100.0),
        str(data.get("action", "exploring")).capitalize()
    ]

func _upgrade_customize_sheet(body: Label) -> void:
    var customization := state["customization"] as Dictionary
    var grass := str(customization.get("grass_density", "lush"))
    var atmosphere := str(customization.get("atmosphere", "cinematic"))
    var camera_style := str(customization.get("camera_style", "hero"))
    var settings_variant: Variant = scene_root.get("settings")
    var day_mode := "auto"
    if typeof(settings_variant) == TYPE_DICTIONARY:
        day_mode = str((settings_variant as Dictionary).get("day_night_mode", "auto"))
    body.text = "SANCTUARY CUSTOMIZATION\n\nGrass density: %s\nAtmosphere: %s\nLighting: %s\nCamera framing: %s\n\nChanges apply to the live 3D sanctuary and persist on this device." % [grass.to_upper(), atmosphere.to_upper(), day_mode.to_upper(), camera_style.to_upper()]
    if hud.has_method("_configure_sheet_button"):
        hud.call("_configure_sheet_button", 0, "GRASS: %s" % grass.to_upper(), Callable(self, "_cycle_grass"))
        hud.call("_configure_sheet_button", 1, "AIR: %s" % atmosphere.to_upper(), Callable(self, "_cycle_atmosphere"))
        hud.call("_configure_sheet_button", 2, "LIGHT: %s" % day_mode.to_upper(), Callable(self, "_cycle_day_mode"))
        hud.call("_configure_sheet_button", 3, "CAM: %s" % camera_style.to_upper(), Callable(self, "_cycle_camera_style"))

func _cycle_grass() -> void:
    var customization := state["customization"] as Dictionary
    var current := str(customization.get("grass_density", "lush"))
    customization["grass_density"] = "balanced" if current == "lush" else ("max" if current == "balanced" else "lush")
    state["customization"] = customization
    _apply_customization()
    save_dirty = true
    _pulse_haptic(12)

func _cycle_atmosphere() -> void:
    var customization := state["customization"] as Dictionary
    var current := str(customization.get("atmosphere", "cinematic"))
    customization["atmosphere"] = "clear" if current == "cinematic" else ("soft" if current == "clear" else "cinematic")
    state["customization"] = customization
    _apply_customization()
    save_dirty = true
    _pulse_haptic(12)

func _cycle_day_mode() -> void:
    var settings_variant: Variant = scene_root.get("settings")
    if typeof(settings_variant) != TYPE_DICTIONARY:
        return
    var settings := settings_variant as Dictionary
    var current := str(settings.get("day_night_mode", "auto"))
    settings["day_night_mode"] = "day" if current == "auto" else ("night" if current == "day" else "auto")
    scene_root.set("settings", settings)
    if scene_root.has_method("_apply_day_night"):
        scene_root.call("_apply_day_night")
    if scene_root.has_method("_save_state"):
        scene_root.call("_save_state")
    if grasslands != null and grasslands.has_method("_update_daylight"):
        grasslands.call("_update_daylight")
    _pulse_haptic(12)

func _cycle_camera_style() -> void:
    var customization := state["customization"] as Dictionary
    var current := str(customization.get("camera_style", "hero"))
    var next := "close" if current == "hero" else ("wide" if current == "close" else "hero")
    customization["camera_style"] = next
    state["customization"] = customization
    var distance := 5.5 if next == "close" else (7.2 if next == "wide" else 6.2)
    scene_root.set("orbit_distance", distance)
    save_dirty = true
    _pulse_haptic(12)

func _apply_customization() -> void:
    if scene_root == null:
        return
    var customization := state["customization"] as Dictionary
    var grass_mode := str(customization.get("grass_density", "lush"))
    var grass := scene_root.find_child("GrassField", true, false) as MultiMeshInstance3D
    if grass != null and grass.multimesh != null:
        var target := 420
        if grass_mode == "balanced":
            target = 300
        elif grass_mode == "max":
            target = grass.multimesh.instance_count
        grass.multimesh.visible_instance_count = mini(target, grass.multimesh.instance_count)

    var world_environment := scene_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
    if world_environment != null and world_environment.environment != null:
        var atmosphere := str(customization.get("atmosphere", "cinematic"))
        match atmosphere:
            "clear":
                world_environment.environment.fog_density = 0.004
                world_environment.environment.fog_height_density = 0.045
            "soft":
                world_environment.environment.fog_density = 0.020
                world_environment.environment.fog_height_density = 0.11
            _:
                world_environment.environment.fog_density = 0.012
                world_environment.environment.fog_height_density = 0.085

func _collection_text() -> String:
    return "YOUR COMPANIONS\n\nMOCHI  •  Baby pygmy hippo\n%s\n\nPORKY  •  Pig\n%s\n\nBAO  •  Shar-Pei\n%s\n\nAll three remain active in the sanctuary while you focus on one." % [_compact_stats("hippo"), _compact_stats("pig"), _compact_stats("sharpei")]

func _companions_text() -> String:
    var selected := str(roster.get("selected_species"))
    return "SELECTED: %s\n\n%s\n\nUse the companion buttons below to move the hero camera, HUD and action controls to another animal. Their autonomous routines continue in the background." % [_display_name(selected).to_upper(), _snapshot_text(selected)]

func _compact_stats(species: String) -> String:
    if species == "hippo":
        return "Bond %d%%  •  Energy %d%%" % [int(float(scene_root.get("bond")) * 100.0), int(float(scene_root.get("energy")) * 100.0)]
    var data := _companion_data(species)
    return "Bond %d%%  •  Energy %d%%" % [int(float(data.get("bond", 0.0)) * 100.0), int(float(data.get("energy", 0.0)) * 100.0)]

func _companions() -> Dictionary:
    var companions_variant: Variant = roster.get("companions") if roster != null else {}
    return companions_variant as Dictionary if typeof(companions_variant) == TYPE_DICTIONARY else {}

func _companion_data(species: String) -> Dictionary:
    var data_variant: Variant = _companions().get(species, {})
    return data_variant as Dictionary if typeof(data_variant) == TYPE_DICTIONARY else {}

func _display_name(species: String) -> String:
    if species == "hippo" and scene_root != null:
        return str(scene_root.get("hippo_name"))
    var data := _companion_data(species)
    var fallback := "Porky" if species == "pig" else ("Bao" if species == "sharpei" else "Mochi")
    return str(data.get("name", fallback))

func _pulse_haptic(duration: int) -> void:
    var settings_variant: Variant = scene_root.get("settings") if scene_root != null else null
    if typeof(settings_variant) == TYPE_DICTIONARY and bool((settings_variant as Dictionary).get("haptics", true)):
        Input.vibrate_handheld(duration)
