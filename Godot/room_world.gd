extends RefCounted
## Host-owned movement placeholder. These are preview rules, not final FR9 rules.
const BOUNDS := Rect2(24, 24, 952, 672)
const PLAYER_SIZE := Vector2(32, 32)
const SPEED := 220.0
const INPUT_TIMEOUT_MS := 250
var positions: Dictionary = {}
var directions: Dictionary = {}
var input_times: Dictionary = {}
var received_sequences: Dictionary = {}
var processed_sequences: Dictionary = {}
var tick := 0

func add_player(peer: int) -> void:
	if positions.has(peer):
		return
	positions[peer] = BOUNDS.position + Vector2(BOUNDS.size.x * (0.35 if peer == 1 else 0.65), BOUNDS.size.y * 0.5) - PLAYER_SIZE / 2
	directions[peer] = Vector2.ZERO

func remove_player(peer: int) -> void:
	positions.erase(peer)
	directions.erase(peer)
	input_times.erase(peer)
	received_sequences.erase(peer)
	processed_sequences.erase(peer)

func accept_input(peer: int, direction: Vector2, now: int, sequence := -1) -> bool:
	if not positions.has(peer) or not direction.is_finite() or direction.length_squared() > 1.001:
		return false
	if sequence >= 0:
		if sequence <= int(received_sequences.get(peer, 0)) or sequence > 2147483647:
			return false
		received_sequences[peer] = sequence
	directions[peer] = direction.limit_length()
	input_times[peer] = now
	return true

func step(delta: float, now: int) -> void:
	for peer in positions:
		var direction: Vector2 = directions[peer]
		if now - int(input_times.get(peer, -INPUT_TIMEOUT_MS)) > INPUT_TIMEOUT_MS:
			direction = Vector2.ZERO
		positions[peer] = move_position(positions[peer], direction, delta)
		processed_sequences[peer] = received_sequences.get(peer, 0)
	tick += 1

static func move_position(position: Vector2, direction: Vector2, delta: float) -> Vector2:
	return (position + direction * SPEED * delta).clamp(BOUNDS.position, BOUNDS.end - PLAYER_SIZE)
