extends "res://tests/lan_duel_smoke.gd"
## Local routing/volume checks; paired mode monitors a complete real LAN duel.
var online_frames := 0

func _process(_delta: float) -> bool:
	if not is_instance_valid(app) or not app.online:
		return false
	var sound = app.client_menu.sound
	if sound.volume > 0.0:
		if not check(sound.voices.music.playing and not sound.voices.music.stream_paused, "Music remains active throughout online flow"):
			return false
	if is_instance_valid(lobby.active_room) and is_instance_valid(lobby.active_room.combat_view):
		check(not lobby.active_room.combat_view.sound.voices.music.playing, "Room effects do not duplicate background music")
	online_frames += 1
	return false

func run() -> void:
	if not OS.get_cmdline_user_args().has("local"):
		await super.run()
		return
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	var sound = app.client_menu.sound
	sound.set_volume(0.37)
	await create_timer(0.2).timeout
	var music: AudioStreamPlayer = sound.voices.music
	var before := music.get_playback_position()
	enter_menu(false)
	if not check(music.playing and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(sound.volume, 0.37), "Lobby starts looping music at selected volume"):
		return
	await create_timer(0.15).timeout
	if AudioServer.get_driver_name() != "Dummy":
		if not check(music.get_playback_position() > before, "Audio playback advances across lobby transition"):
			return
	sound.set_volume(0.0)
	await process_frame
	if not check(not music.playing, "Mute stops online music"):
		return
	sound.set_volume(0.37)
	await process_frame
	await process_frame
	if not check(music.playing, "Unmute restarts online music"):
		return
	lobby.host_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.phase == "ready"), "Hosted room ready"):
		return
	var identity := music.get_instance_id()
	if not check(sound.voices.music.get_instance_id() == identity and music.playing, "Game room retains the same music voice"):
		return
	lobby.active_room.show_settings()
	await process_frame
	if not check(music.playing and not music.stream_paused, "Room settings keep music and networking active"):
		return
	lobby.active_room.close_settings()
	lobby.active_room.leave_room()
	lobby.exit_button.pressed.emit()
	await process_frame
	if not check(not app.online and music.playing, "Lobby Exit returns music to main menu"):
		return
	button("Solo").pressed.emit()
	app.client_menu.pause_game()
	await process_frame
	if not check(music.stream_paused, "Offline pause still pauses its own music"):
		return
	app.client_menu.show_menu()
	await process_frame
	if not check(not music.stream_paused and online_frames > 0, "Menu resumes normal music after local pause"):
		return
	print("PASS lobby/room music, continuity, volume, mute/unmute, settings, return and offline pause")
	quit()
