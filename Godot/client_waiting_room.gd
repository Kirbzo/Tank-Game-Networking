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
var bottom_start_button: Button
var duel_vitals: Dictionary = {}
var vitals_revision := -1
var winner_peer := 0
var vitals_panel: PanelContainer
var vitals_label: Label
var result_overlay: Control
var play_again_button: Button
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
	bottom_start_button = Button.new()
	bottom_start_button.name = "BottomStartGameButton"
	bottom_start_button.text = "Start Game"
	bottom_start_button.add_theme_font_size_override("font_size", 20)
	$HUD/Overlay.add_child(bottom_start_button)
	bottom_start_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_start_button.offset_left = -100
	bottom_start_button.offset_right = 100
	bottom_start_button.offset_top = -152
	bottom_start_button.offset_bottom = -100
	bottom_start_button.pressed.connect(begin_game)
	vitals_panel = PanelContainer.new()
	$HUD/Overlay.add_child(vitals_panel)
	vitals_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	vitals_panel.offset_left = -324
	vitals_panel.offset_right = -24
	vitals_panel.offset_top = -112
	vitals_panel.offset_bottom = -40
	vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.12, 0.16, 0.9)
	background.content_margin_left = 10
	background.content_margin_top = 8
	vitals_panel.add_theme_stylebox_override("panel", background)
	vitals_label = Label.new()
	vitals_label.add_theme_font_size_override("font_size", 14)
	vitals_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_panel.add_child(vitals_label)
	update_connection_status()
	aim_pointer = get_viewport().get_mouse_position()
	if multiplayer.is_server():
		prepare_preview.call_deferred()

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
		cancel_start("Player readiness timed out. Reconnecting...")
	if not controls_active():
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
	if controls_active() and not leaving and session_lobby.session != null and not multiplayer.is_server():
		artwork.apply_positions(tank_view.advance(delta, Engine.get_physics_interpolation_fraction()))

func can_start() -> bool:
	return not leaving and session_lobby != null and session_lobby.session != null and multiplayer.is_server() and phase in ["waiting", "finished"] and not player_names.is_empty()

func request_start() -> void:
	if not can_start():
		return
	prepare_preview()

func prepare_preview(preserve_positions := false, message := "") -> void:
	if leaving or session_lobby == null or session_lobby.session == null or not multiplayer.is_server() or phase == "preparing" or phase == "running":
		return
	if phase == "ready" and same_preview_members():
		return
	var previous: Dictionary = tank_world.positions.duplicate() if preserve_positions else {}
	epoch += 1
	phase = "preparing"
	ready_peers = {1: true}
	connection_event.hide()
	prepare_deadline = Time.get_ticks_msec() + 10000
	tank_world = TankWorld.new()
	for peer in player_names:
		tank_world.add_player(peer)
		if previous.has(peer):
			tank_world.positions[peer] = previous[peer]
	reset_combat(true)
	artwork.apply_positions(tank_world.positions)
	session_lobby.tank_state.rpc(game_id, epoch, "preparing", tank_world.positions)
	if player_names.size() == 1:
		phase = "ready"
		combat.process_mode = Node.PROCESS_MODE_INHERIT
	if not message.is_empty():
		connection_event.text = message
		connection_event.show()
	update_connection_status()

func same_preview_members() -> bool:
	return tank_world.positions.size() == player_names.size() and player_names.keys().all(func(peer): return tank_world.positions.has(peer))

func acknowledge_ready(peer: int, generation: int) -> void:
	if phase != "preparing" or generation != epoch or not player_names.has(peer) or not multiplayer.get_peers().has(peer):
		return
	ready_peers[peer] = true
	if ready_peers.size() == 2 and player_names.size() == 2:
		phase = "ready"
		combat.process_mode = Node.PROCESS_MODE_INHERIT
		session_lobby.tank_state.rpc(game_id, epoch, "ready", tank_world.positions)
		update_connection_status()

func can_begin_game() -> bool:
	return not leaving and session_lobby != null and session_lobby.session != null and multiplayer.is_server() and phase == "ready" and ready_peers.size() == 2 and player_names.size() == 2 and multiplayer.get_peers().size() == 1

func begin_game() -> void:
	if not can_begin_game():
		return
	# Preview projectiles cannot carry over into destructive gameplay.
	combat.clear_shots()
	combat.set_interactions_enabled(true)
	fire_held = false
	phase = "running"
	combat.process_mode = Node.PROCESS_MODE_INHERIT
	snapshot_elapsed = 0.0
	session_lobby.tank_state.rpc(game_id, epoch, "running", tank_world.positions)
	update_connection_status()

