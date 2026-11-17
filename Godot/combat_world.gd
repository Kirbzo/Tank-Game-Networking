extends Node2D
## Host-only logical world. Reuses the imported client's projectile/brick/moose rules.
signal confirmed(kind: String, data: Dictionary)
const Bullet = preload("res://scripts/bullet.gd")
const Brick = preload("res://scripts/brick.gd")
const Moose = preload("res://scripts/moose.gd")
const TankWorld = preload("res://tank_world.gd")
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

class TankContact extends Node2D:
	var active := true
	var contact: Callable
	func take_moose_hit(direction: Vector2) -> void:
		contact.call(direction)

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
		var proxy := TankContact.new()
		proxy.contact = func(direction):
			if tanks.moose_contact(peer, direction):
				confirmed.emit("contact", {"peer": peer})
		proxy.position = tanks.positions[peer]
		add_child(proxy)
		proxies[peer] = proxy
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
		moose.append(animal)

func add_brick(at: Vector2, id: int) -> void:
	var brick := Brick.new()
	brick.position = at
	brick.reinforced = id < 0
	if id >= 0:
		brick.destroyed.connect(func(_at):
			tanks.removed_ice[id] = true
			confirmed.emit("ice", {"id": id}))
	add_child(brick)

func accept_input(peer: int, direction: Vector2, fire: bool, sequence: int, now: int) -> bool:
	if not aims.has(peer) or not direction.is_finite() or absf(direction.length_squared() - 1.0) > 0.001:
		return false
	if sequence <= int(controls.get(peer, {}).get("sequence", 0)) or sequence > 2147483647:
		return false
	controls[peer] = {"sequence": sequence, "at": now, "fire": fire}
	aims[peer] = direction.normalized()
	return true

func _physics_process(delta: float) -> void:
	for peer in proxies:
		proxies[peer].position = tanks.positions[peer]
		cooldowns[peer] = maxf(0.0, cooldowns[peer] - delta)
		var input: Dictionary = controls.get(peer, {})
		if input.get("fire", false) and Time.get_ticks_msec() - int(input.get("at", 0)) <= 250 and cooldowns[peer] <= 0:
			shoot(peer)

func request_fire(peer: int, direction: Vector2, sequence: int) -> bool:
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
	# Preserve this framework's world-only shots; no tank/moose damage or charge.
	bullet.hits_moose = false
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
	return {"aims": aims.duplicate(), "shots": shots, "moose": animals}
