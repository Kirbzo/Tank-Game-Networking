extends SceneTree
## Exercises the configured app/menu, real projectile sweeps and duel lifecycle.
const Brick = preload("res://scripts/brick.gd")
var game: Node2D

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func button(text: String) -> Button:
	for node in game.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func isolate() -> void:
	# Deterministic collision lane; environmental hazards are covered separately.
	for animal in get_nodes_in_group("moose"):
		animal.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.position = Vector2(450, 430)
	game.player_two.position = Vector2(550, 430)
	await frames(3)

func fire(tank: Node2D, angle: float) -> void:
	tank.turret.rotation = angle
	tank.shoot()
	await frames(8)

func run() -> void:
	var app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	game = app.client_menu
	button("Play").pressed.emit()
	if not check(button("Local Co-op / 2 Players") != null and button("Host Game") != null, "Existing Play choices retained"):
		return
	button("Local Duel / 2 Players").pressed.emit()
	await isolate()
	if not check(game.local_duel and app.lobby.session == null and not app.lobby.visible, "Duel starts from menu without a network session"):
		return
	await fire(game.player, 0)
	if not check(game.player.health == 100 and game.player_two.health == 80 and game.hud.text.contains("80 HEALTH"), "P1 projectile damages only P2 by 20 and updates HUD"):
		return
	await fire(game.player_two, PI)
	if not check(game.player.health == 80 and game.player_two.health == 80, "P2 projectile damages only P1"):
		return
	game.player_two.position = game.player.position + Vector2(35, 0)
	await frames(3)
	await fire(game.player, 0)
	if not check(game.player_two.health == 60 and game.player.health == 80, "Close muzzle sweep hits opponent while excluding shooter"):
		return
	game.pause_game()
	var shots: int = game.shots
	game.player.shoot()
	game.player_two.take_projectile_hit(100)
	if not check(game.shots == shots and game.player_two.health == 60, "Pause prevents damage and shooting"):
		return
	game.resume_game()
	game.restart_game()
	await isolate()
	game.player.position = Vector2(280, 185)
	game.player_two.position = Vector2(280, 360)
	await frames(3)
	await fire(game.player, PI / 2)
	if not check(game.player_two.health == 100 and game.remaining == 34, "Ice cover consumes projectile before opponent"):
		return
	# Each result is earned through real projectile hits across all three lives.
	for losing_number in [1, 2]:
		game.restart_game()
		await isolate()
		var loser = game.player if losing_number == 1 else game.player_two
		var winner = game.player_two if losing_number == 1 else game.player
		for life in range(3):
			loser.position = Vector2(450 if losing_number == 1 else 550, 430)
			loser.respawn_protection = 0
			await frames(3)
			for shot in range(5):
				await fire(winner, PI if losing_number == 1 else 0.0)
			if life < 2:
				if not check(loser.lives == 2 - life and loser.health == 100 and loser.respawn_protection > 0, "Life loss restores health and enables respawn protection"):
					return
				loser.position = Vector2(450 if losing_number == 1 else 550, 430)
				await frames(3)
				await fire(winner, PI if losing_number == 1 else 0.0)
				if not check(loser.health == 100, "Real projectile cannot damage a protected respawn"):
					return
		if not check(loser.lives == 0 and not loser.active and game.state == "dying" and paused, "Elimination freezes duel"):
			return
		var frozen: float = game.elapsed
		winner.take_projectile_hit(100)
		await create_timer(2.4).timeout
		if not check(game.state == "results" and game.winner_number == winner.player_number and winner.health == 100 and game.elapsed == frozen, "Correct winner stable after either player's elimination"):
			return
		var content := ""
		for label in game.panel.find_children("*", "Label", true, false):
			content += label.text + "\n"
		if not check(content.contains("Winner: Player %d" % winner.player_number) and game.panel.has_node("VictoryConfetti"), "Result identifies winner and displays source victory effect"):
			return
		button("Play Again").pressed.emit()
		await isolate()
		if not check(game.local_duel and game.winner_number == 0 and game.player.lives == 3 and game.player_two.lives == 3 and game.remaining == 35 and not paused, "Replay retains duel and resets tanks, field and result"):
			return
	# A duel's objective is tank elimination, not clearing the ice field.
	for node in game.world.get_children():
		if node is Brick and not node.reinforced:
			node.hit()
	await frames(3)
	game.finish_game()
	if not check(game.remaining == 0 and game.state == "playing", "Clearing all ice does not end duel"):
		return
	game.start_game(true)
	await isolate()
	await fire(game.player, 0)
	if not check(not game.local_duel and game.player_two.health == 100, "Existing co-op retains friendly-fire protection"):
		return
	game.start_game()
	await frames(3)
	if not check(not game.local_duel and not game.local_coop and game.player.health == 100, "Solo mode remains available"):
		return
	game.show_menu()
	await frames(3)
	print("PASS Local Duel menu, projectile hits, cover, health/lives, respawn protection, both winners, restart, ice objective and co-op/solo isolation")
	quit()
