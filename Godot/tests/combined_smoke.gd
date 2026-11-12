extends SceneTree
## Run host, guest and third in separate processes; local mode covers routing/filtering.
var app: Node
var lobby: Control

class FailingLobby extends "res://lobby.gd":
	func create_host_session() -> Error:
		return ERR_CANT_CREATE

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func until(predicate: Callable, seconds := 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return predicate.call()

func button(text: String) -> Button:
	for node in app.client_menu.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func enter_menu(hosting: bool) -> void:
	button("Play").pressed.emit()
	button("Host Game" if hosting else "Join Game").pressed.emit()

func waiting_room_checks() -> bool:
	var room = lobby.active_room
	if not check(room.get_script() == load("res://client_waiting_room.gd"), "Combined Host/Join uses client waiting-room scene"):
		return false
	if not check(room.artwork.ice_count == 35 and room.artwork.members == room.player_names and room.status_message.text.contains("Waiting"), "Client arena layout and real membership in waiting state"):
		return false
	if not check(room.artwork.find_children("*", "CollisionObject2D", true, false).is_empty(), "Artwork contains no offline gameplay physics"):
		return false
	var positions := {}
	for peer in room.artwork.tank_markers:
		positions[peer] = room.artwork.tank_markers[peer].position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	Input.action_press("fire")
	await create_timer(0.3).timeout
	key.pressed = false
	Input.parse_input_event(key)
	Input.action_release("fire")
	for peer in positions:
		if not check(room.artwork.tank_markers[peer].position == positions[peer], "Tank markers stay stationary while waiting"):
			return false
	room.show_settings()
	if not check(not paused and lobby.session != null, "Room overlay keeps session processing alive"):
		return false
	room.close_settings()
	return check(room.world.tick == 0 and room.client_view.input_sequence == 0 and room.artwork.ice_count == 35, "Waiting does not simulate movement, send input or destroy bricks")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	if not check(startup == "res://application.tscn", "Whole-project startup selects combined application"):
		return
	app = load(startup).instantiate()
	if args.has("failure"):
		var old = app.get_node("AlphaLobby")
		app.remove_child(old)
		old.discovery.free()
		old.free()
		var failing := FailingLobby.new()
		failing.name = "AlphaLobby"
		app.add_child(failing)
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	if not check(not lobby.visible and app.client_menu.ui.visible, "Client menu is initial screen"):
		return
	if args.has("local"):
		await local_checks()
		return
	if args.has("failure"):
		enter_menu(true)
		if not check(lobby.visible and lobby.session == null and lobby.feedback.text.contains("Hosting failed") and lobby.discovery.hosted_game.is_empty(), "One-click failure leaves existing lobby error"):
			return
		print("PASS combined hosting failure")
		quit()
		return
	lobby.discovery.protocol = "moooze-combined-smoke-1"
	var instance := lobby.get_instance_id()
	if args.has("host"):
		var joins := [0]
		lobby.multiplayer.peer_connected.connect(func(_id): joins[0] += 1)
		enter_menu(true)
		if not check(is_instance_valid(lobby.active_room) and lobby.discovery.hosted_game.players == 1, "One Host click opens waiting room"):
			return
		if not await waiting_room_checks():
			return
		var session = lobby.session
		app.host_game()
		if not check(lobby.session == session and not app.client_menu.ui.visible and not app.client_menu.is_processing_unhandled_input(), "Repeated menu action retains one session; hidden input disabled"):
			return
		if not check(await until(func(): return joins[0] == 3, 25.0), "Guest, third player, then guest rejoin"):
			return
		if not check(await until(func(): return lobby.active_room.player_names.size() == 2), "Names RPC reaches stable lobby path"):
			return
		if not check(lobby.active_room.artwork.tank_markers.size() == 2 and lobby.active_room.status_message.text.contains("2/2"), "Host displays both waiting members"):
			return
		await create_timer(1.0).timeout
		lobby.active_room.leave_room()
		if not check(lobby.get_instance_id() == instance and lobby.visible and lobby.session == null, "Host leaves to same persistent lobby"):
			return
		print("PASS combined host lifecycle")
		quit()
		return
	enter_menu(false)
	if not check(lobby.visible and not app.client_menu.ui.visible and lobby.session == null, "Join menu opens lobby without connecting"):
		return
	if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discover combined host"):
		return
	var id: String = lobby.discovery.games.keys()[0]
	if args.has("third"):
		if not check(await until(func(): return lobby.discovery.games.get(id, {}).get("players", 0) == 2), "Full room remains discoverable"):
			return
		lobby.game_id.text = id
		lobby.identify_game(id)
		if not check(lobby.game_list.get_item_text(lobby.listed_ids.find(id)).contains("2/2 · Full") and not lobby.join_button.disabled, "Full row visible and selectable"):
			return
		lobby.join_button.pressed.emit()
		if not check(is_instance_valid(lobby.disconnected_screen) and lobby.disconnected_screen.title.text == "Room Full" and lobby.session == null, "Full Join retains Room Full response"):
			return
		lobby.disconnected_screen.return_button.pressed.emit()
		if not check(await until(func(): return lobby.discovery.games.get(id, {}).get("players", 0) == 1), "Freed slot updates listing"):
			return
		lobby.game_id.text = id
		lobby.identify_game(id)
		if not check(not lobby.join_button.disabled and not lobby.game_list.get_item_text(lobby.listed_ids.find(id)).contains("Full"), "Freed listing becomes joinable"):
			return
	else:
		lobby.game_list.item_selected.emit(lobby.listed_ids.find(id))
	lobby.join_button.pressed.emit()
	if not check(lobby.joining and lobby.joining_screen.visible and lobby.session == null, "Loading precedes ENet startup"):
		return
	if not check(await until(func(): return is_instance_valid(lobby.active_room)), "Actual waiting room joined"):
		return
	if not check(await until(func(): return lobby.active_room.world_positions.size() == 2), "World snapshot RPC reaches combined client"):
		return
	if not check(await until(func(): return lobby.active_room.player_names.size() == 2), "Guest receives real member names"):
		return
	if not await waiting_room_checks():
		return
	await create_timer(2.0 if args.has("third") else 3.0).timeout
	# Exercise actual Escape routing with the client menu hidden.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	if not check(lobby.get_instance_id() == instance and lobby.visible and lobby.session == null, "Guest leaves to same lobby"):
		return
	if args.has("third"):
		print("PASS combined full room, slot reopening and third-player join")
		quit()
		return
	# Our cached 2/2 row can still describe the connection we just left.
	# Observe our departure before interpreting 2/2 as the third player's join.
	if not check(await until(func(): return lobby.discovery.games.get(id, {}).get("players", 0) == 1), "Own departure advertised before awaiting third player"):
		return
	if not check(await until(func(): return lobby.discovery.games.get(id, {}).get("players", 0) == 2), "Third player occupies freed slot"):
		return
	if not check(await until(func(): return lobby.discovery.games.get(id, {}).get("players", 0) == 1), "Third player departure advertised"):
		return
	lobby.game_id.text = id.to_lower()
	lobby.identify_game(lobby.game_id.text)
	lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room)), "Typed lowercase ID rejoins"):
		return
	if not check(await until(func(): return is_instance_valid(lobby.disconnected_screen)), "Host closure shows Disconnected"):
		return
	if not check(lobby.disconnected_screen.title.text == "Disconnected", "Established host-loss explanation"):
		return
	lobby.disconnected_screen.return_button.pressed.emit()
	if not check(await until(func(): return not lobby.discovery.games.has(id), 6.0), "Closed host listing expires"):
		return
	print("PASS combined guest selection, rejoin, host loss and expiry")
	quit()

