extends Control
## Standalone local movement preview; Host integration and networking come later.

const PLAYER_SIZE := Vector2(32, 32)
const MOVE_SPEED := 220.0
const LOBBY_SCENE := "res://lobby.tscn"

@export var game_id := "PREVIEW"
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
	resized.connect(layout_room)
	layout_room()
	grab_focus()

func layout_room() -> void:
	arena = Rect2(Vector2(24, 24), Vector2(maxf(size.x - 48, PLAYER_SIZE.x), maxf(size.y - 48, PLAYER_SIZE.y)))
	if not spawned:
		player_position = arena.get_center() - PLAYER_SIZE / 2
		spawned = true
	clamp_player()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if leaving or settings_screen.visible:
		return
	var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var direction := Vector2(horizontal, vertical).limit_length()
	player_position += direction * MOVE_SPEED * delta
	clamp_player()
	queue_redraw()

func clamp_player() -> void:
	player_position.x = clampf(player_position.x, arena.position.x, arena.end.x - PLAYER_SIZE.x)
	player_position.y = clampf(player_position.y, arena.position.y, arena.end.y - PLAYER_SIZE.y)

func _draw() -> void:
	draw_rect(arena, Color(0.055, 0.085, 0.12))
	var grid_color := Color(0.1, 0.15, 0.2)
	for x in range(int(arena.position.x), int(arena.end.x), 48):
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), grid_color)
	for y in range(int(arena.position.y), int(arena.end.y), 48):
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), grid_color)
	draw_rect(arena, Color(0.3, 0.45, 0.55), false, 2.0)
	draw_rect(Rect2(player_position, PLAYER_SIZE), Color(0.2, 0.8, 0.7))
	draw_rect(Rect2(player_position, PLAYER_SIZE), Color(0.7, 1.0, 0.95), false, 2.0)
	draw_string(ThemeDB.fallback_font, player_position + Vector2(9, 23), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.02, 0.1, 0.12))

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
	# This scene is launched directly and owns no hosted/joined session.
	# Future Host integration must connect room departure to session cleanup.
	var result := get_tree().change_scene_to_file(LOBBY_SCENE)
	if result != OK:
		leaving = false
		set_physics_process(true)
		status_message.text = "Could not return to the lobby. Try the back arrow again."
		status_message.show()
