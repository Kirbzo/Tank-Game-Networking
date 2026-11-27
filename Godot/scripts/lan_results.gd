extends Control
## Local Duel's result layout, with networking permissions supplied by the room.
signal replay_requested
signal lobby_requested
var replay_button: Button

func label_in(box: VBoxContainer, text: String, size: int, color := Color("#eef8ff")) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
	return label

func button_in(box: VBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	box.add_child(button)
	return button

func build(winner: int, players: Array, summary: Dictionary, hosting: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Button", Color("#eef8ff"))
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#214d50") if key == "normal" else Color("#356e71")
		if key == "disabled":
			style.bg_color = Color("#19272f")
		style.set_corner_radius_all(8)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		style.set_border_width_all(1)
		style.border_color = Color("#ffd890") if key == "focus" else Color("#668fab")
		if key == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(3)
		theme.set_stylebox(key, "Button", style)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.09, 0.78)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102f3c")
	style.border_color = Color("#7fb9c9")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 12
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 560
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	label_in(box, "PLAYER %d WINS!" % winner if winner > 0 else "NO WINNER", 46, Color("#ffd890"))
	label_in(box, "Winner: Player %d" % winner if winner > 0 else "Winner: None", 25, Color("#a6dfff"))
	var seconds := int(summary.get("elapsed", 0))
	label_in(box, "%d / %d bricks cleared   |   %d shots fired\nTime played: %02d:%02d" % [int(summary.get("cleared", 0)), int(summary.get("total", 35)), int(summary.get("shots", 0)), seconds / 60, seconds % 60], 21)
	for i in range(players.size()):
		var values: Dictionary = players[i]
		var colors := [Color("#8fd5ff"), Color("#e3b7ff"), Color("#9aff7a"), Color("#ffb86b")]
		label_in(box, "Player %d: %d health / %d lives" % [i + 1, int(values.get("health", 0)), int(values.get("lives", 0))], 20, colors[mini(i, colors.size() - 1)])
	replay_button = button_in(box, "Play Again")
	replay_button.disabled = not hosting
	replay_button.tooltip_text = "" if hosting else "Waiting for host to play again"
	replay_button.pressed.connect(func(): replay_requested.emit())
	if hosting:
		replay_button.grab_focus()
	var back := button_in(box, "Return to Lobby")
	back.pressed.connect(func(): lobby_requested.emit())
	if not hosting:
		back.grab_focus()
	var confetti := preload("res://scripts/confetti.gd").new()
	confetti.name = "VictoryConfetti"
	add_child(confetti)
	move_child(confetti, 1)
