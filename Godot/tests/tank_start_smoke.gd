extends "res://tests/combined_smoke.gd"
## Actual paired ENet instances through the configured application and client menus.
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-tank-start-smoke-1"
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discover host"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room)), "Connected room"):
		return
	var room = lobby.active_room
	var session = lobby.session
	if hosting:
		if not check(room.start_button.disabled and room.start_button.visible, "Solo host Start disabled"):
			return
		room.request_start()
		if not check(room.phase == "waiting", "Solo Start rejected"):
			return
	if not check(await until(func(): return room.player_names.size() == 2), "Both rooms loaded"):
		return
	if not await waiting_room_checks():
		return
	if hosting:
		await create_timer(0.5).timeout
		room.request_start()
		var expired: int = room.epoch
		room.prepare_deadline = 0
		room._physics_process(0.0)
		room.acknowledge_ready(lobby.multiplayer.get_peers()[0], expired)
		if not check(room.phase == "waiting" and not room.start_button.disabled and room.connection_event.text.contains("timed out"), "Readiness timeout permits retry; late acknowledgement rejected"):
			return
		room.start_button.pressed.emit()
		if not check(room.phase == "preparing" and room.tank_world.tick == 0 and room.ready_peers.size() == 1, "Start waits for guest readiness"):
			return
		var guest: int = lobby.multiplayer.get_peers()[0]
		room.accept_tank_input(guest, room.epoch, Vector2.RIGHT, 1)
		if not check(room.tank_world.received_sequences.is_empty(), "Input blocked until both ready"):
			return
	else:
		if not check(not room.start_button.visible, "Guest has no Start control"):
			return
		room.request_start()
		lobby.tank_ready.rpc_id(1, room.game_id, 999)
		if not check(room.phase == "waiting", "Guest cannot start; premature readiness ignored"):
			return
	if not check(await until(func(): return room.phase == "running"), "Both ready; running"):
		return
	if not check(lobby.session == session, "Start preserves ENet session"):
		return
	if not hosting:
		# Invalid commands traverse the same RPC boundary as genuine input.
		lobby.tank_input.rpc_id(1, room.game_id, room.epoch, Vector2(INF, 0), 100000)
		lobby.tank_input.rpc_id(1, room.game_id, room.epoch, Vector2(9, 0), 100000)
		lobby.tank_input.rpc_id(1, room.game_id, room.epoch - 1, Vector2.RIGHT, 100000)
	var generation: int = room.epoch
	room.request_start()
	if not check(room.epoch == generation, "Duplicate Start cannot reset match"):
		return
	# Both tanks move upward: host has an open lane; guest hits ice at y=576.
	key(KEY_W, true)
	await create_timer(2.4).timeout
	key(KEY_W, false)
	await create_timer(0.6).timeout
	if hosting:
		var guest: int = lobby.multiplayer.get_peers()[0]
		if not check(room.tank_world.positions[1].distance_to(Vector2(208, 176)) < 0.1 and room.tank_world.positions[guest].distance_to(Vector2(1072, 576)) < 0.1, "Host resolves perimeter and ice collisions for both tanks"):
			return
		var seq: int = room.tank_world.received_sequences.get(guest, 0)
		room.accept_tank_input(guest, generation, Vector2(INF, 0), seq + 1)
		room.accept_tank_input(guest, generation, Vector2(9, 0), seq + 1)
		room.accept_tank_input(guest, generation, Vector2.RIGHT, seq)
		room.accept_tank_input(guest, generation - 1, Vector2.RIGHT, seq + 1)
		room.accept_tank_input(123, generation, Vector2.RIGHT, seq + 1)
		if not check(room.tank_world.received_sequences[guest] == seq and room.tank_world.positions.size() == 2, "Reject nonfinite, excessive, replay, old-generation and unknown-player input"):
			return
		if not check(await until(func(): return room.phase == "waiting"), "Guest leaving freezes host and returns to waiting"):
			return
		if not check(room.start_button.disabled and lobby.session == session and room.player_names.size() == 1, "Departure retains room and disables Start"):
			return
		if not check(await until(func(): return room.player_names.size() == 2), "Guest rejoins waiting room"):
			return
		await create_timer(0.4).timeout
		room.request_start()
		if not check(await until(func(): return room.phase == "running"), "Readiness handshake works again after rejoin"):
			return
		await create_timer(0.5).timeout
		room.leave_room()
		print("PASS tank host Start/readiness, authority, collisions, validation, departure/rejoin")
	else:
		var peer: int = lobby.multiplayer.get_unique_id()
		var positions: Dictionary = room.tank_view.snapshots[-1].positions
		if not check(positions[1].distance_to(Vector2(208, 176)) < 0.1 and positions[peer].distance_to(Vector2(1072, 576)) < 0.1, "Guest receives identical authoritative positions"):
			return
		if not check(room.artwork.tank_markers[peer].position.distance_to(positions[peer]) < 1.0 and room.tank_view.latest_ack > 0, "Prediction reconciles; tank artwork displays movement"):
			return
		await create_timer(0.7).timeout
		room.leave_room()
		if not check(await until(func(): return lobby.discovery.games.get(lobby.game_id.text, {}).get("players", 0) == 1), "Departure advertised"):
			return
		lobby.identify_game(lobby.game_id.text)
		lobby.join_button.pressed.emit()
		if not check(await until(func(): return is_instance_valid(lobby.active_room)), "Rejoined"):
			return
		room = lobby.active_room
		if not check(room.phase == "waiting", "Rejoin never auto-starts"):
			return
		if not check(await until(func(): return room.phase == "running"), "Rejoined guest ready and running"):
			return
		if not check(await until(func(): return is_instance_valid(lobby.disconnected_screen)), "Host departure notice"):
			return
		print("PASS tank guest ownership, readiness, synchronized movement, prediction, rejoin and host loss")
	quit()
