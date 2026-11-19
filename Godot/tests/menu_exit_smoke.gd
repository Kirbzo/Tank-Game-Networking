extends "res://tests/combined_smoke.gd"
## Persistent launch menu routing, clean cancellation and real reconnection.
func at_main_menu() -> bool:
	return not app.online and not lobby.visible and app.client_menu.visible and app.client_menu.ui.visible and app.client_menu.is_processing() and app.client_menu.is_processing_unhandled_input() and lobby.session == null and not lobby.joining and not is_instance_valid(lobby.active_room) and lobby.discovery.hosted_game.is_empty() and lobby.exit_screen == null

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("standalone"):
		var standalone = load("res://lobby.tscn").instantiate()
		root.add_child(standalone)
		current_scene = standalone
		standalone.exit_button.pressed.emit()
		if not check(await until(func(): return current_scene != null and current_scene.scene_file_path == "res://application.tscn"), "Standalone lobby Exit opens configured launch application"):
			return
		app = current_scene
		lobby = app.lobby
		if not check(at_main_menu(), "Standalone scene Exit also shows main menu"):
			return
		print("PASS standalone lobby Exit -> launch main menu")
		quit()
		return
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-menu-exit-test"
	if args.has("local"):
		for i in range(2):
			enter_menu(true)
			var room = lobby.active_room
			var peer = lobby.session
			if not check(is_instance_valid(room), "Host is usable after menu return"):
				return
			room.leave_button.pressed.emit()
			if not check(lobby.visible and not app.client_menu.ui.visible and lobby.session == null, "Room Back still goes to lobby"):
				return
			lobby.exit_button.pressed.emit()
			await process_frame
			if not check(at_main_menu() and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and button("Play") != null, "Lobby Exit restores main menu and closes previous peer"):
				return
			lobby.show_exit_screen()
			if not check(at_main_menu(), "Repeated Exit is safe"):
				return
		var silent := PacketPeerUDP.new()
		if not check(silent.bind(0, "127.0.0.1") == OK, "Silent join target"):
			return
		for wait in [0.0, 0.6]:
			enter_menu(false)
			lobby.discovery.remember_game("ABC123", "127.0.0.1", silent.get_local_port(), "SilentHost", 1)
			lobby.game_id.text = "ABC123"
			lobby.join_game()
			if wait > 0:
				await create_timer(wait).timeout
				if not check(lobby.session != null, "Pending join opens actual client peer"):
					return
			lobby.show_exit_screen()
			await create_timer(0.7).timeout
			lobby.join_connected()
			if not check(at_main_menu() and lobby.joining_screen.timeout.is_stopped() and not lobby.joining_screen.visible, "Exit cancels delayed/active joins and blocks late completion"):
				return
		silent.close()
		print("PASS main-menu Exit, repeated Host/Back/Exit, input restore and pending cancellation")
		quit()
		return
	var hosting := args.has("host")
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discover first host"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2), "Two real players connected"):
		return
	if hosting:
		# Allow the names RPC to reach the guest before deliberately closing the host.
		await create_timer(0.5).timeout
		var previous = lobby.session
		# Exercise the Exit cleanup callback with an active session as well.
		lobby.show_exit_screen()
		if not check(at_main_menu() and previous.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "Host Exit closes room and returns to menu"):
			return
		await create_timer(0.4).timeout
		enter_menu(true)
		if not check(lobby.session != previous and is_instance_valid(lobby.active_room), "Host can create a fresh room without restarting app"):
			return
		if not check(await until(func(): return lobby.active_room.player_names.size() == 2), "Guest reconnects after both return to menu"):
			return
		if not check(await until(func(): return lobby.active_room.player_names.size() == 1), "Guest second exit updates membership"):
			return
		lobby.active_room.leave_room()
		lobby.exit_button.pressed.emit()
		if not check(at_main_menu(), "Host can exit again"):
			return
	else:
		var old_id: String = lobby.connected_game_id
		if not check(await until(func(): return is_instance_valid(lobby.disconnected_screen)), "Host Exit gives normal disconnect notice"):
			return
		lobby.disconnected_screen.return_button.pressed.emit()
		if not check(lobby.visible and not app.client_menu.ui.visible, "Disconnect Return to Lobby destination unchanged"):
			return
		lobby.exit_button.pressed.emit()
		if not check(at_main_menu(), "Guest lobby Exit returns to menu"):
			return
		enter_menu(false)
		if not check(await until(func(): return lobby.discovery.games.keys().any(func(id): return id != old_id)), "New host listing discovered after reentry"):
			return
		for id in lobby.discovery.games:
			if id != old_id:
				lobby.game_id.text = id
				lobby.identify_game(id)
				break
		lobby.join_button.pressed.emit()
		if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2), "Guest can join again from restored menu"):
			return
		await create_timer(0.3).timeout
		lobby.active_room.leave_room()
		lobby.exit_button.pressed.emit()
		if not check(at_main_menu(), "Guest can exit again"):
			return
	print("PASS actual host/guest Exit -> main menu -> fresh Host/Join without app restart")
	quit()
