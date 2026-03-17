extends SceneTree

func _init() -> void:
    var peer = OfflineMultiplayerPeer.new()
    get_multiplayer().multiplayer_peer = peer
    print("RESULT: ", get_multiplayer().is_server())
    quit()