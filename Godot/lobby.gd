extends Control

const Discovery = preload("res://discovery.gd")
const SESSION_ID_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
var discovery := Discovery.new()
var session: ENetMultiplayerPeer
var host_button: Button
var join_button: Button
var exit_button: Button
var game_list: ItemList
var game_id: LineEdit
var feedback: Label
var hosted: Label
var network_status: Label
var network_address: LineEdit
var listed_ids: Array[String] = []
var local_addresses: Array[String] = []
var joining_screen: Control
var joining := false
var join_target: Dictionary = {}
var connected_game_id := ""

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	var title := add_label(column, "MOOOZE TANKS  /  ALPHA LOBBY")
	title.add_theme_font_size_override("font_size", 30)
	add_label(column, "Host a local session. Discover games on this computer or local network.")
	# Match LobbyImage.jpeg: stacked actions beside the game list.
	var lobby_row := HBoxContainer.new()
	lobby_row.add_theme_constant_override("separation", 32)
	column.add_child(lobby_row)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 200
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 18)
	lobby_row.add_child(controls)
	host_button = add_button(controls, "Host")
	host_button.pressed.connect(host_game)
	join_button = add_button(controls, "Join")
	join_button.disabled = true
	join_button.tooltip_text = "Select a game or enter its ID to join."
	join_button.pressed.connect(join_game)
	exit_button = add_button(controls, "Exit")
	exit_button.disabled = true
	exit_button.tooltip_text = "Exit means leave the hosted session. Leaving is incomplete for alpha."
	var games_column := VBoxContainer.new()
	games_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	games_column.add_theme_constant_override("separation", 12)
	lobby_row.add_child(games_column)
	var games_title := add_label(games_column, "List of Games")
	games_title.add_theme_font_size_override("font_size", 28)
	game_list = ItemList.new()
	game_list.custom_minimum_size = Vector2(0, 280)
	game_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_list.item_selected.connect(select_game)
	games_column.add_child(game_list)
	game_id = LineEdit.new()
	game_id.placeholder_text = "Enter a game ID"
	game_id.text_changed.connect(identify_game)
	games_column.add_child(game_id)
	feedback = add_label(column, "No games available. Ask another user to press Host.")
	hosted = add_label(column, "No session hosted.")
	for address in IP.get_local_addresses():
		if address.is_valid_ip_address() and not address.contains(":") and not address.begins_with("127."):
			local_addresses.append(address)
	add_label(column, "This laptop's IPv4: " + (", ".join(local_addresses) if not local_addresses.is_empty() else "No LAN IPv4 address found"))
	network_address = LineEdit.new()
	network_address.placeholder_text = "If no game appears: enter the host laptop's IPv4 and press Enter"
	network_address.text_submitted.connect(set_network_address)
	column.add_child(network_address)
	network_status = add_label(column, "LAN discovery active. Both laptops must allow Godot on the local network.")
	discovery.games_changed.connect(refresh_games)
	discovery.discovery_failed.connect(discovery_error)
	discovery.network_warning.connect(func(message: String): network_status.text = message)
	refresh_games()
	add_child(discovery)
	# Use the existing ENet transport with Godot's multiplayer lifecycle signals.
	multiplayer.connected_to_server.connect(join_connected)
	multiplayer.connection_failed.connect(join_failed)
	multiplayer.server_disconnected.connect(join_server_disconnected)

func add_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func add_button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 64)
	button.add_theme_font_size_override("font_size", 28)
	parent.add_child(button)
	return button

func host_game() -> void:
	# Guard the action as well as the button: one server per hosting instance.
	if session != null:
		return
	if discovery.bound_port == -1:
		feedback.text = "Cannot host without discovery. Close another local lobby and restart."
		return
	session = ENetMultiplayerPeer.new()
	var result := create_host_session()
	if result != OK:
		feedback.text = "Hosting failed: %s. Try Host again." % error_string(result)
		session = null
		return
	var id := generate_session_id()
	discovery.hosted_game = {"id": id, "port": session.get_host().get_local_port()}
	# Joining requires the existing host endpoint to accept and poll peers.
	multiplayer.multiplayer_peer = session
	discovery.advertise()
	host_button.disabled = true
	var endpoints: Array[String] = []
	for address in local_addresses:
		endpoints.append("%s:%d" % [address, discovery.hosted_game["port"]])
	if endpoints.is_empty():
		endpoints.append("127.0.0.1:%d (no LAN address found)" % discovery.hosted_game["port"])
	hosted.text = "HOSTED SESSION  |  %s\nServer: %s" % [id, ", ".join(endpoints)]
	feedback.text = "Hosting is active. Verify this ID appears in the other user's lobby."
	refresh_games()

func create_host_session() -> Error:
	return session.create_server(0, 1)

