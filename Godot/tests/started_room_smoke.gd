extends "res://tests/combat_smoke.gd"
const STAGE_FILE := "res://.godot/integration/P114-stage.txt"
var probe: GateProbe
class GateProbe extends Node:
	var observed: Dictionary = {}
	@rpc("any_peer", "call_remote", "reliable")
	func report(data: Dictionary) -> void:
		if multiplayer.is_server() and multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
			observed[multiplayer.get_remote_sender_id()] = data
func stage() -> String:
	return FileAccess.get_file_as_string(STAGE_FILE)
func set_stage(value: String) -> void:
	var file := FileAccess.open(STAGE_FILE, FileAccess.WRITE)
	file.store_string(value)
func started_notice() -> bool:
	var notice = lobby.disconnected_screen
	return is_instance_valid(notice) and notice.title.text == "Game already started" and notice.explanation.text.contains("wait until the game has ended") and notice.retry_button.visible and notice.return_button.text == "Return to Lobby" and lobby.session == null and not lobby.joining and not is_instance_valid(lobby.active_room)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var role: String = args[0] if not args.is_empty() else "first"
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-started-room-test"
	probe = GateProbe.new()
	probe.name = "GateProbe"
	root.add_child(probe)
	enter_menu(role == "host")
	if role == "joiner":
		if not check(await until(func(): return stage() == "running" and not lobby.discovery.games.is_empty()), "Wait for running duel"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		if not check(await until(func(): return lobby.discovery.games.get(id,{}).get("started",false)), "Running flag advertised"):
			return
		lobby.game_id.text = id
		lobby.identify_game(id)
		if not check(lobby.game_list.get_item_text(lobby.listed_ids.find(id)).contains("Game started"), "Started listing remains selectable"):
			return
		lobby.join_button.pressed.emit()
		if not check(started_notice(), "Fresh listing shows started notice with Retry and Return"):
			return
		if args.has("render"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/integration/P114-started.png")
		lobby.disconnected_screen.retry_button.pressed.emit()
		if not check(started_notice() and lobby.join_target.id == id, "Retry during match preserves target and notice"):
			return
		lobby.disconnected_screen.return_button.pressed.emit()
		if not check(not is_instance_valid(lobby.disconnected_screen) and lobby.visible and lobby.get_child(0).visible and lobby.join_target.is_empty(), "Return restores lobby"):
			return
		# Host starts during the pre-connect delay: latest listing prevents ENet startup.
		lobby.discovery.set_process(false)
		lobby.discovery.games[id].started = false
		lobby.join_game()
		await create_timer(0.1).timeout
		lobby.discovery.games[id].started = true
		lobby.discovery.games[id].seen = Time.get_ticks_msec()
		await create_timer(0.5).timeout
		if not check(started_notice() and lobby.joining_screen.timeout.is_stopped(), "Start/delay race stops pending Join"):
			return
		lobby.disconnected_back()
		# Deliberately stale discovery: only authoritative admission can stop this.
		lobby.discovery.games[id].started = false
		lobby.discovery.games[id].seen = Time.get_ticks_msec()
		lobby.join_game()
		if not check(await until(started_notice), "Server denies stale-listing late join before opening room"):
			return
		if not check(lobby.joining_screen.timeout.is_stopped(), "Server rejection stops loading timer"):
			return
		set_stage("denied")
		lobby.discovery.set_process(true)
		if not check(await until(func(): return stage() == "ended" and not lobby.discovery.games.get(id,{}).get("started",true)), "End advertises reopened room"):
			return
		lobby.disconnected_screen.retry_button.pressed.emit()
		if not check(lobby.joining and lobby.joining_screen.visible, "Retry after end uses normal loading"):
			return
		if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.phase == "ready" and lobby.active_room.player_names.size() == 3), "Retry after match end admits third player"):
			return
	elif role == "first":
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discover host"):
			return
		lobby.game_id.text = lobby.discovery.games.keys()[0]
		lobby.join_game()
		if not check(await until(func(): return is_instance_valid(lobby.active_room)), "First guest admitted"):
			return
	if role != "host":
		var deadline := Time.get_ticks_msec()+30000
		while Time.get_ticks_msec()<deadline:
			if is_instance_valid(lobby.disconnected_screen):
				if not check(lobby.disconnected_screen.title.text == "Disconnected", "Final host loss notice"):
					return
				print("PASS started-room guest ",role," admission, retry and host close")
				quit()
				return
			var room = lobby.active_room
			probe.report.rpc_id(1,{"phase":room.phase,"count":room.player_names.size(),"epoch":room.epoch})
			await create_timer(0.03).timeout
		check(false,"Guest test completed before timeout")
		return
	if not check(await until(func(): return lobby.active_room.phase == "ready" and lobby.active_room.player_names.size() == 2), "Two players ready"):
		return
	var room = lobby.active_room
	room.begin_game()
	var epoch: int = room.epoch
	var tick: int = room.tank_world.tick
	if not check(room.phase == "running" and lobby.match_started(), "Host start closes room admission"):
		return
	set_stage("running")
	if not check(await until(func(): return stage() == "denied" and lobby.multiplayer.get_peers().size() == 1), "Late join rejected and released"):
		return
	if not check(room.phase == "running" and room.epoch == epoch and room.player_names.size() == 2 and room.tank_world.tick > tick, "Late Join does not interrupt duel"):
		return
	var loser = room.combat.proxies[lobby.multiplayer.get_peers()[0]]
	loser.clear_powerups()
	loser.lives = 1
	loser.take_damage(100)
	if not check(room.phase == "finished" and not lobby.match_started(), "End reopens room without requiring Play Again"):
		return
	set_stage("ended")
	if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 3 and probe.observed.size() == 2 and probe.observed.values().all(func(data): return data.phase == "ready" and data.count == 3)), "Both guests share reopened three-player preview"):
		return
	if not check(room.can_begin_game() and not room.combat.interactions_enabled, "Reopened three-player preview waits for host Start"):
		return
	room.leave_room()
	await create_timer(0.3).timeout
	print("PASS started-room host: authoritative late-join denial, live duel preserved and end/retry reopening")
	quit()
