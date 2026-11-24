extends "res://tests/combined_smoke.gd"
## Paired actual ENet test via application.tscn, Play, Host/Join, Ready and Start.
func aim(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = lobby.active_room.artwork.to_global(at)
	root.push_input(motion, true)
	Input.flush_buffered_events()

func fire_once() -> void:
	fire_button(true)
	await create_timer(0.10).timeout
	fire_button(false)

func fire_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = lobby.active_room.aim_pointer
	event.pressed = pressed
	root.push_input(event, true)