func local_checks() -> void:
	enter_menu(false)
	var old = load("res://discovery.gd").new()
	old.protocol = "moooze-combined-1" # Previous waiting-only build has incompatible RPCs.
	old.hosted_game = {"id": "OLD001", "port": 54321, "username": "OldMoose", "players": 1}
	root.add_child(old)
	old.advertise()
	await create_timer(1.0).timeout
	if not check(not lobby.discovery.games.has("OLD001"), "Old automatic announcements rejected"):
		return
	lobby.game_id.text = "OLD001"
	lobby.identify_game("OLD001")
	lobby.join_game()
	if not check(lobby.join_button.disabled and lobby.session == null and not lobby.joining, "Old typed ID cannot connect"):
		return
	old.broadcast_enabled = false
	lobby.discovery.broadcast_enabled = false
	lobby.set_network_address("127.0.0.1")
	await create_timer(1.0).timeout
	# Also send an unsolicited old-version reply: receiver must reject it.
	old.send_packet("127.0.0.1", lobby.discovery.bound_port, old.announcement())
	await create_timer(0.2).timeout
	if not check(not lobby.discovery.games.has("OLD001"), "Old manual-IP replies rejected"):
		return
	var compatible = load("res://discovery.gd").new()
	compatible.broadcast_enabled = false
	compatible.hosted_game = {"id": "NEW001", "port": 54322, "username": "NewMoose", "players": 1}
	root.add_child(compatible)
	if not check(await until(func(): return lobby.discovery.games.has("NEW001"), 3.0), "Compatible direct-IP query/reply works"):
		return
	lobby.game_id.text = "new001"
	lobby.identify_game("new001")
	if not check(not lobby.join_button.disabled and lobby.available_join_target().id == "NEW001", "Compatible typed ID resolves filtered cache"):
		return
	compatible.hosted_game.clear()
	lobby.discovery.games.clear()
	lobby.set_network_address("")
	compatible.hosted_game = {"id": "NEW002", "port": 54323, "username": "NewMoose", "players": 1}
	compatible.broadcast_enabled = true
	compatible.advertise()
	if not check(await until(func(): return lobby.discovery.games.has("NEW002"), 3.0), "Compatible automatic announcements accepted"):
		return
	old.queue_free()
	compatible.queue_free()
	print("PASS combined menus and protocol filtering across automatic, ID and direct-IP discovery (listing fixtures, not ENet hosts)")
	quit()
