extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func full_notice(lobby: Control) -> bool:
	var notice = lobby.disconnected_screen
	return is_instance_valid(notice) and notice.is_visible_in_tree() and notice.title.text == "Room Full" and notice.explanation.text.contains("already has two players") and notice.return_button.text == "Return to Lobby" and lobby.session == null and not lobby.joining

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	current_scene = lobby
	lobby.discovery.protocol = "moooze-room-full-test"
	if args.has("host"):
		lobby.host_game()
		for i in range(300):
			if lobby.multiplayer.get_peers().size() == 1:
				break
			await create_timer(0.05).timeout
		if not check(lobby.multiplayer.get_peers().size() == 1, "One guest fills actual host"):
			return
		await create_timer(3.0).timeout
		if not check(lobby.multiplayer.get_peers().size() == 1 and lobby.discovery.hosted_game["players"] == 2, "Blocked player does not disturb occupied room"):
			return
		for i in range(200):
			if lobby.multiplayer.get_peers().is_empty():
				break
			await create_timer(0.05).timeout
		lobby.active_room.leave_room()
		print("PASS occupied host capacity")
		quit(0)
		return
	for i in range(300):
		if not lobby.discovery.games.is_empty():
			break
		await create_timer(0.05).timeout
	if not check(not lobby.discovery.games.is_empty(), "Discover actual host"):
		return
	var id: String = lobby.discovery.games.keys()[0]
	lobby.game_id.text = id
	if args.has("occupant"):
		lobby.join_game()
		for i in range(200):
			if is_instance_valid(lobby.active_room):
				break
			await create_timer(0.05).timeout
		if not check(is_instance_valid(lobby.active_room), "First guest joins actual room"):
			return
		await create_timer(5.0).timeout
		if not check(lobby.session != null and lobby.multiplayer.get_peers().size() == 1, "Occupant stays connected during full-room attempts"):
			return
		lobby.active_room.leave_room()
		print("PASS occupied guest remains connected")
		quit(0)
		return
	for i in range(200):
		if lobby.discovery.games.get(id, {}).get("players", 0) == 2:
			break
		await create_timer(0.05).timeout
	if not check(lobby.discovery.games.get(id, {}).get("players", 0) == 2, "Live host advertises full room"):
		return
	lobby.join_game()
	if not check(full_notice(lobby) and lobby.joining_screen == null, "Full Join shows Room Full without connection or Retry"):
		return
	lobby.disconnected_screen.return_button.pressed.emit()
	# Freeze discovery only for deterministic UI races after the real full listing.
	lobby.discovery.set_process(false)
	lobby.discovery.games[id]["players"] = 0
	lobby.join_game()
	await process_frame
	await process_frame
	lobby.join_failed()
	if not check(lobby.joining_screen.retry_button.visible and not is_instance_valid(lobby.disconnected_screen), "Unknown availability preserves existing Retry flow"):
		return
	lobby.discovery.games[id]["players"] = 2
	lobby.discovery.games[id]["seen"] = Time.get_ticks_msec()
	lobby.joining_screen.retry_button.pressed.emit()
	if not check(full_notice(lobby) and not lobby.joining_screen.visible and lobby.joining_screen.timeout.is_stopped(), "Retry with fresh full listing shows Room Full and stops timer"):
		return
	lobby.disconnected_screen.return_button.pressed.emit()
	lobby.discovery.games[id]["players"] = 0
	lobby.join_game()
	await process_frame
	await process_frame
	lobby.discovery.games[id]["players"] = 2
	lobby.discovery.games[id]["seen"] = Time.get_ticks_msec()
	lobby.refresh_games()
	if not check(lobby.joining and not is_instance_valid(lobby.disconnected_screen), "Live full update may include us; wait for connection outcome"):
		return
	lobby.join_failed()
	if not check(full_notice(lobby), "Failed pending Join with fresh full listing closes peer and shows notice"):
		return
	lobby.disconnected_screen.return_button.pressed.emit()
	lobby.discovery.games[id]["seen"] = Time.get_ticks_msec() - lobby.discovery.EXPIRY_MS - 1
	lobby.join_game()
	if not check(lobby.joining and not is_instance_valid(lobby.disconnected_screen), "Expired full listing does not falsely claim room is full"):
		return
	lobby.join_cancelled()
	if not check(lobby.get_child(0).visible and not lobby.host_button.disabled, "Return/cancel restores usable lobby"):
		return
	print("PASS Room Full Join/Retry, pending update, unknown/stale fallback and lobby return")
	quit(0)
