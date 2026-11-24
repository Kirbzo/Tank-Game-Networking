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
var result_overlay: Control
var play_again_button: Button
const CombatWorld = preload("res://combat_world.gd")
const CombatView = preload("res://scripts/combat_view.gd")
var combat: Node2D
var combat_view: Node2D
var combat_sequence := 0
var event_sequence := 0
var last_combat_tick := -1
var ice_revision := -1
var aim_direction := Vector2.RIGHT
var aim_pointer := Vector2.ZERO
var fire_held := false
var fire_sequence := 0
var control_revision := 0
var countdown_number := 0
var countdown_deadline := 0
var resume_phase := "running"
var room_overlay: Control
var room_logo: TextureRect

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
	configure_room_hud()
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
	if multiplayer.is_server() and phase == "countdown":
		advance_countdown()
	if not controls_active():
		return
	process_combat_input()
	if multiplayer.is_server():
		combat.refresh_collision_bodies()
		tank_world.accept_input(1, movement_direction(), Time.get_ticks_msec())
		tank_world.step(delta, Time.get_ticks_msec())
		artwork.apply_positions(tank_world.positions)
		snapshot_elapsed += delta
		if snapshot_elapsed >= 0.05:
			snapshot_elapsed = fmod(snapshot_elapsed, 0.05)
			session_lobby.tank_snapshot.rpc(game_id, epoch, tank_world.tick, tank_world.positions, tank_world.processed_sequences)
			var state: Dictionary = combat.snapshot()
			apply_combat_snapshot(tank_world.tick, state)
			session_lobby.combat_snapshot.rpc(game_id, epoch, tank_world.tick, var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE))
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
	if leaving or session_lobby == null or session_lobby.session == null or not multiplayer.is_server() or phase in ["preparing", "running", "countdown", "paused"]:
		return
	if phase == "ready" and same_preview_members():
		return
	var previous: Dictionary = tank_world.positions.duplicate() if preserve_positions else {}
	epoch += 1
	phase = "preparing"
	settings_screen.hide()
	countdown_number = 0
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
		publish_control("ready")
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
		publish_control("ready")

func can_begin_game() -> bool:
	return not leaving and session_lobby != null and session_lobby.session != null and multiplayer.is_server() and phase == "ready" and ready_peers.size() == 2 and player_names.size() == 2 and multiplayer.get_peers().size() == 1

func begin_game() -> void:
	if not can_begin_game():
		return
	# A fresh authoritative arena prevents preview shots/positions carrying into Start.
	for peer in tank_world.positions:
		tank_world.positions[peer] = TankWorld.spawn_position(peer)
		tank_world.directions[peer] = Vector2.ZERO
	tank_world.hit_push.clear()
	tank_world.bounce_push.clear()
	reset_combat(true)
	countdown_number = 3
	countdown_deadline = Time.get_ticks_msec() + 1000
	publish_control("countdown")

func advance_countdown() -> void:
	if Time.get_ticks_msec() < countdown_deadline:
		return
	countdown_number -= 1
	if countdown_number == 0:
		combat.set_interactions_enabled(true)
		publish_control("running")
	else:
		# Never skip a digit after a stalled host frame.
		countdown_deadline = Time.get_ticks_msec() + 1000
		publish_control("countdown")

func request_pause(paused: bool) -> void:
	if leaving or session_lobby == null or session_lobby.session == null:
		return
	if multiplayer.is_server():
		accept_pause(1, epoch, control_revision, paused)
	else:
		session_lobby.room_pause_request.rpc_id(1, game_id, epoch, control_revision, paused)

func accept_pause(peer: int, generation: int, revision: int, paused: bool) -> void:
	if not multiplayer.is_server() or leaving or generation != epoch or revision != control_revision or not player_names.has(peer):
		return
	if peer != 1 and not multiplayer.get_peers().has(peer):
		return
	if paused and phase in ["ready", "running"]:
		resume_phase = phase
		publish_control("paused")
	elif not paused and phase == "paused":
		publish_control(resume_phase)

