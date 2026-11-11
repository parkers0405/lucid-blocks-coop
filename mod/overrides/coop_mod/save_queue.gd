extends RefCounted

# File-store calls only: captured paths/data, no scene nodes or game resources.
class Job extends RefCounted:
    var operation: Callable
    var target: RefCounted
    var result: Variant = null
    var done: bool = false
    var generation: int

var pending: Array[Job] = []
var active: Job
var task: int = -1
var generation: int = 0

func run(tree: SceneTree, operation: Callable) -> Variant:
    assert(operation.get_object() is RefCounted and not operation.get_object() is Node)
    var job := Job.new()
    job.operation = operation
    job.target = operation.get_object()
    job.generation = generation
    pending.append(job)
    while not job.done:
        poll()
        await tree.process_frame
    return job.result if job.generation == generation else null

func poll() -> void:
    if task >= 0:
        if not WorkerThreadPool.is_task_completed(task):
            return
        WorkerThreadPool.wait_for_task_completion(task)
        active.done = true
        active = null
        task = -1
    while not pending.is_empty():
        active = pending.pop_front()
        if active.generation != generation:
            active.done = true
            continue
        task = WorkerThreadPool.add_task(_execute.bind(active))
        break

func _execute(job: Job) -> void:
    job.result = job.operation.call()

func invalidate() -> void:
    generation += 1