func receive_tank_state(generation: int, state: String, positions: Dictionary) -> void:
	if generation < epoch or state not in ["waiting", "preparing", "ready", "running"]:
		return
	if state == "ready" and (phase != "preparing" or generation != epoch):
		return
	if state == "running" and (phase != "ready" or generation != epoch):
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
	elif state == "running":
		fire_held = false
	artwork.apply_positions(positions)
	update_connection_status()

func accept_tank_input(peer: int, generation: int, direction: Vector2, sequence: int) -> void:
	if controls_active() and generation == epoch and sequence > 0:
		tank_world.accept_input(peer, direction, Time.get_ticks_msec(), sequence)

func receive_tank_snapshot(generation: int, tick: int, positions: Dictionary, acknowledgements: Dictionary) -> void:
	if not controls_active() or generation != epoch or positions.size() != 2:
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
	prepare_preview.call_deferred(false, reason)

func _draw() -> void:
	# The artwork replaces rectangles; the inherited HUD remains above it.
	pass

func update_connection_status() -> void:
	super.update_connection_status()
	if session_lobby != null:
		if phase == "running":
			status_message.text += "\nMove: WASD / arrows · Aim: mouse · Fire: left click"
		elif phase == "finished":
			status_message.text += "\nDuel finished"
		elif phase == "preparing":
			status_message.text += "\nWaiting for player readiness..."
		elif phase == "ready":
			status_message.text += "\nMove and shoot · " + ("Waiting for another player" if player_names.size() == 1 else "Waiting for host to press Start Game")
		else:
			status_message.text += "\nSetting up the waiting room..."
	if is_instance_valid(bottom_start_button):
		bottom_start_button.visible = multiplayer.is_server() and phase in ["waiting", "preparing", "ready"]
		bottom_start_button.disabled = not can_begin_game()
	if is_instance_valid(vitals_panel):
		vitals_panel.visible = phase in ["running", "finished"]

func add_world_player(peer: int, player_name: String) -> void:
	super.add_world_player(peer, player_name)
	sync_members()
	if is_instance_valid(artwork) and multiplayer.is_server() and phase == "ready" and not same_preview_members():
		prepare_preview.call_deferred(true)

func receive_names(names: Dictionary) -> void:
	super.receive_names(names)
	sync_members()

func refresh_world_members() -> void:
	super.refresh_world_members()
	if multiplayer.is_server() and is_instance_valid(artwork) and not same_preview_members():
		if is_instance_valid(combat):
			combat.process_mode = Node.PROCESS_MODE_DISABLED
		if phase in ["preparing", "running"]:
			phase = "waiting"
		prepare_preview.call_deferred(true, connection_event.text)
	sync_members()

func sync_members() -> void:
	if is_instance_valid(artwork):
		artwork.set_members(player_names)
	update_connection_status()

func reset_combat(authority: bool, create_view := true) -> void:
	if is_instance_valid(result_overlay):
		result_overlay.hide()
		result_overlay.queue_free()
		result_overlay = null
	play_again_button = null
	winner_peer = 0
	duel_vitals.clear()
	vitals_revision = -1
	for marker in artwork.tank_markers.values():
		marker.show()
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
		combat.interactions_enabled = false
		combat.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(combat)
		combat.confirmed.connect(confirm_combat)

func controls_active() -> bool:
	return phase in ["ready", "running"]

func combat_input_allowed() -> bool:
	return controls_active() and not leaving and not settings_screen.visible and (DisplayServer.get_name() == "headless" or get_window().has_focus())

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
	for button in [leave_button, settings_button, bottom_start_button]:
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
	if controls_active() and generation == epoch and is_instance_valid(combat):
		combat.request_fire(peer, aim, sequence)

func accept_combat_input(peer: int, generation: int, aim: Vector2, fire: bool, sequence: int) -> void:
	if controls_active() and generation == epoch and is_instance_valid(combat):
		combat.accept_input(peer, aim, fire, sequence, Time.get_ticks_msec())

func confirm_combat(kind: String, data: Dictionary) -> void:
	if not controls_active() or leaving:
		return
	if phase == "ready" and kind in ["ice", "contact"]:
		return
	event_sequence += 1
	apply_combat_event(kind, data)
	session_lobby.combat_event.rpc(game_id, epoch, event_sequence, kind, data)

