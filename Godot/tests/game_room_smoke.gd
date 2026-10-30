extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("FAIL: " + message)
		quit(1)
	return condition

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var room: Control
	if OS.get_cmdline_user_args().has("from-lobby"):
		var lobby = load("res://lobby.tscn").instantiate()
		root.add_child(lobby)
		current_scene = lobby
		await process_frame
		if not check(lobby.test_room_button.is_visible_in_tree() and not lobby.test_room_button.disabled, "Lobby must expose the temporary room button"):
			return
		lobby.joining = true
		lobby.update_join_button()
		lobby.open_test_room()
		if not check(lobby.test_room_button.disabled and current_scene == lobby, "Preview must not interrupt a Join attempt"):
			return
		lobby.joining = false
		lobby.update_join_button()
		lobby.test_room_button.pressed.emit()
		await process_frame
		await process_frame
		if not check(current_scene != null and current_scene.scene_file_path == "res://game_room.tscn", "Temporary button must open the room scene"):
			return
		room = current_scene
	else:
		room = load("res://game_room.tscn").instantiate()
		root.add_child(room)
		current_scene = room
		await process_frame
	room.set_physics_process(false)
	var hud_rect: Rect2 = room.leave_button.get_global_rect()
	var settings_rect: Rect2 = room.settings_button.get_global_rect()
	if not check(room.hud.layer > 0 and not room.hud.follow_viewport_enabled and room.game_id_label.text == "Game ID: PREVIEW", "HUD must be a fixed layer above the world with a labelled preview ID"):
		return
	if not check(hud_rect.position.x < settings_rect.position.x and hud_rect.position.y == settings_rect.position.y, "Leave/settings controls must occupy opposite top corners"):
		return
	room.settings_button.pressed.emit()
	if not check(room.settings_screen.visible and not room.leaving, "Gear must open the temporary settings screen"):
		return
	var paused_position: Vector2 = room.player_position
	key(KEY_D, true)
	room._physics_process(0.1)
	key(KEY_D, false)
	if not check(room.player_position.is_equal_approx(paused_position), "Settings screen must block room movement"):
		return
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	if not check(not room.settings_screen.visible and current_scene == room, "Escape in settings must return to the room, not leave it"):
		return
	room.settings_button.pressed.emit()
	room.settings_back_button.pressed.emit()
	if not check(not room.settings_screen.visible and current_scene == room, "Settings Back must restore the room"):
		return
	var start: Vector2 = room.player_position
	if not check(room.arena.encloses(Rect2(start, room.PLAYER_SIZE)), "Player must spawn entirely inside the room"):
		return
	key(KEY_D, true)
	room._physics_process(0.1)
	key(KEY_D, false)
	var cardinal: Vector2 = room.player_position - start
	if not check(room.leave_button.get_global_rect() == hud_rect and room.settings_button.get_global_rect() == settings_rect, "Player movement must not shift the HUD"):
		return
	if not check(cardinal.x > 0 and is_zero_approx(cardinal.y), "D input must move right"):
		return
	room.player_position = start
	key(KEY_RIGHT, true)
	key(KEY_DOWN, true)
	room._physics_process(0.1)
	key(KEY_RIGHT, false)
	key(KEY_DOWN, false)
	var diagonal: Vector2 = room.player_position - start
	if not check(diagonal.x > 0 and diagonal.y > 0 and is_equal_approx(diagonal.length(), cardinal.length()), "Diagonal arrow movement must have the same speed as straight movement"):
		return
	room.player_position = start
	key(KEY_A, true)
	key(KEY_D, true)
	room._physics_process(0.1)
	key(KEY_A, false)
	key(KEY_D, false)
	if not check(room.player_position.is_equal_approx(start), "Opposite directions must cancel"):
		return
	for code in [KEY_W, KEY_A, KEY_S, KEY_LEFT, KEY_UP]:
		room.player_position = start
		key(code, true)
		room._physics_process(0.1)
		key(code, false)
		if not check(not room.player_position.is_equal_approx(start), "Each movement key must work"):
			return
	key(KEY_W, true)
	key(KEY_A, true)
	room._physics_process(100.0)
	key(KEY_W, false)
	key(KEY_A, false)
	if not check(room.arena.encloses(Rect2(room.player_position, room.PLAYER_SIZE)), "Top/left walls must contain the entire player"):
		return
	key(KEY_S, true)
	key(KEY_D, true)
	room._physics_process(100.0)
	key(KEY_S, false)
	key(KEY_D, false)
	room.size = Vector2(700, 500)
	room.layout_room()
	if not check(room.arena.encloses(Rect2(room.player_position, room.PLAYER_SIZE)), "Bottom/right walls and resizing must contain the entire player"):
		return
	if OS.get_cmdline_user_args().has("escape"):
		key(KEY_ESCAPE, true)
		key(KEY_ESCAPE, false)
	else:
		room.leave_button.pressed.emit()
	room.leave_room() # Repeat during transition must be harmless.
	await process_frame
	await process_frame
	if not check(current_scene != null and current_scene.scene_file_path == "res://lobby.tscn" and current_scene.session == null, "Leave must return to the lobby without starting a session"):
		return
	print("PASS room layers/HUD/settings: fixed controls, preview ID, movement, walls, resize, leave to lobby")
	quit()
