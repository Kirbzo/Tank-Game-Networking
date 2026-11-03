extends RefCounted
## Host-owned movement placeholder. These are preview rules, not final FR9 rules.
const BOUNDS := Rect2(24, 24, 952, 672)
const PLAYER_SIZE := Vector2(32, 32)
const SPEED := 220.0
const INPUT_TIMEOUT_MS := 250
var positions: Dictionary = {}
var directions: Dictionary = {}
var input_times: Dictionary = {}
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

func accept_input(peer: int, direction: Vector2, now: int) -> bool:
	if not positions.has(peer) or not direction.is_finite() or direction.length_squared() > 1.001:
		return false
	directions[peer] = direction.limit_length()
	input_times[peer] = now
	return true

func step(delta: float, now: int) -> void:
	for peer in positions:
		var direction: Vector2 = directions[peer]
		if now - int(input_times.get(peer, -INPUT_TIMEOUT_MS)) > INPUT_TIMEOUT_MS:
			direction = Vector2.ZERO
		var next: Vector2 = positions[peer] + direction * SPEED * delta
		positions[peer] = next.clamp(BOUNDS.position, BOUNDS.end - PLAYER_SIZE)
	tick += 1
