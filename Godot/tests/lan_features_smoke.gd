extends "res://tests/combat_test_base.gd"
const Brick = preload("res://scripts/brick.gd")
## Real ENet peers: host-owned rewards, replacement geometry and timed effects.
var room: Control
var probe: FeatureProbe

class FeatureProbe extends Node:
	var test
	var observed: Dictionary = {}
	var done := false
	@rpc("any_peer", "call_remote", "reliable")
	func report(data: Dictionary) -> void:
		if multiplayer.is_server() and multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
			observed = data
	@rpc("authority", "call_remote", "reliable")
	func fire(at: Vector2) -> void:
		test.aim(at)
		await test.fire_once()
	@rpc("authority", "call_remote", "reliable")
	func move(pressed: bool) -> void:
		var key := InputEventKey.new()
		key.keycode = KEY_D
		key.physical_keycode = KEY_D
		key.pressed = pressed
		Input.parse_input_event(key)
	@rpc("authority", "call_remote", "reliable")
	func finish() -> void:
		done = true

func marked(kind: String) -> Node:
	for brick in room.combat.get_children():
		if brick is Brick and not brick.broken and brick.powerup == kind:
			return brick
	return null

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-features-test-1"
	probe = FeatureProbe.new()
	probe.name = "FeatureProbe"
	probe.test = self
	root.add_child(probe)
	enter_menu(hosting)
	# Optional real loopback connection isolates combat from broadcast availability.
	var args := OS.get_cmdline_user_args()
	if hosting and args.has("loopback"):
		print("ENDPOINT ", lobby.discovery.hosted_game.id, " ", lobby.discovery.hosted_game.port)
	if not hosting and args.has("loopback"):
		var index := args.find("loopback")
		lobby.discovery.remember_game(args[index + 1], "127.0.0.1", int(args[index + 2]), "TestHost", 1)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Feature discovery"):
			return
		lobby.game_id.text = lobby.discovery.games.keys()[0]
		lobby.join_game()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2), "Two connected feature peers"):
		return
	room = lobby.active_room
	if not hosting:
		if not check(await until(func(): return is_instance_valid(room.combat_view)), "Guest feature renderer ready"):
			return
		var deadline := Time.get_ticks_msec() + 60000
		while not probe.done and Time.get_ticks_msec() < deadline:
			var previous_extra: Dictionary = room.tank_world.extra_ice.duplicate()
			room.apply_combat_event("ice_spawn", {"id": 999999, "position": Vector2(450, 430), "revision": -1})
			if not check(room.tank_world.extra_ice == previous_extra, "Stale ice event cannot overwrite snapshot"):
				return
			var anger := false
			for animal in room.combat_view.animals:
				anger = anger or animal.anger_remaining > 0.0
			var before_shots: int = room.combat_view.shots_seen
			room.receive_combat_event(room.epoch, room.event_sequence, "shot", {"id": 999999})
			room.receive_combat_event(room.epoch - 1, room.event_sequence + 1, "shot", {"id": 999999})
			if not check(room.combat_view.shots_seen == before_shots, "Duplicate/stale gameplay events ignored"):
				return
			probe.report.rpc_id(1, {"vitals": room.duel_vitals, "extra": room.tank_world.extra_ice, "ice": room.artwork.ice_count, "phase": room.phase, "anger": anger, "sounds": room.combat_view.sound.last_played.keys(), "position": room.tank_view.predicted_position, "stats": room.match_stats, "shots_seen": room.combat_view.shots_seen, "music": room.combat_view.sound.voices.music.playing})
			await create_timer(0.03).timeout
		if not check(probe.done, "Host completed feature fixture"):
			return
		room.leave_room()
		await process_frame
		app.queue_free()
		await process_frame
		print("PASS LAN features guest: replicated rewards, geometry, warning and replay")
		quit()
		return
	if not check(await until(func(): return room.phase == "ready"), "Feature preview readiness"):
		return
	var guest: int = lobby.multiplayer.get_peers()[0]
	var rewards := 0
	for brick in room.combat.get_children():
		if brick is Brick and not brick.powerup.is_empty():
			rewards += 1
	if not check(rewards == 8, "Eight hidden authoritative rewards"):
		return
	room.begin_game()
	for animal in room.combat.moose:
		animal.set_physics_process(false)
	var proxy = room.combat.proxies[guest]
	for kind in ["heavy", "shield", "speed", "health"]:
		proxy.clear_powerups()
		proxy.take_damage(40 if proxy.health == 100 else 0)
		var brick = marked(kind)
		if not check(brick != null, "Hidden " + kind + " remains available"):
			return
		room.tank_world.positions[guest] = brick.position + Vector2(0, -65)
		room.tank_world.positions[1] = Vector2(950, 640)
		await create_timer(0.25).timeout
		probe.fire.rpc_id(guest, brick.position)
		var effect: String = "recovery" if kind == "health" else kind
		if not check(await until(func(): return float(probe.observed.get("vitals", {}).get(guest, {}).get(effect, 0.0)) > 28.0, 3.0), "Guest real projectile receives " + kind + " from host"):
			return
		if not check(room.combat.proxies[1].powerup_status() == "No power-up", "Reward stays with shooter"):
			return
		if not check(await until(func(): return not probe.observed.get("extra", {}).is_empty() and probe.observed.extra == room.tank_world.extra_ice), "Replacement positions converge on both peers"):
			return
		if kind == "health" and not check(proxy.health == 95, "Health restores 35 without adding lives"):
			return
	proxy.clear_powerups()
	proxy.apply_powerup("heavy")
	room.tank_world.positions[guest] = Vector2(450, 430)
	room.tank_world.positions[1] = Vector2(550, 430)
	await create_timer(0.25).timeout
	probe.fire.rpc_id(guest, Vector2(550, 430))
	if not check(await until(func(): return room.combat.proxies[1].health == 60 and probe.observed.get("vitals", {}).get(1, {}).get("health", -1) == 60), "Guest heavy projectile deals shared 40 damage"):
		return
	var blast_target: Node
	for brick in room.combat.get_children():
		if brick is Brick and not brick.reinforced and not brick.broken:
			var adjacent := 0
			for other in room.combat.get_children():
				if other is Brick and not other.reinforced and not other.broken and other.position.distance_to(brick.position) <= 58:
					adjacent += 1
			if adjacent > 1:
				blast_target = brick
				break
	if not check(blast_target != null, "Heavy blast fixture has adjacent ice"):
		return
	var cleared_before: int = room.combat.cleared_ice
	room.tank_world.positions[guest] = blast_target.position + Vector2(0, -65)
	room.tank_world.positions[1] = Vector2(950, 640)
	await create_timer(0.25).timeout
	probe.fire.rpc_id(guest, blast_target.position)
	if not check(await until(func(): return room.combat.cleared_ice >= cleared_before + 2), "Guest heavy blast destroys adjacent authoritative ice"):
		return
	proxy.clear_powerups()
	proxy.apply_powerup("shield")
	var health: int = proxy.health
	proxy.take_projectile_hit(40)
	if not check(proxy.health == health, "Host shield rejects heavy damage"):
		return
	proxy.clear_powerups()
	proxy.apply_powerup("speed")
	# Random replacement cover must not turn a speed test into a wall test.
	for brick in room.combat.get_children():
		if brick is Brick and Rect2(380, 370, 260, 120).has_point(brick.position):
			var id: int = brick.get_meta("ice_id", -1)
			if id >= 35:
				room.tank_world.extra_ice.erase(id)
				brick.free()
	room.combat.ice_revision += 1
	room.tank_world.positions[guest] = Vector2(450, 430)
	await create_timer(0.25).timeout
	probe.move.rpc_id(guest, true)
	if not check(await until(func(): return room.tank_world.directions[guest].x > 0.9), "Guest movement reaches authority"):
		return
	var before: Vector2 = room.tank_world.positions[guest]
	await create_timer(0.22).timeout
	probe.move.rpc_id(guest, false)
	if not check(await until(func(): return room.tank_world.directions[guest] == Vector2.ZERO), "Guest release reaches authority"):
		return
	await create_timer(0.10).timeout
	var distance: float = room.tank_world.positions[guest].x - before.x
	if not check(distance > 58 and distance < 110, "Host validates guest boosted movement"):
		return
	if not check(probe.observed.position.distance_to(room.tank_world.positions[guest]) < 20, "Guest prediction converges with boosted authority"):
		return
	if args.has("duration"):
		# Observe real host time over the complete source duration; no timer injection.
		proxy.clear_powerups()
		for kind in ["heavy", "shield", "speed", "health"]:
			proxy.apply_powerup(kind)
		room.show_settings()
		await create_timer(5.1).timeout
		if not check(float(probe.observed.vitals[guest].heavy) > 23.0 and float(probe.observed.vitals[guest].heavy) < 26.0, "Server timers advance through host local settings"):
			return
		room.close_settings()
		await create_timer(25.2).timeout
		if not check(await until(func(): return ["heavy", "shield", "speed", "recovery"].all(func(effect): return float(probe.observed.vitals[guest][effect]) == 0.0), 2.0), "All four network effects expire after 30 real gameplay seconds"):
			return
	else:
		proxy.advance_vitals(31.0)
	await create_timer(0.2).timeout
	if not check(room.tank_world.speed_multipliers[guest] == 1.0 and float(probe.observed.vitals[guest].speed) == 0.0, "Host expiry returns both peers to baseline"):
		return
	# A real guest projectile provokes a host-owned moose, which then hits the guest.
	var animal = room.combat.moose[0]
	for other in room.combat.moose:
		other.position = Vector2(150, 200)
	animal.position = Vector2(800, 650)
	room.tank_world.positions[guest] = Vector2(650, 650)
	room.tank_world.positions[1] = Vector2(1000, 200)
	for brick in room.combat.get_children():
		if brick is Brick and Rect2(600, 600, 250, 100).has_point(brick.position):
			brick.position = Vector2(-1000, -1000) # Isolate attack from random replacement cover.
	proxy.clear_powerups()
	proxy.moose_cooldown = 0.0
	proxy.respawn_protection = 0.0
	room.tank_world.contact_cooldowns[guest] = 0.0
	proxy.health = 100
	room.combat.report_vitals(guest)
	await create_timer(0.25).timeout
	probe.fire.rpc_id(guest, animal.position)
	if not check(await until(func(): return probe.observed.get("anger", false) and probe.observed.get("sounds", []).has("moose_angry"), 2.0), "Guest shot produces shared host warning and angry sound"):
		return
	animal.set_physics_process(true)
	if not check(await until(func(): return proxy.health == 80 and probe.observed.get("vitals", {}).get(guest, {}).get("health", 0) == 80, 3.0), "Host moose charges and deals synchronized 20 damage"):
		return
	if not check(animal.charge_remaining == 0.0 and proxy.moose_cooldown > 0 and not proxy.take_moose_hit(Vector2.LEFT), "Contact ends charge and cooldown rejects repeated damage"):
		return
	animal.set_physics_process(false)
	if not check(await until(func(): return probe.observed.get("stats", {}).get("score", -1) == room.combat.cleared_ice * 100 and probe.observed.get("music", false)), "Shared field score and gameplay music"):
		return
	var extra: Dictionary = room.tank_world.extra_ice
	var at: Vector2 = extra.values()[0]
	var blocked: Vector2 = room.tank_world.move_current(at - Vector2(90, 0), Vector2.RIGHT, 1.0)
	if not check(blocked.x <= at.x - 48.0, "Replacement blocks authoritative movement"):
		return
	room.combat.finish_duel()
	await create_timer(0.2).timeout
	if not check(await until(func(): return is_instance_valid(room.play_again_button)), "Results presentation ready"):
		return
	room.play_again_button.pressed.emit()
	if not check(await until(func(): return room.phase == "ready" and probe.observed.get("phase") == "ready" and probe.observed.get("extra", {}).is_empty()), "Replay clears powers and replacement geometry"):
		return
	if not check(room.tank_world.extra_ice.is_empty() and room.combat.proxies[guest].powerup_status() == "No power-up", "Fresh authority has no prior round effects"):
		return
	probe.finish.rpc_id(guest)
	await create_timer(0.2).timeout
	if is_instance_valid(lobby.active_room):
		lobby.active_room.leave_room()
	await process_frame
	app.queue_free()
	await process_frame
	print("PASS LAN features host: projectile-owned rewards, shield, speed/prediction/expiry, replacements, warning and replay")
	quit()
