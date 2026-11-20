extends "res://tests/combined_smoke.gd"
func run() -> void:
	app = load("res://application.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	lobby = app.lobby
	enter_menu(true)
	var room = lobby.active_room
	if not check(await until(func(): return room.phase == "ready"), "Preview ready"):
		return
	room.set_physics_process(false)
	room.phase = "running"
	var marker = room.artwork.tank_markers[1]
	if not check(marker.collision_layer == 0 and marker.collision_mask == 0 and not marker.is_physics_processing() and not marker.damage_enabled, "Visual tank cannot control physics or damage"):
		return
	var aim_before: float = marker.turret.rotation
	for i in range(15):
		marker.position += Vector2.RIGHT
		marker._process(1.0 / 60.0)
	if not check(absf(marker.chassis.rotation) > 0.1 and marker.turret.rotation == aim_before, "Chassis turns independently of aim"):
		return
	room.apply_combat_event("vitals", {"vitals": {1: {"health": 80, "lives": 3, "active": true, "protection": 0.0}}, "revision": 10})
	if not check(marker.hit_flash > 0, "Confirmed health loss flashes"):
		return
	marker.hit_flash = 0.1
	marker.apply_vitals({"health": 80, "lives": 3, "active": true, "protection": 0.0})
	if not check(marker.hit_flash == 0.1, "Repeated snapshot does not restart flash"):
		return
	room.apply_combat_event("shot", {"id": 100, "peer": 1, "position": marker.position + Vector2(50, 0), "direction": Vector2.RIGHT})
	room.apply_combat_event("impact", {"id": 100, "position": marker.position + Vector2(120, 0)})
	if not check(marker.shot_flash > 0 and room.combat_view.particles.size() == 12, "Confirmed muzzle flash and local shard burst"):
		return
	room.apply_combat_event("contact", {"peer": 1})
	if not check(marker.moose_cooldown > 0, "Contact protection visual"):
		return
	if OS.get_cmdline_user_args().has("render"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/integration/P104-hit.png")
	marker.apply_vitals({"health": 100, "lives": 2, "active": true, "protection": 2.0})
	if not check(marker.respawn_protection == 2.0 and marker.hit_flash == 0 and marker.shot_flash == 0, "Respawn protection and cleared pre-death flashes"):
		return
	await create_timer(0.6).timeout
	if not check(marker.hit_flash == 0 and marker.shot_flash == 0 and room.combat_view.particles.is_empty(), "Transient animations expire"):
		return
	room.artwork.reset_ice()
	if not check(marker.moose_cooldown == 0 and marker.respawn_protection == 0 and marker.modulate == Color.WHITE, "Replay clears visual effects"):
		return
	print("PASS LAN animation visual isolation, rotation, confirmed flash/shards, expiry and reset")
	quit()
