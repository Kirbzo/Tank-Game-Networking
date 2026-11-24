extends "res://tests/combined_smoke.gd"
## Uses real mouse-button events, never Input.action_press("fire").
func mouse(at: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = pressed
	Input.parse_input_event(click)
	Input.flush_buffered_events()

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "mouse-fire-test-1"
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discover"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2), "Joined"):
		return
	var room = lobby.active_room
	if not check(await until(func(): return room.phase == "ready"), "Automatic preview is ready"):
		return
	if hosting:
		await create_timer(0.3).timeout
		if not check(await until(func(): return room.phase == "ready"), "Readiness precedes bottom Start Game"):
			return
		room.bottom_start_button.pressed.emit()
	if not check(await until(func(): return room.phase == "running"), "Started"):
		return
	if DisplayServer.get_name() != "headless":
		capture_shots(room, "host" if hosting else "guest")
	if not hosting:
		if not check(await until(func(): return is_instance_valid(room.combat_view) and room.combat_view.shots_seen >= 1, 4.0), "Guest sees host mouse shot"):
			return
	root.grab_focus()
	await create_timer(0.4).timeout
	var at: Vector2 = room.artwork.to_global(Vector2(640, 612))
	if OS.get_cmdline_user_args().has("native"):
		print("NATIVE_CLICK ", OS.get_process_id(), " ", int(at.x), " ", int(at.y))
	else:
		mouse(at, true)
		mouse(at, false) # A click can begin and end between two physics frames.
	await create_timer(0.1).timeout
	print("TRACE role=", hosting, " bindings=", InputMap.action_get_events("fire"), " action=", Input.is_action_pressed("fire"), " focus=", root.has_focus(), " hover=", root.gui_get_hovered_control(), " self=", room, " allowed=", room.combat_input_allowed(), " shots=", room.combat_view.shots_seen)
	mouse(at, false)
	if not check(await until(func(): return is_instance_valid(room.combat_view) and room.combat_view.shots_seen == 2, 4.0), "Mouse clicks create one shot per player on both instances"):
		return
	await create_timer(0.5).timeout
	room.show_settings()
	if not check(await until(func(): return room.phase == "paused"), "Shared Pause reaches this player"):
		return
	var before: int = room.combat_view.shots_seen
	mouse(at, true)
	mouse(at, false)
	await create_timer(0.1).timeout
	if not check(room.combat_view.shots_seen == before, "Shared Pause consumes clicks without firing"):
		return
	room.close_settings()
	if hosting:
		await create_timer(1.0).timeout # Let the guest finish its settings check before closing.
	print("PASS real mouse fire")
	quit()

func capture_shots(room: Control, role: String) -> void:
	for id in [1, 2]:
		if not await until(func(): return is_instance_valid(room.combat_view) and room.combat_view.bullets.has(id), 5.0):
			return
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/mouse-%s-shot-%d.png" % [role, id])
		print("CAPTURE ", role, " shot ", id)
