extends "res://room_world.gd"
## Provisional movement: 235 px/s, a conservative 48px square tank footprint.
## Tanks block on arena bricks, not each other (matching the offline collision mask).
const TANK_SPEED := 235.0
const HALF := Vector2(24, 24)
const CENTER_BOUNDS := Rect2(136, 176, 1008, 512)
var removed_ice: Dictionary = {}
const Player = preload("res://scripts/player.gd")
var hit_push: Dictionary = {}
var contact_cooldowns: Dictionary = {}

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

func add_player(peer: int) -> void:
	if not positions.has(peer):
		positions[peer] = Vector2(208, 612) if peer == 1 else Vector2(1072, 612)
		directions[peer] = Vector2.ZERO

func step(delta: float, now: int) -> void:
	for peer in positions:
		contact_cooldowns[peer] = maxf(0.0, float(contact_cooldowns.get(peer, 0.0)) - delta)
		var direction: Vector2 = directions[peer]
		if now - int(input_times.get(peer, -INPUT_TIMEOUT_MS)) > INPUT_TIMEOUT_MS:
			direction = Vector2.ZERO
		positions[peer] = move_current(positions[peer], direction, delta)
		var push: Vector2 = hit_push.get(peer, Vector2.ZERO)
		if push != Vector2.ZERO:
			positions[peer] = move_tank(positions[peer], push.normalized(), push.length() / TANK_SPEED * delta, removed_ice)
			hit_push[peer] = push.move_toward(Vector2.ZERO, Player.HIT_PUSH_DECELERATION * delta)
		processed_sequences[peer] = received_sequences.get(peer, 0)
	tick += 1

func move_current(at: Vector2, direction: Vector2, delta: float) -> Vector2:
	return move_tank(at, direction, delta, removed_ice)

static func move_tank(at: Vector2, direction: Vector2, delta: float, destroyed: Dictionary = {}) -> Vector2:
	# Swept axis movement prevents tunnelling, sliding along the blocked edge.
	var travel := direction.limit_length() * TANK_SPEED * delta
	for axis in range(2):
		var other := 1 - axis
		var target := clampf(at[axis] + travel[axis], CENTER_BOUNDS.position[axis], CENTER_BOUNDS.end[axis])
		var centers := ice_centers()
		for id in range(centers.size()):
			if destroyed.has(id):
				continue
			var center := centers[id]
			var extent := Vector2(24, 20) + HALF
			if at[other] <= center[other] - extent[other] or at[other] >= center[other] + extent[other]:
				continue
			if travel[axis] > 0 and at[axis] <= center[axis] - extent[axis]:
				target = minf(target, center[axis] - extent[axis])
			elif travel[axis] < 0 and at[axis] >= center[axis] + extent[axis]:
				target = maxf(target, center[axis] + extent[axis])
		at[axis] = target
	return at
