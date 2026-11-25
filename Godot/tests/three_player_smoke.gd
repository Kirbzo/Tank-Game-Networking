extends "res://tests/combat_smoke.gd"
const PHASE_FILE := "res://.godot/integration/P113-phase.txt"
const FULL_FILE := "res://.godot/integration/P113-full.txt"
var probe: LobbyProbe
var role := ""
var departed := false
class LobbyProbe extends Node:
	var test
	var observed: Dictionary = {}
	@rpc("any_peer", "call_remote", "reliable")
	func report(data: Dictionary) -> void:
		if multiplayer.is_server() and multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
			observed[multiplayer.get_remote_sender_id()] = data
	@rpc("authority", "call_remote", "reliable")
	func move(pressed: bool) -> void:
		test.key(pressed)
	@rpc("authority", "call_remote", "reliable")
	func fire() -> void:
		test.aim(Vector2(640,430))
		await test.fire_once()
	@rpc("authority", "call_remote", "reliable")
	func leave() -> void:
		test.lobby.active_room.leave_room()
		test.departed = true
func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)
func set_stage(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
func stage(path: String) -> String:
	return FileAccess.get_file_as_string(path)
func shared(count: int) -> bool:
	if not is_instance_valid(lobby.active_room) or lobby.active_room.player_names.size() != count or lobby.active_room.phase != "ready":
		return false
	for peer in lobby.multiplayer.get_peers():
		var sample: Dictionary = probe.observed.get(peer,{})
		if sample.get("count",0) != count or sample.get("phase","") != "ready" or sample.get("epoch",-1) != lobby.active_room.epoch or sample.get("positions",{}).size() != count:
			return false
	return true
func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else "first"
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-three-player-test"
	probe = LobbyProbe.new()
	probe.name = "LobbyProbe"
	probe.test = self
	root.add_child(probe)
	enter_menu(role == "host")
	if role != "host":
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discovery"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		if role == "second":
			if not check(await until(func(): return stage(PHASE_FILE) == "waiting-room"), "Wait for two-player preview"):
				return
		elif role == "fourth":
			if not check(await until(func(): return stage(PHASE_FILE) == "three" and lobby.discovery.games.get(id,{}).get("players",0) == 3), "3/3 full listing"):
				return
			var endpoint: Dictionary = lobby.discovery.games[id]
			var raw := ENetMultiplayerPeer.new()
			raw.create_client(endpoint.address,endpoint.port)
			for tick in range(20):
				raw.poll()
				await create_timer(0.05).timeout
			if not check(raw.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED, "Transport rejects a fourth peer"):
				return
			raw.close()
			lobby.game_id.text = id
			lobby.identify_game(id)
			lobby.join_button.pressed.emit()
			if not check(is_instance_valid(lobby.disconnected_screen) and lobby.disconnected_screen.title.text == "Room Full" and lobby.session == null, "Fourth Join shows Room Full"):
				return
			set_stage(FULL_FILE,"checked")
			lobby.disconnected_back()
			if not check(await until(func(): return stage(PHASE_FILE) == "slot-open" and lobby.discovery.games.get(id,{}).get("players",0) == 2), "Departure reopens listing"):
				return
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
		if not check(await until(func(): return is_instance_valid(lobby.active_room)), "Join opens room"):
			return
		var deadline := Time.get_ticks_msec()+30000
		while Time.get_ticks_msec()<deadline:
			if departed:
				if not check(lobby.session == null and not is_instance_valid(lobby.active_room), "Voluntary guest leave cleanup"):
					return
				print("PASS three-player departing guest")
				quit()
				return
			if is_instance_valid(lobby.disconnected_screen):
				if not check(lobby.disconnected_screen.title.text == "Disconnected", "Host close notice"):
					return
				print("PASS three-player guest ",role," state/shots, capacity and host loss")
				quit()
				return
			var room = lobby.active_room
			probe.report.rpc_id(1,{"role":role,"count":room.player_names.size(),"phase":room.phase,"epoch":room.epoch,"positions":room.tank_view.snapshots[-1].positions if not room.tank_view.snapshots.is_empty() else {},"shots":room.combat_view.shots_seen if is_instance_valid(room.combat_view) else 0,"vitals":room.duel_vitals})
			await create_timer(0.03).timeout
		check(false,"Guest completed before timeout")
		return
	if not check(await until(func(): return shared(2)), "Initial two-player preview"):
		return
	var room = lobby.active_room
	if not check(room.can_begin_game(), "Two-player duel still allowed"):
		return
	set_stage(PHASE_FILE,"waiting-room")
	if not check(await until(func(): return shared(3)), "Third joins shared safe preview"):
		return
	if not check(room.status_message.text.contains("3/3") and not room.bottom_start_button.disabled and not room.combat.interactions_enabled and room.artwork.tank_markers.size() == 3, "Three-player lobby stays harmless until host Start"):
		return
	var before: Dictionary = room.tank_world.positions.duplicate()
	if args.has("render"):
		root.grab_focus()
	key(true)
	probe.move.rpc(true)
	await create_timer(0.18).timeout
	key(false)
	probe.move.rpc(false)
	await create_timer(0.2).timeout
	for peer in before:
		if not check(room.tank_world.positions[peer].y < before[peer].y, "Every player can move"):
			return
	aim(Vector2(640,430))
	probe.fire.rpc()
	await fire_once()
	if not check(await until(func(): return room.combat_view.shots_seen == 3 and probe.observed.values().all(func(sample): return sample.get("shots",0) == 3)), "All three confirmed shots reach both guests"):
		return
	await create_timer(0.5).timeout
	if not check(room.artwork.ice_count == 35 and room.tank_world.removed_ice.is_empty() and room.duel_vitals.values().all(func(values): return values.health == 100 and values.lives == 3), "Preview shots cause no damage or destruction"):
		return
	if args.has("render"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/integration/P113-three.png")
	set_stage(PHASE_FILE,"three")
	if not check(await until(func(): return stage(FULL_FILE) == "checked"), "Fourth-client capacity check"):
		return
	var leaving_peer := 0
	for peer in probe.observed:
		if probe.observed[peer].role == "second":
			leaving_peer = peer
	probe.leave.rpc_id(leaving_peer)
	if not check(await until(func(): return shared(2)), "Guest departure restores two-player preview"):
		return
	if not check(room.can_begin_game() and not room.artwork.tank_markers.has(leaving_peer), "Duel eligibility and roster cleanup restored"):
		return
	set_stage(PHASE_FILE,"slot-open")
	if not check(await until(func(): return shared(3)), "Fourth guest fills reopened slot"):
		return
	if not check(room.can_begin_game(), "Reopened three-player room is eligible to start"):
		return
	room.leave_room()
	await create_timer(0.3).timeout
	print("PASS three-player host: waiting-room admission, movement/shots, safe preview, capacity and rejoin")
	quit()
