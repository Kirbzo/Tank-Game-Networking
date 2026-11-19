extends "res://tests/combat_smoke.gd"
## Actual LAN-room preview: movement/fire after first Start, no world interactions.
func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-lan-preview-test"
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Preview discovery"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2), "Two actual connected players"):
		return
	var room = lobby.active_room
	if not check(await until(func(): return room.phase == "ready"), "First Start/readiness enters preview"):
		return
	if hosting:
		if not check(not room.combat.interactions_enabled and room.bottom_start_button.visible, "Preview restricted while bottom Start awaits confirmation"):
			return
	var initial: Vector2 = room.artwork.tank_markers[lobby.multiplayer.get_unique_id()].position
	aim(Vector2(424, 532) if hosting else Vector2(1048, 532))
	await fire_once()
	await create_timer(0.8).timeout
	if not check(await until(func(): return room.combat_view.shots_seen == 2), "Both preview shots shown on both instances"):
		return
	if not check(room.artwork.ice_count == 35 and room.tank_world.removed_ice.is_empty(), "Preview shots cannot destroy ice"):
		return
	if hosting:
		for peer in room.combat.proxies:
			room.combat.proxies[peer].take_moose_hit(Vector2.LEFT)
		if not check(room.tank_world.hit_push.is_empty() and room.artwork.contact_timers.is_empty(), "Preview rejects moose contact effects"):
			return
		for i in range(room.combat.moose.size()):
			if not check(room.combat.moose[i].position == room.combat.CORNERS[i], "Preview moose remain inactive"):
				return
	key(true)
	await create_timer(0.25).timeout
	key(false)
	await create_timer(0.3).timeout
	var at: Vector2 = room.artwork.tank_markers[lobby.multiplayer.get_unique_id()].position
	if not check(at.y < initial.y - 10 and room.phase == "ready", "Own tank moves and reconciles before bottom Start"):
		return
	if not check(room.tank_world.move_current(Vector2(208, 176), Vector2.UP, 10).y == 176, "Preview movement still obeys perimeter"):
		return
	if OS.get_cmdline_user_args().has("leave-preview"):
		if hosting:
			if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 1), "Guest leaving preview restores solo host preview"):
				return
			room.begin_game()
			if not check(room.phase == "ready" and room.bottom_start_button.disabled and not room.combat.interactions_enabled, "Departure retains harmless preview and prevents duel Start"):
				return
			room.leave_room()
		else:
			# Let the host complete its preview assertions before our departure resets it.
			await create_timer(0.8).timeout
			room.leave_room()
		print("PASS LAN preview departure cleanup")
		quit()
		return
	if hosting:
		# Leave a live preview shot to verify it cannot survive into full gameplay.
		aim(Vector2(1100, at.y))
		await fire_once()
		room.bottom_start_button.pressed.emit()
		if not check(room.combat.interactions_enabled and room.combat.bullets.is_empty(), "Second Start enables interactions and clears preview shots"):
			return
	if not check(await until(func(): return room.phase == "running"), "Bottom Start begins normal LAN gameplay"):
		return
	await create_timer(0.2).timeout
	aim(Vector2(424, 532) if hosting else Vector2(1048, 532))
	await fire_once()
	if not check(await until(func(): return room.artwork.ice_count == 33), "Normal ice destruction resumes only after second Start"):
		return
	if hosting:
		await create_timer(0.5).timeout
	# Do not tear down the connection before the other instance observes the result.
	await create_timer(0.8).timeout
	print("PASS LAN preview movement/shooting, no ice/moose effects, walls, synchronized shots and normal second Start")
	quit()
