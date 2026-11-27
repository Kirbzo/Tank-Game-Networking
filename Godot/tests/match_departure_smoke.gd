extends "res://tests/combat_smoke.gd"
var room: Control
var probe: DepartureProbe
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func desired_players() -> int:
	if OS.get_cmdline_user_args().has("two"):
		return 2
	return 3 if OS.get_cmdline_user_args().has("three") else 4
class DepartureProbe extends Node:
	var test
	var observed := {}
	var departing := false
	var rejoining := false
	@rpc("any_peer", "call_remote", "reliable")
	func report(sample: Dictionary) -> void:
		if multiplayer.is_server():
			observed[multiplayer.get_remote_sender_id()] = sample
	@rpc("authority", "call_remote", "reliable")
	func depart(abrupt: bool, rejoin := false) -> void:
		departing = true
		rejoining = rejoin
		if abrupt:
			test.lobby.session.close()
		else:
			test.room.leave_room()
func shared_count(count: int) -> bool:
	return room.player_names.size() == count and room.tank_world.positions.size() == count and room.combat.proxies.size() == count and room.player_names.keys().all(func(peer): return peer == 1 or (probe.observed.has(peer) and probe.observed[peer].count == count and probe.observed[peer].positions == count and probe.observed[peer].phase == room.phase and probe.observed[peer].epoch == room.epoch))
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var hosting := args.has("host")
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "departure-%d-%s" % [desired_players(), "survivor" if args.has("survivor") else "continue"]
	probe = DepartureProbe.new()
	probe.name = "DepartureProbe"
	probe.test = self
	root.add_child(probe)
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discovery"):
			return
		lobby.game_id.text = lobby.discovery.games.keys()[0]
		lobby.join_game()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.phase in ["ready", "running"] and lobby.active_room.player_names.size() == desired_players()), "All players ready"):
		return
	room = lobby.active_room
	if not hosting:
		var game_id: String = room.game_id
		while true:
			var deadline := Time.get_ticks_msec() + 40000
			while not probe.departing and Time.get_ticks_msec() < deadline:
				if not check(is_instance_valid(room), "Guest match retained until departure"):
					return
				probe.report.rpc_id(1, {"count": room.player_names.size(), "positions": room.tank_world.positions.size(), "phase": room.phase, "epoch": room.epoch})
				await create_timer(0.03).timeout
			if not check(probe.departing, "Host completes departure scenario"):
				return
			await create_timer(0.2).timeout
			if not check(lobby.session == null or lobby.session.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "Departing guest releases connection"):
				return
			if not probe.rejoining:
				break
			if not check(await until(func(): return lobby.discovery.games.has(game_id) and not lobby.discovery.games[game_id].get("started", true)), "Same room reopens for admission"):
				return
			lobby.game_id.text = game_id
			lobby.join_game()
			if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.phase == "ready"), "Guest rejoins retained game room"):
				return
			room = lobby.active_room
			probe.departing = false
			probe.rejoining = false
		print("PASS guest voluntary/abrupt departure")
		quit()
		return
	room.begin_game()
	if not check(await until(func(): return shared_count(desired_players())), "Running match shared"):
		return
	for animal in room.combat.moose:
		animal.set_physics_process(false)
		animal.position = Vector2(-1000, -1000)
	var original_world = room.tank_world
	var original_combat = room.combat
	var session = lobby.session
	var epoch: int = room.epoch
	room.combat.proxies[1].health = 80
	room.combat.report_vitals(1)
	aim(Vector2(208, 540))
	await fire_once()
	var guests: Array = room.player_names.keys().filter(func(peer): return peer != 1)
	var shots: int = room.combat.match_shots
	var count := desired_players()
	while count > 2:
		var departing: int = guests.pop_back()
		if args.has("survivor") and count == 3:
			var eliminated = room.combat.proxies[guests[0]]
			eliminated.active = false
			eliminated.health = 0
			eliminated.lives = 0
			room.combat.report_vitals(guests[0])
		# A live departing projectile must not retain a freed shooter reference.
		room.combat.aims[departing] = Vector2.UP
		room.combat.shoot(departing)
		shots += 1
		probe.depart.rpc_id(departing, count == 3 and not args.has("survivor"))
		count -= 1
		if not check(await until(func(): return shared_count(count)), "Reduced roster and snapshots shared"):
			return
		if args.has("survivor") and count == 2:
			if not check(await until(func(): return room.phase == "finished" and room.winner_peer == 1), "Departure re-evaluates last living survivor"):
				return
			probe.depart.rpc_id(guests[0], false)
			if not check(await until(func(): return room.player_names.size() == 1), "Guest leaves results"):
				return
			await create_timer(0.2).timeout
			if not check(room.phase == "finished" and lobby.match_started() and is_instance_valid(room.result_overlay), "Results departure cannot bypass host replay lock"):
				return
			room.play_again_button.pressed.emit()
			if not check(await until(func(): return room.phase == "ready" and not lobby.match_started()), "Host replay reopens solo waiting room"):
				return
			room.leave_room()
			print("PASS departure last-survivor winner")
			quit()
			return
		if not check(room.phase == "running" and lobby.session == session and room.epoch == epoch and room.tank_world == original_world and room.combat == original_combat and room.combat.proxies[1].health == 80 and room.combat.match_shots == shots and lobby.match_started(), "Departure preserves match, health, shots, epoch and admission lock"):
			return
		if not check(not room.combat.proxies.has(departing) and not room.artwork.tank_markers.has(departing) and room.combat.bullets.values().all(func(bullet): return is_instance_valid(bullet.shooter)) and room.combat.moose.all(func(animal): return animal.tanks.size() == count), "Departing bodies, projectiles and hazard targets cleaned"):
			return
		var before: Vector2 = room.tank_world.positions[1]
		key(KEY_D, true)
		await create_timer(0.1).timeout
		key(KEY_D, false)
		if not check(room.tank_world.positions[1].x > before.x, "Movement continues"):
			return
		await create_timer(0.25).timeout
		aim(Vector2(208, 540))
		await fire_once()
		shots += 1
		if not check(room.combat.match_shots == shots, "Shooting continues"):
			return
	probe.depart.rpc_id(guests[0], false, true)
	if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 1 and not lobby.match_started()), "Last connected host returns to game-room preview"):
		return
	if not check(lobby.active_room == room and lobby.session == session and not lobby.get_child(0).visible and room.epoch > epoch and room.bottom_start_button.disabled and not room.combat.interactions_enabled and room.game_id_label.is_visible_in_tree(), "Same session and game room retained with harmless preview and game ID"):
		return
	var initial: Vector2 = room.tank_world.positions[1]
	key(KEY_D, true)
	await create_timer(0.1).timeout
	key(KEY_D, false)
	aim(Vector2(208, 540))
	await fire_once()
	if not check(room.tank_world.positions[1].x > initial.x and room.combat.next_shot > 0 and room.combat.match_shots == 0, "Solo host moves and shoots harmlessly while waiting"):
		return
	if not check(await until(func(): return shared_count(2) and room.can_begin_game()), "Rejoined guest enables host Start"):
		return
	room.begin_game()
	if not check(await until(func(): return shared_count(2) and room.phase == "running"), "Same room starts another match"):
		return
	var guest: int = room.player_names.keys().filter(func(peer): return peer != 1)[0]
	probe.depart.rpc_id(guest, false)
	if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 1), "Repeated last guest departure restores preview"):
		return
	room.leave_room()
	print("PASS %d-player departures: continued match, solo game-room movement/fire, reopened admission, rejoin and fresh match" % desired_players())
	quit()
