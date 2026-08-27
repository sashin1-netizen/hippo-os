extends Node

signal snapshot_committed(revision: int)
signal sync_event_queued(event_id: String)
signal source_recovered(source_name: String)

const STORE_PATH := "user://hippo_offline_state.json"
const STORE_TEMP_PATH := "user://hippo_offline_state.tmp.json"
const STORE_BACKUP_PATH := "user://hippo_offline_state.backup.json"
const SCHEMA_VERSION := 1
const SNAPSHOT_INTERVAL := 5.0
const MAX_SYNC_EVENTS := 128

const SOURCES := {
    "game": "user://hippo_save.json",
    "animal_minds": "user://animal_minds.json"
}

var state: Dictionary = {}
var elapsed := 0.0
var last_source_fingerprints: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = -900
    state = _load_store_with_recovery()
    _ensure_schema()
    _recover_corrupt_sources()
    _capture_sources(false)
    _commit_store()

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < SNAPSHOT_INTERVAL:
        return
    elapsed = 0.0
    if _capture_sources(true):
        _commit_store()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _capture_sources(true)
        _commit_store()

func _exit_tree() -> void:
    _capture_sources(true)
    _commit_store()

func get_pending_sync_events() -> Array:
    var queue_variant: Variant = state.get("sync_queue", [])
    if typeof(queue_variant) != TYPE_ARRAY:
        return []
    return (queue_variant as Array).duplicate(true)

func acknowledge_sync_event(event_id: String) -> bool:
    var queue: Array = state.get("sync_queue", []) as Array
    for index in range(queue.size() - 1, -1, -1):
        var item_variant: Variant = queue[index]
        if typeof(item_variant) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("id", "")) == event_id:
            queue.remove_at(index)
            state["sync_queue"] = queue
            _commit_store()
            return true
    return false

func mark_sync_attempt(event_id: String, error_message: String = "") -> void:
    var queue: Array = state.get("sync_queue", []) as Array
    for item_variant: Variant in queue:
        if typeof(item_variant) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = item_variant as Dictionary
        if str(item.get("id", "")) != event_id:
            continue
        item["attempt_count"] = int(item.get("attempt_count", 0)) + 1
        item["last_attempt_unix"] = int(Time.get_unix_time_from_system())
        item["last_error"] = error_message.left(240)
        break
    state["sync_queue"] = queue
    _commit_store()

func force_snapshot() -> void:
    _capture_sources(true)
    _commit_store()

func _ensure_schema() -> void:
    if typeof(state) != TYPE_DICTIONARY:
        state = {}
    state["schema_version"] = SCHEMA_VERSION
    if not state.has("revision"):
        state["revision"] = 0
    if typeof(state.get("sources", {})) != TYPE_DICTIONARY:
        state["sources"] = {}
    if typeof(state.get("sync_queue", [])) != TYPE_ARRAY:
        state["sync_queue"] = []
    if not state.has("created_unix"):
        state["created_unix"] = int(Time.get_unix_time_from_system())

func _capture_sources(queue_changes: bool) -> bool:
    var changed := false
    var sources: Dictionary = state.get("sources", {}) as Dictionary
    for source_name_variant: Variant in SOURCES.keys():
        var source_name := str(source_name_variant)
        var path := str(SOURCES[source_name])
        var payload_variant: Variant = _read_json_dictionary(path)
        if typeof(payload_variant) != TYPE_DICTIONARY:
            continue
        var payload: Dictionary = payload_variant as Dictionary
        var serialized := JSON.stringify(payload)
        var fingerprint := serialized.sha256_text()
        if str(last_source_fingerprints.get(source_name, "")) == fingerprint:
            continue
        last_source_fingerprints[source_name] = fingerprint
        sources[source_name] = {
            "captured_unix": int(Time.get_unix_time_from_system()),
            "sha256": fingerprint,
            "payload": payload.duplicate(true)
        }
        changed = true
        if queue_changes:
            _queue_sync_event(source_name, fingerprint, payload)
    state["sources"] = sources
    return changed

