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

func launch(label: String, operation: Callable, keep: bool = false, priority: bool = false) -> void:
    results[label] = await queue.run(get_tree(), operation, keep, priority)

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
    good = good and results["old_active"] is Dictionary and results["old_active"].get("revision") == 3 and results["old_queued"] == null and results["new"].get("value") == 6
    saved = JSON.parse_string(FileAccess.get_file_as_string(base))
    good = good and saved.get("revision") == 3 and saved.get("value") == 8
    launch("same_active", store.transaction.bind(base, 3, 5, 150))
    queue.invalidate()
    var restored: Dictionary = await queue.run(get_tree(), store.restore.bind(base))
    good = good and restored.get("revision") == 4 and restored.get("value") == 5
    var rejected = await queue.run(get_tree(), store.transaction.bind(next, 1, -1))
    good = good and rejected.is_empty() and JSON.parse_string(FileAccess.get_file_as_string(next))["value"] == 6
    var ordered: String = base + "_ordered"
    launch("blocking", store.transaction.bind(ordered, 0, 1, 150))
    launch("routine", store.transaction.bind(ordered, 3, 4))
    launch("durable_one", store.transaction.bind(ordered, 1, 2), false, true)
    launch("durable_two", store.transaction.bind(ordered, 2, 3), false, true)
    while not results.has("routine"):
        await get_tree().process_frame
    good = good and results["routine"].get("revision") == 4 and results["durable_one"].get("revision") == 2 and results["durable_two"].get("revision") == 3
    launch("keep_blocking", store.transaction.bind(ordered, 4, 5, 150))
    launch("keep_queued", store.transaction.bind(ordered, 5, 6), true)
    queue.invalidate()
    while not results.has("keep_queued"):
        await get_tree().process_frame
    good = good and results["keep_queued"].get("revision") == 6 and store.restore(ordered).get("value") == 6
    launch("load_flush", store.transaction.bind(ordered, 6, 7, 20))
    queue.flush()
    while not results.has("load_flush"):
        await get_tree().process_frame
    good = good and queue.task == -1 and queue.pending.is_empty() and store.restore(ordered).get("revision") == 7
    print("SAVE_QUEUE_RESULT frames=", frames, " failures=", 0 if good else 1)
    return 0 if good else 1
