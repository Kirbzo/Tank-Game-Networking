extends Node
var reported: Dictionary = {}
var acknowledged := false

@rpc("any_peer", "call_remote", "reliable")
func report(positions: Dictionary) -> void:
	if multiplayer.is_server():
		reported = positions

@rpc("authority", "call_remote", "reliable")
func acknowledge() -> void:
	acknowledged = true
