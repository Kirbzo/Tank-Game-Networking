extends "res://tests/combined_smoke.gd"
## Paired actual ENet test via application.tscn, Play, Host/Join, Ready and Start.
func aim(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = lobby.active_room.artwork.to_global(at)
	root.push_input(motion, true)
	Input.flush_buffered_events()

func fire_once() -> void:
	fire_button(true)
	await create_timer(0.10).timeout
	fire_button(false)

func fire_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = lobby.active_room.aim_pointer
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-combat-test-1"
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discovery"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2), "Both players in integrated arena"):
		return
	var room = lobby.active_room
	var peer: int = lobby.multiplayer.get_unique_id()
	var session = lobby.session
	if not check(await until(func(): return room.phase == "ready"), "Automatic preview is ready"):
		return
	if hosting:
		await create_timer(0.4).timeout
		if not check(await until(func(): return room.phase == "ready"), "Readiness precedes bottom Start Game"):
			return
		room.bottom_start_button.pressed.emit()
	if not check(await until(func(): return room.phase == "running"), "Ready then Start"):
		return
	var impacts: Array[Vector2] = []
	room.combat_view.impact_confirmed.connect(func(at): impacts.append(at))
	aim(Vector2(424, 532) if hosting else Vector2(1048, 532))
	await create_timer(0.15).timeout
	await fire_once()
	await create_timer(0.6).timeout
	if not check(await until(func(): return room.artwork.ice_count == 33 and room.combat_view.shots_seen == 2), "Exactly two shots and two identical ice removals"):
		return
	var expected_host := (Vector2(424, 532) - Vector2(208, 612)).angle()
	var expected_guest := (Vector2(1048, 532) - Vector2(1072, 612)).angle()
	for member in room.player_names:
		if not check(absf(angle_difference(room.artwork.tank_markers[member].get_node("Turret").rotation, expected_host if member == 1 else expected_guest)) < 0.01, "Both turret directions synchronized"):
			return
	if not check(room.tank_world.removed_ice.has(17) and room.tank_world.removed_ice.has(31), "Same named ice objects destroyed"):
		return
	if not check(await until(func(): return room.combat_view.animals.size() == 4 and room.combat_view.animals[1].position != Vector2(1114, 206), 3.0), "Both screens receive roaming moose positions"):
		return
	# A former obstacle can now be traversed by the authoritative/predictive solver.
	if not check(room.tank_world.move_current(Vector2(380, 532), Vector2.RIGHT, 0.2).x > 400, "Destroyed ice no longer blocks movement"):
		return
	if hosting:
		var guest: int = lobby.multiplayer.get_peers()[0]
		var seq: int = room.combat.controls[guest].sequence
		for bad in [Vector2.ZERO, Vector2(INF, 0), Vector2(2, 0)]:
			room.accept_combat_input(guest, room.epoch, bad, true, 100000)
		room.accept_combat_input(guest, room.epoch, Vector2.RIGHT, true, seq)
		room.accept_combat_input(guest, room.epoch - 1, Vector2.RIGHT, true, 100000)
		room.accept_combat_input(999, room.epoch, Vector2.RIGHT, true, 100000)
		room.accept_fire_request(guest, room.epoch, Vector2.RIGHT, 1) # Duplicate click request.
		room.accept_fire_request(guest, room.epoch - 1, Vector2.RIGHT, 100000)
		room.accept_fire_request(guest, room.epoch, Vector2(INF, 0), 100000)
		if not check(room.combat.controls[guest].sequence == seq, "Invalid, replayed, old-generation and unknown input rejected"):
			return
		var count: int = room.combat.next_shot
		room.combat.accept_input(guest, Vector2.RIGHT, true, seq + 1, Time.get_ticks_msec() - 251)
		room.combat._physics_process(0.25)
		if not check(room.combat.next_shot == count, "Stale held-fire input cannot continue shooting"):
			return
		# Controlled host-world fixture: same live client scene and authoritative physics.
		# Place one moose in contact and verify it yields without changing tank state.
		var animal = room.combat.moose[0]
		animal.position = Vector2(238, 612)
		animal.emerge_delay = 0
		animal.heading = Vector2.LEFT
		await create_timer(0.1).timeout
		if not check(animal.heading.x > 0 and room.tank_world.positions[1].x < 208 and room.artwork.contact_timers.get(1, 0) > 0 and room.duel_vitals[1].health == 80, "Moose yields and host applies knockback plus shared 20 damage"):
			return
		if not check(not room.tank_world.moose_contact(1, Vector2.RIGHT), "Shared contact cooldown rejects repeated contact"):
			return
		# Moose remain pass-through; the opposing tank now receives an authoritative hit.
		animal.set_physics_process(false)
		animal.position = Vector2(400, 612)
		animal.heading = Vector2.RIGHT
		aim(Vector2(1150, 612))
		await fire_once()
	else:
		# Exercise the RPC validation boundary as well as the host-local assertions.
		lobby.combat_input.rpc_id(1, room.game_id, room.epoch, Vector2(INF, 0), true, 100000)
		lobby.combat_input.rpc_id(1, room.game_id, room.epoch - 1, Vector2.RIGHT, true, 100000)
		lobby.combat_fire.rpc_id(1, room.game_id, room.epoch, Vector2.RIGHT, 1)
		lobby.combat_fire.rpc_id(1, room.game_id, room.epoch - 1, Vector2.RIGHT, 100000)
	if not check(await until(func(): return room.combat_view.shots_seen == 3 and room.combat_view.bullets.is_empty()), "Opposing tank consumes shot after it passes moose"):
		return
	if not check(room.artwork.ice_count == 33 and room.combat_view.animals.size() == 4 and room.combat_view.animals[0].position == Vector2(400, 612), "Shared moose and border outcome"):
		return
	if not check(impacts.size() == 3 and impacts[-1].distance_to(Vector2(1048, 612)) < 0.1, "Both receive the host-confirmed tank hit"):
		return
	if not hosting:
		if not check(room.artwork.contact_timers.has(1) and room.tank_view.snapshots[-1].positions[1].x < 208 and room.duel_vitals[1].health == 80, "Guest receives contact damage, feedback and knocked-back position"):
			return
	if hosting:
		await create_timer(0.8).timeout
		# Hold fire for one second: cadence must remain host-controlled.
		fire_button(true)
		await create_timer(1.0).timeout
		fire_button(false)
		await create_timer(1.9).timeout
		if not check(room.combat_view.shots_seen >= 7 and room.combat_view.shots_seen <= 8, "Imported .22s fire cadence; no duplicate shots"):
			return
		if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 1), "Guest departure returns host to solo preview"):
			return
		if not check(is_instance_valid(room.combat) and not room.combat.interactions_enabled and lobby.session == session, "Departure resets duel into harmless preview and retains session"):
			return
		room.leave_room()
		print("PASS combat host: controls, authority, ice, moose contact, tank damage, cadence and cleanup")
	else:
		# Duplicates and old epochs cannot resurrect/create a second presentation.
		var before: int = room.combat_view.shots_seen
		room.receive_combat_event(room.epoch, room.event_sequence, "shot", {"id": 999})
		room.receive_combat_event(room.epoch - 1, room.event_sequence + 1, "shot", {"id": 999})
		if not check(room.combat_view.shots_seen == before, "Duplicate and stale events ignored"):
			return
		await create_timer(4.0).timeout
		if not check(room.combat_view.shots_seen >= 7 and room.combat_view.shots_seen <= 8 and room.artwork.ice_count == 33 and room.combat_view.bullets.is_empty(), "Guest sees matching repeated shots and final world state"):
			return
		room.leave_room()
		print("PASS combat guest: pre-start gating, aim, single shot presentation, shared interactions, deduplication and leave")
	quit()
