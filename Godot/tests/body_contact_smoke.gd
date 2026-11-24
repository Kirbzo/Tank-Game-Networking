extends "res://tests/combat_smoke.gd"
var probe
class ContactProbe extends Node:
	var test
	var observed: Dictionary = {}
	var done := false
	@rpc("any_peer", "call_remote", "reliable")
	func report(state: Dictionary) -> void:
		if multiplayer.is_server():
			observed = state
	@rpc("authority", "call_remote", "reliable")
	func move(pressed: bool) -> void:
		test.key(KEY_A, pressed)
	@rpc("authority", "call_remote", "reliable")
	func finish() -> void:
		done = true
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func run() -> void:
	var world = preload("res://tank_world.gd").new()
	world.positions = {1: Vector2(400, 430), 2: Vector2(500, 430)}
	var swept = world.move_body(1, world.positions[1], Vector2(600, 0))
	if not check(swept.position.x <= 452.01 and swept.normal == Vector2.LEFT, "Swept tank contact cannot tunnel"):
		return
	world.moose_positions.append(Vector2(450, 430))
	var overlap = world.move_body(1, Vector2(445, 430), Vector2.ZERO)
	if not check(overlap.position.distance_to(Vector2(450, 430)) >= 44.99, "Overlapping moving hazard separates"):
		return
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-body-contact-test"
	probe = ContactProbe.new()
	probe.test = self
	probe.name = "ContactProbe"
	root.add_child(probe)
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Discovery"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.phase == "ready" and lobby.active_room.player_names.size() == 2), "Both ready"):
		return
	var room = lobby.active_room
	if not hosting:
		while not probe.done:
			if not is_instance_valid(room):
				check(false, "Host left before contact checks completed")
				return
			probe.report.rpc_id(1, {"vitals": room.duel_vitals, "positions": room.tank_view.snapshots[-1].positions if not room.tank_view.snapshots.is_empty() else {}})
			await create_timer(0.05).timeout
		print("PASS guest body contact state and prediction remains connected")
		quit()
		return
	var guest: int = lobby.multiplayer.get_peers()[0]
	for stage in range(2):
		if stage == 1:
			room.begin_game()
			if not check(await until(func(): return room.phase == "running"), "Countdown completes before contact fixtures"):
				return
			for animal in room.combat.moose:
				animal.set_physics_process(false)
		room.tank_world.positions[1] = Vector2(400, 430)
		room.tank_world.positions[guest] = Vector2(480, 430)
		await create_timer(0.3).timeout
		key(KEY_D, true)
		probe.move.rpc_id(guest, true)
		await create_timer(0.7).timeout
		key(KEY_D, false)
		probe.move.rpc_id(guest, false)
		await create_timer(0.25).timeout
		if not check(room.tank_world.positions[1].x < room.tank_world.positions[guest].x and room.tank_world.positions[1].distance_to(room.tank_world.positions[guest]) >= 47.99, "Head-on tanks bounce without crossing in preview and match"):
			return
		if not check(room.duel_vitals[1].health == 100 and room.duel_vitals[guest].health == 100 and probe.observed.vitals[1].health == 100, "Tank contacts cause no damage on both peers"):
			return
	var animal = room.combat.moose[0]
	room.tank_world.positions[1] = Vector2(400, 430)
	room.tank_world.positions[guest] = Vector2(800, 430)
	room.combat.proxies[1].respawn_protection = 1.5
	room.combat.proxies[1].moose_cooldown = 0
	animal.position = Vector2(465, 430)
	animal.heading = Vector2.LEFT
	animal.emerge_delay = 0
	animal.set_physics_process(true)
	key(KEY_D, true)
	await create_timer(0.5).timeout
	key(KEY_D, false)
	if not check(room.duel_vitals[1].health == 100 and room.tank_world.positions[1].x < animal.position.x and room.tank_world.positions[1].distance_to(animal.position) >= 44.8, "Invincible tank stays solid against moose without damage"):
		return
	animal.set_physics_process(false)
	await physics_frame
	room.combat.proxies[1].respawn_protection = 0
	room.combat.proxies[1].moose_cooldown = 0
	room.tank_world.contact_cooldowns[1] = 0.0
	room.combat.proxies[1].position = room.tank_world.positions[1]
	animal.previous_contacts.clear()
	animal.position = room.combat.proxies[1].position + Vector2(44.95, 0)
	animal.heading = Vector2.LEFT
	animal._physics_process(0.001)
	if not check(await until(func(): return room.duel_vitals[1].health == 80 and probe.observed.vitals[1].health == 80), "Normal moose contact still deals shared damage"):
		return
	room.tank_world.bounce_push[1] = Vector2.RIGHT * 150.0
	room.combat.proxies[1].take_damage(100)
	if not check(not room.tank_world.bounce_push.has(1) and room.combat.proxies[1].lives == 2, "Respawn clears old body bounce"):
		return
	probe.finish.rpc_id(guest)
	await create_timer(0.2).timeout
	print("PASS host swept collision, preview/match bounce, invincible moose contact and normal damage")
	quit()
