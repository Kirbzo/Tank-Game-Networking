extends "res://game_room.gd"
## Client arena artwork in a live waiting room, with existing membership/HUD cleanup.
const ArenaArtwork = preload("res://scripts/waiting_arena.gd")
var artwork: Node2D
const TankWorld = preload("res://tank_world.gd")
var tank_world := TankWorld.new()
var tank_view := View.new()
var phase := "waiting"
var epoch := 0
var ready_peers: Dictionary = {}
var prepare_deadline := 0
var start_button: Button

func _ready() -> void:
	super._ready()
	artwork = ArenaArtwork.new()
	add_child(artwork)
	resized.connect(fit_artwork)
	fit_artwork()
	sync_members()
	game_id_label.tooltip_text = "Connected waiting room"
	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.text = "Start"
	start_button.position = Vector2(150, 45)
	start_button.size = Vector2(140, 45)
	$HUD/Overlay.add_child(start_button)
	start_button.pressed.connect(request_start)
	update_connection_status()

func fit_artwork() -> void:
	var factor := minf(size.x / 1280.0, size.y / 800.0)
	artwork.scale = Vector2.ONE * factor
	artwork.position = (size - Vector2(1280, 800) * factor) / 2.0

func _physics_process(delta: float) -> void:
	if leaving or session_lobby == null or session_lobby.session == null:
		return
	if multiplayer.is_server() and phase == "preparing" and Time.get_ticks_msec() >= prepare_deadline:
		cancel_start("Player readiness timed out. Try Start again.")
	if phase != "running":
		return
	if multiplayer.is_server():
		tank_world.accept_input(1, movement_direction(), Time.get_ticks_msec())
		tank_world.step(delta, Time.get_ticks_msec())
		artwork.apply_positions(tank_world.positions)
		snapshot_elapsed += delta
		if snapshot_elapsed >= 0.05:
			snapshot_elapsed = fmod(snapshot_elapsed, 0.05)
			session_lobby.tank_snapshot.rpc(game_id, epoch, tank_world.tick, tank_world.positions, tank_world.processed_sequences)
	else:
		var sequence := tank_view.predict(movement_direction(), delta)
		if sequence > 0:
			session_lobby.tank_input.rpc_id(1, game_id, epoch, movement_direction(), sequence)

func _process(delta: float) -> void:
	super._process(delta)
	if phase == "running" and not leaving and session_lobby.session != null and not multiplayer.is_server():
		artwork.apply_positions(tank_view.advance(delta, Engine.get_physics_interpolation_fraction()))

func can_start() -> bool:
	return not leaving and session_lobby != null and session_lobby.session != null and multiplayer.is_server() and phase == "waiting" and player_names.size() == 2 and multiplayer.get_peers().size() == 1

func request_start() -> void:
	if not can_start():
		return
	epoch += 1
	phase = "preparing"
	ready_peers = {1: true}
	connection_event.hide()
	prepare_deadline = Time.get_ticks_msec() + 10000
	tank_world = TankWorld.new()
	for peer in player_names:
		tank_world.add_player(peer)
	artwork.apply_positions(tank_world.positions)
	session_lobby.tank_state.rpc(game_id, epoch, "preparing", tank_world.positions)
	update_connection_status()

func acknowledge_ready(peer: int, generation: int) -> void:
	if phase != "preparing" or generation != epoch or not player_names.has(peer) or not multiplayer.get_peers().has(peer):
		return
	ready_peers[peer] = true
	if ready_peers.size() == 2 and player_names.size() == 2:
		phase = "running"
		snapshot_elapsed = 0.0
		session_lobby.tank_state.rpc(game_id, epoch, "running", tank_world.positions)
		update_connection_status()

func receive_tank_state(generation: int, state: String, positions: Dictionary) -> void:
	if generation < epoch or state not in ["waiting", "preparing", "running"]:
		return
	if state == "running" and (phase != "preparing" or generation != epoch):
		return
	epoch = generation
	phase = state
	if state == "preparing":
		tank_view = View.new()
		tank_view.movement_solver = TankWorld.move_tank
		tank_view.display_bounds = TankWorld.CENTER_BOUNDS
		# Assets and the room are already loaded; initialize prediction before acknowledging.
		tank_view.receive(0, positions, {}, multiplayer.get_unique_id(), 1.0 / Engine.physics_ticks_per_second)
		session_lobby.tank_ready.rpc_id(1, game_id, epoch)
	artwork.apply_positions(positions)
	update_connection_status()

func accept_tank_input(peer: int, generation: int, direction: Vector2, sequence: int) -> void:
	if phase == "running" and generation == epoch and sequence > 0:
		tank_world.accept_input(peer, direction, Time.get_ticks_msec(), sequence)

func receive_tank_snapshot(generation: int, tick: int, positions: Dictionary, acknowledgements: Dictionary) -> void:
	if phase != "running" or generation != epoch or positions.size() != 2:
		return
	for peer in positions:
		if not player_names.has(peer) or not positions[peer] is Vector2 or not positions[peer].is_finite():
			return
	tank_view.receive(tick, positions, acknowledgements, multiplayer.get_unique_id(), 1.0 / Engine.physics_ticks_per_second)

func cancel_start(reason: String) -> void:
	epoch += 1
	phase = "waiting"
	ready_peers.clear()
	tank_world = TankWorld.new()
	for peer in player_names:
		tank_world.add_player(peer)
	artwork.apply_positions(tank_world.positions)
	session_lobby.tank_state.rpc(game_id, epoch, "waiting", tank_world.positions)
	update_connection_status()
	connection_event.text = reason
	connection_event.show()

func _draw() -> void:
	# The artwork replaces rectangles; the inherited HUD remains above it.
	pass

func update_connection_status() -> void:
	super.update_connection_status()
	if session_lobby != null:
		if phase == "running":
			status_message.text += "\nMove: WASD / arrows"
		elif phase == "preparing":
			status_message.text += "\nWaiting for player readiness..."
		else:
			status_message.text += "\nWaiting for another player" if multiplayer.get_peers().is_empty() else "\nBoth players connected · Waiting for host to Start"
	if is_instance_valid(start_button):
		start_button.visible = multiplayer.is_server() and phase != "running"
		start_button.disabled = not can_start()

func add_world_player(peer: int, player_name: String) -> void:
	super.add_world_player(peer, player_name)
	sync_members()

func receive_names(names: Dictionary) -> void:
	super.receive_names(names)
	sync_members()

func refresh_world_members() -> void:
	super.refresh_world_members()
	if multiplayer.is_server() and player_names.size() < 2 and phase != "waiting":
		cancel_start(connection_event.text)
	sync_members()

func sync_members() -> void:
	if is_instance_valid(artwork):
		artwork.set_members(player_names)
	update_connection_status()
