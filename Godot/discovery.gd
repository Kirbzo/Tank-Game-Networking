extends Node
## Alpha discovery only. No player joining or gameplay messages are accepted.
signal games_changed
signal discovery_failed(message: String)

const FIRST_PORT := 49140
const SLOT_COUNT := 16
const PROTOCOL := "moooze-alpha-1"
const EXPIRY_MS := 4000
var instance_id := Crypto.new().generate_random_bytes(12).hex_encode()
var games: Dictionary = {}
var hosted_game: Dictionary = {}
var socket := PacketPeerUDP.new()
var bound_port := -1
var elapsed := 0.0

func _ready() -> void:
	for port in range(FIRST_PORT, FIRST_PORT + SLOT_COUNT):
		if socket.bind(port) == OK:
			bound_port = port
			break
	if bound_port == -1:
		discovery_failed.emit("Discovery unavailable: all 16 local lobby slots are in use.")
		return
	socket.set_broadcast_enabled(true)

func _process(delta: float) -> void:
	if bound_port == -1:
		return
	while socket.get_available_packet_count() > 0:
		var packet := socket.get_packet()
		var address := socket.get_packet_ip()
		if packet.size() > 1024:
			continue
		var value: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not value is Dictionary:
			continue
		var data: Dictionary = value
		if data.get("protocol") != PROTOCOL or data.get("instance") == instance_id:
			continue
		var id := str(data.get("id", ""))
		var port := int(data.get("port", 0))
		if not id.begins_with("MT-") or id.length() != 27 or port < 1 or port > 65535:
			continue
		var is_new := not games.has(id)
		games[id] = {"id": id, "address": address, "port": port, "seen": Time.get_ticks_msec()}
		if is_new:
			games_changed.emit()
	var expired: Array = []
	for id in games:
		if Time.get_ticks_msec() - int(games[id]["seen"]) > EXPIRY_MS:
			expired.append(id)
	for id in expired:
		games.erase(id)
	if not expired.is_empty():
		games_changed.emit()
	elapsed += delta
	if elapsed >= 0.75:
		elapsed = 0.0
		advertise()

func advertise() -> void:
	if hosted_game.is_empty() or bound_port == -1:
		return
	var data := hosted_game.duplicate()
	data["protocol"] = PROTOCOL
	data["instance"] = instance_id
	var packet := JSON.stringify(data).to_utf8_buffer()
	# Separate listening ports allow multiple processes on one computer.
	for port in range(FIRST_PORT, FIRST_PORT + SLOT_COUNT):
		for address in ["127.0.0.1", "255.255.255.255"]:
			socket.set_dest_address(address, port)
			socket.put_packet(packet)

func _exit_tree() -> void:
	socket.close()