func _queue_sync_event(source_name: String, fingerprint: String, payload: Dictionary) -> void:
    var queue: Array = state.get("sync_queue", []) as Array
    var event_id := "%s-%s-%s" % [source_name, str(Time.get_ticks_usec()), fingerprint.left(12)]
    queue.append({
        "id": event_id,
        "schema_version": SCHEMA_VERSION,
        "source": source_name,
        "created_unix": int(Time.get_unix_time_from_system()),
        "payload_sha256": fingerprint,
        "payload": payload.duplicate(true),
        "attempt_count": 0,
        "last_attempt_unix": 0,
        "last_error": ""
    })
    while queue.size() > MAX_SYNC_EVENTS:
        queue.pop_front()
    state["sync_queue"] = queue
    sync_event_queued.emit(event_id)

func _recover_corrupt_sources() -> void:
    var sources_variant: Variant = state.get("sources", {})
    if typeof(sources_variant) != TYPE_DICTIONARY:
        return
    var sources: Dictionary = sources_variant as Dictionary
    for source_name_variant: Variant in SOURCES.keys():
        var source_name := str(source_name_variant)
        var path := str(SOURCES[source_name])
        if _is_valid_json_dictionary(path):
            continue
        var snapshot_variant: Variant = sources.get(source_name, {})
        if typeof(snapshot_variant) != TYPE_DICTIONARY:
            continue
        var snapshot: Dictionary = snapshot_variant as Dictionary
        var payload_variant: Variant = snapshot.get("payload", {})
        if typeof(payload_variant) != TYPE_DICTIONARY:
            continue
        if _write_json_atomic(path, payload_variant as Dictionary):
            source_recovered.emit(source_name)
            print("HippoOS offline persistence recovered source: %s" % source_name)

func _load_store_with_recovery() -> Dictionary:
    var primary_variant: Variant = _read_json_dictionary(STORE_PATH)
    if typeof(primary_variant) == TYPE_DICTIONARY:
        return primary_variant as Dictionary
    var backup_variant: Variant = _read_json_dictionary(STORE_BACKUP_PATH)
    if typeof(backup_variant) == TYPE_DICTIONARY:
        return backup_variant as Dictionary
    return {}

func _commit_store() -> void:
    _ensure_schema()
    state["revision"] = int(state.get("revision", 0)) + 1
    state["updated_unix"] = int(Time.get_unix_time_from_system())
    if not _write_json_atomic(STORE_PATH, state):
        push_warning("HippoOS offline persistence could not commit snapshot")
        return
    snapshot_committed.emit(int(state.get("revision", 0)))

func _write_json_atomic(path: String, payload: Dictionary) -> bool:
    var temp_path := STORE_TEMP_PATH if path == STORE_PATH else "%s.tmp" % path
    var backup_path := STORE_BACKUP_PATH if path == STORE_PATH else "%s.backup" % path
    var temp := FileAccess.open(temp_path, FileAccess.WRITE)
    if temp == null:
        return false
    temp.store_string(JSON.stringify(payload))
    temp.flush()
    temp = null

    var dir := DirAccess.open("user://")
    if dir == null:
        return false
    var final_name := path.trim_prefix("user://")
    var temp_name := temp_path.trim_prefix("user://")
    var backup_name := backup_path.trim_prefix("user://")
    if dir.file_exists(backup_name):
        dir.remove(backup_name)
    if dir.file_exists(final_name):
        if dir.rename(final_name, backup_name) != OK:
            return false
    if dir.rename(temp_name, final_name) != OK:
        if dir.file_exists(backup_name) and not dir.file_exists(final_name):
            dir.rename(backup_name, final_name)
        return false
    return true

func _read_json_dictionary(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return null
    return parsed

func _is_valid_json_dictionary(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return true
    return typeof(_read_json_dictionary(path)) == TYPE_DICTIONARY