func receive_combat_event(generation: int, sequence: int, kind: String, data: Dictionary) -> void:
	if generation != epoch or not controls_active() or sequence <= event_sequence:
		return
	event_sequence = sequence
	apply_combat_event(kind, data)

func apply_combat_event(kind: String, data: Dictionary) -> void:
	if phase == "ready" and kind in ["ice", "contact"]:
		return
	if kind == "vitals":
		# A newer unreliable snapshot may arrive before this reliable life event.
		if int(data.get("revision", -1)) < vitals_revision:
			return
		if int(data.get("revision", -1)) == vitals_revision and int(data.get("tick", -1)) < maxi(last_combat_tick, tank_view.latest_tick):
			return
		apply_vitals(data)
		var peer: int = data.get("respawn", 0)
		if peer != 0:
			artwork.apply_positions(data.positions)
			if not multiplayer.is_server() and peer == multiplayer.get_unique_id():
				# Discard pre-death prediction instead of replaying it at the new spawn.
				var sequence: int = tank_view.input_sequence
				tank_view = View.new()
				tank_view.input_sequence = sequence
				tank_view.movement_solver = tank_world.move_current
				tank_view.display_bounds = TankWorld.CENTER_BOUNDS
				tank_view.receive(data.tick, data.positions, data.acks, peer, 1.0 / Engine.physics_ticks_per_second)
	elif kind == "result":
		apply_vitals(data)
		show_duel_result(int(data.winner))
	elif kind == "ice":
		tank_world.removed_ice[int(data.id)] = true
		artwork.remove_ice(int(data.id))
		combat_view.sound.play("brick")
	elif kind == "contact":
		artwork.contact_timers[int(data.peer)] = 2.0
		if artwork.tank_markers.has(int(data.peer)):
			artwork.tank_markers[int(data.peer)].moose_cooldown = 2.0
		combat_view.sound.play_moose_contact()
	else:
		if kind == "shot":
			if artwork.tank_markers.has(int(data.peer)):
				artwork.tank_markers[int(data.peer)].shot_flash = 0.06
		combat_view.event(kind, data)

func apply_combat_snapshot(tick: int, state: Dictionary) -> void:
	if not controls_active() or tick <= last_combat_tick:
		return
	last_combat_tick = tick
	apply_vitals(state)
	artwork.apply_aims(state.aims)
	combat_view.apply_snapshot(state)

func apply_vitals(data: Dictionary) -> void:
	var revision: int = data.get("revision", -1)
	if revision < vitals_revision:
		return
	vitals_revision = revision
	duel_vitals = data.get("vitals", {}).duplicate(true)
	var lines: PackedStringArray = []
	for peer in player_names:
		if not duel_vitals.has(peer):
			continue
		var values: Dictionary = duel_vitals[peer]
		lines.append("%s: %d HP / %d lives" % [str(player_names[peer]).left(18), values.health, values.lives])
		if artwork.tank_markers.has(peer):
			artwork.tank_markers[peer].apply_vitals(values)
		if float(values.protection) > 0:
			artwork.contact_timers[peer] = float(values.protection)
	if is_instance_valid(vitals_label):
		vitals_label.text = "\n".join(lines)

func show_duel_result(winner: int) -> void:
	if phase == "finished":
		return
	winner_peer = winner
	phase = "finished"
	fire_held = false
	combat_view.clear_shots()
	combat_view.sound.play("victory" if winner == multiplayer.get_unique_id() else "defeat")
	result_overlay = Control.new()
	$HUD.add_child(result_overlay)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.09, 0.85)
	result_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	result_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	center.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(460, 0)
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	var title := Label.new()
	title.text = "Winner: " + str(player_names.get(winner, "None"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	if multiplayer.is_server():
		play_again_button = Button.new()
		play_again_button.text = "Play Again"
		play_again_button.pressed.connect(request_start)
		column.add_child(play_again_button)
	else:
		var waiting := Label.new()
		waiting.text = "Waiting for host to play again"
		column.add_child(waiting)
	var back := Button.new()
	back.text = "Return to Lobby"
	back.pressed.connect(leave_room)
	column.add_child(back)
	var confetti := preload("res://scripts/confetti.gd").new()
	result_overlay.add_child(confetti)
	result_overlay.move_child(confetti, 1)
	update_connection_status()
