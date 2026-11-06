extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var World = load("res://room_world.gd")
	var unit = World.new()
	unit.add_player(1)
	var start: Vector2 = unit.positions[1]
	if not check(not unit.accept_input(55, Vector2.RIGHT, 0), "Unknown peer rejected"):
		return
	if not check(not unit.accept_input(1, Vector2(NAN, 0), 0) and not unit.accept_input(1, Vector2(INF, 0), 0) and not unit.accept_input(1, Vector2(100, 100), 0), "Invalid movement rejected"):
		return
	unit.accept_input(1, Vector2.ONE.normalized(), 0)
	unit.step(0.1, 100)
	if not check(is_equal_approx(unit.positions[1].distance_to(start), 22.0), "Normalized diagonal speed"):
		return
	start = unit.positions[1]
	unit.step(0.1, 500)
	if not check(unit.positions[1] == start, "Stale held input expires"):
		return
	unit.accept_input(1, Vector2.RIGHT, 500)
	unit.step(100.0, 500)
	if not check(unit.positions[1].x == World.BOUNDS.end.x - World.PLAYER_SIZE.x, "Host clamps world bounds"):
		return
	if OS.get_cmdline_user_args().has("unit"):
		print("PASS authoritative movement validation")
		quit(0)
		return
	var hosting := OS.get_cmdline_user_args().has("host")
	var probe = load("res://tests/world_probe.gd").new()
	probe.name = "WorldProbe"
	root.add_child(probe)
	var lobby = load("res://lobby.tscn").instantiate()
	lobby.username = "BraveMoose" if hosting else "LuckyOtter"
	root.add_child(lobby)
	current_scene = lobby
	lobby.discovery.protocol = "moooze-world-sync-test"
	if hosting:
		lobby.host_game()
		var room = lobby.active_room
		key(KEY_D, true)
		await create_timer(0.4).timeout
		key(KEY_D, false)
		for i in range(300):
			if room.world.positions.size() == 2:
				break
			await create_timer(0.05).timeout
		if not check(room.world.positions.size() == 2, "Ready handshake spawns second player"):
			return
		if not check(room.player_names.get(1) == "BraveMoose" and room.player_names.values().has("LuckyOtter") and room.host_label.text == "Host: BraveMoose", "Host displays both assigned usernames and host header"):
			return
		key(KEY_W, true)
		await create_timer(0.4).timeout
		key(KEY_W, false)
		for i in range(300):
			if not probe.reported.is_empty():
				break
			await create_timer(0.05).timeout
		if not check(probe.reported == room.world.positions, "Both instances converge to identical host state"):
			return
		var peer: int = lobby.multiplayer.get_peers()[0]
		var guest_start: Vector2 = World.BOUNDS.position + Vector2(World.BOUNDS.size.x * 0.65, World.BOUNDS.size.y * 0.5) - World.PLAYER_SIZE / 2
		if not check(room.world.positions[peer].distance_to(guest_start) > 50, "Client input moves authoritative guest"):
			return
		probe.acknowledge.rpc_id(peer)
		for i in range(200):
			if room.world.positions.size() == 1:
				break
			await create_timer(0.05).timeout
		if not check(room.world.positions.size() == 1 and room.world_positions.size() == 1 and room.player_names.size() == 1, "Disconnected player removed from shared state"):
			return
		room.leave_room()
	else:
		await create_timer(0.8).timeout
		for i in range(300):
			if not lobby.discovery.games.is_empty():
				break
			await create_timer(0.05).timeout
		if not check(not lobby.discovery.games.is_empty(), "Discover real host"):
			return
		lobby.game_id.text = lobby.discovery.games.keys()[0]
		lobby.join_game()
		for i in range(300):
			if is_instance_valid(lobby.active_room) and lobby.active_room.world_positions.size() == 2 and lobby.active_room.player_names.size() == 2:
				break
			await create_timer(0.05).timeout
		if not check(is_instance_valid(lobby.active_room) and lobby.active_room.world_positions.size() == 2, "Late join receives both players"):
			return
		var room = lobby.active_room
		if not check(room.player_names.get(1) == "BraveMoose" and room.player_names.get(lobby.multiplayer.get_unique_id()) == "LuckyOtter" and room.host_label.text == "Host: BraveMoose", "Client receives both assigned usernames and matching host header"):
			return
		if not check(room.NAME_COLOR == Color.WHITE and room.host_label.get_theme_color("font_color") == Color.WHITE, "Names and host header use white text"):
			return
		var font := ThemeDB.fallback_font
		for position in [room.arena.position, room.arena.get_center(), room.arena.end - room.PLAYER_SIZE]:
			var baseline: Vector2 = room.name_baseline(position, "BraveMoose")
			if not check(baseline.y + font.get_descent(room.NAME_FONT_SIZE) <= position.y and baseline.y - font.get_ascent(room.NAME_FONT_SIZE) >= 0, "Username stays above player and visible at walls"):
				return
		var original_host_x: float = World.BOUNDS.position.x + World.BOUNDS.size.x * 0.35 - World.PLAYER_SIZE.x / 2
		if not check(room.world_positions[1].x > original_host_x + 30, "Late join receives host's prior movement"):
			return
		room.size = Vector2(700, 500)
		room.layout_room()
		if not check(room.arena == World.BOUNDS, "Resizing preserves common world bounds"):
			return
		key(KEY_D, true)
		key(KEY_S, true)
		var deadline := Time.get_ticks_msec() + 600
		var last_tick: int = room.world_tick
		var last_remote: Vector2 = room.display_positions.get(1, Vector2.ZERO)
		var last_prediction: Vector2 = room.client_view.predicted_position
		var interpolated_frames := 0
		var predicted_frames := 0
		while Time.get_ticks_msec() < deadline:
			await process_frame
			var remote: Vector2 = room.display_positions.get(1, Vector2.ZERO)
			if room.world_tick == last_tick:
				if not remote.is_equal_approx(last_remote):
					interpolated_frames += 1
				if not room.client_view.predicted_position.is_equal_approx(last_prediction):
					predicted_frames += 1
			last_tick = room.world_tick
			last_remote = remote
			last_prediction = room.client_view.predicted_position
		key(KEY_D, false)
		key(KEY_S, false)
		if not check(interpolated_frames > 0 and predicted_frames > 0, "Remote interpolation and local prediction advance between host snapshots"):
			return
		if not check(room.fps_label.is_visible_in_tree() and room.fps_label.text.begins_with("FPS: "), "Live FPS counter present"):
			return
		print("TRACE between snapshots remote frames=", interpolated_frames, " local predictions=", predicted_frames)
		var original_host_y: float = World.BOUNDS.get_center().y - World.PLAYER_SIZE.y / 2
		if not check(room.world_positions[1].y < original_host_y - 30, "Host movement reaches client during simultaneous input"):
			return
		room.show_settings()
		await create_timer(0.3).timeout
		var stopped: Dictionary = room.world_positions.duplicate()
		key(KEY_D, true)
		await create_timer(0.3).timeout
		key(KEY_D, false)
		if not check(room.world_positions == stopped, "Settings stops local input while snapshots continue"):
			return
		room.close_settings()
		lobby.room_input.rpc_id(1, Vector2(999, 999), room.client_view.input_sequence + 1)
		await create_timer(0.3).timeout
		if not check(room.world_positions == stopped, "Oversized network input cannot teleport player"):
			return
		room.receive_world(room.world_tick - 1, {})
		if not check(room.world_positions == stopped, "Old snapshot ignored"):
			return
		if not check(room.client_view.latest_ack > 0 and room.client_view.pending_inputs.size() < 10, "Host acknowledges sequenced input without growing replay queue"):
			return
		probe.report.rpc_id(1, room.world_positions)
		for i in range(200):
			if probe.acknowledged:
				break
			await create_timer(0.05).timeout
		if not check(probe.acknowledged, "Host confirms exact world equality"):
			return
		room.leave_room()
	print("PASS synchronized world " + ("host" if hosting else "client"))
	quit(0)