func publish_control(next_phase: String) -> void:
	# A new generation rejects movement/fire/snapshots already in flight on other channels.
	epoch += 1
	control_revision += 1
	combat.controls.clear()
	for peer in tank_world.directions:
		tank_world.directions[peer] = Vector2.ZERO
	tank_world.input_times.clear()
	var state: Dictionary = combat.snapshot()
	receive_control(epoch, control_revision, next_phase, countdown_number, tank_world.tick, tank_world.positions, tank_world.processed_sequences, state)
	session_lobby.room_control.rpc(game_id, epoch, control_revision, next_phase, countdown_number, tank_world.tick, tank_world.positions, tank_world.processed_sequences, state)

func receive_control(generation: int, revision: int, next_phase: String, number: int, tick: int, positions: Dictionary, acknowledgements: Dictionary, state: Dictionary) -> void:
	if generation < epoch or (not multiplayer.is_server() and revision <= control_revision) or next_phase not in ["countdown", "running", "paused", "ready"]:
		return
	if next_phase == "countdown" and phase != "countdown" and not multiplayer.is_server():
		reset_combat(false)
	epoch = generation
	control_revision = revision
	phase = next_phase
	countdown_number = number if phase == "countdown" else 0
	fire_held = false
	# Freeze at the host's exact boundary, discarding pre-pause prediction/interpolation.
	tank_world.positions = positions.duplicate()
	if not multiplayer.is_server():
		var sequence: int = tank_view.input_sequence
		tank_view = View.new()
		tank_view.input_sequence = sequence
		tank_world.prediction_peer = multiplayer.get_unique_id()
		tank_view.movement_solver = tank_world.predict_movement
		tank_view.display_bounds = TankWorld.CENTER_BOUNDS
		tank_view.receive(tick, positions, acknowledgements, multiplayer.get_unique_id(), 1.0 / Engine.physics_ticks_per_second)
	artwork.apply_positions(positions)
	apply_combat_snapshot(tick, state, true)
	set_gameplay_processing(controls_active())
	settings_screen.visible = phase == "paused"
	if phase == "paused":
		settings_back_button.grab_focus()
	else:
		grab_focus()
	update_connection_status()

func set_gameplay_processing(enabled: bool) -> void:
	if is_instance_valid(combat):
		combat.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(artwork):
		artwork.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(combat_view):
		for voice in combat_view.sound.voices.values():
			voice.stream_paused = not enabled

func configure_room_hud() -> void:
	settings_button.text = "Pause"
	settings_button.tooltip_text = "Pause the game for both players"
	settings_button.add_theme_font_size_override("font_size", 20)
	settings_button.offset_left = -184
	settings_button.offset_right = -40
	settings_button.offset_top = 32
	settings_button.offset_bottom = 80
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.02, 0.06, 0.1, 0.72)
	settings_screen.add_theme_stylebox_override("panel", backdrop)
	var card := StyleBoxTexture.new()
	card.texture = preload("res://assets/menu_panel.svg")
	card.content_margin_left = 32
	card.content_margin_right = 32
	card.content_margin_top = 24
	card.content_margin_bottom = 24
	$HUD/SettingsScreen/Center/Panel.add_theme_stylebox_override("panel", card)
	$HUD/SettingsScreen/Center/Panel/Content/Title.text = "GAME PAUSED"
	$HUD/SettingsScreen/Center/Panel/Content/Title.add_theme_color_override("font_color", Color("#ffd66b"))
	$HUD/SettingsScreen/Center/Panel/Content/Placeholder.text = "Paused for both players"
	settings_back_button.text = "Resume"
	room_logo = TextureRect.new()
	room_logo.name = "RoomLogo"
	room_logo.texture = preload("res://assets/hud_logo.png")
	room_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	room_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD/Overlay.add_child(room_logo)
	room_logo.position = Vector2(120, 8)
	room_logo.size = Vector2(92, 76)
	room_overlay = preload("res://scripts/room_overlay.gd").new()
	room_overlay.name = "RoomOverlay"
	room_overlay.room = self
	$HUD/Overlay.add_child(room_overlay)

