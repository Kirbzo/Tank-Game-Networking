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
const CombatWorld = preload("res://combat_world.gd")
const CombatView = preload("res://scripts/combat_view.gd")
var combat: Node2D
var combat_view: Node2D
var combat_sequence := 0
var event_sequence := 0
var last_combat_tick := -1
var aim_direction := Vector2.RIGHT
var aim_pointer := Vector2.ZERO
var fire_held := false
var fire_sequence := 0

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
	aim_pointer = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_pointer = event.position
	if event.is_action_released("fire"):
		fire_held = false
	elif event.is_action_pressed("fire") and combat_input_allowed() and not pointer_over_room_button():
		# Capture the edge before GUI handling and before a later release in this frame.
		# State polling alone loses short clicks; unreliable held-input packets can too.
		fire_held = true
		update_aim()
		fire_sequence += 1
		if multiplayer.is_server():
			accept_fire_request(1, epoch, aim_direction, fire_sequence)
		else:
			session_lobby.combat_fire.rpc_id(1, game_id, epoch, aim_direction, fire_sequence)

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
	process_combat_input()
	if multiplayer.is_server():
		tank_world.accept_input(1, movement_direction(), Time.get_ticks_msec())
		tank_world.step(delta, Time.get_ticks_msec())
		artwork.apply_positions(tank_world.positions)
		snapshot_elapsed += delta
		if snapshot_elapsed >= 0.05:
			snapshot_elapsed = fmod(snapshot_elapsed, 0.05)
			session_lobby.tank_snapshot.rpc(game_id, epoch, tank_world.tick, tank_world.positions, tank_world.processed_sequences)
			var state: Dictionary = combat.snapshot()
			apply_combat_snapshot(tank_world.tick, state)
			session_lobby.combat_snapshot.rpc(game_id, epoch, tank_world.tick, state)
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
	reset_combat(true)
	artwork.apply_positions(tank_world.positions)
	session_lobby.tank_state.rpc(game_id, epoch, "preparing", tank_world.positions)
	update_connection_status()

func acknowledge_ready(peer: int, generation: int) -> void:
	if phase != "preparing" or generation != epoch or not player_names.has(peer) or not multiplayer.get_peers().has(peer):
		return
	ready_peers[peer] = true
	if ready_peers.size() == 2 and player_names.size() == 2:
		phase = "running"
		combat.process_mode = Node.PROCESS_MODE_INHERIT
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
		tank_world = TankWorld.new()
		reset_combat(false)
		tank_view = View.new()
		tank_view.movement_solver = tank_world.move_current
		tank_view.display_bounds = TankWorld.CENTER_BOUNDS
		# Assets and the room are already loaded; initialize prediction before acknowledging.
		tank_view.receive(0, positions, {}, multiplayer.get_unique_id(), 1.0 / Engine.physics_ticks_per_second)
		session_lobby.tank_ready.rpc_id(1, game_id, epoch)
	elif state == "waiting":
		reset_combat(false, false)
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
	reset_combat(false, false)
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
			status_message.text += "\nMove: WASD / arrows · Aim: mouse · Fire: left click"
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

func reset_combat(authority: bool, create_view := true) -> void:
	if is_instance_valid(combat):
		combat.confirmed.disconnect(confirm_combat)
		remove_child(combat)
		combat.free()
	if is_instance_valid(combat_view):
		artwork.remove_child(combat_view)
		combat_view.free()
	combat_sequence = 0
	fire_sequence = 0
	fire_held = false
	event_sequence = 0
	last_combat_tick = -1
	aim_direction = Vector2.RIGHT
	artwork.reset_ice()
	var directions := {}
	for peer in player_names:
		directions[peer] = Vector2.RIGHT
	artwork.apply_aims(directions)
	if create_view:
		combat_view = CombatView.new()
		artwork.add_child(combat_view)
	if authority:
		combat = CombatWorld.new()
		combat.tanks = tank_world
		combat.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(combat)
		combat.confirmed.connect(confirm_combat)

func combat_input_allowed() -> bool:
	return phase == "running" and not leaving and not settings_screen.visible and (DisplayServer.get_name() == "headless" or get_window().has_focus())

func process_combat_input() -> void:
	var fire := false
	if combat_input_allowed():
		update_aim()
		fire = fire_held and not pointer_over_room_button()
	else:
		fire_held = false
	combat_sequence += 1
	if multiplayer.is_server():
		accept_combat_input(1, epoch, aim_direction, fire, combat_sequence)
	else:
		session_lobby.combat_input.rpc_id(1, game_id, epoch, aim_direction, fire, combat_sequence)

func pointer_over_room_button() -> bool:
	for button in [leave_button, settings_button, start_button]:
		if is_instance_valid(button) and button.is_visible_in_tree() and button.get_global_rect().has_point(aim_pointer):
			return true
	return false

func update_aim() -> void:
	var peer := multiplayer.get_unique_id()
	if artwork.tank_markers.has(peer):
		var target: Vector2 = artwork.get_global_transform_with_canvas().affine_inverse() * aim_pointer
		var offset: Vector2 = target - artwork.tank_markers[peer].position
		if offset.length_squared() > 0.01:
			aim_direction = offset.normalized()

func accept_fire_request(peer: int, generation: int, aim: Vector2, sequence: int) -> void:
	if phase == "running" and generation == epoch and is_instance_valid(combat):
		combat.request_fire(peer, aim, sequence)

func accept_combat_input(peer: int, generation: int, aim: Vector2, fire: bool, sequence: int) -> void:
	if phase == "running" and generation == epoch and is_instance_valid(combat):
		combat.accept_input(peer, aim, fire, sequence, Time.get_ticks_msec())

func confirm_combat(kind: String, data: Dictionary) -> void:
	if phase != "running" or leaving:
		return
	event_sequence += 1
	apply_combat_event(kind, data)
	session_lobby.combat_event.rpc(game_id, epoch, event_sequence, kind, data)

func receive_combat_event(generation: int, sequence: int, kind: String, data: Dictionary) -> void:
	if generation != epoch or phase != "running" or sequence <= event_sequence:
		return
	event_sequence = sequence
	apply_combat_event(kind, data)

func apply_combat_event(kind: String, data: Dictionary) -> void:
	if kind == "ice":
		tank_world.removed_ice[int(data.id)] = true
		artwork.remove_ice(int(data.id))
		combat_view.sound.play("brick")
	elif kind == "contact":
		artwork.contact_timers[int(data.peer)] = 2.0
		combat_view.sound.play_moose_contact()
	else:
		if kind == "shot":
			artwork.muzzle_flashes.append({"position": data.position + data.direction * 4.0, "life": 0.06})
		combat_view.event(kind, data)

func apply_combat_snapshot(tick: int, state: Dictionary) -> void:
	if phase != "running" or tick <= last_combat_tick:
		return
	last_combat_tick = tick
	artwork.apply_aims(state.aims)
	combat_view.apply_snapshot(state)
