extends "res://tests/local_duel_smoke.gd"
## Existing offline effect APIs, actual projectile collision, and rica moose rules.
func run() -> void:
	var app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(app)
	current_scene = app
	game = app.client_menu
	game.start_game(true, true)
	await isolate()
	var tank = game.player
	var other = game.player_two
	tank.apply_powerup("heavy")
	await fire(tank, 0)
	if not check(other.health == 60 and tank.heavy_ammo == 4, "Offline heavy shot deals 40 damage and consumes one charge"):
		return
	other.apply_powerup("health")
	if not check(other.health == 95, "Health effect restores 35"):
		return
	other.apply_powerup("shield")
	await fire(tank, 0)
	if not check(other.health == 95 and not other.take_moose_hit(Vector2.RIGHT), "Shield blocks projectile and offline contact damage"):
		return
	other.advance_vitals(9.0)
	other.take_projectile_hit(20)
	if not check(other.health == 75 and other.shield_time == 0, "Expired shield restores damage"):
		return
	tank.apply_powerup("speed")
	Input.action_press("move_left")
	await frames(3)
	if not check(absf(tank.velocity.x + tank.SPEED * 1.5) < 0.1, "Offline speed effect uses client movement controls"):
		return
	Input.action_release("move_left")
	tank.take_damage(100)
	if not check(tank.heavy_ammo == 0 and tank.speed_time == 0 and tank.lives == 2, "Death clears offline power-ups"):
		return
	game.restart_game()
	await isolate()
	tank = game.player
	other = game.player_two
	var animal = get_nodes_in_group("moose")[0]
	animal.position = Vector2(480, 430)
	animal.emerge_delay = 0
	animal.heading = Vector2.LEFT
	animal._physics_process(0.0)
	if not check(tank.health == 80 and tank.hit_push.x < 0 and animal.heading.x > 0, "Offline rica contact damages, knocks back and yields"):
		return
	tank.advance_vitals(3.0)
	animal._physics_process(0.0)
	if not check(tank.health == 80, "Sustained overlap cannot re-hit after cooldown without separation"):
		return
	animal.position = Vector2(800, 430)
	animal._physics_process(0.0)
	animal.position = Vector2(480, 430)
	animal._physics_process(0.0)
	if not check(tank.health == 60, "Fresh contact after separation can hit again"):
		return
	tank.hit_push = Vector2.ZERO
	# Snowball crosses the unchanged moose collision body and reaches the opponent.
	animal.position = Vector2(500, 430)
	await frames(3)
	await fire(tank, 0)
	if not check(other.health == 80 and not animal.has_method("hit"), "Snowballs pass through moose without provocation"):
		return
	# Existing roaming code still turns and bounces off the perimeter.
	animal.position = Vector2(140, 430)
	animal.heading = Vector2.LEFT
	animal.previous_contacts.clear()
	animal.process_mode = Node.PROCESS_MODE_INHERIT
	await frames(15)
	if not check(animal.position.x >= 132 and animal.heading.x > 0 and animal.gait > 0, "Roaming moose bounce at walls and animate their gait"):
		return
	game.show_menu()
	await frames(3)
	print("PASS offline power-up APIs/heavy projectile, expiry/death cleanup; rica moose contact, separation, yielding, pass-through shots and wall roaming")
	quit()