func show_settings() -> void:
	request_pause(true)

func close_settings() -> void:
	request_pause(false)

func receive_tank_state(generation: int, state: String, positions: Dictionary) -> void:
	if generation < epoch or state not in ["waiting", "preparing", "ready", "running"]:
		return
	if state == "ready" and (phase != "preparing" or generation != epoch):
		return
	if state == "running" and (phase != "ready" or generation != epoch):
		return
	epoch = generation
	phase = state
	countdown_number = 0
	settings_screen.hide()
	set_gameplay_processing(controls_active())
	if state == "preparing":
		tank_world = TankWorld.new()
		tank_world.positions = positions.duplicate()
		reset_combat(false)
		tank_view = View.new()
		tank_world.prediction_peer = multiplayer.get_unique_id()
		tank_view.movement_solver = tank_world.predict_movement
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
	if tick <= tank_view.latest_tick:
		return
	for peer in positions:
		if not player_names.has(peer) or not positions[peer] is Vector2 or not positions[peer].is_finite():
			return
	tank_world.positions = positions.duplicate()
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
	$HUD/Overlay/GameIdPanel.visible = phase in ["waiting", "preparing", "ready"]
	if session_lobby != null:
		if phase == "finished":
			status_message.text += "\nDuel finished"
		elif phase == "preparing":
			status_message.text += "\nWaiting for player readiness..."
		elif phase == "ready":
			status_message.text += "\n" + ("Waiting for another player" if player_names.size() == 1 else "Waiting for host to press Start Game")
		elif phase == "waiting":
			status_message.text += "\nSetting up the waiting room..."
	if is_instance_valid(bottom_start_button):
		bottom_start_button.visible = multiplayer.is_server() and phase in ["waiting", "preparing", "ready"]
		bottom_start_button.disabled = not can_begin_game()
	settings_button.disabled = phase not in ["ready", "running"]

func add_world_player(peer: int, player_name: String) -> void:
	super.add_world_player(peer, player_name)
	sync_members()
	if is_instance_valid(artwork) and multiplayer.is_server() and not same_preview_members():
		if phase == "paused" and resume_phase == "ready":
			phase = "waiting"
		if phase in ["ready", "waiting"]:
			prepare_preview.call_deferred(true)

func receive_names(names: Dictionary) -> void:
	super.receive_names(names)
	sync_members()

func refresh_world_members() -> void:
	super.refresh_world_members()
	if multiplayer.is_server() and is_instance_valid(artwork) and not same_preview_members():
		if is_instance_valid(combat):
			combat.process_mode = Node.PROCESS_MODE_DISABLED
		if phase in ["preparing", "running", "countdown", "paused"]:
			phase = "waiting"
		settings_screen.hide()
		countdown_number = 0
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
	ice_revision = -1
	aim_direction = Vector2.RIGHT
	artwork.reset_ice()
	var directions := {}
	for peer in player_names:
		directions[peer] = Vector2.RIGHT
	artwork.apply_aims(directions)
	if create_view:
		combat_view = CombatView.new()
		artwork.add_child(combat_view)
		var menu := session_lobby.get_parent().get_node_or_null("MooozeTanks")
		if menu != null:
			combat_view.sound.set_volume(menu.sound.volume)
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
				tank_world.prediction_peer = multiplayer.get_unique_id()
				tank_view.movement_solver = tank_world.predict_movement
				tank_view.display_bounds = TankWorld.CENTER_BOUNDS
				tank_view.receive(data.tick, data.positions, data.acks, peer, 1.0 / Engine.physics_ticks_per_second)
	elif kind == "result":
		apply_vitals(data)
		show_duel_result(int(data.winner), data.get("summary", {}))
	elif kind in ["ice", "ice_spawn"]:
		if int(data.get("revision", ice_revision + 1)) <= ice_revision:
			return
		ice_revision = int(data.get("revision", ice_revision + 1))
		if kind == "ice":
			tank_world.removed_ice[int(data.id)] = true
			tank_world.extra_ice.erase(int(data.id))
			artwork.remove_ice(int(data.id))
			combat_view.sound.play("brick")
		else:
			tank_world.extra_ice[int(data.id)] = data.position
			artwork.spawn_ice(int(data.id), data.position)
	elif kind == "contact":
		artwork.contact_timers[int(data.peer)] = 2.0
		if artwork.tank_markers.has(int(data.peer)):
			artwork.tank_markers[int(data.peer)].moose_cooldown = 2.0
	else:
		if kind == "shot":
			if artwork.tank_markers.has(int(data.peer)):
				artwork.tank_markers[int(data.peer)].shot_flash = 0.06
		combat_view.event(kind, data)

