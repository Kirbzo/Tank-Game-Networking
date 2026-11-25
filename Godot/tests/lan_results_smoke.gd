extends "res://tests/combined_smoke.gd"
func run() -> void:
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	enter_menu(true)
	var room = lobby.active_room
	if not check(await until(func(): return room.phase == "ready"), "Room ready"):
		return
	room.player_names = {1: "TestHost", 42: "TestGuest"}
	room.artwork.set_members(room.player_names)
	room.apply_vitals({"revision": 10, "vitals": {1: {"health": 80, "lives": 3, "active": true, "protection": 0.0}, 42: {"health": 0, "lives": 0, "active": false, "protection": 0.0}}})
	room.show_duel_result(1, {"elapsed": 9, "shots": 34, "cleared": 0, "total": 35})
	var labels: Array[String] = []
	for node in room.result_overlay.find_children("*", "Label", true, false):
		labels.append(node.text)
	if not check(labels.has("PLAYER 1 WINS!") and labels.has("Player 1: 80 health / 3 lives") and labels.has("Player 2: 0 health / 0 lives") and labels[2].contains("Time played: 00:09") and labels.all(func(text): return not text.contains("GAME OVER")), "Winner-focused design, statistics and host mapping"):
		return
	if not check(room.play_again_button.has_focus() and not room.play_again_button.disabled and not paused, "Host replay focus and active network tree"):
		return
	if OS.get_cmdline_user_args().has("render"):
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/integration/P105-results.png")
	var back: Button
	for node in room.result_overlay.find_children("*", "Button", true, false):
		if node.text == "Return to Lobby":
			back = node
	back.pressed.emit()
	await process_frame
	if not check(lobby.session == null and not is_instance_valid(lobby.active_room) and lobby.visible and app.online, "Result Return to Lobby preserves destination and disconnects"):
		return
	var guest_card = preload("res://scripts/lan_results.gd").new()
	root.add_child(guest_card)
	guest_card.build(2, [{"health": 0, "lives": 0}, {"health": 100, "lives": 1}], {"elapsed": 65, "shots": 17, "cleared": 2, "total": 35}, false)
	if not check(guest_card.replay_button.disabled, "Guest replay disabled"):
		return
	print("PASS LAN results layout, role mapping, summary, permissions and lobby destination")
	quit()
