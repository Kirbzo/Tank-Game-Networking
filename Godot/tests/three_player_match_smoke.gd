extends "res://tests/combat_smoke.gd"
var room: Control
var probe: MatchProbe
func desired_players() -> int:
	return 3
class MatchProbe extends Node:
	var test
	var observed: Dictionary = {}
	var done := false
	@rpc("any_peer", "call_remote", "reliable")
	func report(data: Dictionary) -> void:
		if multiplayer.is_server():
			observed[multiplayer.get_remote_sender_id()] = data
	@rpc("authority", "call_remote", "reliable")
	func fire(at: Vector2) -> void:
		test.aim(at)
		await test.fire_once()
	@rpc("authority", "call_remote", "reliable")
	func finish() -> void:
		done = true
func labels() -> Array[String]:
	var texts: Array[String] = []
	if is_instance_valid(room.result_overlay):
		for node in room.result_overlay.find_children("*","Label",true,false):
			texts.append(node.text)
	return texts
func health_shared(peer: int, hp: int, lives: int) -> bool:
	if room.duel_vitals.get(peer,{}).get("health",-1) != hp or room.duel_vitals[peer].lives != lives:
		return false
	return probe.observed.size() == desired_players() - 1 and probe.observed.values().all(func(sample): return sample.vitals.get(peer,{}).get("health",-1) == hp and sample.vitals[peer].lives == lives)
func run() -> void:
	var args = OS.get_cmdline_user_args()
	var hosting: bool = args.has("host")
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	lobby.discovery.protocol = "%d-player-match-test-" % desired_players() + ("guest" if args.has("guest-wins") else "host")
	probe = MatchProbe.new()
	probe.name = "MatchProbe"
	probe.test = self
	root.add_child(probe)
	enter_menu(hosting)
	if not hosting:
		if not check(await until(func(): return not lobby.discovery.games.is_empty()),"Discovery"):
			return
		lobby.game_id.text = lobby.discovery.games.keys()[0]
		lobby.join_game()
	if not check(await until(func(): return is_instance_valid(lobby.active_room) and lobby.active_room.phase == "ready" and lobby.active_room.player_names.size() == desired_players()),"All three ready"):
		return
	room = lobby.active_room
	if not hosting:
		var deadline := Time.get_ticks_msec()+55000
		while not probe.done and Time.get_ticks_msec()<deadline:
			if not check(is_instance_valid(room),"Host retains session"):
				return
			room.begin_game()
			probe.report.rpc_id(1,{"phase":room.phase,"epoch":room.epoch,"vitals":room.duel_vitals,"winner":room.winner_peer,"labels":labels()})
			await create_timer(0.03).timeout
		if not check(probe.done,"Completed before deadline"):
			return
		if not check(await until(func(): return is_instance_valid(lobby.disconnected_screen)),"Clean host shutdown after completed match checks"):
			return
		print("PASS %d-player guest: shared elimination/survivor, statistics, host-only start and replay" % desired_players())
		quit()
		return
	if not check(await until(func(): return probe.observed.size() == desired_players() - 1),"Guest reports"):
		return
	var session = lobby.session
	room.begin_game()
	if not check(room.phase == "running" and lobby.match_started(),"Three-player host Start"):
		return
	for animal in room.combat.moose:
		animal.set_physics_process(false)
		animal.position = Vector2(-1000,-1000)
	var roster: Array = [1]
	for peer in room.player_names:
		if peer != 1:
			roster.append(peer)
	var winner: int = roster[desired_players() - 1] if args.has("guest-wins") else 1
	var losers: Array = []
	for peer in roster:
		if peer != winner:
			losers.append(peer)
	var first_eliminated := 0
	for loser in losers:
		for life in range(3):
			room.tank_world.positions[winner] = Vector2(450,430)
			room.tank_world.positions[loser] = Vector2(550,430)
			for other in roster:
				if other != winner and other != loser:
					room.tank_world.positions[other] = Vector2(500,430) if other == first_eliminated else Vector2(800 + roster.find(other) * 90,430)
			await create_timer(0.25).timeout
			for shot in range(5):
				if winner == 1:
					aim(Vector2(550,430))
					await fire_once()
				else:
					probe.fire.rpc_id(winner,Vector2(550,430))
				await create_timer(0.30).timeout
				var hp := 100-(shot+1)*20
				var remaining := 3-life
				if shot == 4:
					remaining -= 1
					hp = 100 if remaining>0 else 0
				if not check(await until(func(): return health_shared(loser,hp,remaining)),"All peers reconcile actual projectile damage/lives"):
					return
			if life<2:
				await create_timer(2.1).timeout
		if loser != losers[-1]:
			if not check(room.phase == "running" and not room.combat.ended and lobby.match_started(),"Multiple survivors continue after every non-final elimination"):
				return
		if first_eliminated == 0:
			first_eliminated = loser
			if not check(room.phase == "running" and not room.combat.ended and lobby.match_started() and not is_instance_valid(room.result_overlay),"First elimination does not end match or reopen admission"):
				return
			if not check(probe.observed.values().all(func(sample): return sample.phase == "running" and sample.labels.is_empty()),"Eliminated player stays connected without early results"):
				return
			var at: Vector2 = room.tank_world.positions[loser]
			room.accept_tank_input(loser,room.epoch,Vector2.RIGHT,2147483647)
			var count: int = room.combat.next_shot
			room.accept_fire_request(loser,room.epoch,Vector2.RIGHT,2147483647)
			# Defense against a held-fire sample retained just before elimination.
			room.combat.controls[loser] = {"fire":true,"at":Time.get_ticks_msec(),"sequence":123}
			room.combat.cooldowns[loser] = 0.0
			room.combat._physics_process(0.0)
			room.combat.shoot(loser)
			room.combat.controls.erase(loser)
			await create_timer(0.2).timeout
			if not check(room.tank_world.positions[loser] == at and room.combat.next_shot == count and room.combat.proxies[loser].collision_layer == 0,"Eliminated tank cannot move/fire/block shots"):
				return
	var winner_name: String = room.player_names[winner]
	if not check(await until(func(): return room.phase == "finished" and probe.observed.values().all(func(sample): return sample.phase == "finished" and sample.winner == winner)),"Only final survivor wins for every player"):
		return
	var texts := labels()
	if not check(texts.has("%s WINS!" % winner_name) and texts.has("Winner: %s" % winner_name) and texts.size() == desired_players() + 3 and texts.all(func(text): return not text.contains("GAME OVER")) and probe.observed.values().all(func(sample): return sample.labels == texts),"Username winner mapping and all statistics match"):
		return
	if args.has("render"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/integration/P117-winner.png" if desired_players() == 4 else "res://.godot/integration/P115-winner.png")
	var old_epoch: int = room.epoch
	room.play_again_button.pressed.emit()
	if not check(await until(func(): return room.phase == "ready" and room.epoch>old_epoch and probe.observed.values().all(func(sample): return sample.epoch == room.epoch and sample.phase == "ready")),"Replay resets all three on same session"):
		return
	if not check(lobby.session == session and room.duel_vitals.values().all(func(values): return values.health == 100 and values.lives == 3 and values.active),"Replay restores all lives/health"):
		return
	probe.finish.rpc()
	room.set_physics_process(false)
	await create_timer(0.15).timeout
	room.leave_room()
	await create_timer(0.2).timeout
	print("PASS %d-player host: last standing, no early end, eliminated host/guest isolation, winner UI and replay" % desired_players())
	quit()
