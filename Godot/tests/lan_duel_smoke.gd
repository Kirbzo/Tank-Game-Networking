extends "res://tests/combat_test_base.gd"
## Two actual ENet instances; only fixture positioning/hazard isolation is injected.
var probe: Node
var room: Control

class Probe extends Node:
	var test
	var observed: Dictionary = {}
	var done := false
	@rpc("any_peer", "call_remote", "reliable")
	func report(data: Dictionary) -> void:
		if multiplayer.is_server() and multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
			observed = data
	@rpc("authority", "call_remote", "reliable")
	func fire(target: Vector2) -> void:
		test.aim(target)
		await test.fire_once()
	@rpc("authority", "call_remote", "reliable")
	func finish() -> void:
		done = true

func shared_health(peer: int, health: int, lives: int) -> bool:
	var remote: Dictionary = probe.observed.get("vitals", {}).get(peer, {})
	return room.duel_vitals.get(peer, {}).get("health", -1) == health and room.duel_vitals.get(peer, {}).get("lives", -1) == lives and remote.get("health", -1) == health and remote.get("lives", -1) == lives

func shoot_at(shooter: int, target: int) -> void:
	var at: Vector2 = room.tank_world.positions[target]
	if shooter == 1:
		aim(at)
		await fire_once()
	else:
		probe.fire.rpc_id(shooter, at)
	await create_timer(0.3).timeout

func lane() -> void:
	var guest: int = lobby.multiplayer.get_peers()[0]
	room.tank_world.positions[1] = Vector2(450, 430)
	room.tank_world.positions[guest] = Vector2(550, 430)
	await create_timer(0.3).timeout

