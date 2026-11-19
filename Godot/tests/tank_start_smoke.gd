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
	var solo_position := Vector2.ZERO
	if hosting:
		if not check(await until(func(): return room.phase == "ready"), "Solo host preview starts automatically"):
			return
		room.begin_game()
		if not check(room.phase == "ready" and room.bottom_start_button.disabled and room.find_child("StartButton", true, false) == null, "Only bottom Start remains; solo duel Start rejected"):
			return
		room.accept_fire_request(1, room.epoch, Vector2.RIGHT, 1)
		if not check(room.combat.next_shot == 1 and not room.combat.interactions_enabled and room.combat.proxies[1].health == 100, "Solo host can aim/fire harmlessly before anyone joins"):
			return
		var initial: Vector2 = room.tank_world.positions[1]
		key(KEY_W, true)
		await create_timer(0.1).timeout
		key(KEY_W, false)
		solo_position = room.tank_world.positions[1]
		if not check(room.tank_world.positions[1].y < initial.y, "Host moves before a guest connects"):
			return
	if not check(await until(func(): return room.player_names.size() == 2), "Both rooms loaded"):
		return
	if not await waiting_room_checks():
		return
	if hosting:
		if not check(room.tank_world.positions[1] == solo_position, "Guest join preserves the host's waiting-room position"):
			return
		# Force the existing timeout path; recovery must no longer need a first button.
		var expired: int = room.epoch
		room.phase = "preparing"
		room.prepare_deadline = 0
		room._physics_process(0.0)
		room.acknowledge_ready(lobby.multiplayer.get_peers()[0], expired)
		if not check(room.phase == "waiting" and room.bottom_start_button.disabled and room.connection_event.text.contains("timed out"), "Timeout rejects old acknowledgement and schedules automatic retry"):
			return
	else:
		if not check(not room.bottom_start_button.visible and room.find_child("StartButton", true, false) == null, "Guest has no Start control"):
			return
		room.request_start()
		lobby.tank_ready.rpc_id(1, room.game_id, 999)
	if not check(await until(func(): return room.phase == "ready"), "Both ready; second Start still required"):
		return
	if hosting:
		if not check(room.bottom_start_button.visible and not room.bottom_start_button.disabled, "Bottom Start Game enabled only with both peers ready"):
			return
		var rect: Rect2 = room.bottom_start_button.get_global_rect()
		if not check(rect.get_center().y > room.size.y * 0.7 and rect.end.y < room.size.y and not rect.intersects(room.game_id_label.get_global_rect()), "Second Start is near bottom without covering game ID"):
			return
	else:
		room.begin_game()
		if not check(room.phase == "ready" and not room.bottom_start_button.visible, "Guest cannot confirm Start Game"):
			return
	key(KEY_W, true)
	await create_timer(0.2).timeout
	key(KEY_W, false)
	if not check(room.phase == "ready" and (room.tank_world.tick > 0 if hosting else room.tank_view.input_sequence > 0), "Movement is active between both Start clicks"):
		return
	if hosting:
		await create_timer(0.2).timeout
		room.bottom_start_button.pressed.emit()
	if not check(await until(func(): return room.phase == "running"), "Second Start begins game for both players"):
		return
	if not check(not room.bottom_start_button.visible, "Start button hides during gameplay"):
		return
	if not check(lobby.session == session, "Start preserves ENet session"):
		return
	if hosting:
		# Isolate the original wall/movement acceptance path from the now-active hazard.
		# combat_smoke separately verifies actual contact impulses and shared results.
		for member in room.player_names:
			room.tank_world.contact_cooldowns[member] = 1000.0
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
		if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 1), "Guest leaving restores solo preview automatically"):
			return
		if not check(room.bottom_start_button.disabled and lobby.session == session and room.player_names.size() == 1, "Departure retains preview but disables duel Start"):
			return
		if not check(await until(func(): return room.player_names.size() == 2), "Guest rejoins waiting room"):
			return
		await create_timer(0.4).timeout
		if not check(await until(func(): return room.phase == "ready"), "Rejoin requires readiness again"):
			return
		room.bottom_start_button.pressed.emit()
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
		if not check(room.phase != "running", "Rejoin enters preview without auto-starting duel"):
			return
		if not check(await until(func(): return room.phase == "running"), "Rejoined guest ready and running"):
			return
		if not check(await until(func(): return is_instance_valid(lobby.disconnected_screen)), "Host departure notice"):
			return
		print("PASS tank guest ownership, readiness, synchronized movement, prediction, rejoin and host loss")
	quit()
