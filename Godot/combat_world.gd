extends Node2D
## Host-only logical world. Reuses the imported client's projectile/brick/moose rules.
signal confirmed(kind: String, data: Dictionary)
const Bullet = preload("res://scripts/bullet.gd")
const Brick = preload("res://scripts/brick.gd")
const Moose = preload("res://scripts/moose.gd")
const TankWorld = preload("res://tank_world.gd")
const Player = preload("res://scripts/player.gd")
const FIRE_INTERVAL = preload("res://scripts/player.gd").FIRE_INTERVAL
const CORNERS = preload("res://scripts/game.gd").CORNERS
var tanks: RefCounted
var controls: Dictionary = {}
var aims: Dictionary = {}
var cooldowns: Dictionary = {}
var proxies: Dictionary = {}
var bullets: Dictionary = {}
var moose: Array = []
var next_shot := 0
var fire_requests: Dictionary = {}
var interactions_enabled := true
var ended := false
var previous_lives: Dictionary = {}
var vitals_revision := 0

func _ready() -> void:
	# Authority coordinates never inherit the visual arena's viewport scaling.
	top_level = true
	global_position = Vector2.ZERO
	hide()
	for center in TankWorld.border_centers():
		add_brick(center, -1)
	var centers := TankWorld.ice_centers()
	for id in range(centers.size()):
		add_brick(centers[id], id)
	for peer in tanks.positions:
		# Reuse Local Duel's actual tank damage/life logic, but never its local input.
		var proxy := Player.new()
		proxy.position = tanks.positions[peer]
		proxy.damage_enabled = interactions_enabled
		add_child(proxy)
		proxy.set_physics_process(false)
		proxy.collision_mask = 0
		proxies[peer] = proxy
		previous_lives[peer] = proxy.lives
		proxy.vitals_changed.connect(report_vitals.bind(peer))
		proxy.exploded.connect(func(): confirmed.emit("explosion", {"position": proxy.position, "peer": peer}))
		proxy.lives_depleted.connect(finish_duel)
		proxy.moose_hit.connect(func():
			tanks.hit_push[peer] = proxy.hit_push
			tanks.contact_cooldowns[peer] = proxy.moose_cooldown
			confirmed.emit("contact", {"peer": peer}))
		aims[peer] = Vector2.RIGHT
		cooldowns[peer] = 0.0
	for i in range(CORNERS.size()):
		var animal := Moose.new()
		animal.position = CORNERS[i]
		animal.heading = Vector2.RIGHT if i % 2 == 0 else Vector2.LEFT
		animal.emerge_delay = 0.6 + i * 0.25
		animal.tanks = proxies.values()
		# Logical host positions, not offline tank physics, determine contact here.
		animal.authoritative_contacts = true
		add_child(animal)
		animal.set_physics_process(interactions_enabled)
		moose.append(animal)

func set_interactions_enabled(enabled: bool) -> void:
	interactions_enabled = enabled
	for proxy in proxies.values():
		proxy.damage_enabled = enabled and not ended
	for child in get_children():
		if child is Brick:
			child.reinforced = int(child.get_meta("ice_id", -1)) < 0 or not enabled
	for animal in moose:
		animal.set_physics_process(enabled)

func clear_shots() -> void:
	for bullet in bullets.values():
		bullet.free()
	controls.clear()

func add_brick(at: Vector2, id: int) -> void:
	var brick := Brick.new()
	brick.position = at
	brick.reinforced = id < 0 or not interactions_enabled
	brick.set_meta("ice_id", id)
	if id >= 0:
		brick.destroyed.connect(func(_at):
			tanks.removed_ice[id] = true
			confirmed.emit("ice", {"id": id}))
	add_child(brick)

func accept_input(peer: int, direction: Vector2, fire: bool, sequence: int, now: int) -> bool:
	if ended or not proxies.has(peer) or not proxies[peer].active:
		return false
	if not aims.has(peer) or not direction.is_finite() or absf(direction.length_squared() - 1.0) > 0.001:
		return false
	if sequence <= int(controls.get(peer, {}).get("sequence", 0)) or sequence > 2147483647:
		return false
	controls[peer] = {"sequence": sequence, "at": now, "fire": fire}
	aims[peer] = direction.normalized()
	return true

