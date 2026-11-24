extends "res://room_world.gd"
## Provisional movement: 235 px/s, a conservative 48px square tank footprint.
## LAN body contacts are solid independently of damage/protection state.
const TANK_SPEED := 235.0
const HALF := Vector2(24, 24)
const CENTER_BOUNDS := Rect2(136, 176, 1008, 512)
var removed_ice: Dictionary = {}
var extra_ice: Dictionary = {}
var speed_multipliers: Dictionary = {}
const Player = preload("res://scripts/player.gd")
var hit_push: Dictionary = {}
var contact_cooldowns: Dictionary = {}
var moose_positions: Array[Vector2] = []
var inactive_peers: Array = []
var prediction_peer := 0
var bounce_push: Dictionary = {}
const BOUNCE_SPEED := 150.0

func moose_contact(peer: int, away: Vector2) -> bool:
	if not positions.has(peer) or float(contact_cooldowns.get(peer, 0.0)) > 0:
		return false
	contact_cooldowns[peer] = Player.MOOSE_COOLDOWN
	hit_push[peer] = (away.normalized() if away.length_squared() > 0.01 else Vector2.LEFT) * Player.HIT_PUSH_SPEED
	return true

static func border_centers() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for col in range(24):
		result.append(Vector2(88 + col * 48, 132))
		result.append(Vector2(88 + col * 48, 732))
	for row in range(1, 15):
		result.append(Vector2(88, 132 + row * 40))
		result.append(Vector2(1192, 132 + row * 40))
	return result

static func ice_centers() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cluster in [Vector2(280, 252), Vector2(760, 252), Vector2(424, 492), Vector2(904, 492)]:
		for col in range(4):
			for row in range(2):
				result.append(cluster + Vector2(col * 48, row * 40))
	for row in range(3):
		result.append(Vector2(616, 292 + row * 40))
	return result

static func spawn_position(peer: int) -> Vector2:
	# Clear central lanes, over 330 pixels from the nearest moose corner.
	return Vector2(440, 412) if peer == 1 else Vector2(840, 412)

func add_player(peer: int) -> void:
	if not positions.has(peer):
		positions[peer] = spawn_position(peer)
		directions[peer] = Vector2.ZERO

func step(delta: float, now: int) -> void:
	for peer in positions:
		contact_cooldowns[peer] = maxf(0.0, float(contact_cooldowns.get(peer, 0.0)) - delta)
		var direction: Vector2 = directions[peer]
		if now - int(input_times.get(peer, -INPUT_TIMEOUT_MS)) > INPUT_TIMEOUT_MS:
			direction = Vector2.ZERO
		var bounce: Vector2 = bounce_push.get(peer, Vector2.ZERO)
		var motion := direction * TANK_SPEED * clampf(float(speed_multipliers.get(peer, 1.0)), 1.0, 1.5) * delta + bounce * delta
		var push: Vector2 = hit_push.get(peer, Vector2.ZERO)
		if push != Vector2.ZERO:
			motion += push * delta
			hit_push[peer] = push.move_toward(Vector2.ZERO, Player.HIT_PUSH_DECELERATION * delta)
		bounce_push[peer] = bounce.move_toward(Vector2.ZERO, 900.0 * delta)
		var result := move_body(peer, positions[peer], motion)
		positions[peer] = result.position
		if result.normal != Vector2.ZERO:
			bounce_push[peer] = result.normal * BOUNCE_SPEED
			if int(result.peer) > 0:
				bounce_push[int(result.peer)] = -result.normal * BOUNCE_SPEED
		processed_sequences[peer] = received_sequences.get(peer, 0)
	tick += 1

func move_current(at: Vector2, direction: Vector2, delta: float) -> Vector2:
	return move_tank(at, direction, delta, removed_ice, extra_ice)

func predict_movement(at: Vector2, direction: Vector2, delta: float) -> Vector2:
	return move_body(prediction_peer, at, direction.limit_length() * TANK_SPEED * clampf(float(speed_multipliers.get(prediction_peer, 1.0)), 1.0, 1.5) * delta).position

func move_body(peer: int, at: Vector2, motion: Vector2) -> Dictionary:
	var bodies: Array[Dictionary] = []
	for other in positions:
		if other != peer and not inactive_peers.has(other):
			bodies.append({"position": positions[other], "radius": 48.0, "peer": other})
	for center in moose_positions:
		bodies.append({"position": center, "radius": 45.0, "peer": 0})
	var normal := Vector2.ZERO
	var collided_peer := 0
	# Moving hazards/respawns can begin overlapped: separate before the sweep.
	for body in bodies:
		var away: Vector2 = at - body.position
		var distance := away.length()
		if distance < float(body.radius) - 0.001:
			normal = away / distance if distance > 0.001 else (Vector2.LEFT if peer == 1 else Vector2.RIGHT)
			at = move_current(at, normal, (float(body.radius) - distance + 0.01) / TANK_SPEED)
			collided_peer = int(body.peer)
	# A swept circle prevents crossing another body, including on large steps.
	for attempt in range(3):
		var destination := move_current(at, motion.normalized(), motion.length() / TANK_SPEED)
		var travel := destination - at
		var length_squared := travel.length_squared()
		if length_squared < 0.000001:
			break
		var earliest := 1.0
		var hit_normal := Vector2.ZERO
		var hit_peer := 0
		for body in bodies:
			var offset: Vector2 = at - body.position
			var approach := offset.dot(travel)
			if approach >= 0:
				continue
			var discriminant: float = approach * approach - length_squared * (offset.length_squared() - float(body.radius) * float(body.radius))
			if discriminant < 0:
				continue
			var fraction := (-approach - sqrt(discriminant)) / length_squared
			if fraction >= -0.001 and fraction <= earliest:
				earliest = maxf(0.0, fraction)
				hit_normal = (offset + travel * earliest).normalized()
				hit_peer = int(body.peer)
		at += travel * earliest
		if hit_normal == Vector2.ZERO:
			break
		normal = hit_normal
		collided_peer = hit_peer
		motion = (travel * (1.0 - earliest)).slide(normal)
	return {"position": at, "normal": normal, "peer": collided_peer}

static func move_tank(at: Vector2, direction: Vector2, delta: float, destroyed: Dictionary = {}, extra: Dictionary = {}) -> Vector2:
	# Swept axis movement prevents tunnelling, sliding along the blocked edge.
	var travel := direction.limit_length() * TANK_SPEED * delta
	for axis in range(2):
		var other := 1 - axis
		var target := clampf(at[axis] + travel[axis], CENTER_BOUNDS.position[axis], CENTER_BOUNDS.end[axis])
		var centers := {}
		var initial := ice_centers()
		for id in range(initial.size()):
			centers[id] = initial[id]
		centers.merge(extra, true)
		for id in centers:
			if destroyed.has(id):
				continue
			var center: Vector2 = centers[id]
			var extent := Vector2(24, 20) + HALF
			if at[other] <= center[other] - extent[other] or at[other] >= center[other] + extent[other]:
				continue
			if travel[axis] > 0 and at[axis] <= center[axis] - extent[axis]:
				target = minf(target, center[axis] - extent[axis])
			elif travel[axis] < 0 and at[axis] >= center[axis] + extent[axis]:
				target = maxf(target, center[axis] + extent[axis])
		at[axis] = target
	return at
