extends Node

class Store extends RefCounted:
    func restore(path: String) -> Dictionary:
        return JSON.parse_string(FileAccess.get_file_as_string(path))
    func transaction(path: String, revision: int, value: int, delay: int = 0) -> Dictionary:
        OS.delay_msec(delay)
        var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"revision": 0}
        if previous["revision"] != revision or value < 0:
            return {}
        var file := FileAccess.open(path + ".pending", FileAccess.WRITE)
        var saved: Dictionary = {"revision": revision + 1, "value": value}
        file.store_string(JSON.stringify(saved))
        file.flush()
        file.close()
        return saved if DirAccess.rename_absolute(path + ".pending", path) == OK else {}

var queue = preload("res://coop_mod/save_queue.gd").new()
var store := Store.new()
var results: Dictionary = {}
var frames: int = 0

func _process(_delta: float) -> void:
    frames += 1

func launch(label: String, operation: Callable) -> void:
    results[label] = await queue.run(get_tree(), operation)

func run() -> int:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var base: String = "user://save-queue-" + str(Time.get_ticks_usec())
    launch("first", store.transaction.bind(base, 0, 10, 200))
    launch("second", store.transaction.bind(base, 1, 9))
    launch("stale", store.transaction.bind(base, 0, 99))
    while results.size() < 3:
        await get_tree().process_frame
    var good: bool = results["first"].get("revision") == 1 and results["second"].get("revision") == 2 and results["stale"].is_empty() and frames > 2
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base))
    good = good and saved.get("revision") == 2 and saved.get("value") == 9
    launch("old_active", store.transaction.bind(base, 2, 8, 150))
    launch("old_queued", store.transaction.bind(base, 3, 7))
    queue.invalidate()
    var next: String = base + "_next"
    launch("new", store.transaction.bind(next, 0, 6))
    while results.size() < 6:
        await get_tree().process_frame
    good = good and results["old_active"] == null and results["old_queued"] == null and results["new"].get("value") == 6
    saved = JSON.parse_string(FileAccess.get_file_as_string(base))
    good = good and saved.get("revision") == 3 and saved.get("value") == 8
    launch("same_active", store.transaction.bind(base, 3, 5, 150))
    queue.invalidate()
    var restored: Dictionary = await queue.run(get_tree(), store.restore.bind(base))
    good = good and restored.get("revision") == 4 and restored.get("value") == 5
    var rejected = await queue.run(get_tree(), store.transaction.bind(next, 1, -1))
    good = good and rejected.is_empty() and JSON.parse_string(FileAccess.get_file_as_string(next))["value"] == 6
    print("SAVE_QUEUE_RESULT frames=", frames, " failures=", 0 if good else 1)
    return 0 if good else 1
