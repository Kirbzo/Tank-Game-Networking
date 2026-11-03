extends Control
## Separate modal screen; the existing lobby UI is hidden, never rebuilt.
signal retry_requested
signal back_requested
signal timed_out
signal cancel_requested

const JOIN_TIMEOUT_SECONDS := 30.0

var title: Label
var status: Label
var countdown: Label
var indicator: ProgressBar
var retry_button: Button
var back_button: Button
var cancel_button: Button
var timeout := Timer.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	countdown = Label.new()
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(countdown)
	indicator = ProgressBar.new()
	indicator.step = 0.01
	indicator.custom_minimum_size = Vector2(400, 20)
	indicator.show_percentage = false
	column.add_child(indicator)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(func(): cancel_requested.emit())
	column.add_child(cancel_button)
	retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.pressed.connect(func(): retry_requested.emit())
	column.add_child(retry_button)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(func(): back_requested.emit())
	column.add_child(back_button)
	timeout.one_shot = true
	timeout.wait_time = JOIN_TIMEOUT_SECONDS
	timeout.timeout.connect(func():
		update_progress()
		timed_out.emit()
	)
	add_child(timeout)

func begin() -> void:
	show()
	title.text = "Joining Game..."
	status.text = "Please wait while we connect you to the game server..."
	indicator.value = 0
	indicator.show()
	countdown.show()
	cancel_button.show()
	retry_button.hide()
	back_button.hide()
	timeout.start()
	update_progress()

func show_connected(game_id: String) -> void:
	timeout.stop()
	cancel_button.hide()
	countdown.hide()
	status.text = "Connected to game %s. Back returns to the lobby without disconnecting." % game_id
	indicator.hide()
	retry_button.hide()
	back_button.show()
	back_button.grab_focus()

func show_failure() -> void:
	timeout.stop()
	cancel_button.hide()
	title.text = "Unable to join the game."
	status.text = "Please try again."
	indicator.hide()
	countdown.hide()
	retry_button.show()
	back_button.show()
	retry_button.grab_focus()

func update_progress() -> void:
	var remaining := timeout.time_left
	indicator.value = 100.0 * (1.0 - remaining / JOIN_TIMEOUT_SECONDS)
	countdown.text = "Connecting: %d seconds remaining (closes if unable to connect)" % int(ceil(remaining))

func _process(_delta: float) -> void:
	if visible and indicator.visible:
		update_progress()
