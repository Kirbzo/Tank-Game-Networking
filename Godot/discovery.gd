extends Node
## Alpha discovery only. No player joining or gameplay messages are accepted.
signal games_changed
signal discovery_failed(message: String)
signal network_warning(message: String)

const FIRST_PORT := 49140
const SLOT_COUNT := 16
const PROTOCOL := "moooze-alpha-2"
const ID_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
var protocol := PROTOCOL
const EXPIRY_MS := 4000
var instance_id := Crypto.new().generate_random_bytes(12).hex_encode()
var games: Dictionary = {}
var hosted_game: Dictionary = {}
var socket := PacketPeerUDP.new()
var interface_sockets: Array[PacketPeerUDP] = []
var bound_port := -1
var elapsed := 0.0
var direct_address := ""
var broadcast_enabled := true
var announcements_enabled := true
var lookup_id := ""
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
	# A wildcard socket sends limited broadcasts over the default route only.
	# Bind senders to each IPv4 interface so Wi-Fi, Ethernet and VM LANs work.
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var peer := PacketPeerUDP.new()
		if peer.bind(0, address) == OK:
			peer.set_broadcast_enabled(true)
			interface_sockets.append(peer)

func _process(delta: float) -> void:
	if bound_port == -1:
		return
	read_packets(socket)
	for peer in interface_sockets:
		read_packets(peer)
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
		if not lookup_id.is_empty():
			query_lan()

func read_packets(peer: PacketPeerUDP) -> void:
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		var address := peer.get_packet_ip()
		var sender_port := peer.get_packet_port()
		if packet.size() > 1024:
			continue
		var value: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if not value is Dictionary:
			continue
		var data: Dictionary = value
		if data.get("protocol") != protocol or data.get("instance") == instance_id:
			continue
		if data.get("type") == "query":
			var requested_id := str(data.get("id", ""))
			if not hosted_game.is_empty() and (requested_id.is_empty() or requested_id == hosted_game["id"]):
				send_packet(address, sender_port, announcement())
			continue
		var id := str(data.get("id", ""))
		if not (data.get("port") is float or data.get("port") is int):
			continue
		var port := int(data.get("port", 0))
		if data.get("type") != "announcement" or not valid_game_id(id) or port < 1 or port > 65535:
			continue
		var is_new: bool = not games.has(id) or games[id]["address"] != address
		games[id] = {"id": id, "address": address, "port": port, "seen": Time.get_ticks_msec()}
		if is_new:
			games_changed.emit()

func set_direct_address(value: String) -> bool:
	var address := value.strip_edges()
	if not address.is_empty() and (not address.is_valid_ip_address() or address.contains(":")):
		return false
	direct_address = address
	warned_send_error = false
	query_direct_host()
	return true

func valid_game_id(id: String) -> bool:
	if id.length() != 6:
		return false
	for character in id:
		if not ID_CHARACTERS.contains(character):
			return false
	return true

func create_game_id() -> String:
	var id := ""
	while id.length() < 6:
		var value := int(Crypto.new().generate_random_bytes(1)[0])
		# Rejection sampling keeps all 36 characters equally likely.
		if value < 252:
			id += ID_CHARACTERS[value % ID_CHARACTERS.length()]
	if games.has(id):
		return create_game_id()
	return id

func reload_games(value: String, requested_id: String = "") -> bool:
	var normalized_id := requested_id.strip_edges().to_upper()
	if not normalized_id.is_empty() and not valid_game_id(normalized_id):
		return false
	# Validate both fields before changing the active lookup.
	var address := value.strip_edges()
	if not address.is_empty() and (not address.is_valid_ip_address() or address.contains(":")):
		return false
	lookup_id = normalized_id
	if not set_direct_address(value):
		return false
	if bound_port == -1:
		discovery_failed.emit("Discovery unavailable: restart after freeing a local lobby slot.")
		return true
	query_lan()
	advertise()
	return true

func query_packet() -> PackedByteArray:
	return JSON.stringify({"protocol": protocol, "instance": instance_id, "type": "query", "id": lookup_id}).to_utf8_buffer()

func query_lan() -> void:
	if not broadcast_enabled or bound_port == -1:
		return
	var packet := query_packet()
	send_lan_packet(packet)

func send_lan_packet(packet: PackedByteArray) -> void:
	for port in range(FIRST_PORT, FIRST_PORT + SLOT_COUNT):
		send_packet("127.0.0.1", port, packet)
		if interface_sockets.is_empty():
			send_packet("255.255.255.255", port, packet)
		for peer in interface_sockets:
			send_packet("255.255.255.255", port, packet, peer)

func query_direct_host() -> void:
	if direct_address.is_empty() or bound_port == -1:
		return
	var packet := query_packet()
	for port in range(FIRST_PORT, FIRST_PORT + SLOT_COUNT):
		send_packet(direct_address, port, packet)

func announcement() -> PackedByteArray:
	var data := hosted_game.duplicate()
	data["protocol"] = protocol
	data["instance"] = instance_id
	data["type"] = "announcement"
	return JSON.stringify(data).to_utf8_buffer()

func send_packet(address: String, port: int, packet: PackedByteArray, peer: PacketPeerUDP = null) -> void:
	var sender := socket if peer == null else peer
	var result := sender.set_dest_address(address, port)
	if result == OK:
		result = sender.put_packet(packet)
	if result != OK and not warned_send_error:
		warned_send_error = true
		network_warning.emit("Discovery send failed (%s). Check your network and firewall." % error_string(result))

func advertise() -> void:
	if hosted_game.is_empty() or bound_port == -1:
		return
	if not broadcast_enabled or not announcements_enabled:
		return
	send_lan_packet(announcement())

func _exit_tree() -> void:
	socket.close()
	for peer in interface_sockets:
		peer.close()
