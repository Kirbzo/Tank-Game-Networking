extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		failed = true
		printerr("FAIL: " + message)
		quit(1)
	return value

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var hosting := args.has("host")
	var host_leaves := args.has("host-leaves")
	var lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	lobby.discovery.protocol = "moooze-connected-room-test"
	if hosting:
		lobby.host_button.pressed.emit()
		if not check(is_instance_valid(lobby.active_room), "Host enters room"):
			return
		if not check(lobby.active_room.game_id == lobby.discovery.hosted_game["id"], "Real host ID"):
			return
		for i in range(300):
			if lobby.multiplayer.get_peers().size() == 1:
				break
			await create_timer(0.05).timeout
		if not check(lobby.multiplayer.get_peers().size() == 1, "Actual remote connection"):
			return
		await create_timer(1.0).timeout
		if not check(lobby.active_room.status_message.text.contains("2/2"), "Host count"):
			return
		if not host_leaves:
			for i in range(200):
				if lobby.multiplayer.get_peers().is_empty():
					break
				await create_timer(0.05).timeout
			await process_frame
			await process_frame
			if not check(lobby.multiplayer.get_peers().is_empty() and lobby.active_room.status_message.text.contains("1/2"), "Host remains after client leave"):
				return
		lobby.active_room.leave_button.pressed.emit()
	else:
		for i in range(300):
			if not lobby.discovery.games.is_empty():
				break
			await create_timer(0.05).timeout
		if not check(not lobby.discovery.games.is_empty(), "Host discoverable while in room"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id.to_lower()
		lobby.join_game()
		for i in range(300):
			if is_instance_valid(lobby.active_room):
				break
			await create_timer(0.05).timeout
		if not check(is_instance_valid(lobby.active_room), "Join enters room"):
			return
		if not check(lobby.active_room.game_id == id, "Matching room ID"):
			return
		if host_leaves:
			for i in range(200):
				if not is_instance_valid(lobby.active_room):
					break
				await create_timer(0.05).timeout
			await create_timer(1.0).timeout
			var notice = lobby.disconnected_screen
			if not check(is_instance_valid(notice) and notice.is_visible_in_tree() and notice.title.text == "Disconnected" and notice.explanation.text.contains("host disconnected"), "Separate host departure screen visible"):
				return
			if not check(lobby.session == null and not lobby.joining and not lobby.get_child(0).visible and notice.return_button.has_focus(), "Notice blocks lobby after cleaning up connection"):
				return
			lobby.join_server_disconnected()
			if not check(lobby.disconnected_screen == notice, "Repeated disconnect keeps one notice"):
				return
			lobby.join_connected()
			if not check(not is_instance_valid(lobby.active_room), "Late connected callback cannot reopen room"):
				return
			notice.return_button.pressed.emit()
			notice.return_button.pressed.emit()
			lobby.join_server_disconnected()
		else:
			await create_timer(2.0).timeout
			if not check(lobby.session != null and lobby.active_room.status_message.text.contains("2/2"), "Connection persists in room"):
				return
			lobby.active_room.leave_button.pressed.emit()
	await process_frame
	if not check(not is_instance_valid(lobby.active_room) and lobby.session == null, "Leave clears room/session"):
		return
	if not check(lobby.get_child(0).is_visible_in_tree() and not lobby.host_button.disabled, "Usable lobby restored"):
		return
	print("PASS connected room " + ("host" if hosting else "client") + (" host-leaves" if host_leaves else " client-leaves"))
	quit(1 if failed else 0)
