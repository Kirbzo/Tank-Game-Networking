extends "res://room_world.gd"
## Provisional movement: 235 px/s, a conservative 48px square tank footprint.
## Tanks block on arena bricks, not each other (matching the offline collision mask).
const TANK_SPEED := 235.0
const HALF := Vector2(24, 24)
const CENTER_BOUNDS := Rect2(136, 176, 1008, 512)

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
		var direction: Vector2 = directions[peer]
		if now - int(input_times.get(peer, -INPUT_TIMEOUT_MS)) > INPUT_TIMEOUT_MS:
			direction = Vector2.ZERO
		positions[peer] = move_tank(positions[peer], direction, delta)
		processed_sequences[peer] = received_sequences.get(peer, 0)
	tick += 1

static func move_tank(at: Vector2, direction: Vector2, delta: float) -> Vector2:
	# Swept axis movement prevents tunnelling, sliding along the blocked edge.
	var travel := direction.limit_length() * TANK_SPEED * delta
	for axis in range(2):
		var other := 1 - axis
		var target := clampf(at[axis] + travel[axis], CENTER_BOUNDS.position[axis], CENTER_BOUNDS.end[axis])
		for center in ice_centers():
			var extent := Vector2(24, 20) + HALF
			if at[other] <= center[other] - extent[other] or at[other] >= center[other] + extent[other]:
				continue
			if travel[axis] > 0 and at[axis] <= center[axis] - extent[axis]:
				target = minf(target, center[axis] - extent[axis])
			elif travel[axis] < 0 and at[axis] >= center[axis] + extent[axis]:
				target = maxf(target, center[axis] + extent[axis])
		at[axis] = target
	return at