func apply_combat_snapshot(tick: int, state: Dictionary, boundary := false) -> void:
	if not boundary and (not controls_active() or tick <= last_combat_tick):
		return
	last_combat_tick = tick
	if int(state.get("ice_revision", -1)) >= ice_revision:
		ice_revision = int(state.get("ice_revision", -1))
		tank_world.removed_ice = state.get("removed_ice", tank_world.removed_ice).duplicate()
		tank_world.extra_ice = state.get("extra_ice", tank_world.extra_ice).duplicate()
		artwork.apply_ice_state(tank_world.removed_ice, tank_world.extra_ice)
	if not multiplayer.is_server():
		tank_world.moose_positions.clear()
		for animal in state.moose:
			tank_world.moose_positions.append(animal.position)
		tank_world.inactive_peers.clear()
		for peer in state.vitals:
			if not state.vitals[peer].active:
				tank_world.inactive_peers.append(peer)
	apply_vitals(state)
	artwork.apply_aims(state.aims)
	combat_view.apply_snapshot(state)

func apply_vitals(data: Dictionary) -> void:
	var revision: int = data.get("revision", -1)
	if revision < vitals_revision:
		return
	vitals_revision = revision
	duel_vitals = data.get("vitals", {}).duplicate(true)
	for peer in player_names:
		if not duel_vitals.has(peer):
			continue
		var values: Dictionary = duel_vitals[peer]
		tank_world.speed_multipliers[peer] = 1.5 if float(values.get("speed", 0.0)) > 0.0 else 1.0
		if artwork.tank_markers.has(peer):
			artwork.tank_markers[peer].apply_vitals(values)
		if float(values.protection) > 0:
			artwork.contact_timers[peer] = float(values.protection)

func show_duel_result(winner: int, summary: Dictionary = {}) -> void:
	for marker in artwork.tank_markers.values():
		marker.effects_running = false
	if phase == "finished":
		return
	winner_peer = winner
	phase = "finished"
	fire_held = false
	combat_view.clear_shots()
	combat_view.sound.play("victory" if winner == multiplayer.get_unique_id() else "defeat")
	result_overlay = preload("res://scripts/lan_results.gd").new()
	$HUD.add_child(result_overlay)
	var guest := 0
	for peer in player_names:
		if peer != 1:
			guest = peer
	var winner_number := 1 if winner == 1 else (2 if winner == guest and guest != 0 else 0)
	result_overlay.build(winner_number, [duel_vitals.get(1, {}), duel_vitals.get(guest, {})], summary, multiplayer.is_server())
	play_again_button = result_overlay.replay_button if multiplayer.is_server() else null
	result_overlay.replay_requested.connect(request_start)
	result_overlay.lobby_requested.connect(leave_room)
	update_connection_status()
