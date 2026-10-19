extends Control

const Discovery = preload("res://discovery.gd")
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
var reload_button: Button
var listed_ids: Array[String] = []

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
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	host_button = add_button(controls, "Host")
	host_button.pressed.connect(host_game)
	join_button = add_button(controls, "Join")
	join_button.disabled = true
	join_button.tooltip_text = "Real joining is deferred to WP2."
	exit_button = add_button(controls, "Exit")
	exit_button.disabled = true
	exit_button.tooltip_text = "Exit means leave the hosted session. Leaving is incomplete for alpha."
	hosted = add_label(column, "No session hosted. Only Host is functional in this alpha.")
	var addresses: Array[String] = []
	for address in IP.get_local_addresses():
		if address.is_valid_ip_address() and not address.contains(":") and not address.begins_with("127."):
			addresses.append(address)
	add_label(column, "This laptop's IPv4: " + (", ".join(addresses) if not addresses.is_empty() else "No LAN IPv4 address found"))
	network_address = LineEdit.new()
	network_address.placeholder_text = "If no game appears: enter the host laptop's IPv4 and press Reload"
	network_address.text_submitted.connect(set_network_address)
	column.add_child(network_address)
	network_status = add_label(column, "LAN discovery active. Both laptops must allow Godot on the local network.")
	add_label(column, "AVAILABLE GAMES  /  select an entry to identify its session")
	game_list = ItemList.new()
	game_list.custom_minimum_size = Vector2(0, 210)
	game_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_list.item_selected.connect(select_game)
	column.add_child(game_list)
	game_id = LineEdit.new()
	game_id.placeholder_text = "Optional: enter the 6-character session ID, then press Reload to find its listing"
	game_id.text_changed.connect(identify_game)
	game_id.text_submitted.connect(func(_value: String): set_network_address(network_address.text))
	column.add_child(game_id)
	reload_button = add_button(column, "Reload")
	reload_button.pressed.connect(func(): set_network_address(network_address.text))
	feedback = add_label(column, "No games available. Ask another user to press Host.")
	add_label(column, "ALPHA WALKTHROUGH\n1. Working: Host starts a session and advertises its ID to other lobbies.\n2. Explanation only: select a game or enter its ID; Join stays disabled until WP2.\n3. Explanation only: Exit will leave the hosted session. Leaving is incomplete.\nClose the window to end this alpha process; its listing expires after four seconds.")
	discovery.games_changed.connect(refresh_games)
	discovery.discovery_failed.connect(discovery_error)
	discovery.network_warning.connect(func(message: String): network_status.text = message)
	refresh_games()
	add_child(discovery)

func add_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func add_button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 44)
	parent.add_child(button)
	return button

func host_game() -> void:
	if discovery.bound_port == -1:
		feedback.text = "Cannot host without discovery. Close another local lobby and restart."
		return
	session = ENetMultiplayerPeer.new()
	var result := session.create_server(0, 1)
	if result != OK:
		feedback.text = "Hosting failed: %s. Try Host again." % error_string(result)
		session = null
		return
	var id := discovery.create_game_id()
	discovery.hosted_game = {"id": id, "port": session.get_host().get_local_port()}
	# The endpoint is real, but alpha never connects clients to it.
	session.refuse_new_connections = true
	discovery.advertise()
	host_button.disabled = true
	hosted.text = "HOSTED SESSION  |  %s\nSession launched. Waiting for WP2 joining; no gameplay in alpha." % id
	feedback.text = "Hosting is active. Verify this ID appears in the other user's lobby."
	refresh_games()

func refresh_games() -> void:
	var selected := game_id.text.strip_edges().to_upper()
	game_list.clear()
	listed_ids.clear()
	var entries := discovery.games.duplicate()
	if not discovery.hosted_game.is_empty():
		var own_id: String = discovery.hosted_game["id"]
		entries[own_id] = {"id": own_id, "address": "this device", "port": discovery.hosted_game["port"]}
	var ids: Array = entries.keys()
	ids.sort()
	for id in ids:
		listed_ids.append(str(id))
		game_list.add_item("%s  |  %s  |  hosted alpha session" % [id, entries[id]["address"]])
		if id == selected:
			game_list.select(game_list.item_count - 1)
	if entries.is_empty():
		feedback.text = "No games available. Ask another user to press Host."
	elif not selected.is_empty():
		identify_game(selected)
	else:
		feedback.text = "%d hosted session(s) found. Select one to see its game ID." % entries.size()

func select_game(index: int) -> void:
	game_id.text = listed_ids[index]
	identify_game(game_id.text)

func identify_game(value: String) -> void:
	var id := value.strip_edges().to_upper()
	if id.is_empty():
		feedback.text = "Select a game or enter its ID. Joining is unavailable in alpha."
	elif listed_ids.has(id):
		feedback.text = "Identified %s. Intended next step: Join (WP2). No connection was made." % id
	else:
		feedback.text = "No available game matches this ID. Check the ID or wait for its host."

func discovery_error(message: String) -> void:
	host_button.disabled = true
	feedback.text = message
	network_status.text = message

func set_network_address(value: String) -> void:
	if discovery.bound_port == -1:
		discovery_error("Discovery unavailable: close another local lobby and restart.")
		return
	var requested_id := game_id.text.strip_edges().to_upper()
	if not requested_id.is_empty() and not discovery.valid_game_id(requested_id):
		network_status.text = "Enter a session ID with exactly 6 letters/numbers, or clear it to list all games."
		return
	if not discovery.reload_games(value, requested_id):
		network_status.text = "Enter a valid IPv4 address, such as 192.168.1.25 (not a game ID)."
	elif not requested_id.is_empty():
		game_id.text = requested_id
		network_status.text = "Looking for session %s on the local network%s. Join remains disabled." % [requested_id, (" at " + discovery.direct_address) if not discovery.direct_address.is_empty() else ""]
		if listed_ids.has(requested_id):
			identify_game(requested_id)
		else:
			feedback.text = "No listing for %s yet. Waiting for a host reply; check Wi-Fi or enter the host IPv4 if needed." % requested_id
	elif discovery.direct_address.is_empty():
		network_status.text = "Reloading automatic LAN discovery. Manual host lookup cleared."
	else:
		network_status.text = "Looking for hosted games at %s. If none appear, check both firewalls and Wi-Fi isolation." % discovery.direct_address

func _exit_tree() -> void:
	if session != null:
		session.close()
