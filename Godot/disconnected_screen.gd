extends Control
## Shared full-screen notice for a lost connection or advertised full room.
signal lobby_requested
var heading := "Disconnected"
var hint := "Return to the lobby to join another room."
var message := "The host disconnected or closed the room."
var title: Label
var explanation: Label
var return_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	title = Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	explanation = Label.new()
	explanation.text = message + " " + hint
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(explanation)
	return_button = Button.new()
	return_button.text = "Return to Lobby"
	return_button.custom_minimum_size.y = 56
	return_button.pressed.connect(func(): lobby_requested.emit())
	column.add_child(return_button)
	return_button.grab_focus()
