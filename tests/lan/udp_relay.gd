extends SceneTree

# Test-only UDP relay for ENet traffic: guest -> relay_port -> host_port, with seeded delay, jitter, loss, reorder, stall and cut.
# Args: relay_port host_port profile seed log_path stop_path
const PROFILES := {
    "clean": {"delay": 0, "jitter": 0, "loss": 0.0, "reorder": 0.0},
    "typical": {"delay": 60, "jitter": 15, "loss": 0.01, "reorder": 0.0},
    "bad": {"delay": 150, "jitter": 40, "loss": 0.03, "reorder": 0.01},
    "spike": {"delay": 60, "jitter": 15, "loss": 0.01, "reorder": 0.0, "stall_every": 20000, "stall_ms": 1500},
    "cut": {"delay": 0, "jitter": 0, "loss": 0.0, "reorder": 0.0, "cut_after": 25000, "cut_ms": 8000},
}
const RECV_BUFFER := 1 << 22
var guest := PacketPeerUDP.new()
var host := PacketPeerUDP.new()
var guest_ip: String = ""
var guest_port: int = 0
var profile: Dictionary
var rng := RandomNumberGenerator.new()
var queue: Array = []  # [due_ms, to_host, bytes]
var stats := {"profile": "", "forwarded": 0, "dropped": 0, "reordered": 0, "stalled": 0, "cut_dropped": 0, "max_delay_ms": 0, "send_errors": 0, "max_loop_gap_ms": 0, "bytes_to_host": 0, "bytes_to_guest": 0}
var first_ms: int = -1
var log_path: String
var stop_path: String
var last_loop_ms: int = -1

func _initialize() -> void:
    var a := OS.get_cmdline_user_args()
    if a.size() != 6 or not PROFILES.has(a[2]):
        push_error("udp_relay: bad arguments")
        quit(2)
        return
    stats["profile"] = a[2]
    profile = PROFILES[a[2]]
    rng.seed = int(a[3])
    log_path = a[4]
    stop_path = a[5]
    # The default 64 KB receive ring overflows on one full ENet window (WARNING "Buffer full, dropping packets"), which is loss on top of the profile.
    if guest.bind(int(a[0]), "127.0.0.1", RECV_BUFFER) != OK or host.bind(0, "127.0.0.1", RECV_BUFFER) != OK:
        push_error("udp_relay: bind failed")
        quit(3)
        return
    host.set_dest_address("127.0.0.1", int(a[1]))
    print("UDP_RELAY_READY ", a[0], " ", a[2])

func _process(_delta: float) -> bool:
    var now: int = Time.get_ticks_msec()
    if last_loop_ms >= 0:
        stats["max_loop_gap_ms"] = maxi(int(stats["max_loop_gap_ms"]), now - last_loop_ms)
    last_loop_ms = now
    while guest.get_available_packet_count() > 0:
        var bytes := guest.get_packet()
        guest_ip = guest.get_packet_ip()
        guest_port = guest.get_packet_port()
        _enqueue(now, true, bytes)
    while host.get_available_packet_count() > 0:
        _enqueue(now, false, host.get_packet())
    var rest: Array = []
    for item in queue:
        if item[0] > now:
            rest.append(item)
        elif item[1]:
            _count_send(host.put_packet(item[2]))
            stats["bytes_to_host"] += item[2].size()
        elif guest_port != 0:
            guest.set_dest_address(guest_ip, guest_port)
            _count_send(guest.put_packet(item[2]))
            stats["bytes_to_guest"] += item[2].size()
    queue = rest
    if FileAccess.file_exists(stop_path):
        var file := FileAccess.open(log_path, FileAccess.WRITE)
        file.store_string(JSON.stringify(stats))
        file.close()
        quit(0)
        return true
    OS.delay_usec(200)
    return false

func _enqueue(now: int, to_host: bool, bytes: PackedByteArray) -> void:
    if first_ms < 0:
        first_ms = now
    var since: int = now - first_ms
    if profile.has("cut_after") and since >= int(profile["cut_after"]) and since < int(profile["cut_after"]) + int(profile["cut_ms"]):
        stats["cut_dropped"] += 1
        return
    if rng.randf() < float(profile["loss"]):
        stats["dropped"] += 1
        return
    var delay: float = float(profile["delay"]) + rng.randf_range(-1.0, 1.0) * float(profile["jitter"])
    if rng.randf() < float(profile["reorder"]):
        delay += 30.0
        stats["reordered"] += 1
    var due: int = now + maxi(0, int(delay))
    if profile.has("stall_every"):
        var phase: int = since % int(profile["stall_every"])
        if since >= int(profile["stall_every"]) and phase < int(profile["stall_ms"]):
            due = maxi(due, now + int(profile["stall_ms"]) - phase)
            stats["stalled"] += 1
    stats["max_delay_ms"] = maxi(int(stats["max_delay_ms"]), due - now)
    stats["forwarded"] += 1
    queue.append([due, to_host, bytes])

func _count_send(err: Error) -> void:
    if err != OK:
        stats["send_errors"] += 1