func generate_session_id() -> String:
	var id := ""
	for index in range(6):
		id += SESSION_ID_CHARACTERS[randi_range(0, SESSION_ID_CHARACTERS.length() - 1)]
	return id

func refresh_games() -> void:
	var selected := game_id.text.strip_edges().to_upper()
	game_list.clear()
	listed_ids.clear()
	var entries := discovery.games.duplicate()
	if not discovery.hosted_game.is_empty():
		var own_id: String = discovery.hosted_game["id"]
		entries[own_id] = {"id": own_id, "address": local_addresses[0] if not local_addresses.is_empty() else "127.0.0.1", "port": discovery.hosted_game["port"]}
	var ids: Array = entries.keys()
	ids.sort()
	for id in ids:
		listed_ids.append(str(id))
		game_list.add_item("%s  |  %s:%d  |  discovery only" % [id, entries[id]["address"], entries[id]["port"]])
		if id == selected:
			game_list.select(game_list.item_count - 1)
	if entries.is_empty():
		feedback.text = "No games available. Ask another user to press Host."
	elif not selected.is_empty():
		identify_game(selected)
	else:
		feedback.text = "%d hosted session(s) found. Select one to see its game ID." % entries.size()
	if not connected_game_id.is_empty():
		feedback.text = "Connected to game %s. Waiting in the lobby." % connected_game_id
	update_join_button()

func select_game(index: int) -> void:
	game_id.text = listed_ids[index]
	identify_game(game_id.text)

func identify_game(value: String) -> void:
	var id := value.strip_edges().to_upper()
	if id.is_empty():
		feedback.text = "Select a game or enter its ID. Joining is unavailable in alpha."
	elif listed_ids.has(id):
		feedback.text = "Identified %s. Select Join to connect." % id
	else:
		feedback.text = "No available game matches this ID. Check the ID or wait for its host."
	update_join_button()

func update_join_button() -> void:
	join_button.disabled = joining or session != null or (joining_screen != null and joining_screen.visible) or not discovery.games.has(game_id.text.strip_edges().to_upper())

func join_game() -> void:
	if joining or session != null:
		return
	var id := game_id.text.strip_edges().to_upper()
	if not discovery.games.has(id):
		update_join_button()
		return
	join_target = discovery.games[id].duplicate()
	start_join()

func start_join() -> void:
	if joining or session != null:
		return
	joining = true
	join_button.disabled = true
	if joining_screen == null:
		joining_screen = preload("res://joining_screen.gd").new()
		add_child(joining_screen)
		joining_screen.retry_requested.connect(start_join)
		joining_screen.back_requested.connect(join_back)
		joining_screen.timed_out.connect(join_failed)
	# Hiding the previous UI also removes its mouse/keyboard focus targets.
	get_child(0).hide()
	joining_screen.begin()
	# Show the screen immediately; start the network attempt on the next frame.
	await get_tree().process_frame
	if not joining or not is_inside_tree():
		return
	session = ENetMultiplayerPeer.new()
	var result := session.create_client(join_target["address"], int(join_target["port"]))
	if result != OK:
		join_failed()
		return
	multiplayer.multiplayer_peer = session

func join_connected() -> void:
	if not joining:
		return
	joining = false
	connected_game_id = join_target["id"]
	joining_screen.timeout.stop()
	joining_screen.hide()
	get_child(0).show()
	host_button.disabled = true
	feedback.text = "Connected to game %s. Waiting in the lobby." % connected_game_id
	update_join_button()

func join_failed() -> void:
	if not joining:
		return
	joining = false
	multiplayer.multiplayer_peer = null
	if session != null:
		session.close()
		session = null
	joining_screen.show_failure()

func join_back() -> void:
	joining_screen.timeout.stop()
	joining_screen.hide()
	get_child(0).show()
	refresh_games()
	# Allow another attempt after Back, including a stale target (which may fail).
	join_button.disabled = false
	join_button.grab_focus()

func join_server_disconnected() -> void:
	if connected_game_id.is_empty():
		join_failed()
		return
	connected_game_id = ""
	joining = true
	get_child(0).hide()
	joining_screen.show()
	join_failed()
	host_button.disabled = discovery.bound_port == -1

func discovery_error(message: String) -> void:
	host_button.disabled = true
	feedback.text = message
	network_status.text = message

func set_network_address(value: String) -> void:
	if not discovery.set_direct_address(value):
		network_status.text = "Enter a valid IPv4 address, such as 192.168.1.25 (not a game ID)."
	elif discovery.direct_address.is_empty():
		network_status.text = "Automatic LAN discovery active. Manual host lookup cleared."
	else:
		network_status.text = "Looking for hosted games at %s. If none appear, check both firewalls and Wi-Fi isolation." % discovery.direct_address

func _exit_tree() -> void:
	if session != null:
		session.close()
