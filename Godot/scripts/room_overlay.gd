extends Control
## HUD-only artwork; the host owns countdown steps and gameplay transitions.
const PANEL = preload("res://assets/menu_panel.svg")
var room: Control
var pulse := 0.0
var last_number := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if room.countdown_number != last_number:
		last_number = room.countdown_number
		pulse = 0.0
	pulse = minf(pulse + delta, 1.0)
	queue_redraw()

func crosshair_visible() -> bool:
	return room.controls_active() and not room.leaving and not room.pointer_over_room_button() and Rect2(Vector2.ZERO, size).has_point(room.aim_pointer)

func _draw() -> void:
	if crosshair_visible():
		var mouse: Vector2 = get_global_transform_with_canvas().affine_inverse() * room.aim_pointer
		# The original client's reticle, with a pale outline for ice and dark foliage.
		for width in [3.5, 1.5]:
			var tint := Color("#eefaff") if width > 2 else Color("#285879")
			draw_arc(mouse, 10, 0, TAU, 32, tint, width, true)
			for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(mouse + direction * 6, mouse + direction * 16, tint, width, true)
	if room.phase != "countdown":
		return
	var center := size / 2.0
	var scale_factor := minf(size.x / 1280.0, size.y / 800.0) * (1.0 + 0.14 * pow(1.0 - minf(pulse / 0.35, 1.0), 3))
	draw_set_transform(center, 0, Vector2.ONE * scale_factor)
	draw_texture_rect(PANEL, Rect2(-150, -125, 300, 250), false)
	var font := ThemeDB.fallback_font
	var title := "GET READY"
	draw_string(font, Vector2(-font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x / 2, -65), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#a6dfff"))
	var number := str(room.countdown_number)
	var at := Vector2(-font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 108).x / 2, 48)
	draw_string_outline(font, at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 108, 6, Color("#193b50"))
	draw_string(font, at, number, HORIZONTAL_ALIGNMENT_LEFT, -1, 108, Color("#ffd66b"))
	for i in range(3):
		draw_circle(Vector2((i - 1) * 26, 86), 5, Color("#a6dfff") if i < room.countdown_number else Color("#285879"))
	draw_set_transform(Vector2.ZERO)

