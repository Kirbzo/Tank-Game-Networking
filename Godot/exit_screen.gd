extends Control
## Shown after the lobby disconnects; future main-screen routing is deferred.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	var message := Label.new()
	message.text = "Exiting game..."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(message)
