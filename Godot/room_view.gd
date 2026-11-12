extends RefCounted
## Display-only snapshot interpolation and locally predicted movement.
const World = preload("res://room_world.gd")
const BUFFER_SECONDS := 0.1
const MAX_SNAPSHOTS := 32
const MAX_PENDING_INPUTS := 120
var snapshots: Array[Dictionary] = []
var pending_inputs: Array[Dictionary] = []
var input_sequence := 0
var latest_ack := 0
var latest_tick := -1
var render_time := 0.0
var predicted_position := Vector2.ZERO
var previous_prediction := Vector2.ZERO
var correction_offset := Vector2.ZERO
var prediction_ready := false
var local_peer := 0
var movement_solver: Callable = World.move_position
var display_bounds := Rect2(World.BOUNDS.position, World.BOUNDS.size - World.PLAYER_SIZE)

func predict(direction: Vector2, delta: float) -> int:
	if not prediction_ready or pending_inputs.size() >= MAX_PENDING_INPUTS:
		return 0
	input_sequence += 1
	pending_inputs.append({"sequence": input_sequence, "direction": direction, "delta": delta})
	previous_prediction = predicted_position
	predicted_position = movement_solver.call(predicted_position, direction, delta)
	return input_sequence

func receive(tick: int, positions: Dictionary, acknowledgements: Dictionary, peer: int, step: float) -> void:
	if tick <= latest_tick:
		return
	latest_tick = tick
	local_peer = peer
	var stamp := tick * step
	if snapshots.is_empty():
		render_time = stamp - BUFFER_SECONDS
	snapshots.append({"time": stamp, "positions": positions.duplicate()})
	while snapshots.size() > MAX_SNAPSHOTS:
		snapshots.pop_front()
	if not positions.has(peer):
		prediction_ready = false
		pending_inputs.clear()
		return
	latest_ack = maxi(latest_ack, clampi(int(acknowledgements.get(peer, 0)), 0, input_sequence))
	while not pending_inputs.is_empty() and int(pending_inputs[0]["sequence"]) <= latest_ack:
		pending_inputs.pop_front()
	var corrected: Vector2 = positions[peer]
	for command in pending_inputs:
		corrected = movement_solver.call(corrected, command["direction"], command["delta"])
	if prediction_ready:
		var change := corrected - predicted_position
		previous_prediction += change
		correction_offset -= change
		if correction_offset.length() > 64:
			correction_offset = Vector2.ZERO
	else:
		previous_prediction = corrected
		prediction_ready = true
	predicted_position = corrected

func advance(delta: float, fraction := 1.0) -> Dictionary:
	if snapshots.is_empty():
		return {}
	var newest: float = snapshots[-1]["time"]
	# Catch up gradually after a stall; never extrapolate an unconfirmed remote state.
	var speed := 1.1 if newest - render_time > BUFFER_SECONDS + 0.1 else 1.0
	render_time = minf(render_time + delta * speed, newest)
	while snapshots.size() > 2 and float(snapshots[1]["time"]) <= render_time:
		snapshots.pop_front()
	var first: Dictionary = snapshots[0]
	var second: Dictionary = snapshots[1] if snapshots.size() > 1 else first
	var duration: float = second["time"] - first["time"]
	var weight := clampf((render_time - float(first["time"])) / duration, 0.0, 1.0) if duration > 0 else 1.0
	var result: Dictionary = {}
	# Use newest membership so a removed player cannot linger in older snapshots.
	for peer in snapshots[-1]["positions"]:
		var target: Vector2 = second["positions"].get(peer, snapshots[-1]["positions"][peer])
		var origin: Vector2 = first["positions"].get(peer, target)
		result[peer] = origin.lerp(target, weight)
	correction_offset = correction_offset.lerp(Vector2.ZERO, 1.0 - exp(-20.0 * delta))
	if prediction_ready and result.has(local_peer):
		result[local_peer] = (previous_prediction.lerp(predicted_position, clampf(fraction, 0.0, 1.0)) + correction_offset).clamp(display_bounds.position, display_bounds.end)
	return result