func _physics_process(delta: float) -> void:
	if ended:
		return
	for peer in proxies:
		proxies[peer].position = tanks.positions[peer]
		proxies[peer].advance_vitals(delta)
		# Keep the existing shared movement/contact cooldown in sync with player.gd.
		proxies[peer].moose_cooldown = maxf(proxies[peer].moose_cooldown, float(tanks.contact_cooldowns.get(peer, 0.0)))
		cooldowns[peer] = maxf(0.0, cooldowns[peer] - delta)
		var input: Dictionary = controls.get(peer, {})
		if input.get("fire", false) and Time.get_ticks_msec() - int(input.get("at", 0)) <= 250 and cooldowns[peer] <= 0:
			shoot(peer)

func request_fire(peer: int, direction: Vector2, sequence: int) -> bool:
	if ended or not proxies.has(peer) or not proxies[peer].active:
		return false
	if not aims.has(peer) or not direction.is_finite() or absf(direction.length_squared() - 1.0) > 0.001:
		return false
	if sequence <= int(fire_requests.get(peer, 0)) or sequence > 2147483647:
		return false
	fire_requests[peer] = sequence
	if cooldowns[peer] > 0:
		return false
	aims[peer] = direction.normalized()
	shoot(peer)
	return true

func shoot(peer: int) -> void:
	cooldowns[peer] = FIRE_INTERVAL
	next_shot += 1
	var id := next_shot
	var bullet := Bullet.new()
	# Preview shots pass through tanks/moose; matches reuse local swept hit rules.
	bullet.hits_moose = interactions_enabled
	bullet.hits_tanks = interactions_enabled
	bullet.shooter = proxies[peer]
	bullet.origin = tanks.positions[peer]
	bullet.direction = aims[peer]
	bullet.position = bullet.origin + bullet.direction * 50.0
	bullet.impact = func(at): confirmed.emit("impact", {"id": id, "position": at})
	bullet.tree_exiting.connect(func():
		bullets.erase(id)
		if is_inside_tree() and not is_queued_for_deletion():
			confirmed.emit("remove", {"id": id}))
	bullets[id] = bullet
	add_child(bullet)
	confirmed.emit("shot", {"id": id, "peer": peer, "position": bullet.position, "direction": bullet.direction})

func snapshot() -> Dictionary:
	var shots := {}
	for id in bullets:
		shots[id] = bullets[id].position
	var animals := []
	for animal in moose:
		animals.append({"position": animal.position, "heading": animal.heading, "gait": animal.gait})
	return {"aims": aims.duplicate(), "shots": shots, "moose": animals, "vitals": vitals(), "revision": vitals_revision}

func vitals() -> Dictionary:
	var result := {}
	for peer in proxies:
		var proxy = proxies[peer]
		result[peer] = {"health": proxy.health, "lives": proxy.lives, "active": proxy.active, "protection": proxy.respawn_protection}
	return result

func report_vitals(peer: int) -> void:
	vitals_revision += 1
	var proxy = proxies[peer]
	var respawned: bool = proxy.lives < int(previous_lives[peer]) and proxy.active
	previous_lives[peer] = proxy.lives
	if respawned:
		tanks.positions[peer] = proxy.position
		tanks.directions[peer] = Vector2.ZERO
		tanks.hit_push.erase(peer)
		tanks.input_times.erase(peer)
	confirmed.emit("vitals", {"vitals": vitals(), "revision": vitals_revision, "positions": tanks.positions.duplicate(), "tick": tanks.tick, "acks": tanks.processed_sequences.duplicate(), "respawn": peer if respawned else 0})

func finish_duel() -> void:
	if ended:
		return
	ended = true
	var winner := 0
	for peer in proxies:
		if proxies[peer].active:
			winner = peer
	set_interactions_enabled(false)
	controls.clear()
	confirmed.emit("result", {"winner": winner, "vitals": vitals(), "revision": vitals_revision})
	clear_shots.call_deferred()