func run() -> void:
	var hosting := OS.get_cmdline_user_args().has("host")
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "moooze-lan-duel-test"
	probe = Probe.new()
	probe.name = "DuelProbe"
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
		if not check(await until(func(): return not lobby.discovery.games.is_empty()), "Duel discovery"):
			return
		var id: String = lobby.discovery.games.keys()[0]
		lobby.game_id.text = id
		lobby.identify_game(id)
		lobby.join_button.pressed.emit()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.player_names.size() == 2), "Real duel membership"):
		return
	room = lobby.active_room
	if not hosting:
		var original_epoch := -1
		var rejected := false
		var stale_rejected := false
		var stale_vitals_rejected := false
		while not probe.done:
			if not is_instance_valid(room):
				check(false, "Host closed before duel fixture completed")
				return
			if original_epoch < 0 and room.phase == "running":
				original_epoch = room.epoch
			if room.phase == "running" and room.vitals_revision > 0 and not stale_vitals_rejected:
				var before: Dictionary = room.duel_vitals.duplicate(true)
				var predicted: Vector2 = room.tank_view.predicted_position
				room.apply_combat_event("vitals", {"revision": room.vitals_revision - 1, "vitals": {}, "respawn": lobby.multiplayer.get_unique_id(), "positions": {}, "tick": 999999, "acks": {}})
				room.apply_combat_event("vitals", {"revision": room.vitals_revision, "vitals": {}, "respawn": lobby.multiplayer.get_unique_id(), "positions": {}, "tick": -999, "acks": {}})
				stale_vitals_rejected = room.duel_vitals == before and room.tank_view.predicted_position == predicted
				if not check(stale_vitals_rejected, "Old cross-channel vitals cannot roll back health or respawn prediction"):
					return
			if room.phase == "finished":
				var generation: int = room.epoch
				room.request_start()
				rejected = room.epoch == generation and room.phase == "finished" and not is_instance_valid(room.play_again_button)
				lobby.combat_fire.rpc_id(1, room.game_id, room.epoch, Vector2.LEFT, 100000)
			if original_epoch >= 0 and room.epoch > original_epoch and room.phase == "ready":
				room.receive_combat_event(original_epoch, 999999, "result", {"winner": 0})
				stale_rejected = room.phase == "ready"
			probe.report.rpc_id(1, {"vitals": room.duel_vitals, "phase": room.phase, "winner": room.winner_peer, "epoch": room.epoch, "replay_rejected": rejected, "stale_rejected": stale_rejected, "stale_vitals_rejected": stale_vitals_rejected, "position": room.tank_view.predicted_position})
			await create_timer(0.05).timeout
		print("PASS LAN duel guest: authoritative vitals, result, guest replay rejection, reset and stale epoch")
		quit()
		return
	var session = lobby.session
	var guest: int = lobby.multiplayer.get_peers()[0]
	if not check(await until(func(): return room.phase == "ready"), "Preview readiness"):
		return
	for animal in room.combat.moose:
		animal.set_physics_process(false)
	await lane()
	await shoot_at(1, guest)
	if not check(await until(func(): return shared_health(guest, 100, 3)), "Preview projectile cannot damage tank"):
		return
	room.bottom_start_button.pressed.emit()
	for animal in room.combat.moose:
		animal.set_physics_process(false)
	if not check(await until(func(): return probe.observed.get("phase") == "running"), "Both in authoritative duel"):
		return
	for round_index in range(2):
		var loser: int = guest if round_index == 0 else 1
		var winner: int = guest if loser == 1 else 1
		for life in range(3):
			await lane()
			for shot in range(5):
				await shoot_at(winner, loser)
				var expected_health: int = 100 - (shot + 1) * 20
				var expected_lives: int = 3 - life
				if shot == 4:
					expected_lives -= 1
					expected_health = 100 if expected_lives > 0 else 0
				if not check(await until(func(): return shared_health(loser, expected_health, expected_lives)), "Both instances reconcile real projectile damage/life loss"):
					return
			if life < 2:
				if not check(room.tank_world.positions[loser] == room.combat.proxies[loser].spawn_position, "Host restores authoritative spawn"):
					return
				if loser == guest:
					if not check(await until(func(): return probe.observed.position.distance_to(room.combat.proxies[loser].spawn_position) < 1), "Guest prediction reconciles respawn"):
						return
				await lane()
				await shoot_at(winner, loser)
				if not check(shared_health(loser, 100, 2 - life), "Real projectile cannot damage respawn protection"):
					return
				await create_timer(2.1).timeout
		if not check(await until(func(): return room.phase == "finished" and probe.observed.get("phase") == "finished" and probe.observed.get("winner") == winner), "Both see the same winner"):
			return
		var shots: int = room.combat.next_shot
		var tick: int = room.tank_world.tick
		room.accept_fire_request(winner, room.epoch, Vector2.RIGHT, 200000)
		await create_timer(0.3).timeout
		if not check(room.combat.next_shot == shots and room.tank_world.tick == tick and probe.observed.replay_rejected and probe.observed.stale_vitals_rejected, "Result freezes simulation; stale health and client restart/fire rejected"):
			return
		var old_epoch: int = room.epoch
		if not check(await until(func(): return is_instance_valid(room.play_again_button)), "Final explosion precedes replay controls"):
			return
		room.play_again_button.pressed.emit()
		if not check(await until(func(): return room.phase == "ready" and probe.observed.get("epoch", 0) > old_epoch and probe.observed.get("stale_rejected", false)), "Host replay resets both peers and ignores old result"):
			return
		if not check(await until(func(): return shared_health(1, 100, 3) and shared_health(guest, 100, 3)) and room.artwork.ice_count == 35 and not is_instance_valid(room.result_overlay) and lobby.session == session, "Replay restores vitals/field while retaining ENet"):
			return
		room.bottom_start_button.pressed.emit()
		for animal in room.combat.moose:
			animal.set_physics_process(false)
		if not check(await until(func(): return probe.observed.get("phase") == "running"), "Replayed round starts on the same session"):
			return
	await lane()
	await shoot_at(1, guest)
	if not check(await until(func(): return shared_health(guest, 80, 3)), "Replayed round accepts real shots and reconciles fresh health"):
		return
	probe.finish.rpc_id(guest)
	await create_timer(0.5).timeout
	print("PASS LAN duel host: real shots, shared damage/lives, respawn immunity/reconciliation, both winners, freeze and two complete rounds/replays")
	quit()
