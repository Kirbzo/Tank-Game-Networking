extends "res://tests/combat_smoke.gd"
## Actual host/guest ENet pair. No simulated connection or client-side authority.
var room: Control
var probe: Node
var digits: Array[int] = []
var digit_times: Array[int] = []
var running_at := 0
var frozen_visuals := true
var previous_frozen: Dictionary = {}
var previous_epoch := -1

class Probe extends Node:
	var test
	var observed: Dictionary = {}
	var done := false
	@rpc("any_peer", "call_remote", "reliable")
	func report(data: Dictionary) -> void:
		if multiplayer.is_server() and multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
			observed = data
	@rpc("authority", "call_remote", "reliable")
	func command(action: String) -> void:
		if action == "pause":
			test.room.settings_button.pressed.emit()
		elif action == "resume":
			test.room.settings_back_button.pressed.emit()
		elif action == "aim":
			test.aim_check()
		elif action == "leave":
			test.room.leave_room()
		elif action == "finish":
			done = true

func visual_state() -> Dictionary:
	var positions := {}
	for peer in room.artwork.tank_markers:
		var marker = room.artwork.tank_markers[peer]
		positions[peer] = [marker.position, marker.health, marker.lives, marker.heavy_time, marker.respawn_protection]
	var shots := {}
	for id in room.combat_view.bullets:
		shots[id] = room.combat_view.bullets[id].position
	var animals := []
	for animal in room.combat_view.animals:
		animals.append(animal.position)
	return {"positions": positions, "shots": shots, "animals": animals}

func observe() -> void:
	if not is_instance_valid(room):
		return
	if room.phase == "countdown" and (digits.is_empty() or digits[-1] != room.countdown_number):
		digits.append(room.countdown_number)
		digit_times.append(Time.get_ticks_msec())
	if room.phase == "running" and running_at == 0:
		running_at = Time.get_ticks_msec()
	if room.phase in ["countdown", "paused"]:
		var current := visual_state()
		if previous_epoch == room.epoch:
			frozen_visuals = frozen_visuals and current == previous_frozen
		previous_epoch = room.epoch
		previous_frozen = current
	else:
		previous_epoch = -1

