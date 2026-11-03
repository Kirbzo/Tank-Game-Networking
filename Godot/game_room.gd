extends Control
## Connected views draw host state; standalone preview keeps local movement.

const PLAYER_SIZE := Vector2(32, 32)
const MOVE_SPEED := 220.0
const LOBBY_SCENE := "res://lobby.tscn"

@export var game_id := "PREVIEW"
var session_lobby: Node
const World = preload("res://room_world.gd")
var world := World.new()
var world_positions: Dictionary = {}
var world_tick := -1
var snapshot_elapsed := 0.0
var arena := Rect2()
var player_position := Vector2.ZERO
var leaving := false
var spawned := false
@onready var hud: CanvasLayer = $HUD
@onready var leave_button: Button = $HUD/Overlay/LeaveButton
@onready var settings_button: Button = $HUD/Overlay/SettingsButton
@onready var game_id_label: Label = $HUD/Overlay/GameIdPanel/GameId
@onready var settings_screen: Control = $HUD/SettingsScreen
@onready var settings_back_button: Button = $HUD/SettingsScreen/Center/Panel/Content/BackButton
@onready var status_message: Label = $HUD/Overlay/StatusMessage

func _ready() -> void:
	leave_button.pressed.connect(leave_room)
	settings_button.pressed.connect(show_settings)
	settings_back_button.pressed.connect(close_settings)
	game_id_label.text = "Game ID: " + game_id
	update_connection_status()
	resized.connect(layout_room)
	layout_room()
	if session_lobby != null and multiplayer.is_server():
		world.add_player(1)
		world_positions = world.positions.duplicate()
	grab_focus()

func update_connection_status() -> void:
	if session_lobby == null:
		return
	var hosting: bool = not session_lobby.discovery.hosted_game.is_empty()
	var count := 1 + multiplayer.get_peers().size()
	status_message.text = "%s | %d/2 players connected" % ["Hosting" if hosting else "Connected", count]
	status_message.show()

func layout_room() -> void:
	arena = World.BOUNDS if session_lobby != null else Rect2(Vector2(24, 24), Vector2(maxf(size.x - 48, PLAYER_SIZE.x), maxf(size.y - 48, PLAYER_SIZE.y)))
	if not spawned:
		player_position = arena.get_center() - PLAYER_SIZE / 2
		spawned = true
	clamp_player()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if leaving:
		return
	if session_lobby != null:
		process_world(delta)
		return
	if settings_screen.visible:
		return
	var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var direction := Vector2(horizontal, vertical).limit_length()
	player_position += direction * MOVE_SPEED * delta
	clamp_player()
	queue_redraw()

func movement_direction() -> Vector2:
	if settings_screen.visible or (DisplayServer.get_name() != "headless" and not get_window().has_focus()):
		return Vector2.ZERO
	var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	return Vector2(horizontal, vertical).limit_length()

func process_world(delta: float) -> void:
	var direction := movement_direction()
	if multiplayer.is_server():
		world.accept_input(1, direction, Time.get_ticks_msec())
		world.step(delta, Time.get_ticks_msec())
		world_positions = world.positions.duplicate()
		world_tick = world.tick
		snapshot_elapsed += delta
		if snapshot_elapsed >= 0.05:
			snapshot_elapsed = 0.0
			broadcast_world()
	else:
		session_lobby.room_input.rpc_id(1, direction)
	queue_redraw()

func add_world_player(peer: int) -> void:
	world.add_player(peer)
	world_positions = world.positions.duplicate()
	broadcast_world()

func refresh_world_members() -> void:
	if not multiplayer.is_server():
		return
	for peer in world.positions.keys():
		if peer != 1 and not multiplayer.get_peers().has(peer):
			world.remove_player(peer)
	world_positions = world.positions.duplicate()
	broadcast_world()
	queue_redraw()

func broadcast_world() -> void:
	for peer in world.positions:
		if peer != 1 and multiplayer.get_peers().has(peer):
			session_lobby.room_snapshot.rpc_id(peer, game_id, world.tick, world.positions)

func receive_world(tick: int, positions: Dictionary) -> void:
	if tick <= world_tick or positions.size() > 2:
		return
	for peer in positions:
		if not peer is int or not positions[peer] is Vector2 or not positions[peer].is_finite() or not arena.encloses(Rect2(positions[peer], PLAYER_SIZE)):
			return
	world_tick = tick
	world_positions = positions.duplicate()
	queue_redraw()

func clamp_player() -> void:
	player_position.x = clampf(player_position.x, arena.position.x, arena.end.x - PLAYER_SIZE.x)
	player_position.y = clampf(player_position.y, arena.position.y, arena.end.y - PLAYER_SIZE.y)

func _draw() -> void:
	if session_lobby != null:
		# Fit the common logical world into this viewport, preserving aspect ratio.
		var scale_factor := minf(size.x / 1000.0, size.y / 720.0)
		draw_set_transform((size - Vector2(1000, 720) * scale_factor) / 2, 0, Vector2.ONE * scale_factor)
	draw_rect(arena, Color(0.055, 0.085, 0.12))
	var grid_color := Color(0.1, 0.15, 0.2)
	for x in range(int(arena.position.x), int(arena.end.x), 48):
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), grid_color)
	for y in range(int(arena.position.y), int(arena.end.y), 48):
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), grid_color)
	draw_rect(arena, Color(0.3, 0.45, 0.55), false, 2.0)
	if session_lobby != null:
		for peer in world_positions:
			draw_player(world_positions[peer], peer == multiplayer.get_unique_id(), "Host" if peer == 1 else "Player 2")
		draw_set_transform(Vector2.ZERO)
		return
	draw_player(player_position, true, "P")

func draw_player(position: Vector2, local: bool, label: String) -> void:
	draw_rect(Rect2(position, PLAYER_SIZE), Color(0.95, 0.6, 0.2) if label == "Player 2" else Color(0.2, 0.8, 0.7))
	draw_rect(Rect2(position, PLAYER_SIZE), Color(0.7, 1.0, 0.95), false, 2.0)
	draw_string(ThemeDB.fallback_font, position + Vector2(0, 23), label + (" (You)" if local and session_lobby != null else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.02, 0.1, 0.12))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		accept_event()
		if settings_screen.visible:
			close_settings()
		else:
			leave_room()

func show_settings() -> void:
	if leaving:
		return
	settings_screen.show()
	settings_back_button.grab_focus()

func close_settings() -> void:
	settings_screen.hide()
	grab_focus()

func leave_room() -> void:
	if leaving:
		return
	leaving = true
	set_physics_process(false)
	if session_lobby != null:
		session_lobby.return_from_room()
		return
	# Standalone preview has no session to close.
	var result := get_tree().change_scene_to_file(LOBBY_SCENE)
	if result != OK:
		leaving = false
		set_physics_process(true)
		status_message.text = "Could not return to the lobby. Try the back arrow again."
		status_message.show()
