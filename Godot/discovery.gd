extends Node
## Alpha discovery only. No player joining or gameplay messages are accepted.
signal games_changed
signal discovery_failed(message: String)
signal network_warning(message: String)

const FIRST_PORT := 49140
const SLOT_COUNT := 16
const PROTOCOL := "moooze-alpha-1"
var protocol := PROTOCOL
const EXPIRY_MS := 4000
var instance_id := Crypto.new().generate_random_bytes(12).hex_encode()
var games: Dictionary = {}
var hosted_game: Dictionary = {}
var socket := PacketPeerUDP.new()
var bound_port := -1
var elapsed := 0.0
var direct_address := ""
var broadcast_enabled := true
var warned_send_error := false

func _ready() -> void:
	for port in range(FIRST_PORT, FIRST_PORT + SLOT_COUNT):
		# Explicit IPv4 binding matches LAN IPv4 broadcast/unicast destinations.
		if socket.bind(port, "0.0.0.0") == OK:
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
		var sender_port := socket.get_packet_port()
		if packet.size() > 1024:
			continue
		var value: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not value is Dictionary:
			continue
		var data: Dictionary = value
		if data.get("protocol") != protocol or data.get("instance") == instance_id:
			continue
		if data.get("type") == "query":
			if not hosted_game.is_empty():
				send_packet(address, sender_port, announcement())
			continue
		var id := str(data.get("id", ""))
		if not (data.get("port") is float or data.get("port") is int):
			continue
		var port := int(data.get("port", 0))
		if not id.begins_with("MT-") or id.length() != 27 or port < 1 or port > 65535:
			continue
		var is_new: bool = not games.has(id) or games[id]["address"] != address
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
		query_direct_host()

func set_direct_address(value: String) -> bool:
	var address := value.strip_edges()
	if not address.is_empty() and (not address.is_valid_ip_address() or address.contains(":")):
		return false
	direct_address = address
	warned_send_error = false
	query_direct_host()
	return true

func query_direct_host() -> void:
	if direct_address.is_empty() or bound_port == -1:
		return
	var packet := JSON.stringify({"protocol": protocol, "instance": instance_id, "type": "query"}).to_utf8_buffer()
	for port in range(FIRST_PORT, FIRST_PORT + SLOT_COUNT):
		send_packet(direct_address, port, packet)

func announcement() -> PackedByteArray:
	var data := hosted_game.duplicate()
	data["protocol"] = protocol
	data["instance"] = instance_id
	data["type"] = "announcement"
	return JSON.stringify(data).to_utf8_buffer()

func send_packet(address: String, port: int, packet: PackedByteArray) -> void:
	var result := socket.set_dest_address(address, port)
	if result == OK:
		result = socket.put_packet(packet)
	if result != OK and not warned_send_error:
		warned_send_error = true
		network_warning.emit("Discovery send failed (%s). Check your network and firewall." % error_string(result))

func advertise() -> void:
	if hosted_game.is_empty() or bound_port == -1:
		return
	if not broadcast_enabled:
		return
	var packet := announcement()
	# Separate listening ports allow multiple processes on one computer.
	for port in range(FIRST_PORT, FIRST_PORT + SLOT_COUNT):
		for address in ["127.0.0.1", "255.255.255.255"]:
			send_packet(address, port, packet)

func _exit_tree() -> void:
	socket.close()
