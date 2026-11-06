extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: " + message)
		quit(1)
	return value

func run() -> void:
	var View = load("res://room_view.gd")
	var World = load("res://room_world.gd")
	var view = View.new()
	var state := {1: Vector2(100, 100), 2: Vector2(200, 200)}
	view.receive(0, state, {2: 0}, 2, 1.0 / 60)
	view.receive(6, {1: Vector2(122, 100), 2: Vector2(200, 200)}, {2: 0}, 2, 1.0 / 60)
	var display: Dictionary = view.advance(0.15)
	if not check(display[1].is_equal_approx(Vector2(111, 100)), "Remote display interpolates between snapshots"):
		return
	view.predict(Vector2.RIGHT, 1.0 / 60)
	view.predict(Vector2.RIGHT, 1.0 / 60)
	if not check(view.predicted_position.x > 207 and state[2] == Vector2(200, 200), "Local prediction responds without modifying authoritative state"):
		return
	view.receive(9, {1: Vector2(133, 100), 2: Vector2(200 + 220.0 / 60, 200)}, {2: 1}, 2, 1.0 / 60)
	if not check(view.pending_inputs.size() == 1 and is_equal_approx(view.predicted_position.x, 200 + 440.0 / 60), "Acknowledged input removed; unacknowledged input replayed once"):
		return
	view.receive(12, {1: Vector2(144, 100), 2: Vector2(208, 200)}, {2: 2}, 2, 1.0 / 60)
	if not check(view.pending_inputs.is_empty() and view.predicted_position == Vector2(208, 200), "Host correction wins"):
		return
	view.receive(3, {}, {}, 2, 1.0 / 60)
	if not check(view.latest_tick == 12, "Out-of-order snapshot ignored"):
		return
	view.receive(15, {1: Vector2(155, 100), 2: Vector2(800, 200)}, {2: 2}, 2, 1.0 / 60)
	if not check(view.correction_offset == Vector2.ZERO and view.predicted_position.x == 800, "Large correction snaps instead of prolonged drift"):
		return
	for i in range(200):
		view.predict(Vector2.RIGHT, 1.0 / 60)
	if not check(view.pending_inputs.size() == view.MAX_PENDING_INPUTS and view.predicted_position.x <= World.BOUNDS.end.x - World.PLAYER_SIZE.x, "Prediction queue and bounds remain bounded without acknowledgements"):
		return
	var lost = View.new()
	lost.receive(0, state, {}, 2, 1.0 / 60)
	lost.receive(12, {1: Vector2(144, 100), 2: Vector2(200, 200)}, {}, 2, 1.0 / 60)
	display = lost.advance(0.15)
	if not check(display[1].x > 100 and display[1].x < 144, "Missing snapshots still interpolate safely"):
		return
	display = lost.advance(2.0)
	if not check(display[1] == Vector2(144, 100), "Stalled stream holds latest state without extrapolation"):
		return
	lost.receive(15, {2: Vector2(200, 200)}, {}, 2, 1.0 / 60)
	if not check(not lost.advance(0.01).has(1), "Removed remote entity is not rendered from stale history"):
		return
	var server = World.new()
	server.add_player(2)
	if not check(server.accept_input(2, Vector2.RIGHT, 0, 1) and not server.processed_sequences.has(2), "Input acknowledged only after host simulation"):
		return
	server.step(1.0 / 60, 0)
	if not check(server.processed_sequences[2] == 1 and not server.accept_input(2, Vector2.LEFT, 1, 1), "Duplicate sequence cannot replay movement"):
		return
	if not check(not server.accept_input(2, Vector2(999, 0), 1, 2) and server.received_sequences[2] == 1, "Invalid input cannot consume acknowledgement sequence"):
		return
	print("PASS interpolation, prediction/reconciliation, stale/lost snapshots, bounds, queue and host acknowledgement validation")
	quit(0)
