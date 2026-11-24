extends "res://tests/combined_smoke.gd"
## Real combined navigation, viewport bounds, volume handoff and optional render captures.
func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/integration/P090-" + name + ".png")

func run() -> void:
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	await capture("menu")
	if not check(button("Solo") != null and button("Multiplayer") != null and button("Controls") != null and button("Sound") != null and button("Credits") != null and button("Exit") != null, "All latest main-menu choices"):
		return
	app.client_menu.sound.set_volume(0.25)
	enter_menu(false)
	await capture("lobby")
	var local_duel: Button
	for control in lobby.find_children("*", "Button", true, false):
		if control.text == "Local Duel / 2 Players":
			local_duel = control
	if not check(local_duel != null and root.get_visible_rect().encloses(local_duel.get_global_rect()) and root.get_visible_rect().encloses(lobby.host_button.get_global_rect()), "Network lobby and local mode fit viewport"):
		return
	local_duel.pressed.emit()
	if not check(not app.online and app.client_menu.local_coop and app.client_menu.state == "playing" and lobby.session == null, "Local Duel routes without creating a network session"):
		return
	app.client_menu.show_menu()
	enter_menu(true)
	var room = lobby.active_room
	if not check(await until(func(): return room.phase == "ready"), "Solo host preview loads immediately"):
		return
	await capture("room")
	if not check(room.bottom_start_button.disabled and is_equal_approx(room.combat_view.sound.volume, 0.25) and room.fps_label.is_visible_in_tree(), "Host Start, FPS and menu volume retained"):
		return
	room.player_names = {1: "TestHost", 42: "TestGuest"}
	room.artwork.set_members(room.player_names)
	room.apply_vitals({"revision": 10, "vitals": {1: {"health": 65, "lives": 2, "active": true, "protection": 0.0}, 42: {"health": 0, "lives": 0, "active": false, "protection": 0.0}}})
	room.show_duel_result(1, {"elapsed": 65, "shots": 34, "cleared": 8, "total": 35, "score": 800})
	if not check(await until(func(): return is_instance_valid(room.result_overlay)), "Final animation resolves to results"):
		return
	await capture("results")
	if not check(not room.combat_view.sound.voices.music.playing and not room.combat_view.sound.voices.engine.playing and root.get_visible_rect().encloses(room.play_again_button.get_global_rect()), "Results stop gameplay loops and keep replay visible"):
		return
	room.leave_room()
	lobby.show_exit_screen()
	if not check(not app.online and lobby.session == null and app.client_menu.state == "menu", "Results exit returns cleanly through lobby to menu"):
		return
	print("PASS integrated menu/local duel/lobby/room/results routes, bounds, FPS and audio lifecycle")
	quit()