func aim_check() -> void:
	root.grab_focus()
	await create_timer(0.2).timeout
	# Letterboxing/non-unit arena scale uses the same transform for aim and reticle.
	var original_scale: Vector2 = room.artwork.scale
	var original_position: Vector2 = room.artwork.position
	room.artwork.scale = Vector2(0.7, 0.7)
	room.artwork.position = Vector2(83, 61)
	var peer: int = lobby.multiplayer.get_unique_id()
	var target: Vector2 = room.artwork.tank_markers[peer].position + Vector2(80, -40)
	aim(target)
	room.update_aim()
	var expected := Vector2(80, -40).normalized()
	var actual: Vector2 = room.room_overlay.get_global_transform_with_canvas() * (room.room_overlay.get_global_transform_with_canvas().affine_inverse() * room.aim_pointer)
	if not check(room.aim_direction.distance_to(expected) < 0.001 and actual.distance_to(room.artwork.to_global(target)) < 0.01 and room.room_overlay.crosshair_visible(), "Mouse/reticle/turret agree under scaled, offset arena"):
		return
	room.artwork.scale = original_scale
	room.artwork.position = original_position
	aim(room.artwork.tank_markers[peer].position + Vector2(100, 0))
	room.update_aim()
	await fire_once()
	print("AIM_PASS ", "host" if lobby.multiplayer.is_server() else "guest")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/P118-%s-%s.png" % [label, "host" if lobby.multiplayer.is_server() else "guest"])

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-room-controls-test"
	probe = Probe.new()
	probe.name = "RoomControlsProbe"
	probe.test = self
	root.add_child(probe)
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discover host"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if hosting:
		if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.phase == "ready"), "Solo preview ready"):
			return
		lobby.active_room.settings_button.pressed.emit()
		if not check(lobby.active_room.phase == "paused", "Solo preview can pause before guest joins"):
			return
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2 and lobby.active_room.phase == "ready"), "Both players ready"):
		return
	room = lobby.active_room
	process_frame.connect(observe)
	if not check(room.settings_button.text == "Pause" and room.room_logo.texture != null and not room.status_message.text.contains("Move") and room.get("vitals_panel") == null, "Pause/logo, no controls line or duplicate vitals panel"):
		return
	if not check(room.room_logo.get_global_rect().end.y < 100 and not room.room_logo.get_global_rect().intersects(room.leave_button.get_global_rect()), "Logo above arena and clear of Back"):
		return
	if not hosting:
		var captured := {}
		while not probe.done and is_instance_valid(room):
			var key: String = room.phase
			if key in ["countdown", "paused", "running"] and not captured.has(key):
				captured[key] = true
				await capture(key)
			if not is_instance_valid(room) or lobby.session == null:
				break
			probe.report.rpc_id(1, {"phase": room.phase, "epoch": room.epoch, "digits": digits, "times": digit_times, "running": running_at, "frozen": frozen_visuals, "state": visual_state(), "shots": room.combat_view.shots_seen, "paused_ui": room.settings_screen.visible})
			await create_timer(0.02).timeout
		if not is_instance_valid(room):
			if OS.get_cmdline_user_args().has("host-leaves"):
				if not check(is_instance_valid(lobby.disconnected_screen), "Host departure during pause shows Disconnected"):
					return
			else:
				if not check(lobby.session == null and lobby.visible, "Voluntary departure returns guest to lobby"):
					return
		print("PASS room controls guest: countdown, frozen simulation, scaled aiming, pause/resume and departure")
		quit()
		return
	var guest: int = lobby.multiplayer.get_peers()[0]
	if not check(await until(func(): return probe.observed.get("phase") == "ready"), "Guest fixture ready"):
		return
	probe.command.rpc_id(guest, "pause")
	if not check(await until(func(): return room.phase == "paused" and probe.observed.get("phase") == "paused"), "New guest can pause preview after joining paused solo host"):
		return
	room.close_settings()
	if not check(await until(func(): return room.phase == "ready" and probe.observed.get("phase") == "ready"), "Preview resume has synchronized control revision"):
		return
	var start_stamp := Time.get_ticks_msec()
	room.begin_game()
	var start_positions: Dictionary = room.tank_world.positions.duplicate()
	for peer in start_positions:
		for corner in room.combat.CORNERS:
			if not check(start_positions[peer].distance_to(corner) > 330, "Safe spawn distance from every moose"):
				return
		for center in room.TankWorld.ice_centers():
			var offset: Vector2 = (start_positions[peer] - center).abs()
			if not check(offset.x >= 48 or offset.y >= 44, "Tank spawn outside ice collision bounds"):
				return
	await capture("countdown")
	room.request_pause(true)
	room.begin_game()
	room.accept_fire_request(guest, room.epoch, Vector2.RIGHT, 99999)
	room.accept_tank_input(guest, room.epoch, Vector2.RIGHT, 99999)
	if not check(room.phase == "countdown" and room.combat.next_shot == 0, "Countdown rejects duplicate Start, Pause and combat"):
		return
	if OS.get_cmdline_user_args().has("leave-countdown"):
		if not check(await until(func(): return probe.observed.get("phase") == "countdown"), "Shared countdown before disconnect"):
			return
		probe.command.rpc_id(guest, "leave")
		if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 1), "Guest departure cancels countdown into solo preview"):
			return
		await create_timer(3.2).timeout
		if not check(room.phase == "ready" and not room.combat.interactions_enabled and room.bottom_start_button.disabled, "Cancelled countdown never starts later"):
			return
		print("PASS room countdown departure and cancellation")
		quit()
		return
	if not check(await until(func(): return room.phase == "running" and probe.observed.get("phase") == "running"), "Host releases both players after countdown"):
		return
	print("COUNTDOWN_TRACE digits=", digits, " guest=", probe.observed.digits, " elapsed=", running_at - start_stamp)
	if not check(digits == [3, 2, 1] and probe.observed.digits == digits and running_at - start_stamp >= 3000 and running_at - start_stamp < 3500, "Full ordered 3-2-1 over three seconds on both peers"):
		return
	for i in range(1, 3):
		if not check(abs((digit_times[i] - digit_times[0]) - (probe.observed.times[i] - probe.observed.times[0])) < 120, "Countdown relative timing agrees within 120ms"):
			return
	print("COUNTDOWN_MS host=", running_at - digit_times[0], " guest=", probe.observed.running - probe.observed.times[0])
	if not check(room.tank_world.positions == start_positions and room.duel_vitals[1].health == 100 and room.duel_vitals[guest].health == 100, "Start preserves safe spawns and full health"):
		return
	await capture("running")
	# Live projectile and power-up timers must freeze, not merely the input controls.
	room.combat.proxies[1].apply_powerup("shield")
	room.accept_fire_request(1, room.epoch, Vector2.RIGHT, 1)
	await create_timer(0.05).timeout
	room.settings_button.pressed.emit()
	if not check(await until(func(): return probe.observed.get("phase") == "paused"), "Host Pause reaches guest"):
		return
	await capture("paused")
	var state: Dictionary = room.combat.snapshot().duplicate(true)
	var tick: int = room.tank_world.tick
	var elapsed: float = room.combat.match_elapsed
	var revision: int = room.control_revision
	room.accept_pause(guest, room.epoch - 1, revision, false)
	room.accept_pause(123, room.epoch, revision, false)
	room.accept_fire_request(guest, room.epoch, Vector2.RIGHT, 99999)
	room.accept_tank_input(guest, room.epoch, Vector2.RIGHT, 99999)
	await create_timer(0.8).timeout
	if not check(room.phase == "paused" and room.combat.snapshot() == state and room.tank_world.tick == tick and room.combat.match_elapsed == elapsed and probe.observed.frozen and frozen_visuals, "Pause freezes both tanks, bullets, moose, health and timers; invalid requests rejected"):
		return
	if not check(probe.observed.paused_ui and not paused, "Both show Resume while networking remains active"):
		return
	probe.command.rpc_id(guest, "resume")
	if not check(await until(func(): return room.phase == "running" and probe.observed.get("phase") == "running"), "Guest Resume unpauses host and guest"):
		return
	await create_timer(0.15).timeout
	if not check(room.tank_world.tick > tick and room.combat.match_elapsed > elapsed and not room.settings_screen.visible, "Authoritative simulation resumes"):
		return
	await aim_check()
	var shots: int = room.combat.next_shot
	probe.command.rpc_id(guest, "aim")
	if not check(await until(func(): return room.combat.next_shot > shots), "Guest mouse shot reaches authority after resume"):
		return
	await create_timer(0.2).timeout
	probe.command.rpc_id(guest, "pause")
	if not check(await until(func(): return room.phase == "paused" and probe.observed.get("phase") == "paused"), "Guest Pause freezes both players"):
		return
	room.settings_back_button.pressed.emit()
	if not check(await until(func(): return room.phase == "running" and probe.observed.get("phase") == "running"), "Host Resume unpauses both"):
		return
	room.request_pause(true)
	if not check(await until(func(): return probe.observed.get("phase") == "paused"), "Paused before disconnect"):
		return
	if OS.get_cmdline_user_args().has("host-leaves"):
		room.leave_room()
		await create_timer(0.5).timeout
	else:
		probe.command.rpc_id(guest, "leave")
		if not check(await until(func(): return room.phase == "ready" and room.player_names.size() == 1), "Guest departure while paused restores solo preview"):
			return
		if not check(not room.settings_screen.visible and room.bottom_start_button.disabled and room.artwork.process_mode == Node.PROCESS_MODE_INHERIT, "Pause UI and frozen visuals cleared after departure"):
			return
	print("PASS room controls host: countdown, safe spawns, both pause/resume directions, frozen world, aiming, stale-input rejection and disconnect")
	quit()
